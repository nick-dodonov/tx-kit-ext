def _host_runner_impl(ctx):
    target = ctx.attr.target
    default_info = target[DefaultInfo]
    source_executable = default_info.files_to_run.executable
    
    # Create output file - on Windows this should be .exe
    is_windows = ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo])
    output_name = ctx.label.name + (".exe" if is_windows else "")
    output = ctx.actions.declare_file(output_name)
    
    # Copy the executable (works on both Unix and Windows with bash)
    ctx.actions.run_shell(
        inputs = [source_executable],
        outputs = [output],
        command = "cp -f \"$1\" \"$2\"",
        arguments = [source_executable.path, output.path],
    )
    
    return [
        DefaultInfo(
            files = depset([output]),
            executable = output,
            runfiles = default_info.default_runfiles,
        ),
    ]

host_runner = rule(
    implementation = _host_runner_impl,
    attrs = {
        "target": attr.label(
            executable = True,
            cfg = "exec",
        ),
        "_windows_constraint": attr.label(
            default = "@platforms//os:windows",
        ),
    },
    executable = True,
)
