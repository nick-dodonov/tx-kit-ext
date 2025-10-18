"""Starlark build definitions for tx_binary rule (cc_binary wrapper allowing to multi-platform runs)."""

# OBSOLETE Just keep it for reference.
#   --run_under is much simpler now with exec transition support in Bazel and
#   doesn't require to replace standard cc_test/cc_binary rules.
# TODO: Remove file in future when another build extension will be created.

load("@emsdk//emscripten_toolchain:wasm_rules.bzl", "wasm_cc_binary")
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load(":tx_common.bzl", "merge_copts", "merge_linkopts", "log_warning")

def tx_binary(name, **kwargs):
    """Creates a multi-platform binary target that works for native and WASM platforms.

    Args:
        name: The name of the target.
        **kwargs: Additional keyword arguments passed to cc_binary.
    """

    log_warning("""tx_binary is obsolete, prefer using standard cc_binary (update copts/linkopts args accordingly) with --run_under and --platforms flags. Example in .bazelrc:
    build:wasm --platforms=@emsdk//:platform_wasm
    build:wasm --extra_toolchains=@bazel_tools//tools/python:autodetecting_toolchain
    test:wasm --run_under="@tx-kit-ext//tools/wasm:runner --"
    run:wasm --run_under="@tx-kit-ext//tools/wasm:runner --"
""")

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
