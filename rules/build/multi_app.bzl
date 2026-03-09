"""Build rule for creating multi-platform binaries based on the same source and available in the same execution environment."""

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

load("@emsdk//emscripten_toolchain:wasm_rules.bzl", "wasm_cc_binary")

load("@rules_android//rules:rules.bzl", "android_binary")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")

load(":run_wrapper_cmd.bzl", "run_wrapper_cmd")
load(":tx_common.bzl", "tx_cc")
load(
    ":filter_deps.bzl",
    "cc_deps_filter",
    "droid_top_manifest",
)
load(":multi_common.bzl", "validate_platforms", "build_platform_select_dict")

# Android library to wrap execution of cc_library, allowing to declare simple main() function in C++ app
_DROID_GLUE_LIB = Label("//rules/build/droid:droid_glue")
# Default Android manifest template for applications
_DROID_GLUE_DEFAULT_MANIFEST = Label("//rules/build/droid:template.AndroidManifest.xml")

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
    droid_manifest = kwargs.pop("droid_manifest", None)
    droid_srcs = kwargs.pop("droid_srcs", [])
    droid_deps = kwargs.pop("droid_deps")
    droid_assets = kwargs.pop("droid_assets", [])
    droid_assets_dir = kwargs.pop("droid_assets_dir", None)
    enabled_platforms = kwargs.pop("platforms", ["host", "wasm", "droid"])
    
    # Validate platforms parameter
    validate_platforms(enabled_platforms)

    kwargs["copts"] = tx_cc.get_copts(kwargs.pop("copts", []))
    kwargs["cxxopts"] = tx_cc.get_cxxopts(kwargs.pop("cxxopts", []))
    kwargs["linkopts"] = tx_cc.get_linkopts(kwargs.pop("linkopts", []))

    ################################################################
    # Extract and filter deps for C++ targets (cc_library)
    # Android deps may include android_library targets, so filter to only CcInfo
    all_deps = kwargs.pop("deps", [])
    if all_deps:
        cc_deps_filter_name = "{}.cc_deps".format(name)
        cc_deps_filter(
            name = cc_deps_filter_name,
            deps = all_deps,
            visibility = ["//visibility:private"],
        )
        cc_deps = [":{}".format(cc_deps_filter_name)]
    else:
        cc_deps = []

    ################################################################
    # Current target configuration platform binary
    if "host" in enabled_platforms:
        host_cc_rule = cc_test if is_test else cc_binary
        # cc_test does not have cc_binary-only attrs (output_licenses, etc.)
        host_kwargs = {k: v for k, v in kwargs.items() if not (is_test and k in _CC_BINARY_ONLY_ATTRS)}
        host_kwargs["deps"] = cc_deps

        host_cc_rule(
            name = "{}-host".format(name),
            visibility = visibility,
            target_compatible_with = select({
                "@platforms//cpu:wasm32": ["@platforms//:incompatible"],
                "@platforms//os:android": ["@platforms//:incompatible"],
                "//conditions:default": [],
            }),
            **host_kwargs,
        )

    ################################################################
    # WASM specific targets with runner wrapper
    if "wasm" in enabled_platforms:
        wasm_kwargs = {k: v for k, v in kwargs.items() if k not in (_CC_TEST_ONLY_ATTRS if is_test else [])}
        wasm_kwargs["deps"] = cc_deps
        wasm_kwargs["features"] = [  # toolchain features
            "exit_runtime",  # runner wrapper needs to exit runtime
        ]
        cc_binary(
            name = "{}-wasm.tar".format(name),
            visibility = visibility,
            target_compatible_with = ["@platforms//cpu:wasm32"],
            **wasm_kwargs,
        )

        wasm_cc_binary(
            name = "{}-wasm.dir".format(name),
            cc_target = ":{}-wasm.tar".format(name),
            visibility = visibility,
        )

        run_wrapper_cmd(
            name = "{}-wasm".format(name),
            bin_target = ":{}-wasm.dir".format(name),
            is_test = is_test,
            visibility = visibility,
        )

    ################################################################
    # Droid (Android) specific targets with runner wrapper
    if "droid" in enabled_platforms:
        droid_name = "{}-droid".format(name)
        
        droid_lib_exclude = _CC_BINARY_ONLY_ATTRS + (_CC_TEST_ONLY_ATTRS if is_test else [])
        droid_lib_kwargs = {k: v for k, v in kwargs.items() if k not in droid_lib_exclude}
        droid_lib_kwargs["deps"] = cc_deps
        cc_library(
            name = "{}.lib".format(droid_name),
            target_compatible_with = ["@platforms//os:android"],
            alwayslink = is_test,  # Prevent linker from stripping test registration code
            **droid_lib_kwargs,
        )

        droid_deps = [":{}.lib".format(droid_name)] + all_deps + droid_deps

        # If no custom manifest provided - use topmost manifest from dependencies:
        # So it defaults to AndroidManifest.xml from droid_glue library, but can also be overridden in another deps
        if droid_manifest == None:
            #droid_manifest = _DROID_GLUE_DEFAULT_MANIFEST
            droid_top_manifest(
                name = "{}.manifest".format(droid_name),
                deps = droid_deps,
            )
            droid_manifest = ":{}.manifest".format(droid_name)

        droid_apk_name = "{}-apk".format(droid_name)
        android_binary(
            name = droid_apk_name,
            srcs = droid_srcs,
            assets = droid_assets,
            assets_dir = droid_assets_dir,
            deps = droid_deps,
            manifest = droid_manifest,
            manifest_values = {
                "native_lib_name": droid_apk_name,  # android_binary rule makes lib{droid_apk_name}.so from cc_library deps
            },
            visibility = visibility,
        )

        run_wrapper_cmd(
            name = "{}".format(droid_name),
            bin_target = ":{}-apk".format(droid_name),
            is_test = is_test,
            visibility = visibility,
        )

    ################################################################
    # Default alias for current target platform
    if is_test:
        # Build test list dynamically based on enabled platforms
        test_targets = []
        if "host" in enabled_platforms:
            test_targets.append(":{}-host".format(name))
        if "wasm" in enabled_platforms:
            test_targets.append(":{}-wasm".format(name))
        if "droid" in enabled_platforms:
            test_targets.append(":{}-droid".format(name))
        
        native.test_suite(
            name = name,
            tests = test_targets,
            visibility = visibility,
        )
    else:
        # Alias to simplify build/run for current target platform
        select_dict = build_platform_select_dict(name, enabled_platforms)
        native.alias(
            name = name,
            visibility = visibility,
            actual = select(select_dict),
        )


# Common attributes shared between multi_app and multi_test
_COMMON_ATTRS = {
    "droid_manifest": attr.label(default = None),
    "droid_srcs": attr.label_list(
        allow_files = [".java", ".srcjar"],
        default = [],
    ),
    "droid_deps": attr.label_list(
        default = [_DROID_GLUE_LIB],
        doc = "Labels for Android dependencies (i.e. glue libraries). Default is NativeActivity glue.",
    ),
    "droid_assets": attr.label_list(
        allow_files = True,
        cfg = "target",
    ),
    "droid_assets_dir": attr.string(),

    "deps": attr.label_list(
        providers = [
            [CcInfo],
            [JavaInfo],
        ],
        doc = "Dependencies: cc_library (CcInfo) or android_library/java_library (JavaInfo). All deps are passed to both cc_library and android_binary.",
    ),
    "platforms": attr.string_list(
        default = ["host", "wasm", "droid"],
        configurable = False,
        doc = "List of platforms to build for. Valid values: 'host', 'wasm', 'droid'. Default: all platforms.",
    ),
}

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
