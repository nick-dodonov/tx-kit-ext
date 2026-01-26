"""Build definitions for tx_binary rule (cc_binary wrapper w/ default build settings for multi-platform runs)."""

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load(":tx_common.bzl", "tx_cc")

def tx_binary(name, **kwargs):
    """Creates a multi-platform binary target w/ default tx build options.

    Args:
        name: The name of the target.
        **kwargs: Additional keyword arguments passed to cc_binary.
    """
    cc_binary(
        name = name,
        copts = tx_cc.get_copts(kwargs.pop("copts", [])),
        cxxopts = tx_cc.get_cxxopts(kwargs.pop("cxxopts", [])),
        linkopts = tx_cc.get_linkopts(kwargs.pop("linkopts", [])),
        stamp = kwargs.pop("stamp", 1),
        **kwargs
    )
