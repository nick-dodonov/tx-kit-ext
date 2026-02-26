"""Build rule for creating multi-platform binaries based on the same source and available in the same execution environment."""

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_android//rules:rules.bzl", "android_binary")

load("@emsdk//emscripten_toolchain:wasm_rules.bzl", "wasm_cc_binary")

load(":run_wrapper_cmd.bzl", "make_run_wrapper_cmd")
load(":tx_common.bzl", "tx_cc")

_DROID_MAIN_LIB = "//rules/build/droid:droid_main"
_DROID_MANIFEST_TEMPLATE = "//rules/build/droid:AndroidManifest.xml.template"
_DEFAULT_DROID_DEPS = ["@androidndk//:native_app_glue"]
_DEFAULT_DROID_LINKOPTS = [
    "-llog",
    "-landroid",
    "-Wl,--undefined=ANativeActivity_onCreate",
]

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


def _multi_binary_impl(name, visibility, **kwargs):
    #TODO: exclude attribute from inheritence
    if kwargs.pop("target_compatible_with", None) != None:
        fail("multi_binary does not support target_compatible_with attribute")

    droid_linkopts = kwargs.pop("droid_linkopts", None)
    droid_deps = kwargs.pop("droid_deps", None)
    droid_manifest = kwargs.pop("droid_manifest", None)

    kwargs["copts"] = tx_cc.get_copts(kwargs.pop("copts", []))
    kwargs["cxxopts"] = tx_cc.get_cxxopts(kwargs.pop("cxxopts", []))
    kwargs["linkopts"] = tx_cc.get_linkopts(kwargs.pop("linkopts", []))

    # Current target configuration platform binary
    cc_binary(
        name = "{}-host".format(name),
        visibility = visibility,
        target_compatible_with = select({
            "@platforms//cpu:wasm32": ["@platforms//:incompatible"],
            "@platforms//os:android": ["@platforms//:incompatible"],
            "//conditions:default": [],
        }),
        **kwargs,
    )

    # WASM specific targets including runner wrapper
    cc_binary(
        name = "{}-wasm.tar".format(name),
        visibility = visibility,
        target_compatible_with = ["@platforms//cpu:wasm32"],
        **kwargs,
    )

    wasm_cc_binary(
        name = "{}-wasm.dir".format(name),
        cc_target = ":{}-wasm.tar".format(name),
        visibility = visibility,
    )

    make_run_wrapper_cmd(
        name = "{}-wasm.cmd".format(name),
        bin_target = ":{}-wasm.dir".format(name),
        visibility = visibility,
    )

    native.alias(
        name = "{}-wasm".format(name),
        actual = ":{}-wasm.cmd".format(name),
        visibility = visibility,
    )

    # Droid (Android) specific targets including runner wrapper
    droid_name = "{}-droid".format(name)
    droid_deps_final = droid_deps if droid_deps else _DEFAULT_DROID_DEPS
    # Use explicit list; droid_linkopts from inherit_attrs can be select() that resolves empty for android
    droid_linkopts_final = droid_linkopts if droid_linkopts else _DEFAULT_DROID_LINKOPTS

    _droid_exclude = _CC_BINARY_ONLY_ATTRS + ["linkopts", "main"]
    droid_lib_kwargs = {k: v for k, v in kwargs.items() if k not in _droid_exclude}
    droid_lib_kwargs["srcs"] = kwargs.get("srcs", [])
    droid_lib_kwargs["deps"] = kwargs.get("deps", []) + droid_deps_final + [_DROID_MAIN_LIB]

    cc_library(
        name = "{}.lib".format(droid_name),
        visibility = visibility,
        target_compatible_with = ["@platforms//os:android"],
        linkopts = _DEFAULT_DROID_LINKOPTS,
        **droid_lib_kwargs,
    )

    droid_apk_name = "{}-apk".format(droid_name)
    if droid_manifest != None:
        manifest_src = droid_manifest
    else:
        manifest_gen = "{}_manifest".format(droid_name)
        native.genrule(
            name = manifest_gen,
            srcs = [_DROID_MANIFEST_TEMPLATE],
            outs = ["AndroidManifest.xml"],
            cmd = "sed 's/__LIB_NAME__/{}/' $(location {}) > $@".format(
                droid_apk_name,
                _DROID_MANIFEST_TEMPLATE,
            ),
        )
        manifest_src = ":{}".format(manifest_gen)

    android_binary(
        name = droid_apk_name,
        manifest = manifest_src,
        deps = [":{}.lib".format(droid_name)],
        visibility = visibility,
    )

    make_run_wrapper_cmd(
        name = "{}.cmd".format(droid_name),
        bin_target = ":{}-apk".format(droid_name),
        visibility = visibility,
    )

    native.alias(
        name = droid_name,
        actual = ":{}.cmd".format(droid_name),
        visibility = visibility,
    )

    # Alias to simplify build/run for current target platform
    native.alias(
        name = name,
        visibility = visibility,
        actual = select({
            "//conditions:default": ":{}-host".format(name),
            "@platforms//cpu:wasm32": ":{}-wasm.cmd".format(name),
            "@platforms//os:android": ":{}.cmd".format(droid_name),
        }),
    )


# https://bazel.build/extending/macros
multi_binary = macro(
    inherit_attrs = native.cc_binary,
    implementation = _multi_binary_impl,
    attrs = {
        "droid_linkopts": attr.string_list(default = []),
        "droid_deps": attr.label_list(default = []),
        "droid_manifest": attr.label(default = None),
    },
)
