"""Build rule for creating multi-platform binaries based on the same source and available in the same execution environment."""

load("@emsdk//emscripten_toolchain:wasm_rules.bzl", "wasm_cc_binary")
load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
load("@rules_android//rules:rules.bzl", "android_binary")
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_test.bzl", "cc_test")
load(":filter_deps.bzl", "droid_top_manifest")
load(
    ":multi_common.bzl",
    "multi_common",
    "build_platform_select_dict",
    "validate_platforms",
)
load(":run_wrapper_cmd.bzl", "run_wrapper_cmd")
load(":cc_common.bzl", "cc_common")
load(
    ":embedded.bzl",
    "embedded_files",
    "host_embedded_data",
)

# Android library to wrap execution of cc_library, allowing to declare simple main() function in C++ app
_DROID_GLUE_LIB = Label("//rules/droid:droid_glue")

# Common attributes shared between multi_app and multi_test
_COMMON_ATTRS = multi_common.get_common_attrs() | {
    "droid_deps": attr.label_list(
        default = [_DROID_GLUE_LIB],
        doc = "Labels for Android dependencies (i.e. glue libraries). Default is NativeActivity glue.",
    ),
}

# cc_binary-only attributes to exclude when creating cc_library for droid
_CC_BINARY_ONLY_ATTRS = [
    "args",
    "distribs",
    "dynamic_deps",
    "env",
    "link_extra_lib",
    "linkshared",
    "malloc",
    "nocopts",
    "output_licenses",
    "reexport_deps",
    "stamp",
]

# cc_test-only attributes to exclude when creating cc_binary/cc_library for wasm/droid
_CC_TEST_ONLY_ATTRS = [
    "env_inherit",
    "flaky",
    "local",
    "shard_count",
    "size",
    "timeout",
]

def _multi_app_impl(name, visibility, **kwargs):
    #TODO: exclude attribute from inheritence
    if kwargs.pop("target_compatible_with", None) != None:
        fail("multi_app does not support target_compatible_with attribute")

    is_test = kwargs.pop("is_test")

    enabled_platforms = kwargs.pop("platforms", ["host", "wasm", "droid"])
    embedded_data = kwargs.pop("embedded_data", None)

    # Extract Android-specific attributes
    droid_kwargs = multi_common.pop_droid_kwargs(kwargs)
    droid_deps = kwargs.pop("droid_deps")

    tags = kwargs.pop("tags", [])
    if tags == None:
        tags = []
    tags = tags + ["multi"]  # Tag to identify multi_app/test targets in test filters, etc.

    # Validate platforms parameter
    validate_platforms(enabled_platforms)

    kwargs["copts"] = cc_common.get_copts(kwargs.pop("copts", []))
    kwargs["cxxopts"] = cc_common.get_cxxopts(kwargs.pop("cxxopts", []))
    kwargs["linkopts"] = cc_common.get_linkopts(kwargs.pop("linkopts", []))
    kwargs["features"] = cc_common.get_features(kwargs.pop("features", []))

    test_targets = []

    ################################################################
    # Extract and filter deps for C++ targets (cc_library)
    # Android deps may include android_library targets, so filter to only CcInfo
    all_deps = kwargs.pop("deps", [])
    kwargs["deps"] = multi_common.get_cc_deps(name, all_deps)

    ################################################################
    # Current target configuration platform binary
    if "host" in enabled_platforms:
        host_embedded_data(
            name = "{}-host.data".format(name),
            embedded_data = embedded_data,
            deps = all_deps,  # pass deps to be able to collect transitive embedded files
        )

        # cc_test does not have cc_binary-only attrs (output_licenses, etc.)
        host_kwargs = {k: v for k, v in kwargs.items() if not (is_test and k in _CC_BINARY_ONLY_ATTRS)}
        host_data = host_kwargs.pop("data") or []
        host_data = [":{}-host.data".format(name)] + host_data  # Include embedded files in runfiles for host

        host_cc_rule = cc_test if is_test else cc_binary
        host_cc_rule(
            name = "{}-host".format(name),
            tags = tags + ["host"],
            target_compatible_with = HOST_CONSTRAINTS,
            visibility = visibility,
            data = host_data,
            **host_kwargs
        )
        test_targets.append(":{}-host".format(name))

    ################################################################
    # WASM specific targets with runner wrapper
    if "wasm" in enabled_platforms:
        wasm_kwargs = {k: v for k, v in kwargs.items() if k not in (_CC_TEST_ONLY_ATTRS if is_test else [])}
        cc_binary(
            name = "{}-wasm.tar".format(name),
            target_compatible_with = ["@platforms//cpu:wasm32"],
            **cc_common.get_wasm_cc_kwargs(wasm_kwargs)
        )

        wasm_cc_binary(
            name = "{}-wasm.dir".format(name),
            cc_target = ":{}-wasm.tar".format(name),
            visibility = visibility,
        )

        run_wrapper_cmd(
            name = "{}-wasm".format(name),
            bin_target = ":{}-wasm.dir".format(name),
            tags = tags + ["wasm"],
            is_test = is_test,
            visibility = visibility,
        )
        test_targets.append(":{}-wasm".format(name))

    ################################################################
    # Droid (Android) specific targets with runner wrapper
    if "droid" in enabled_platforms:
        droid_name = "{}-droid".format(name)

        droid_lib_exclude = _CC_BINARY_ONLY_ATTRS + (_CC_TEST_ONLY_ATTRS if is_test else [])
        droid_lib_kwargs = {k: v for k, v in kwargs.items() if k not in droid_lib_exclude}
        cc_library(
            name = "{}.lib".format(droid_name),
            target_compatible_with = ["@platforms//os:android"],
            alwayslink = is_test,  # Prevent linker from stripping test registration code
            **droid_lib_kwargs
        )

        droid_deps = [":{}.lib".format(droid_name)] + all_deps + droid_deps

        # If no custom manifest provided - use topmost manifest from dependencies:
        # So it defaults to AndroidManifest.xml from droid_glue library, but can also be overridden in another deps
        if droid_kwargs['manifest'] == None:
            droid_top_manifest(
                name = "{}.manifest".format(droid_name),
                deps = droid_deps,
            )
            droid_kwargs['manifest'] = ":{}.manifest".format(droid_name)

        droid_apk_name = "{}-apk".format(droid_name)
        android_binary(
            name = droid_apk_name,
            visibility = visibility,
            deps = droid_deps,
            manifest_values = {
                "native_lib_name": droid_apk_name,  # android_binary rule makes lib{droid_apk_name}.so from cc_library deps
            },
            **droid_kwargs
        )

        run_wrapper_cmd(
            name = droid_name,
            tags = tags + ["droid", "exclusive"],  # exclusive: prevent parallel execution with other tests (emulator conflict)
            visibility = visibility,
            bin_target = ":{}".format(droid_apk_name),
            is_test = is_test,
        )
        test_targets.append(":{}".format(droid_name))

    ################################################################
    # Default alias for current target platform
    if is_test:
        # Build test list dynamically based on enabled platforms
        native.test_suite(
            name = name,
            tags = tags,
            visibility = visibility,
            tests = test_targets,
        )
    else:
        # Alias to simplify build/run for current target platform
        select_dict = build_platform_select_dict(name, enabled_platforms)
        native.alias(
            name = name,
            visibility = visibility,
            actual = select(select_dict),
        )

# https://bazel.build/extending/macros
multi_app = macro(
    inherit_attrs = native.cc_binary,
    implementation = _multi_app_impl,
    attrs = _COMMON_ATTRS | {
        "is_test": attr.bool(default = False, configurable = False),
    },
)

multi_test = macro(
    inherit_attrs = native.cc_test,
    implementation = _multi_app_impl,
    attrs = _COMMON_ATTRS | {
        "is_test": attr.bool(default = True, configurable = False),
    },
)
