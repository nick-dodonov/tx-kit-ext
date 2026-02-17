load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("@rules_shell//shell:sh_test.bzl", "sh_test")

_runner_target = Label("//runner:runner")
_sh_wrapper_target = Label("//runner:sh_wrapper.cmd")


def generate_run_wrapper_script(name, bin_target, testonly=False):
    """Generate simple script for running a binary target via the runner target from rootpath.

    NOTE:
        It cannot be used directly for execution without runfiles. 
        So it must be wrapped with sh_binary or sh_test with runner and binary targets in data.
    """
    native.genrule(
        name = "{}.genrule".format(name),
        srcs = [
            _runner_target,
            bin_target,
        ],
        outs = [name],
        cmd = """
# `$${{paths##* }}` is hack selecting the last path from space-separated list of paths,
#   because py_binary on Windows gives launcher .exe and launcher script.
# TODO: select .exe on Windows and script on Unix instead of relying on order in rootpaths
runner_paths='$(rootpaths {runner_target})'
runner_path=$${{runner_paths##* }}

# If there are multiple paths (contains space) we need to select the common directory for them:
#   wasm_cc_binary generates multiple files in the same directory with different extensions.
binary_paths='$(rootpaths {binary_target})'
if [[ "$$binary_paths" == *" "* ]]; then
    first_path=$${{binary_paths%% *}}
    binary_path=$$(dirname "$$first_path")
else
    # Single file: use the file itself (normal binary target, .tar when built with wasm toolchain)
    binary_path="$$binary_paths"
fi

echo $${{runner_path}} $${{binary_path}} > $@
"""
            .format(
                runner_target=_runner_target, 
                binary_target=bin_target,
            ),
        #output_to_bindir = True,
        executable = True,
        testonly = testonly,

        # It anyway requires wrapper (because of runfiles), so only when requested in dependant rule
        tags = ["manual"],
    )


def make_run_wrapper_cmd(name, bin_target, is_test=False, **kwargs):
    """Creates a shell wrapper command for running a binary target via the runner target.
    
    Args:
        name: The name of the binary target to wrap.
        bin_target: The label of the binary target to be executed by the runner.
        is_test: Whether this wrapper must be a test target. Defaults to False.
        **kwargs: Additional keyword arguments passed to sh_binary or sh_test.
    """

    #TODO: possibly can be optimized by single rule that generates wrapper script and runs it without intermediate arguments file
    runner_args_name = "{}.args".format(name)
    generate_run_wrapper_script(
        name = runner_args_name,
        bin_target = bin_target,
        testonly = kwargs.get("testonly", False),
    )

    runner_cmd_name = "{}.cmd".format(name)
    sh_rule = sh_binary if not is_test else sh_test
    sh_rule(
        name = runner_cmd_name,
        srcs = [_sh_wrapper_target],
        data = [
            runner_args_name,
            _runner_target,
            bin_target,
        ],
        #TODO: possibly restrict exec_compatible_with / target_compatible_with to host platforms only (using something as @platforms//os:HOST)
        **kwargs,
    )
