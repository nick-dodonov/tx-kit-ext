"""Build rule for creating multi-platform binaries based on the same source and available in the same execution environment."""

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_android//rules:rules.bzl", "android_binary")

load("@emsdk//emscripten_toolchain:wasm_rules.bzl", "wasm_cc_binary")

load(":run_wrapper_cmd.bzl", "make_run_wrapper_cmd")
load(":tx_common.bzl", "tx_cc")

_DROID_GLUE_LIB = "//rules/build/droid:droid_native"
_DROID_MANIFEST_TEMPLATE = "//rules/build/droid:AndroidManifest.xml.template"

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
    wasm_kwargs = {k: v for k, v in kwargs.items()}
    wasm_kwargs["features"] = [  # toolchain features
        "exit_runtime",  # runner wrapper needs to exit runtime
        "use_pthreads",  # threading support w/ boost
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

    droid_lib_kwargs = {k: v for k, v in kwargs.items() if k not in _CC_BINARY_ONLY_ATTRS}
    cc_library(
        name = "{}.lib".format(droid_name),
        visibility = visibility,
        target_compatible_with = ["@platforms//os:android"],
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
        deps = [
            ":{}.lib".format(droid_name),
            _DROID_GLUE_LIB,
        ],
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
        "droid_manifest": attr.label(default = None),
    },
)
