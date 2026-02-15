"""Rule to build a tool for the execution platform."""

def _exec_binary_impl(ctx):
    # DEBUG: print providers binary can give
    # print("DEBUG: binary:", ctx.attr.binary)

    # Get the tool built for exec configuration
    binary_info = ctx.attr.binary[DefaultInfo]
    binary_exe = binary_info.files_to_run.executable
    
    # Get binary basename without extension for name matching
    binary_basename = binary_exe.basename
    if binary_exe.extension:
        binary_name = binary_basename[:-len(binary_exe.extension)-1]
    else:
        binary_name = binary_basename

    # On Windows, py_binary creates both launcher.exe and the launcher script file.
    # The launcher.exe expects the script to be in the same directory.
    # Rename files matching binary basename to avoid collisions (e.g., runner -> host, runner.exe -> host.exe).
    # This preserves the relationship between launcher and script.
    symlinks = []
    originals = []
    executable_symlink = None
    declared_names = {}  # Track declared names to detect collisions

    for src_file in binary_info.files.to_list():
        # Skip source files - only symlink generated outputs
        if src_file.is_source:
            continue

        # Get source file name without extension
        src_basename = src_file.basename
        if src_file.extension:
            src_name = src_basename[:-len(src_file.extension)-1]
            extension = "." + src_file.extension
        else:
            src_name = src_basename
            extension = ""

        # Rename only if basename matches binary to avoid self-reference collision
        if src_name == binary_name:
            new_basename = ctx.label.name + extension
        else:
            new_basename = src_basename

        # Detect name collisions
        if new_basename in declared_names:
            fail("Output name collision detected: {} (from {} and {})".format(
                new_basename,
                declared_names[new_basename],
                src_file.path
            ))
        declared_names[new_basename] = src_file.path

        symlink = ctx.actions.declare_file(new_basename)

        #print("Creating symlink for tool output: {} -> {}".format(symlink, src_file))
        ctx.actions.symlink(
            output = symlink,
            target_file = src_file,
        )
        symlinks.append(symlink)
        originals.append(src_file)

        # Track which symlink corresponds to the primary executable
        if src_file == binary_exe:
            executable_symlink = symlink

    #print("Executable symlink for tool output: {}".format(executable_symlink))
    if not executable_symlink:
        fail("Executable not found in tool outputs")

    # add original tool files to runfiles so they are available at runtime
    #runfiles = ctx.runfiles(files = originals)
    #runfiles = runfiles.merge(binary_info.default_runfiles)
    runfiles = binary_info.default_runfiles
    
    # Add data dependency (built in target configuration) to runfiles
    # Include both files and their runfiles so target binary can run
    if ctx.attr.data:
        data_files = ctx.attr.data[DefaultInfo].files.to_list()
        data_runfiles = ctx.attr.data[DefaultInfo].default_runfiles
        runfiles = runfiles.merge(ctx.runfiles(files = data_files))
        runfiles = runfiles.merge(data_runfiles)
    
    return [
        DefaultInfo(
            executable = executable_symlink,
            files = depset(symlinks),
            runfiles = runfiles,
        ),
    ]

exec_binary = rule(
    implementation = _exec_binary_impl,
    attrs = {
        "binary": attr.label(
            executable = True,
            mandatory = True,
            cfg = "exec",
        ),
        "data": attr.label(
            allow_single_file = True,
            cfg = "target",
            doc = "Additional data dependency (built in target configuration)",
        ),
    },
    executable = True,
)

exec_test = rule(
    implementation = _exec_binary_impl,
    attrs = {
        "binary": attr.label(
            executable = True,
            mandatory = True,
            cfg = "exec",
        ),
        "data": attr.label(
            allow_single_file = True,
            cfg = "target",
            doc = "Additional data dependency (built in target configuration)",
        ),
    },
    test = True,
)
