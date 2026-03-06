# TX Build Rules

This directory contains custom Bazel build rules for the TX workspace.

## Active Rules

- **multi_lib** - C++ library with multi-platform support (host/wasm/droid)
- **multi_app** - C++ application with multi-platform support
- **multi_test** - C++ test with multi-platform support
- **exec_binary** - Wrapper for binaries executed during the build
- **wasm_helper** - WASM-specific utilities (wasm_preload_params)

## Helper Modules

- **tx_common.bzl** - Common utilities for compiler/linker options
- **filter_deps.bzl** - Dependency filtering utilities
- **run_wrapper_cmd.bzl** - Command-line wrapper generation
- **droid/** - Android-specific templates and glue code

## Documentation

For information about Bazel rules and macros:

- [Bazel Rules Documentation](https://bazel.build/extending/rules)
- [Bazel Symbolic Macros Documentation](https://bazel.build/extending/macros)
- [Bazel Attributes Reference](https://bazel.build/rules/lib/attr)
