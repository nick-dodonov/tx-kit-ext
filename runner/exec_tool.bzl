"""Rule to build a tool for the execution platform."""

def _exec_tool_impl(ctx):
    # Get the tool built for exec configuration
    tool_info = ctx.attr.tool[DefaultInfo]
    tool_exe = tool_info.files_to_run.executable
    
    # On Windows, py_binary creates both launcher.exe and the launcher script file.
    # The launcher.exe expects the script to be in the same directory.
    # Create symlinks for all generated files, preserving their basenames.
    symlinks = []
    executable_symlink = None
    
    for src_file in tool_info.files.to_list():
        # Skip source files - only symlink generated outputs
        if src_file.is_source:
            continue
        
        # Preserve original basename so files can find each other
        symlink = ctx.actions.declare_file(src_file.basename)

        #print("Creating symlink for tool output: {} -> {}".format(symlink, src_file))
        ctx.actions.symlink(
            output = symlink,
            target_file = src_file,
        )
        symlinks.append(symlink)
        
        # Track which symlink corresponds to the primary executable
        if src_file == tool_exe:
            executable_symlink = symlink
    
    #print("Executable symlink for tool output: {}".format(executable_symlink))
    if not executable_symlink:
        fail("Executable not found in tool outputs")
    
    return [
        DefaultInfo(
            executable = executable_symlink,
            files = depset(symlinks),
            runfiles = tool_info.default_runfiles,
        ),
    ]

exec_tool = rule(
    implementation = _exec_tool_impl,
    attrs = {
        "tool": attr.label(
            executable = True,
            mandatory = True,
            cfg = "exec",
        ),
    },
    executable = True,
)
