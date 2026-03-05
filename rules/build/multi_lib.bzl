"""Build rule for creating multi-platform cc_library for host, wasm, and android.

Creates platform-specific cc_library targets with suffixes (-host, -wasm, -droid)
so build outputs are separated. An alias selects the appropriate variant based on
the current --platforms configuration.
"""

load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

load("@rules_android//rules:rules.bzl", "android_library")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")

load(":tx_common.bzl", "tx_cc")
load(":filter_deps.bzl", "cc_deps_filter")

def _multi_lib_impl(name, visibility, **kwargs):
    # multi_library manages target_compatible_with itself
    if kwargs.pop("target_compatible_with", None) != None:
        fail("multi_library does not support target_compatible_with attribute")

    kwargs["copts"] = tx_cc.get_copts(kwargs.pop("copts", []))
    kwargs["cxxopts"] = tx_cc.get_cxxopts(kwargs.pop("cxxopts", []))

    # Extract and filter deps for C++ targets (cc_library)
    # Android targets may include JavaInfo deps, so we filter to only CcInfo
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

    # Update kwargs to use filtered deps
    kwargs["deps"] = filtered_cc_deps

    ################################################################
    # Host: exclude wasm and android
    cc_library(
        name = "{}-host".format(name),
        visibility = visibility,
        target_compatible_with = select({
            "@platforms//cpu:wasm32": ["@platforms//:incompatible"],
            "@platforms//os:android": ["@platforms//:incompatible"],
            "//conditions:default": [],
        }),
        **kwargs,
    )

    ################################################################
    # WASM
    cc_library(
        name = "{}-wasm".format(name),
        visibility = visibility,
        target_compatible_with = ["@platforms//cpu:wasm32"],
        **kwargs,
    )

    ################################################################
    # Droid (Android NDK)
    cc_library(
        name = "{}-droid".format(name),
        visibility = visibility,
        target_compatible_with = ["@platforms//os:android"],
        **kwargs,
    )

    ################################################################
    # Alias selects variant based on current --platforms
    native.alias(
        name = name,
        actual = select({
            "@platforms//cpu:wasm32": ":{}-wasm".format(name),
            "@platforms//os:android": ":{}-droid".format(name),
            "//conditions:default": ":{}-host".format(name),
        }),
        visibility = visibility,
    )


# https://bazel.build/extending/macros
multi_lib = macro(
    inherit_attrs = native.cc_library,
    implementation = _multi_lib_impl,
    attrs = {
        "deps": attr.label_list(
            providers = [
                [CcInfo],
                [JavaInfo],
            ],
            doc = "Dependencies: cc_library (CcInfo) or android_library/java_library (JavaInfo). Only CcInfo deps are passed to cc_library targets.",
        ),
    },
)
