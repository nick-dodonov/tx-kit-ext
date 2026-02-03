load("@rules_python//python:defs.bzl", "py_binary", "py_test")


def _run_wrapper_script_impl(ctx):
    target_binary = ctx.file.target_binary

    wrapper_script = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(
        output = wrapper_script,
        content = """#!/usr/bin/env python3
import sys
import runner

target_binary = '{target_binary}'
options = runner.Options(
    platform=runner.Platform('{platform}'),
    file=target_binary,
)
runner.start(options)
""".format(
#RUNNER-BINARY: runner_binary = '{runner_binary}'
            #RUNNER-BINARY: runner_binary = ctx.executable.runner_binary.short_path,
            target_binary = target_binary.short_path,
            platform = ctx.attr.platform,
        ),
        is_executable = True,
    )
    runfiles = ctx.runfiles(files = [
        #RUNNER-BINARY: ctx.executable.runner_binary, 
        target_binary
    ])
    #RUNNER-BINARY: runfiles = runfiles.merge(ctx.attr.runner_binary[DefaultInfo].default_runfiles)

    return [DefaultInfo(
        executable = wrapper_script,
        runfiles = runfiles,
    )]


run_wrapper_script = rule(
    implementation = _run_wrapper_script_impl,
    attrs = {
        #RUNNER-BINARY:
        # "runner_binary": attr.label(
        #     default = Label(":runner"),
        #     executable = True,
        #     cfg = "exec",
        # ),
        "target_binary": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "The binary target to wrap",
        ),
        "platform": attr.string( #TODO: make options configurable
            default = "auto",
            doc = "The platform to run the target binary on (e.g., 'wasm')",
        ),
    },
    executable = True,
)


# https://bazel.build/extending/macros
def _run_wrapper_impl(name, visibility, target_binary, platform, is_test):
    wrapper_script_name = "{}.py".format(name)
    run_wrapper_script(
        name = wrapper_script_name,
        target_binary = target_binary,
        platform = platform,
    )
    if not is_test:
        py_binary(
            name = name,
            srcs = [":{}".format(wrapper_script_name)],
            main = ":{}".format(wrapper_script_name),
            deps = [Label("//runner:runner_lib")],
            visibility = visibility,
        )
    else:
        py_test(
            name = name,
            srcs = [":{}".format(wrapper_script_name)],
            main = ":{}".format(wrapper_script_name),
            deps = [Label("//runner:runner_lib")],
            visibility = visibility,
        )

run_wrapper = macro(
    implementation = _run_wrapper_impl,
    attrs = {
        "target_binary": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "The binary target to wrap",
        ),
        "platform": attr.string( #TODO: make options configurable
            default = "auto",
            doc = "The platform to run the target binary on (e.g., 'wasm')",
        ),
        "is_test": attr.bool(
            default = False, 
            configurable = False, 
            doc = "If true, creates a target wrapper as a test target",
        ),
    },
)
