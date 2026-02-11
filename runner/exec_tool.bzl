"""Rule to build a tool for the execution platform."""

def _exec_tool_impl(ctx):
    # Get the tool built for exec configuration
    tool_info = ctx.attr.tool[DefaultInfo]
    tool_exe = tool_info.files_to_run.executable
    
    # On some platforms (e.g., Windows), a tool may have multiple output files
    # (e.g., py_binary creates both launcher.exe and launcher script).
    # Create symlinks for all of them to preserve the full tool structure.
    symlinks = []
    executable_symlink = None
    
    for src_file in tool_info.files.to_list():
        # Preserve file names in a subdirectory to avoid conflicts
        print("Creating symlink for tool output: {}".format(src_file))
        symlink = ctx.actions.declare_file(ctx.label.name + "/" + src_file.basename)
        ctx.actions.symlink(
            output = symlink,
            target_file = src_file,
        )
        symlinks.append(symlink)
        
        # Track which symlink corresponds to the primary executable
        if src_file == tool_exe:
            executable_symlink = symlink
    
    print("Executable symlink for tool output: {}".format(executable_symlink))
    if not executable_symlink:
        fail("Executable not found in tool outputs")
    
    return [DefaultInfo(
        executable = executable_symlink,
        files = depset(symlinks),
        runfiles = tool_info.default_runfiles,
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
