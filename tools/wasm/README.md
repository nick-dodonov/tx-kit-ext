# WASM Runner

Python-based WebAssembly runner that replaces the shell script `run-wasm.sh`.

## Features

- **Cross-platform**: Works on any system with Python 3.6+
- **Multiple execution modes**: Supports both Node.js and emrun
- **Bazel integration**: Handles both `bazel test` and `bazel run` contexts
- **Error handling**: Comprehensive error messages and exit codes
- **Colored output**: Clear visual feedback with ANSI colors

## Usage

### Basic usage with Node.js (default)
```bash
python3 runner.py path/to/file.wasm
```

### Using emrun for browser execution
```bash
python3 runner.py path/to/file.wasm --emrun
# or
python3 runner.py path/to/file.wasm -e
```

### With additional arguments
```bash
python3 runner.py path/to/file.wasm --arg1 value --arg2
python3 runner.py path/to/file.wasm --emrun --verbose
```

## Execution Modes

### Test Mode (Node.js)
- Default mode when `--emrun` is not specified
- Runs the JavaScript version of the WASM file using Node.js
- Suitable for automated testing and CI/CD
- Works in both interactive and non-interactive environments

### Run Mode (emrun)
- Activated with `--emrun` or `-e` flag
- Uses Emscripten's `emrun` tool to serve and run the HTML file
- Launches Chrome in headless mode
- Cannot be used in Bazel test mode

## Environment Variables

The runner automatically detects and responds to these Bazel environment variables:

- `BUILD_WORKSPACE_DIRECTORY`: Bazel workspace root
- `BUILD_WORKING_DIRECTORY`: Working directory for `bazel run`
- `RUNFILES_DIR`: Test runfiles directory for `bazel test`
- `BAZEL_TEST`: Indicates test execution context

## File Resolution

The runner automatically handles file path resolution:

1. **Direct path**: If the HTML file exists at the specified path
2. **Runfiles resolution**: For `bazel test`, searches in `_main/` subdirectory
3. **Extension handling**: Automatically converts `.wasm` to `.html` extension

## Examples

### Testing with tx-pkg-misc
```bash
# Run the misc test binary
cd /path/to/tx-pkg-misc
python3 /path/to/tx-kit-ext/tools/wasm/runner.py bazel-bin/test/misc-bin

# Run with emrun
python3 /path/to/tx-kit-ext/tools/wasm/runner.py bazel-bin/test/misc-bin --emrun
```

### Integration with Bazel
The runner is designed to work seamlessly with Bazel build rules:

```python
# In your BUILD.bazel file
py_binary(
    name = "wasm_runner",
    srcs = ["//tx-kit-ext/tools/wasm:runner.py"],
    main = "runner.py",
)
```

## Error Handling

The runner provides clear error messages for common issues:

- **File not found**: Shows attempted paths and current directory
- **Missing dependencies**: Clear indication if Node.js or emrun is not available
- **Invalid usage**: Prevents `--emrun` usage in test mode
- **Execution errors**: Proper exit codes and colored output

## Exit Codes

- `0`: Success
- `1`: General error (file not found, execution failed)
- `127`: Command not found (Node.js or emrun missing)
- `130`: Interrupted by user (Ctrl+C)

## Development

### Code Structure

- `WasmRunner`: Main class handling execution logic
- `Colors`: ANSI color constants for terminal output
- `parse_arguments()`: Command-line argument parsing
- `main()`: Entry point with exception handling

### Best Practices Applied

- **Type hints**: Full type annotations for better code clarity
- **Docstrings**: Comprehensive documentation for all functions
- **Error handling**: Proper exception handling with meaningful messages
- **Separation of concerns**: Clear class and function responsibilities
- **Path handling**: Using `pathlib.Path` for cross-platform compatibility
- **Command execution**: Safe subprocess handling with proper error codes