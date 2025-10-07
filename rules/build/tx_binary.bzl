"""Starlark build definitions for tx_binary using cc_binary."""

load("@emsdk//emscripten_toolchain:wasm_rules.bzl", "wasm_cc_binary")
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load(":tx_common.bzl", "merge_copts", "merge_linkopts")

def tx_binary(name, *args, **kwargs):
    """Creates a multi-platform binary target that works for native and WASM platforms.

    Args:
        name: The name of the target.
        *args: Additional arguments passed to cc_binary.
        **kwargs: Additional keyword arguments passed to cc_binary.
    """

    # Merge user options with defaults
    user_copts = kwargs.pop("copts", [])
    user_linkopts = kwargs.pop("linkopts", [])
    merged_copts = merge_copts(user_copts)
    merged_linkopts = merge_linkopts(user_linkopts)

    # Бинарник целевой сборки
    cc_binary(
        name = name + "-bin",
        copts = merged_copts,
        linkopts = merged_linkopts,
        *args,
        **kwargs
    )

    # Unpack WASM targets
    wasm_cc_binary(
        name = name + "-wasm",
        cc_target = ":" + name + "-bin",
        visibility = ["//visibility:public"],
        target_compatible_with = ["@platforms//cpu:wasm32"],
    )

    # Make WASM runner target
    # Используем Label для получения пути относительно текущего .bzl файла
    runner_script = Label(":run-wasm.sh")
    sh_binary(
        name = name + "-wasm-runner",
        srcs = [runner_script],
        args = ["$(execpaths :" + name + "-wasm)"],
        data = [":" + name + "-wasm"],
        visibility = ["//visibility:public"],
        target_compatible_with = ["@platforms//cpu:wasm32"],
    )

    # Create alias to run target similarly on native and WASM platforms
    native.alias(
        name = name,
        actual = select({
            "@platforms//cpu:wasm32": ":" + name + "-wasm-runner",
            "//conditions:default": ":" + name + "-bin",
        }),
        visibility = ["//visibility:public"],
    )
