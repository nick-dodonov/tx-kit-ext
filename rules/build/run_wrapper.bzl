load("@rules_python//python:defs.bzl", "py_binary", "py_test")
load(":exec_binary.bzl", "exec_binary", "exec_test")

# Shared attributes for both rule and macro
_SHARED_ATTRS = {
    "target_binary": attr.label(
        mandatory = True,
        doc = "The binary target label (path resolved at runtime)",
    ),
    "target_args": attr.string_list(
        default = [],
        doc = "Arguments to pass to the target binary when running",
    ),
}

# https://bazel.build/extending/rules
def _run_wrapper_script_impl(ctx):
    # Get label info without accessing file to avoid creating dependency
    target_label = ctx.attr.target_binary.label
    
    # Construct expected binary path from label (package + name)
    # For //test/log:log -> test/log/log
    if target_label.package:
        binary_path = target_label.package + "/" + target_label.name
    else:
        binary_path = target_label.name

    wrapper_script = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(
        output = wrapper_script,
        content = """#!/usr/bin/env python3
import sys
import pathlib
import runner

# Target binary: {target_label}
options = runner.Options(
    file=pathlib.Path("{binary_path}"),
    args={target_args} + sys.argv[1:],
)

if __name__ == "__main__":
    runner.start(options)
""".format(
            target_label = str(target_label),
            binary_path = binary_path,
            target_args = ctx.attr.target_args,
        ),
        is_executable = True,
    )
    # Don't include target_binary in runfiles here - it will be added by exec_binary via data
    runfiles = ctx.runfiles()

    return [DefaultInfo(
        executable = wrapper_script,
        runfiles = runfiles,
    )]

run_wrapper_script = rule(
    implementation = _run_wrapper_script_impl,
    attrs = _SHARED_ATTRS,
    executable = True,
)

# https://bazel.build/extending/macros
def _run_wrapper_impl(name, visibility, target_binary, target_args, tags, is_test):
    wrapper_script_name = "{}.py".format(name)
    run_wrapper_script(
        name = wrapper_script_name,
        target_binary = target_binary,
        target_args = target_args,
        testonly = is_test,
        visibility = ["//visibility:private"],
    )

    # Create py_binary/py_test with internal name - these will be built in exec config
    py_target_name = "{}_py".format(name)
    
    if not is_test:
        py_binary(
            name = py_target_name,
            srcs = [":{}".format(wrapper_script_name)],
            main = ":{}".format(wrapper_script_name),
            deps = [Label("//runner:lib")],
            tags = tags,
            visibility = ["//visibility:private"],
        )
        # Wrap with exec_binary to force building in exec configuration
        # Pass target_binary through data to keep it in target configuration
        exec_binary(
            name = name,
            binary = ":{}" .format(py_target_name),
            data = target_binary,
            visibility = visibility,
        )
    else:
        py_test(
            name = py_target_name,
            srcs = [":{}".format(wrapper_script_name)],
            main = ":{}".format(wrapper_script_name),
            deps = [Label("//runner:lib")],
            tags = tags,
            visibility = ["//visibility:private"],
            testonly = True,
        )
        # Wrap with exec_test to force building in exec configuration
        # Pass target_binary through data to keep it in target configuration
        exec_test(
            name = name,
            binary = ":{}" .format(py_target_name),
            data = target_binary,
            visibility = visibility,
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
