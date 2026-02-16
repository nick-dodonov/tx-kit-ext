load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
# load(":run_wrapper.bzl", "run_wrapper")

_runner_target = Label("//runner:runner")

def make_run_wrapper_cmd(name, bin_target):
    """Creates a shell wrapper command for running a binary target via the runner target.
    
    Args:
        name: The name of the binary target to wrap.
        bin_target: The label of the binary target to be executed by the runner.
    """

    # run_wrapper(
    #     name = "{}.run".format(name),
    #     target_binary = bin_target,
    #     target_args = kwargs.get("args", []),
    #     tags = kwargs.get("tags", []),
    #     visibility = kwargs.get("visibility", ["//visibility:public"]),
    # )

    #
    # TODO: can be optimized by single rule that generates wrapper script and runs it without intermediate file with arguments
    #   previous attempt in run_wrapper wasn't working because of multiple outputs of py_binary on Windows.
    # 
    runner_args_name = "{}.args".format(name)
    native.genrule(
        name = runner_args_name + "-gen",
        srcs = [
            _runner_target,
            bin_target,
        ],
        outs = [runner_args_name],
        # `${paths##* }` in bash is hack selecting the last path from space-separated list of paths,
        #   because py_binary on Windows gives launcher .exe and launcher script.
        cmd = "paths='$(rootpaths {runner_target})'; echo $${{paths##* }} $(rootpath {bin_target}) > $@"
            .format(
                runner_target=_runner_target, 
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
            _runner_target,
            bin_target,
        ],
        # exec_compatible_with = [
        #     "@platforms//os:windows",
        #     "@platforms//os:macos",
        #     "@platforms//os:linux",
        # ],
        tags = ["manual"],  # only when requested in dependant rules (to avoid spam)
    )
