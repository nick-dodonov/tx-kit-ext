"""Build rule for creating multi-platform binaries based on the same source and available in the same execution environment."""

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")

load("@emsdk//emscripten_toolchain:wasm_rules.bzl", "wasm_cc_binary")

load(":run_wrapper_cmd.bzl", "make_run_wrapper_cmd")
load(":tx_common.bzl", "tx_cc")


def _multi_binary_impl(name, visibility, **kwargs):
    #TODO: exclude attribute from inheritence
    if kwargs.pop("target_compatible_with", None) != None:
        fail("multi_binary does not support target_compatible_with attribute")

    kwargs["copts"] = tx_cc.get_copts(kwargs.pop("copts", []))
    kwargs["cxxopts"] = tx_cc.get_cxxopts(kwargs.pop("cxxopts", []))
    kwargs["linkopts"] = tx_cc.get_linkopts(kwargs.pop("linkopts", []))

    # Current target configuration platform binary
    cc_binary(
        name = "{}-host".format(name),
        visibility = visibility,
        target_compatible_with = select({
            "@platforms//cpu:wasm32": ["@platforms//:incompatible"],
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

    # Alias to simplify build/run for current target platform
    native.alias(
        name = name,
        visibility = visibility,
        actual = select({
            "//conditions:default": ":{}-host".format(name),
            "@platforms//cpu:wasm32": ":{}-wasm.cmd".format(name),
        }),
    )


# https://bazel.build/extending/macros
multi_binary = macro(
    inherit_attrs = native.cc_binary,
    implementation = _multi_binary_impl,
    attrs = {},
)
