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
load(":filter_deps.bzl", "droid_top_manifest")
load(
    ":multi_common.bzl",
    "multi_common",
    "build_platform_select_dict",
    "validate_platforms",
)
load(":cc_common.bzl", "cc_common")
load(
    "@tx-kit-ext//rules:embedded.bzl",
    "droid_embedded_assets",
    "wasm_embedded_linkopts_params",
)

def _multi_lib_impl(name, visibility, **kwargs):
    # multi_library manages target_compatible_with itself
    if kwargs.pop("target_compatible_with", None) != None:
        fail("multi_library does not support target_compatible_with attribute")

    enabled_platforms = kwargs.pop("platforms", ["host", "wasm", "droid"])
    embedded_data = kwargs.pop("embedded_data", None)

    # Extract Android-specific attributes
    droid_library = kwargs.pop("droid_library", False)
    droid_manifest = kwargs.pop("droid_manifest", None)
    droid_srcs = kwargs.pop("droid_srcs")
    droid_exports = kwargs.pop("droid_exports")
    droid_custom_package = kwargs.pop("droid_custom_package", None)
    droid_assets = kwargs.pop("droid_assets", [])
    droid_assets_dir = kwargs.pop("droid_assets_dir", None)
    droid_resource_files = kwargs.pop("droid_resource_files", [])

    tags = kwargs.pop("tags", [])
    if tags == None:
        tags = []
    tags = tags + ["multi"]  # Tag to identify multi_app/test targets in test filters, etc.

    # Validate platforms parameter
    validate_platforms(enabled_platforms)

    kwargs["copts"] = cc_common.get_copts(kwargs.pop("copts", []))
    kwargs["cxxopts"] = cc_common.get_cxxopts(kwargs.pop("cxxopts", []))
    kwargs["features"] = cc_common.get_features(kwargs.pop("features", []))

    ################################################################
    # Filters deps to only those providing CcInfo
    all_deps = kwargs.pop("deps", [])
    kwargs["deps"] = multi_common.get_cc_deps(name, all_deps)

    ################################################################
    # Host: exclude wasm and android
    if "host" in enabled_platforms:
        host_kwargs = {k: v for k, v in kwargs.items()}
        host_data = host_kwargs.pop("data") or []  # Include embedded files in runfiles for host
        host_data = host_data + embedded_data

        cc_library(
            name = "{}-host".format(name),
            tags = tags + ["host"],
            target_compatible_with = select({
                "@platforms//cpu:wasm32": ["@platforms//:incompatible"],
                "@platforms//os:android": ["@platforms//:incompatible"],
                "//conditions:default": [],
            }),
            visibility = visibility,
            data = host_data,
            **host_kwargs
        )

    ################################################################
    # WASM
    if "wasm" in enabled_platforms:
        wasm_embedded_linkopts_params(
            name = "{}-wasm.params".format(name),
            embedded_data = embedded_data,
        )

        wasm_kwargs = cc_common.get_wasm_cc_kwargs(kwargs)
        additional_linker_inputs = wasm_kwargs.pop("additional_linker_inputs") or []
        additional_linker_inputs = additional_linker_inputs + [":{}-wasm.params".format(name)]

        wasm_linkopts = wasm_kwargs.pop("linkopts") or []
        wasm_linkopts = wasm_linkopts + ["@$(execpaths :{}-wasm.params)".format(name)]

        cc_library(
            name = "{}-wasm".format(name),
            tags = tags + ["wasm"],
            visibility = visibility,
            target_compatible_with = ["@platforms//cpu:wasm32"],
            additional_linker_inputs = additional_linker_inputs,
            linkopts = wasm_linkopts,
            **wasm_kwargs
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

            #TODO: add assets_dir to droid_embedded_assets rule allowing to setup it
            droid_assets_dir = "assets"
            droid_embedded_assets(
                name = "{}.assets".format(droid_name),
                embedded_data = embedded_data,
            )
            droid_assets = droid_assets + [":{}.assets".format(droid_name)]

            android_library(
                name = droid_name,
                tags = tags + ["droid"],
                srcs = droid_srcs,
                manifest = droid_manifest,
                custom_package = droid_custom_package,
                assets = droid_assets,
                assets_dir = droid_assets_dir,
                resource_files = droid_resource_files,
                deps = droid_deps,
                exports = droid_exports,
                visibility = visibility,
                target_compatible_with = ["@platforms//os:android"],
            )
        else:
            # No Java sources: create cc_library with main name (backward compatible)
            cc_library(
                name = droid_name,
                tags = tags + ["droid"],
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
    attrs = multi_common.get_common_attrs() | {
        "droid_library": attr.bool(
            default = False,
            configurable = False,
            doc = "Set to True to create android_library wrapper for Android platform. Required when droid_* attributes are specified.",
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
    },
)
