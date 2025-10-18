"""Build definitions for tx_test rule (cc_test wrapper w/ default build settings for multi-platform runs)."""

load("@emsdk//emscripten_toolchain:wasm_rules.bzl", "wasm_cc_binary")
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@rules_shell//shell:sh_test.bzl", "sh_test")
load(":tx_common.bzl", "log_warning", "tx_cc")

def tx_test(name, **kwargs):
    """Creates a multi-platform test target w/ default tx build options.

    Args:
        name: The name of the target.
        **kwargs: Additional keyword arguments passed to cc_test.
    """
    cc_test(
        name = name,
        copts = tx_cc.get_copts(kwargs.pop("copts", [])),
        cxxopts = tx_cc.get_cxxopts(kwargs.pop("cxxopts", [])),
        linkopts = tx_cc.get_linkopts(kwargs.pop("linkopts", [])),
        size = kwargs.pop("size", "small"),
        testonly = True,
        visibility = ["//visibility:private"],
        **kwargs
    )


# OBSOLETE Just keep it for reference.
#   --run_under is much simpler now with exec transition support in Bazel and
#   doesn't require to replace standard cc_test/cc_binary rules.
# TODO: Remove file in future when another build extension will be created.
def tx_test_old(name, **kwargs):
    """Creates a multi-platform test target that works for native and WASM platforms.

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
    test_size = kwargs.pop("size", "small")

    # Native test binary - not a test target itself, just a compilation target
    cc_binary(
        name = name + "-bin",
        copts = tx_cc.get_copts(kwargs.pop("copts", [])),
        cxxopts = tx_cc.get_cxxopts(kwargs.pop("cxxopts", [])),
        linkopts = tx_cc.get_linkopts(kwargs.pop("linkopts", [])),
        size = test_size,
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
