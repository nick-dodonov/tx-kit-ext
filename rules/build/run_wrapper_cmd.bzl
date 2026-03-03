# load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
# load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("@bazel_skylib//rules:native_binary.bzl", "native_binary")
load("@bazel_skylib//rules:native_binary.bzl", "native_test")

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

# If there are multiple paths (contains space):
#   - Prefer .apk for android_binary (droid)
#   - Else use dirname of first (wasm_cc_binary: multiple files in same directory)
binary_paths='$(rootpaths {binary_target})'
if [[ "$$binary_paths" == *" "* ]]; then
    apk_path=$$(echo "$$binary_paths" | tr ' ' '\\n' | grep '\\.apk$$' | head -1) || true
    if [[ -n "$$apk_path" ]]; then
        binary_path="$$apk_path"
    else
        first_path=$${{binary_paths%% *}}
        binary_path=$$(dirname "$$first_path")
    fi
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
        name: Target name for the wrapper command.
        bin_target: The label of the binary target to be executed by the runner.
        is_test: Whether this wrapper must be a test target. Defaults to False.
        **kwargs: Additional keyword arguments passed to sh_binary or sh_test.
    """
    cmd_name = "{}.cmd".format(name)

    #TODO: run_wrapper_cmd possibly can be optimized by single rule that generates wrapper script with runfiles 
    #       without intermediate arguments file and binary/test wrapper with data dependencies
    runner_args_name = "{}.args".format(cmd_name)
    generate_run_wrapper_script(
        name = runner_args_name,
        bin_target = bin_target,
        testonly = kwargs.get("testonly", False),
    )

    # sh_rule = sh_binary if not is_test else sh_test
    # sh_rule(
    #     name = cmd_name,
    #     srcs = [_sh_wrapper_target],
    #     data = [
    #         runner_args_name,
    #         _runner_target,
    #         bin_target,
    #     ],
    #     **kwargs,
    # )

    # Skylib native wrapper for running target via runner, to avoid declaring target name with extension (otherwise Windows fails in sh_binary/sh_test)
    # - Not required to declare alias without extension over it to simplify usage
    # - https://github.com/bazelbuild/bazel-skylib/blob/main/docs/native_binary_doc.md
    native_rule = native_binary if not is_test else native_test
    native_rule(
        name = name,
        out = cmd_name,
        src = _sh_wrapper_target,
        data = [
            runner_args_name,
            _runner_target,
            bin_target,
        ],
        **kwargs,

        #TODO: possibly restrict exec_compatible_with / target_compatible_with to host platforms
        # target_compatible_with = select({
        #     "@platforms//os:windows": [],
        #     "@platforms//os:linux": [],
        #     "@platforms//os:macos": [],
        #     #"//conditions:default": ["@platforms//:incompatible"],
        # }),
        # tags = ["wasm"],
    )
