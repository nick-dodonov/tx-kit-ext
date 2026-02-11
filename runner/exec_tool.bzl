"""Rule to build a tool for the execution platform."""

def _exec_tool_impl(ctx):
    # Get the runner executable from exec configuration  
    runner_info = ctx.attr.tool[DefaultInfo]
    runner_exe = None
    
    # Find the .exe file in the outputs
    for f in runner_info.files.to_list():
        if f.path.endswith(".exe"):
            runner_exe = f
            break
    
    if not runner_exe:
        fail("Could not find .exe in tool outputs")
    
    # Create a shell wrapper that finds runner.exe via runfiles
    wrapper = ctx.actions.declare_file(ctx.label.name + ".bat")
    
    # Compute the workspace-relative path to runner.exe
    # runner_exe.path is like: bazel-out/arm64_windows-opt-exec-.../external/tx-kit-ext+/runner/runner.exe
    # We need to extract the part after "bin/" for runfiles
    workspace_name = ctx.label.workspace_name if ctx.label.workspace_name else "_main"
    runner_workspace = runner_exe.owner.workspace_name if runner_exe.owner else "tx-kit-ext+"
    runner_label_path = "/".join([runner_workspace, "runner", "runner.exe"])
    
    # The wrapper looks for runner in runfiles directory  
    wrapper_content = """@echo off
setlocal EnableDelayedExpansion

rem Find runfiles directory
set RUNFILES=%~dp0host_runner.bat.runfiles
if not exist "!RUNFILES!" (
    echo ERROR: Runfiles directory not found: !RUNFILES!
    exit /b 1
)

rem Run the actual runner.exe from runfiles
"!RUNFILES!\\{runner_runfiles_path}" %*
endlocal
""".format(runner_runfiles_path = runner_label_path.replace("/", "\\\\"))
    
    ctx.actions.write(
        output = wrapper,
        content = wrapper_content,
        is_executable = True,
    )
    
    return [DefaultInfo(
        executable = wrapper,
        files = depset([wrapper, runner_exe]),
        runfiles = ctx.runfiles(files = [runner_exe]).merge(runner_info.default_runfiles),
    )]

exec_tool = rule(
    implementation = _exec_tool_impl,
    attrs = {
        "tool": attr.label(
            mandatory = True,
            cfg = "exec",
            executable = True,
        ),
    },
    executable = True,
)
