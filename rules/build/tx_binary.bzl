"""Build definitions for tx_binary rule (cc_binary wrapper w/ default build settings for multi-platform runs)."""

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load(":tx_common.bzl", "tx_cc")
load(":run_wrapper_cmd.bzl", "make_run_wrapper_cmd")

#TODO: try rewrite using Symbolic Macro https://bazel.build/versions/9.0.0/extending/macros
def tx_binary(name, **kwargs):
    """Creates a multi-platform binary target w/ default tx build options and runner.

    Args:
        name: The name of the target.
        **kwargs: Additional keyword arguments passed to cc_binary.
    """
    bin_name = "{}.bin".format(name)
    cc_binary(
        name = bin_name,
        copts = tx_cc.get_copts(kwargs.pop("copts", [])),
        cxxopts = tx_cc.get_cxxopts(kwargs.pop("cxxopts", [])),
        linkopts = tx_cc.get_linkopts(kwargs.pop("linkopts", [])),
        **kwargs
    )

    cmd_name = "{}.cmd".format(name)
    make_run_wrapper_cmd(
        name = cmd_name,
        bin_target = ":{}".format(bin_name),
        tags = ["manual"],
    )

    native.alias(
        name = name,
        actual = ":{}".format(cmd_name),
        tags = ["manual"],
    )
