load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("@bazel_skylib//rules:native_binary.bzl", "native_binary")
load("@bazel_skylib//rules:native_binary.bzl", "native_test")
load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")

_runner_target = Label("//runner:runner")


def _run_wrapper_args(name, bin_target, testonly=False):
    """Generate arguments script for running a binary target via the runner target from rootpath.

    NOTE:
        It cannot be used directly for execution without runfiles.
        So it must be wrapped with sh_binary/sh_test with runner and binary target in dependencies.
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

_NATIVE_RULE_MODE = True  # Set to False to switch to shell wrapper instead of Skylib native_binary/native_test

def run_wrapper_cmd(name, bin_target, is_test=False, via_skylib=_NATIVE_RULE_MODE, **kwargs):
    """Creates a shell wrapper command for running a binary target via the runner target.
    
    Args:
        name: Target name for the wrapper command.
        bin_target: The label of the binary target to be executed by the runner.
        is_test: Whether this wrapper must be a test target. Defaults to False.
        via_skylib: Whether to use Skylib native_binary/native_test instead of shell wrapper.
        **kwargs: Additional keyword arguments passed to sh_binary or sh_test.
    """
    #TODO: run_wrapper_cmd possibly can be optimized by single rule that generates wrapper script with runfiles 
    #       without intermediate arguments file and binary/test wrapper with data dependencies
    runner_args_name = "{}.args".format(name)
    _run_wrapper_args(
        name = runner_args_name,
        bin_target = bin_target,
        testonly = kwargs.get("testonly", False),
    )

    cmd_name = "{}.cmd".format(name)
    if via_skylib:
        # Skylib native wrapper for running target via runner, to avoid declaring target name with extension (otherwise Windows fails in sh_binary/sh_test)
        # - Not required to declare alias without extension over it to simplify usage
        # - https://github.com/bazelbuild/bazel-skylib/blob/main/docs/native_binary_doc.md
        native_rule = native_binary if not is_test else native_test
        native_rule(
            name = name,
            out = cmd_name,
            src = Label("//runner:sh_wrapper"),
            data = [
                runner_args_name,
                _runner_target,
                bin_target,
            ] + kwargs.pop("data", []),
            exec_compatible_with = HOST_CONSTRAINTS,
            **kwargs,
        )
    else:
        sh_rule = sh_binary if not is_test else sh_test
        sh_rule(
            name = cmd_name,
            srcs = Label("//runner:sh_wrapper"),
            data = [
                runner_args_name,
                _runner_target,
                bin_target,
            ],
            exec_compatible_with = HOST_CONSTRAINTS,
            **kwargs,
        )

        visibility = kwargs.get("visibility", None)
        if is_test:
            native.test_suite(
                name = name,
                tests = [":{}".format(cmd_name)],
                visibility = visibility,
            )
        else:
            native.alias(
                name = name,
                actual = ":{}".format(cmd_name),
                visibility = visibility,
            )

