# Runner

Cross-platform execution tools for Bazel targets.

## Contents

### `runner` - Python Binary Executor

A Python-based tool that executes binary files for different target platforms. Automatically detects or allows explicit specification of the target platform (native execution or WASM).

**Key features:**
- Auto-detection of binary platform (WASM vs native)
- Support for runfiles resolution
- Environment-aware execution (BUILD_WORKING_DIRECTORY, RUNFILES)
- Cross-platform compatibility

**Usage:**
```bash
bazel run //runner -- [--platform auto|wasm|exec] <binary_path> [args...]
```

### `sh_wrapper.cmd` - Hybrid Bash+Batch Script

A cross-platform shell wrapper that allows running `sh_binary` targets on Windows even when a specific build platform is selected (e.g., `--platforms=@emsdk//:platform_wasm`). In such cases, the native `.exe` wrapper isn't produced by the rule implementation, and this hybrid script provides compatibility.

**Key features:**
- Single file works as both Bash and Windows Batch script
- Supports argument loading from `.args` files
- Environment variable inspection (BUILD_*, RUNFILES_*)
- Terminal color support when available

**Technical notes:**
- Works with implicit `bash` (using `sh` gives "`@goto': not a valid identifier"` error)
- Based on [hybrid script technique](https://danq.me/2022/06/13/bash-batch/)
- See `sh_wrapper.md` for implementation details and alternatives

**Usage in Bazel:**

Example of target that can run target executable via execution platform even in target configuration:
```starlark
sh_binary(
    name = "my_script",
    srcs = ["@tx-kit-ext//runner:sh_wrapper.cmd"],
    data = [
        "@tx-kit-ext//runner",
        ":target_cc_binary",
    ],
    args = [
        "$(location @tx-kit-ext//runner)",
        "$(location :target_cc_binary)",
    ],
)
```

## Build Configuration

The `BUILD.bazel` file exports:
- `:runner` - exec_binary wrapper forcing runner to be built for exec platform
- `:lib` - Python library with runner implementation
- `sh_wrapper.cmd` - Exported file for use in other targets

## Use Cases

1. **Running WASM binaries in tests** - Use runner with `--run_under` flag
2. **Cross-platform shell scripts** - Use sh_wrapper.cmd for Windows compatibility
3. **Composing executables** - Load arguments from files to chain multiple executables
