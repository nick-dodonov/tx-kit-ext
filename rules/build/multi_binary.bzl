"""Build rule for creating multi-platform binaries based on the same source and available in the same execution environment."""

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@emsdk//emscripten_toolchain:wasm_rules.bzl", "wasm_cc_binary")
load(":run_wrapper_cmd.bzl", "make_run_wrapper_cmd")
load(":tx_common.bzl", "tx_cc")


def _multi_binary_impl(name, visibility, **kwargs):
    #print(kwargs)
    kwargs["copts"] = tx_cc.get_copts(kwargs.pop("copts", []))
    kwargs["cxxopts"] = tx_cc.get_cxxopts(kwargs.pop("cxxopts", []))
    kwargs["linkopts"] = tx_cc.get_linkopts(kwargs.pop("linkopts", []))

    #TODO: exclude atribute from inheritence
    if kwargs["target_compatible_with"] != None:
        fail("multi_binary does not support target_compatible_with attribute")

    # Current target configuration platform binary
    kwargs["target_compatible_with"] = select({
        "@platforms//cpu:wasm32": ["@platforms//:incompatible"],
        "//conditions:default": [],
    })
    cc_binary(
        name = "{}-host".format(name),
        visibility = visibility,
        **kwargs,
    )

    # WASM specific targets including runner wrapper
    kwargs["target_compatible_with"] = ["@platforms//cpu:wasm32"]
    cc_binary(
        name = "{}-wasm.tar".format(name),
        visibility = visibility,
        **kwargs,
    )

    wasm_cc_binary(
        name = "{}-wasm".format(name),
        cc_target = ":{}-wasm.tar".format(name),
    )

    make_run_wrapper_cmd(
        name = "{}-wasm.cmd".format(name),
        bin_target = ":{}-wasm".format(name),
    )

    # Alias to simplify build/run for current target platform
    native.alias(
        name = name,
        actual = select({
            "//conditions:default": ":{}-host".format(name),
            "@platforms//cpu:wasm32": ":{}-wasm.cmd".format(name),
        }),
        visibility = visibility,
    )


# https://bazel.build/extending/macros
multi_binary = macro(
    inherit_attrs = native.cc_binary,
    implementation = _multi_binary_impl,
    attrs = {},
)
