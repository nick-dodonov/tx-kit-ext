"""Build definitions for tx_test rule (cc_test wrapper w/ default build settings for multi-platform runs)."""

load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("//runner:defs.bzl", "run_wrapper")
load(":tx_common.bzl", "tx_cc")

def tx_test(name, **kwargs):
    """Creates a multi-platform test target w/ default tx build options.

    Args:
        name: The name of the target.
        **kwargs: Additional keyword arguments passed to cc_test.
    """
    bin_name = name
    cc_test(
        name = bin_name,
        copts = tx_cc.get_copts(kwargs.pop("copts", [])),
        cxxopts = tx_cc.get_cxxopts(kwargs.pop("cxxopts", [])),
        linkopts = tx_cc.get_linkopts(kwargs.pop("linkopts", [])),
        visibility = kwargs.get("visibility", ["//visibility:private"]),
        testonly = True,
        **kwargs
    )

    wrapper_tags = kwargs.get("tags", []) + ["manual"]  # add "manual" tag to prevent auto-discovery by test runners
    run_wrapper(
        name = "{}.run".format(name),
        platform = select({
            "@platforms//cpu:wasm32": "wasm",
            "//conditions:default": "auto",
        }),
        target_binary = ":{}".format(bin_name),
        target_args = kwargs.get("args", []),
        tags = wrapper_tags,
        visibility = kwargs.get("visibility", ["//visibility:private"]),
        is_test = True,
    )
