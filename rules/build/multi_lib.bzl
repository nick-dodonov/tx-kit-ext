"""Build rule for creating multi-platform cc_library for host, wasm, and android.

Creates platform-specific cc_library targets with suffixes (-host, -wasm, -droid)
so build outputs are separated. An alias selects the appropriate variant based on
the current --platforms configuration.

For Android platform with Java sources, creates android_library wrapping the cc_library.
"""

load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

load("@rules_android//rules:rules.bzl", "android_library")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")

load(":tx_common.bzl", "tx_cc")
load(":filter_deps.bzl", "cc_deps_filter")
load(":multi_common.bzl", "validate_platforms", "generate_manifest", "build_platform_select_dict")

def _multi_lib_impl(name, visibility, **kwargs):
    # multi_library manages target_compatible_with itself
    if kwargs.pop("target_compatible_with", None) != None:
        fail("multi_library does not support target_compatible_with attribute")

    # Extract Android-specific attributes
    droid_manifest = kwargs.pop("droid_manifest", None)
    droid_srcs = kwargs.pop("droid_srcs", [])
    droid_library = kwargs.pop("droid_library", False)
    enabled_platforms = kwargs.pop("platforms", ["host", "wasm", "droid"])
    
    # Validate platforms parameter
    validate_platforms(enabled_platforms)

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
    if "host" in enabled_platforms:
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
    if "wasm" in enabled_platforms:
        cc_library(
            name = "{}-wasm".format(name),
            visibility = visibility,
            target_compatible_with = ["@platforms//cpu:wasm32"],
            **kwargs,
        )

    ################################################################
    # Droid (Android NDK)
    if "droid" in enabled_platforms:
        droid_name = "{}-droid".format(name)
        
        # Create android_library wrapper when explicitly requested via droid_library
        if droid_library:
            # Create cc_library with .lib suffix (similar to multi_app pattern)
            droid_cc_name = "{}.lib".format(droid_name)
            cc_library(
                name = droid_cc_name,
                visibility = visibility,
                target_compatible_with = ["@platforms//os:android"],
                **kwargs,
            )
            
            # Generate Android manifest if needed (no default template for libraries)
            manifest_src = generate_manifest(
                base_name = droid_name,
                droid_manifest = droid_manifest,
                lib_name = droid_name,
                use_default_template = False,
            )
            
            # Create android_library that wraps cc_library (main target name)
            android_library_kwargs = {
                "name": droid_name,
                "srcs": droid_srcs,
                "deps": [":{}".format(droid_cc_name)] + all_deps,  # cc_library + all deps (CcInfo + JavaInfo)
                "visibility": visibility,
                "target_compatible_with": ["@platforms//os:android"],
            }
            
            # Only add manifest if one was generated
            if manifest_src != None:
                android_library_kwargs["manifest"] = manifest_src
            
            android_library(**android_library_kwargs)
        else:
            # No Java sources: create cc_library with main name (backward compatible)
            cc_library(
                name = droid_name,
                visibility = visibility,
                target_compatible_with = ["@platforms//os:android"],
                **kwargs,
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
        "platforms": attr.string_list(
            default = ["host", "wasm", "droid"],
            configurable = False,
            doc = "List of platforms to build for. Valid values: 'host', 'wasm', 'droid'. Default: all platforms.",
        ),
    },
)
