'''
Sample usage:
load("@tx-kit-ext//rules/build:multi_app.bzl", "multi_app")
load("@tx-kit-ext//rules/build:wasm_helper.bzl", "wasm_preload_params")

wasm_preload_params(
    name = "preload_params",
    assets = "@tx-pkg-misc//data:fonts_group",
)

multi_app(
    name = "sample",
    srcs = glob(["**/*.cpp"]),
    additional_linker_inputs = [
        ":preload_params",
    ],
    linkopts = ["@$(execpaths :preload_params)"],
    platforms = ["wasm"],
)
'''

def _wasm_preload_params_impl(ctx):
    param_file = ctx.actions.declare_file(ctx.label.name + ".txt")

    content = []
    for f in ctx.files.assets:
        # f.path — full path for emcc (on disk)
        # f.short_path — path without the prefix of the external repository/bin directory
        
        # Remove the ../ prefix for external repositories in short_path, if it exists
        vfs_path = f.short_path
        if vfs_path.startswith("../"):
            # turns ../repo_name/path/file into path/file
            vfs_path = "/".join(vfs_path.split("/")[2:])
        
        # Format: physical_path@path_in_wasm
        content.append("--preload-file %s@/%s" % (f.path, vfs_path))
    
    ctx.actions.write(param_file, "\n".join(content))
    
    # return [
    #     DefaultInfo(
    #         files = depset([param_file]),
    #         # Pass files itself to be available to the linker
    #         runfiles = ctx.runfiles(files = ctx.files.assets) 
    #     )
    # ]
    return [
        DefaultInfo(files = depset([param_file]))
    ]

wasm_preload_params = rule(
    implementation = _wasm_preload_params_impl,
    attrs = {"assets": attr.label(allow_files = True)},
)
