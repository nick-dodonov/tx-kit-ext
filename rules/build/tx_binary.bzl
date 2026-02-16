"""Build definitions for tx_binary rule (cc_binary wrapper w/ default build settings for multi-platform runs)."""

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load(":run_wrapper.bzl", "run_wrapper")
load(":tx_common.bzl", "tx_cc")

#TODO: try rewrite using Symbolic Macro https://bazel.build/versions/9.0.0/extending/macros
def tx_binary(name, **kwargs):
    """Creates a multi-platform binary target w/ default tx build options and runner.

    Args:
        name: The name of the target.
        **kwargs: Additional keyword arguments passed to cc_binary.
    """
    bin_name = name
    cc_binary(
        name = bin_name,
        copts = tx_cc.get_copts(kwargs.pop("copts", [])),
        cxxopts = tx_cc.get_cxxopts(kwargs.pop("cxxopts", [])),
        linkopts = tx_cc.get_linkopts(kwargs.pop("linkopts", [])),
        **kwargs
    )

    # run_wrapper(
    #     name = "{}.run".format(name),
    #     target_binary = ":{}".format(bin_name),
    #     target_args = kwargs.get("args", []),
    #     tags = kwargs.get("tags", []),
    #     visibility = kwargs.get("visibility", ["//visibility:public"]),
    # )

    #
    # TODO: can be optimized by single rule that generates wrapper script and runs it without intermediate file with arguments
    #   previous attempt in run_wrapper wasn't working because of multiple outputs of py_binary on Windows.
    # 
    runner_target = Label("//runner:runner")
    bin_target = ":{}".format(bin_name)

    runner_args_name = "{}.args".format(name)
    native.genrule(
        name = runner_args_name + "-gen",
        srcs = [
            runner_target,
            bin_target,
        ],
        outs = [runner_args_name],
        # `${paths##* }` in bash is hack selecting the last path from space-separated list of paths,
        #   because py_binary on Windows gives launcher .exe and launcher script.
        cmd = "paths='$(rootpaths {runner_target})'; echo $${{paths##* }} $(rootpath {bin_target}) > $@"
            .format(
                runner_target=runner_target, 
                bin_target=bin_target
            ),
        tags = ["manual"],  # only when requested in dependant rules (to avoid spam)
    )

    runner_cmd_name = "{}.cmd".format(name)
    sh_binary(
        name = runner_cmd_name,
        srcs = ["@tx-kit-ext//runner:sh_wrapper.cmd"],
        data = [
            runner_args_name,
            runner_target,
            bin_target,
        ],

        # exec_compatible_with = [
        #     "@platforms//os:windows",
        #     "@platforms//os:macos",
        #     "@platforms//os:linux",
        # ],

        tags = ["manual"],  # only when requested in dependant rules (to avoid spam)
    )
