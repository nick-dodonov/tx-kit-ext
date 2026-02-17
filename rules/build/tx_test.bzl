"""Build definitions for tx_test rule (cc_test wrapper w/ default build settings for multi-platform runs)."""

load("@rules_cc//cc:cc_test.bzl", "cc_test")
load(":tx_common.bzl", "tx_cc")
load(":run_wrapper_cmd.bzl", "make_run_wrapper_cmd")


def tx_test(name, **kwargs):
    """Creates a multi-platform test target w/ default tx build options.

    Args:
        name: The name of the target.
        **kwargs: Additional keyword arguments passed to cc_test.
    """
    size = kwargs.pop("size", "small")
    tags = kwargs.pop("tags", [])

    bin_name = "{}.bin".format(name)
    cc_test(
        name = bin_name,
        copts = tx_cc.get_copts(kwargs.pop("copts", [])),
        cxxopts = tx_cc.get_cxxopts(kwargs.pop("cxxopts", [])),
        linkopts = tx_cc.get_linkopts(kwargs.pop("linkopts", [])),

        size = size,
        testonly = True,
        tags = tags + ["manual"],
        **kwargs
    )

    cmd_name = "{}.cmd".format(name)
    make_run_wrapper_cmd(
        name = cmd_name,
        bin_target = ":{}".format(bin_name),
        is_test = True,

        size = size,
        testonly = True,
        tags = tags + ["manual"],
    )

    # not native.alias allowing to `bazel test` the target
    native.test_suite(
        name = name,
        tests = [":{}".format(cmd_name)],
        tags = tags,
    )
