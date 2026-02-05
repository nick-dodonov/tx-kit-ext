load("@rules_python//python:defs.bzl", "py_binary", "py_test")

# Shared attributes for both rule and macro
_SHARED_ATTRS = {
    "platform": attr.string(
        default = "auto",
        doc = "The platform to run the target binary on (e.g., 'wasm')",
    ),
    "target_binary": attr.label(
        allow_single_file = True,
        mandatory = True,
        doc = "The binary target to wrap",
    ),
    "target_args": attr.string_list(
        default = [],
        doc = "Arguments to pass to the target binary when running",
    ),
}

# https://bazel.build/extending/rules
def _run_wrapper_script_impl(ctx):
    target_binary = ctx.file.target_binary

    wrapper_script = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(
        output = wrapper_script,
        content = """#!/usr/bin/env python3
import sys
import runner

target_binary = "{target_binary}"
options = runner.Options(
    platform=runner.Platform("{platform}"),
    file=target_binary,
    args={target_args} + sys.argv[1:],
)
runner.start(options)
""".format(
#RUNNER-BINARY: runner_binary = '{runner_binary}'
            #RUNNER-BINARY: runner_binary = ctx.executable.runner_binary.short_path,
            target_binary = target_binary.short_path,
            target_args = ctx.attr.target_args,
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
    attrs = _SHARED_ATTRS | {
        #RUNNER-BINARY:
        # "runner_binary": attr.label(
        #     allow_single_file = True,
        #     default = Label(":runner"),
        #     executable = True,
        #     cfg = "exec",
        #     doc = "Optional runner binary to execute the target binary (e.g., for specific platforms)",
        # ),
    },
    executable = True,
)


# https://bazel.build/extending/macros
def _run_wrapper_impl(name, visibility, platform, target_binary, target_args, tags, is_test):
    wrapper_script_name = "{}.py".format(name)
    run_wrapper_script(
        name = wrapper_script_name,
        platform = platform,
        target_binary = target_binary,
        target_args = target_args,
        testonly = is_test,
    )

    if not is_test:
        py_binary(
            name = name,
            srcs = [":{}".format(wrapper_script_name)],
            main = ":{}".format(wrapper_script_name),
            deps = [Label("//runner:runner_lib")],
            tags = tags,
            visibility = visibility,
        )
    else:
        py_test(
            name = name,
            srcs = [":{}".format(wrapper_script_name)],
            main = ":{}".format(wrapper_script_name),
            deps = [Label("//runner:runner_lib")],
            tags = tags,
            visibility = visibility,
            testonly = True,
        )

run_wrapper = macro(
    implementation = _run_wrapper_impl,
    attrs = _SHARED_ATTRS | {
        "tags": attr.string_list(
            default = [],
            configurable = False,
            doc = "Tags to apply to the wrapper target",
        ),
        "is_test": attr.bool(
            default = False,
            configurable = False,
            doc = "If true, creates a target wrapper for test binary target",
        ),
    },
)
