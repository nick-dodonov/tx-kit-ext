"""Creates a wrapper script for executing a binary in host/exec configuration.

Cross-platform solution using cfg=exec for automatic host binary selection.
"""

def _host_wrapper_impl(ctx):
    """Implementation that creates cross-platform wrapper."""
    binary = ctx.attr.binary

    # Get the executable from the binary target (already in exec config)
    binary_files = binary[DefaultInfo].files_to_run
    executable = binary_files.executable

    # Get workspace name for runfiles path
    # Handle both main repo and external repos
    if executable.short_path.startswith("../"):
        # External repository: ../repo_name/path/to/binary
        workspace_name = executable.short_path.split("/")[1]
        binary_short_path = "/".join(executable.short_path.split("/")[2:])
    else:
        # Main repository
        workspace_name = ctx.workspace_name
        binary_short_path = executable.short_path

    # Detect platform from executable extension
    #TODO: use same way as py_binary rule to determine if it's Windows or not, since some platforms may have different executable extensions
    is_windows = executable.extension == "exe"

    if is_windows:
        wrapper = ctx.actions.declare_file(ctx.label.name + ".bat")
        binary_path_win = binary_short_path.replace("/", "\\")
        wrapper_content = """@echo off
REM Generated host binary wrapper
set RUNFILES=%~dp0%~n0.bat.runfiles
"%RUNFILES%\\{workspace}\\{binary_path}" %*
""".format(workspace = workspace_name, binary_path = binary_path_win)
    else:
        wrapper = ctx.actions.declare_file(ctx.label.name + ".sh")
        wrapper_content = """#!/bin/bash
# Generated host binary wrapper
RUNFILES="$(dirname "$0")/$(basename "$0" .sh).sh.runfiles"
exec "$RUNFILES/{workspace}/{binary_path}" $@
""".format(workspace = workspace_name, binary_path = binary_short_path)

    ctx.actions.write(
        output = wrapper,
        content = wrapper_content,
        is_executable = True,
    )

    # Merge runfiles from the original binary
    runfiles = ctx.runfiles(files = [wrapper])
    runfiles = runfiles.merge(binary[DefaultInfo].default_runfiles)

    return [DefaultInfo(
        executable = wrapper,
        files = depset([wrapper]),
        runfiles = runfiles,
    )]

host_wrapper = rule(
    implementation = _host_wrapper_impl,
    attrs = {
        "binary": attr.label(
            executable = True,
            mandatory = True,
            cfg = "exec",
        ),
    },
    executable = True,
)
