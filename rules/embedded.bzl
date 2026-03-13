"""
Build rules for embedding files into C++ targets on different platform via different methods.

Embedded files declaration:
- embedded_files - declares mapping of file labels to their corresponding paths in the embedded assets.

Embedded files usage:
- host_embedded_data - depends on embedded_files and deps to make the files available for host targets (e.g., via runfiles)
- droid_embedded_assets - depends on embedded_files and prepares assets/ structure for android_library/android_binary packaging
- wasm_embedded_linkopts_params - depends on embedded_files and generates a parameter file to be used in linkopts for emcc --preload-file options for wasm cc_binary targets
"""
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

_LOG_ENABLED = True
def _log(message):
    """Logs a warning message during the build."""
    if _LOG_ENABLED:
        _LOG_COLOR = "\033[1;34m"  # blue
        _LOG_RESET = "\033[0m"
        print(_LOG_COLOR + message + _LOG_RESET)  # buildifier: disable=print

################################################################
EmbeddedFilesInfo = provider(
    "Provides information about embedded files and their target paths.",
    fields = {
        "files_to_dir": "A dictionary mapping file labels to their corresponding paths in the embedded assets.",
    }
)

################################################################
def _embedded_files_impl(ctx):
    _log("=== embedded_files declaration {}".format(ctx.label))
    return [
        EmbeddedFilesInfo(
            files_to_dir=ctx.attr.files_to_dir,
        ),
    ]

embedded_files = rule(
    implementation = _embedded_files_impl,
    attrs = {
        "files_to_dir": attr.label_keyed_string_dict(allow_files=True),
    },
)

##########################################
def _embedded_files_aspect_impl(target, ctx):
    _log("=== embedded_files_aspect traverse {}".format(target))
    
    all_embedded_infos = []
    if hasattr(ctx.rule.attr, "data"):
        target_data = ctx.rule.attr.data
        for d in target_data:
            if EmbeddedFilesInfo in d:
                all_embedded_infos.append(d[EmbeddedFilesInfo])

    for dep in ctx.rule.attr.deps:
        if EmbeddedFilesInfo in dep:
            all_embedded_infos.append(dep[EmbeddedFilesInfo])
    
    if not all_embedded_infos:
        return []

    _log("  collected EmbeddedFilesInfo ({} count): {}".format(len(all_embedded_infos), all_embedded_infos))
    files_to_dir = {}
    for info in all_embedded_infos:
        #TODO: detect conflict files and fail
        files_to_dir.update(info.files_to_dir)

    return [EmbeddedFilesInfo(files_to_dir=files_to_dir)]

embedded_files_aspect = aspect(
    implementation = _embedded_files_aspect_impl,
    attr_aspects = ["deps"],  # traverse by "deps" attributes to collect embedded files transitively
    required_providers = [CcInfo],  # only apply to C++ targets (to filter out another deps that are not relevant for embedding)
)

################################################################
def _host_embedded_data_impl(ctx):
    _log("=== host_embedded_data processing {}".format(ctx.label))

    all_files_to_dir = {}

    # take embedded files from deps first (to allow override by current target)
    # they where collected by embedded_files_aspect and merged transitively
    for dep in ctx.attr.deps:
        if EmbeddedFilesInfo in dep:
            #TODO: detect conflict files and fail
            all_files_to_dir.update(dep[EmbeddedFilesInfo].files_to_dir)

    # then update with embedded files from current target if present
    if ctx.attr.embedded != None:
        all_files_to_dir.update(ctx.attr.embedded[EmbeddedFilesInfo].files_to_dir)

    result_files = []
    for source, target_dir in all_files_to_dir.items():
        _log("entry: {} -> {}".format(source, target_dir))  # e.g., Label("//data/fonts_group") -> "data/fonts"
        for source_file in source.files.to_list():
            output_path = "{}/{}".format(target_dir, source_file.basename)  # e.g., "data/fonts/Roboto-Regular.ttf"
            output_file = ctx.actions.declare_file(output_path)
            _log("  symlink: {} -> {}".format(output_file, source_file))
            ctx.actions.symlink(
                output = output_file,
                target_file = source_file,
            )
            result_files.append(output_file)

    files = depset(direct = result_files)
    runfiles = ctx.runfiles(files = result_files)
    return [
        DefaultInfo(files = files, runfiles = runfiles),
    ]

host_embedded_data = rule(
    implementation = _host_embedded_data_impl,
    attrs = {
        "embedded": attr.label(
            mandatory = False,
            providers = [EmbeddedFilesInfo],
        ),
        "deps": attr.label_list(
            aspects = [embedded_files_aspect],  # to collect embedded files transitively
        ),
    },
)

################################################################
def _droid_embedded_assets_impl(ctx):
    _log("=== droid_embedded_assets processing {}".format(ctx.label))

    # Create files in the Android assets directory structure
    # android_library with assets_dir="assets" will strip the "assets/" prefix when packaging

    outputs = []
    files_to_dir = ctx.attr.embedded[EmbeddedFilesInfo].files_to_dir
    for source, target_dir in files_to_dir.items():
        # value is the relative path within assets (e.g., "data/fonts")
        # We need to create files at "assets/data/fonts/..." for android_library
        _log("entry: {} -> {}".format(source, target_dir))
        output_dir = "assets/{}".format(target_dir)  # e.g., "assets/data/fonts"
        _log("  output_dir: {}".format(output_dir))
        _log("  source files count: {}".format(len(source.files.to_list())))

        for source_file in source.files.to_list():
            _log("  processing file: {}".format(source_file))
            _log("    file.path: {} is_directory={} is_source={} is_symlink={}".format(source_file.path, source_file.is_directory, source_file.is_source, source_file.is_symlink))
            _log("    file.short_path: {}".format(source_file.short_path))
            # _log("    file.basename: {}".format(source_file.basename))
            # _log("    file.extension: {}".format(source_file.extension))
            # _log("    file.dirname: {}".format(source_file.dirname))

            # Declare output file in the assets structure
            output_path = "{}/{}".format(output_dir, source_file.basename)
            output_file = ctx.actions.declare_file(output_path)
            _log("    output_file.path: {}".format(output_file.path))
            _log("    output_file.short_path: {}".format(output_file.short_path))

            # Create symlink according to Bazel docs: output first, then target_file
            ctx.actions.symlink(
                output = output_file,
                target_file = source_file,
            )
            _log("    symlink: {} -> {}".format(output_file.short_path, source_file.short_path))
            outputs.append(output_file)
    
    # _log("=== droid_embedded_assets ({}) summary ===".format(ctx.label))
    # _log("Total output files count: {}".format(len(outputs)))
    # for out in outputs:
    #     _log("  {} (short: {})".format(out.path, out.short_path))
    
    return [DefaultInfo(files=depset(outputs))]


droid_embedded_assets = rule(
    implementation = _droid_embedded_assets_impl,
    attrs = {
        "embedded": attr.label(
            providers = [EmbeddedFilesInfo],
        ),
    },
)

################################################################
def _wasm_embedded_linkopts_params_impl(ctx):
    _log("=== wasm_embedded_linkopts_params processing {}".format(ctx.label))
    param_file = ctx.actions.declare_file(ctx.label.name + ".txt")

    files_to_dir = ctx.attr.assets[EmbeddedFilesInfo].files_to_dir
    linkopts = []
    for source, target_dir in files_to_dir.items():
        _log("entry: {} -> {}".format(source, target_dir))
        for source_file in source.files.to_list():
            target_path = "{}/{}".format(target_dir, source_file.basename)  # e.g., "data/fonts/Roboto-Regular.ttf"
            _log("  adding --preload-file option {} -> {}".format(source_file.path, target_path))
            # Format: --preload-file physical_path@path_in_wasm
            linkopts.append("--preload-file %s@/%s\n" % (source_file.path, target_path))

    ctx.actions.write(param_file, "".join(linkopts))
    return [
        DefaultInfo(files = depset([param_file])),
        # Don't need to pass files itself as dependency build tree should be available to linker..
        # runfiles = ctx.runfiles(files = ctx.files.assets)
    ]

wasm_embedded_linkopts_params = rule(
    implementation = _wasm_embedded_linkopts_params_impl,
    attrs = {
        "assets": attr.label(
            providers = [EmbeddedFilesInfo],
        ),
    },
)
