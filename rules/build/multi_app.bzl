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
load(":filter_deps.bzl", "cc_deps_filter")

_DROID_GLUE_LIB = Label("//rules/build/droid:droid_glue")
_DROID_MANIFEST_TEMPLATE = Label("//rules/build/droid:template.AndroidManifest.xml")

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
    enabled_platforms = kwargs.pop("platforms", ["host", "wasm", "droid"])
    
    # Validate platforms parameter
    valid_platforms = ["host", "wasm", "droid"]
    for platform in enabled_platforms:
        if platform not in valid_platforms:
            fail("Invalid platform '{}'. Must be one of: {}".format(platform, valid_platforms))
    if len(enabled_platforms) == 0:
        fail("platforms list cannot be empty. Must specify at least one platform: {}".format(valid_platforms))

    kwargs["copts"] = tx_cc.get_copts(kwargs.pop("copts", []))
    kwargs["cxxopts"] = tx_cc.get_cxxopts(kwargs.pop("cxxopts", []))
    kwargs["linkopts"] = tx_cc.get_linkopts(kwargs.pop("linkopts", []))

    # Extract and filter deps for C++ targets (cc_binary, cc_library, cc_test)
    # Android targets need all deps (both CcInfo and JavaInfo), so we keep them separate
    all_deps = kwargs.pop("deps", [])
    if all_deps:
        # Create a filter target to extract only CcInfo deps for C++ targets
        cc_deps_filter_name = "{}.cc_deps".format(name)
        cc_deps_filter(
            name = cc_deps_filter_name,
            deps = all_deps,
            visibility = ["//visibility:private"],
        )
        filtered_cc_deps = [":{}".format(cc_deps_filter_name)]
    else:
        filtered_cc_deps = []

    ################################################################
    # Current target configuration platform binary
    if "host" in enabled_platforms:
        host_cc_rule = cc_test if is_test else cc_binary
        # cc_test does not have cc_binary-only attrs (output_licenses, etc.)
        host_kwargs = {k: v for k, v in kwargs.items() if not (is_test and k in _CC_BINARY_ONLY_ATTRS)}
        host_kwargs["deps"] = filtered_cc_deps

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
        wasm_kwargs["deps"] = filtered_cc_deps
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
        cc_library(
            name = "{}.lib".format(droid_name),
            visibility = visibility,
            target_compatible_with = ["@platforms//os:android"],
            alwayslink = is_test,  # Prevent linker from stripping test registration code
            deps = filtered_cc_deps,
            **droid_lib_kwargs,
        )

        droid_apk_name = "{}-apk".format(droid_name)
        if droid_manifest != None:
            manifest_src = droid_manifest
        else:
            manifest_gen = "{}_manifest".format(droid_name)
            manifest_out = "{}_AndroidManifest.xml".format(droid_name.replace("-", "_"))
            native.genrule(
                name = manifest_gen,
                srcs = [_DROID_MANIFEST_TEMPLATE],
                outs = [manifest_out],
                cmd = "sed 's/__LIB_NAME__/{}/' $(location {}) > $@".format(
                    droid_apk_name,
                    _DROID_MANIFEST_TEMPLATE,
                ),
            )
            manifest_src = ":{}".format(manifest_gen)

        android_binary(
            name = droid_apk_name,
            manifest = manifest_src,
            deps = [
                ":{}.lib".format(droid_name),
                _DROID_GLUE_LIB,
            ] + all_deps,
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
        # Build select() dict dynamically based on enabled platforms
        if len(enabled_platforms) == 1:
            # Single platform: use simple alias without select
            platform = enabled_platforms[0]
            target_name = ":{}-{}".format(name, platform)
            native.alias(
                name = name,
                visibility = visibility,
                actual = target_name,
            )
        else:
            # Multiple platforms: use select() to choose based on current platform
            select_dict = {}
            default_target = None
            
            if "host" in enabled_platforms:
                default_target = ":{}-host".format(name)
            if "wasm" in enabled_platforms:
                select_dict["@platforms//cpu:wasm32"] = ":{}-wasm".format(name)
                if default_target == None:
                    default_target = ":{}-wasm".format(name)
            if "droid" in enabled_platforms:
                select_dict["@platforms//os:android"] = ":{}-droid".format(name)
                if default_target == None:
                    default_target = ":{}-droid".format(name)
            
            select_dict["//conditions:default"] = default_target
            
            native.alias(
                name = name,
                visibility = visibility,
                actual = select(select_dict),
            )


# Common attributes shared between multi_app and multi_test
_COMMON_ATTRS = {
    "droid_manifest": attr.label(default = None),

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
        "deps": attr.label_list(
            providers = [
                [CcInfo],
                [JavaInfo],
            ],
            doc = "Dependencies: cc_library (CcInfo) or android_library/java_library (JavaInfo). All deps are passed to both cc_library and android_binary.",
        ),
    },
)

multi_binary = multi_app

multi_test = macro(
    inherit_attrs = native.cc_test,
    implementation = _multi_app_impl,
    attrs = _COMMON_ATTRS | {
        "is_test": attr.bool(default = True, configurable = False),
        "deps": attr.label_list(
            providers = [
                [CcInfo],
                [JavaInfo],
            ],
            doc = "Dependencies: cc_library (CcInfo) or android_library/java_library (JavaInfo). All deps are passed to both cc_library and android_binary.",
        ),
    },
)
