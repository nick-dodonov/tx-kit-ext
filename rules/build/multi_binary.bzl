load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("@emsdk//emscripten_toolchain:wasm_rules.bzl", "wasm_cc_binary")
load("//rules/build:run_wrapper_cmd.bzl", "generate_run_wrapper_script")

_runner_target = Label("//runner:runner")


def _multi_binary_impl(name, visibility, **kwargs):
    if kwargs["target_compatible_with"] != None:
        fail("multi_binary does not support target_compatible_with attribute")

    kwargs["target_compatible_with"] = select({
        "@platforms//cpu:wasm32": ["@platforms//:incompatible"],
        "//conditions:default": [],
    })
    cc_binary(
        name = "{}-host".format(name),
        visibility = visibility,
        **kwargs,
    )

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

    generate_run_wrapper_script(
        name = "{}-wasm-run.cmd".format(name),
        bin_target = ":{}-wasm".format(name),
    )

    sh_binary(
        name = "{}-wasm.cmd".format(name),
        srcs = ["{}-wasm-run.cmd".format(name)],
        data = [
            _runner_target,
            ":{}-wasm".format(name),
        ],
        visibility = visibility,
    )

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
