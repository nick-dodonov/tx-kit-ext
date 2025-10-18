"""Build definitions for tx_test rule (cc_test wrapper w/ default build settings for multi-platform runs)."""

load("@rules_cc//cc:cc_test.bzl", "cc_test")
load(":tx_common.bzl", "tx_cc")

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
