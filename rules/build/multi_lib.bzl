"""Build rule for creating multi-platform cc_library for host, wasm, and android.

Creates platform-specific cc_library targets with suffixes (-host, -wasm, -droid)
so build outputs are separated. An alias selects the appropriate variant based on
the current --platforms configuration.

For Android platform with Java sources, creates android_library wrapping the cc_library.
"""

load("@rules_android//rules:rules.bzl", "android_library")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load(
    ":filter_deps.bzl",
    "cc_deps_filter",
    "droid_top_manifest",
)
load(
    ":multi_common.bzl",
    "build_platform_select_dict",
    "validate_platforms",
)
load(":tx_common.bzl", "tx_cc")

def _multi_lib_impl(name, visibility, **kwargs):
    # multi_library manages target_compatible_with itself
    if kwargs.pop("target_compatible_with", None) != None:
        fail("multi_library does not support target_compatible_with attribute")

    # Extract Android-specific attributes
    droid_library = kwargs.pop("droid_library", False)
    droid_manifest = kwargs.pop("droid_manifest", None)
    droid_srcs = kwargs.pop("droid_srcs")
    droid_exports = kwargs.pop("droid_exports")
    droid_custom_package = kwargs.pop("droid_custom_package", None)
    droid_assets = kwargs.pop("droid_assets", [])
    droid_assets_dir = kwargs.pop("droid_assets_dir", None)
    enabled_platforms = kwargs.pop("platforms", ["host", "wasm", "droid"])

    # Validate platforms parameter
    validate_platforms(enabled_platforms)

    kwargs["copts"] = tx_cc.get_copts(kwargs.pop("copts", []))
    kwargs["cxxopts"] = tx_cc.get_cxxopts(kwargs.pop("cxxopts", []))

    ################################################################
    # Extract and filter deps for C++ targets (cc_library)
    # Android deps may include android_library targets, so filter to only CcInfo
    all_deps = kwargs.pop("deps", [])
    if all_deps:
        cc_deps_filter_name = "{}.cc_deps".format(name)
        cc_deps_filter(
            name = cc_deps_filter_name,
            deps = all_deps,
        )
        cc_deps = [":{}".format(cc_deps_filter_name)]
    else:
        cc_deps = []

    # Update kwargs to use filtered deps
    kwargs["deps"] = cc_deps

    ################################################################
    # Host: exclude wasm and android
    if "host" in enabled_platforms:
        cc_library(
            name = "{}-host".format(name),
            target_compatible_with = select({
                "@platforms//cpu:wasm32": ["@platforms//:incompatible"],
                "@platforms//os:android": ["@platforms//:incompatible"],
                "//conditions:default": [],
            }),
            visibility = visibility,
            **kwargs
        )

    ################################################################
    # WASM
    if "wasm" in enabled_platforms:
        cc_library(
            name = "{}-wasm".format(name),
            visibility = visibility,
            target_compatible_with = ["@platforms//cpu:wasm32"],
            **kwargs
        )

    ################################################################
    # Droid (Android NDK)
    if "droid" in enabled_platforms:
        droid_name = "{}-droid".format(name)

        # Create android_library wrapper when explicitly requested via droid_library
        if droid_library:
            droid_cc_name = "{}.lib".format(droid_name)
            cc_library(
                name = droid_cc_name,
                visibility = visibility,
                target_compatible_with = ["@platforms//os:android"],
                **kwargs
            )

            droid_deps = [":{}.lib".format(droid_name)] + all_deps

            if droid_manifest == None:
                droid_top_manifest(
                    name = "{}.manifest".format(droid_name),
                    deps = droid_deps,
                )
                droid_manifest = ":{}.manifest".format(droid_name)

            android_library(
                name = droid_name,
                srcs = droid_srcs,
                manifest = droid_manifest,
                custom_package = droid_custom_package,
                assets = droid_assets,
                assets_dir = droid_assets_dir,
                deps = droid_deps,
                exports = droid_exports,
                visibility = visibility,
                target_compatible_with = ["@platforms//os:android"],
            )
        else:
            # No Java sources: create cc_library with main name (backward compatible)
            cc_library(
                name = droid_name,
                visibility = visibility,
                target_compatible_with = ["@platforms//os:android"],
                **kwargs
            )

    ################################################################
    # Alias selects variant based on current --platforms
    select_dict = build_platform_select_dict(name, enabled_platforms)
    native.alias(
        name = name,
        actual = select(select_dict),
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
        "droid_library": attr.bool(
            default = False,
            configurable = False,
            doc = "Set to True to create android_library wrapper for Android platform. Required when droid_srcs or droid_manifest is specified.",
        ),
        "droid_manifest": attr.label(
            default = None,
            doc = "Optional AndroidManifest.xml template for Android platform. If not provided, android_library is created without explicit manifest.",
        ),
        "droid_srcs": attr.label_list(
            allow_files = [".java", ".srcjar"],
            default = [],
            doc = "Java/Kotlin source files for Android platform. Automatically creates android_library wrapping cc_library.",
        ),
        "droid_exports": attr.label_list(
            providers = [
                [CcInfo],
                [JavaInfo],
            ],
            doc = (
                "The closure of all rules reached via `exports` attributes are considered " +
                "direct dependencies of any rule that directly depends on the target with " +
                "`exports`. The `exports` are not direct deps of the rule they belong to."
            ),
        ),
        "droid_custom_package": attr.string(
            doc = ("Java package for which java sources will be generated. " +
                   "By default the package is inferred from the directory where the BUILD file " +
                   "containing the rule is. You can specify a different package but this is " +
                   "highly discouraged since it can introduce classpath conflicts with other " +
                   "libraries that will only be detected at runtime."),
        ),
        "droid_assets": attr.label_list(
            allow_files = True,
            cfg = "target",
            default = [],
            doc = "Asset files for Android platform. Passed to android_library.",
        ),
        "droid_assets_dir": attr.string(
            doc = "Directory for Android assets. Passed to android_library.",
        ),
        "platforms": attr.string_list(
            default = ["host", "wasm", "droid"],
            configurable = False,
            doc = "List of platforms to build for. Valid values: 'host', 'wasm', 'droid'. Default: all platforms.",
        ),
    },
)
