"""Starlark build definitions for tx_test rule (cc_test wrapper allowing to multi-platform runs)."""

# OBSOLETE Just keep it for reference.
#   --run_under is much simpler now with exec transition support in Bazel and
#   doesn't require to replace standard cc_test/cc_binary rules.
# TODO: Remove file in future when another build extension will be created.

load("@emsdk//emscripten_toolchain:wasm_rules.bzl", "wasm_cc_binary")
load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@rules_shell//shell:sh_test.bzl", "sh_test")
load(":tx_common.bzl", "merge_copts", "merge_linkopts", "log_warning")

def tx_test(name, **kwargs):
    """Creates a multi-platform test target that works for native and WASM platforms.

    The main test target works directly for both native and WASM platforms.
    For WASM, it compiles to WASM binary and can be executed in browser.

    Usage:
    - Native: bazel test //test:name
    - WASM: bazel test //test:name --platforms=@emsdk//:platform_wasm
    - WASM run: bazel run //test:name --platforms=@emsdk//:platform_wasm

    Args:
        name: The name of the target.
        **kwargs: Additional keyword arguments passed to cc_test.
    """

    log_warning("""tx_test is obsolete, prefer using standard cc_test (update copts/linkopts/size args accordingly) with --run_under and --platforms flags. Example in .bazelrc:
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

    # Extract test-specific kwargs that don't apply to cc_binary
    test_size = kwargs.pop("size", "small")
    #TODO: test_timeout = kwargs.pop("timeout", None)
    #TODO: test_flaky = kwargs.pop("flaky", None)
    #TODO: test_shard_count = kwargs.pop("shard_count", None)

    # Native test binary - not a test target itself, just a compilation target
    cc_test(
        name = name + "-bin",
        copts = merged_copts,
        linkopts = merged_linkopts,
        testonly = True,
        visibility = ["//visibility:private"],
        **kwargs
    )

    # Extract WASM results for execution via emrun
    wasm_cc_binary(
        name = name + "-wasm",
        cc_target = ":" + name + "-bin",
        target_compatible_with = ["@platforms//cpu:wasm32"],
        visibility = ["//visibility:public"],
        testonly = True,
    )

    # Main test wrapper - works for both native and WASM platforms
    runner_script = Label(":run-wasm.sh")
    sh_test(
        name = name,
        srcs = select({
            "@platforms//cpu:wasm32": [runner_script],
            "//conditions:default": [":" + name + "-bin"],
        }),
        args = select({
            "@platforms//cpu:wasm32": ["$(execpaths :" + name + "-wasm)"],
            "//conditions:default": [],
        }),
        data = select({
            "@platforms//cpu:wasm32": [":" + name + "-wasm"],
            "//conditions:default": [":" + name + "-bin"],
        }),
        testonly = True,
        size = test_size,
        visibility = ["//visibility:public"],
    )
