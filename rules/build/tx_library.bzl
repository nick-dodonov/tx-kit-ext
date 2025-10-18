"""Build definitions for tx_library rule (cc_library wrapper w/ default build settings for multi-platform libs)."""

load("@rules_cc//cc:defs.bzl", "cc_library")
load(":tx_common.bzl", "tx_cc")

def tx_library(name, **kwargs):
    """Creates a multi-platform library target w/ default tx build options.

    Args:
        name: The name of the target.
        **kwargs: Additional keyword arguments passed to cc_library.
    """
    cc_library(
        name = name,
        copts = tx_cc.get_copts(kwargs.pop("copts", [])),
        cxxopts = tx_cc.get_cxxopts(kwargs.pop("cxxopts", [])),
        **kwargs
    )
