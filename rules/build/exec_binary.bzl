"""Rule to build a tool for the execution platform."""

def _exec_binary_impl(ctx):
    # Get the tool built for exec configuration
    binary_info = ctx.attr.binary[DefaultInfo]
    binary_exe = binary_info.files_to_run.executable

    # On Windows, py_binary creates both launcher.exe and the launcher script file.
    # The launcher.exe expects the script to be in the same directory.
    # Create symlinks in an isolated subdirectory (named after this rule) to avoid
    # collisions with source outputs, while preserving basenames for file discovery.
    symlinks = []
    originals = []
    executable_symlink = None

    for src_file in binary_info.files.to_list():
        # Skip source files - only symlink generated outputs
        if src_file.is_source:
            continue

        # Preserve original basename so files can find each other within isolated output directory
        symlink = ctx.actions.declare_file(src_file.basename)

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
    },
    test = True,
)
