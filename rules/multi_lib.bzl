"""Build rule for creating multi-platform cc_library for host, wasm, and android.

Creates platform-specific cc_library targets with suffixes (-host, -wasm, -droid)
so build outputs are separated. An alias selects the appropriate variant based on
the current --platforms configuration.

For Android platform with Java sources, creates android_library wrapping the cc_library.
"""

load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
load("@rules_android//rules:rules.bzl", "android_library")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load(
    "@tx-kit-ext//rules:embedded.bzl",
    "droid_embedded_assets",
    "wasm_embedded_linkopts_params",
)
load(":cc_common.bzl", "cc_common")
load(":droid_deps.bzl", "droid_all_deps")
load(
    ":multi_common.bzl",
    "build_platform_select_dict",
    "multi_common",
    "validate_platforms",
)

def _droid_default_custom_package(name, package_name):
    # Default android_library behaviour w/o custom_package specified is to automatically resolve it depending on target's path,
    #   it looks for "src", "java", "javatest" in parents (look external/rules_android+/rules/java.bzl).
    # So it fails in android_library w/o custom_package specified for simple targets (i.e. demo/pkg/boot:sublib).
    # Workaround it by defaulting to "tx.<target_name>" package which is valid and unique for each target
    #   (it can be overridden by user via custom_package if needed)
    
    # Android package names cannot contain hyphens (otherwise appt2 cannot generate R.java)
    # Android package must have a prefix (otherwise "attribute 'package' in <manifest> tag is not a valid Android package name: 'sublib'")
    result = "tx.{}".format(name.replace("-", "_"))

    # TODO: think to add target's package_name path as prefix
    #print("{}:{} -> {}".format(package_name, name, result))
    return result

def _multi_lib_impl(name, visibility, **kwargs):
    # multi_library manages target_compatible_with itself
    if kwargs.pop("target_compatible_with", None) != None:
        fail("multi_library does not support target_compatible_with attribute")

    enabled_platforms = kwargs.pop("platforms", ["host", "wasm", "droid"])
    embedded_data = kwargs.pop("embedded_data", None)

    # Extract Android-specific attributes
    droid_exports = kwargs.pop("droid_exports")
    droid_kwargs = multi_common.pop_droid_kwargs(kwargs)

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
        host_data = host_kwargs.pop("data") or [] + embedded_data  # Include embedded files in runfiles for host

        cc_library(
            name = "{}-host".format(name),
            tags = tags + ["host"],
            target_compatible_with = HOST_CONSTRAINTS,
            visibility = visibility,
            data = host_data,
            **host_kwargs
        )

    ################################################################
    # WASM
    if "wasm" in enabled_platforms:
        wasm_embedded_linkopts_params(
            name = "{}-wasm.params".format(name),
            target_compatible_with = ["@platforms//cpu:wasm32"],
            visibility = ["//visibility:private"],
            embedded_data = embedded_data,
        )

        wasm_kwargs = cc_common.get_wasm_cc_kwargs(kwargs)

        wasm_additional_linker_inputs = wasm_kwargs.pop("additional_linker_inputs") or []
        wasm_additional_linker_inputs = wasm_additional_linker_inputs + [":{}-wasm.params".format(name)]

        wasm_linkopts = wasm_kwargs.pop("linkopts") or []
        wasm_linkopts = wasm_linkopts + ["@$(execpaths :{}-wasm.params)".format(name)]

        cc_library(
            name = "{}-wasm".format(name),
            tags = tags + ["wasm"],
            target_compatible_with = ["@platforms//cpu:wasm32"],
            visibility = visibility,
            additional_linker_inputs = wasm_additional_linker_inputs,
            linkopts = wasm_linkopts,
            **wasm_kwargs
        )

    ################################################################
    # Droid (Android NDK)
    if "droid" in enabled_platforms:
        droid_name = "{}-droid".format(name)
        droid_tags = tags + ["droid"]

        # All deps target allowing to provide android_library deps to android_binary in multi_app even via pure cc_library targets.
        droid_all_deps(
            name = "{}.droid_deps".format(droid_name),
            target_compatible_with = ["@platforms//os:android"],
            visibility = ["//visibility:private"],
            all_deps = all_deps,
        )

        cc_kwargs = {k: v for k, v in kwargs.items()}
        cc_data = cc_kwargs.pop("data") or [] + [":{}.droid_deps".format(droid_name)]  # Include custom deps provider to be traversable in android_binary deps closure

        # Create cc_library target for Android platform. It will be wrapped by android_library with the same deps and additional Java sources, resources, etc.
        droid_cc_name = "{}.lib".format(droid_name)
        cc_library(
            name = droid_cc_name,
            target_compatible_with = ["@platforms//os:android"],
            visibility = ["//visibility:private"],
            data = cc_data,
            **cc_kwargs
        )

        # Create android_library target # TODO: if required
        droid_deps = [":{}.lib".format(droid_name)] + all_deps

        if not droid_kwargs.get("custom_package"):
            droid_kwargs["custom_package"] = _droid_default_custom_package(name, native.package_name())

        #TODO: add assets_dir to droid_embedded_assets rule allowing to setup it
        if embedded_data:
            droid_kwargs["assets_dir"] = "assets"
            droid_embedded_assets(
                name = "{}.assets".format(droid_name),
                target_compatible_with = ["@platforms//os:android"],
                visibility = ["//visibility:private"],
                embedded_data = embedded_data,
            )
            droid_kwargs["assets"] = [":{}.assets".format(droid_name)] + (droid_kwargs.get("assets") or [])

        android_library(
            name = droid_name,
            tags = droid_tags,
            target_compatible_with = ["@platforms//os:android"],
            visibility = visibility,
            deps = droid_deps,
            exports = [":{}.lib".format(droid_name)] + droid_exports,
            **droid_kwargs
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
