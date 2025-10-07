# AI Agent Instructions for tx-kit-repo

This document guides AI agents working with the tx-kit-repo codebase.

## Project Architecture

The repository is organized as a Bazel-based modular monorepo with these key components:

### 1. Private Registry System
- Located in `/modules` - manages Bazel module dependencies
- Uses `source.json` files to track module versions and integrity hashes
- Custom Python tooling in `/tools` for registry maintenance
- Example module: `lwlog` (logging library with native and WASM support)

### 2. Build Rules and Extensions
- `/configs/builder` contains custom Bazel build rules:
  - `tx_binary.bzl` - Multi-platform binary target support (native + WASM)
  - `tx_test.bzl` - Multi-platform test target support
  - `tx_common.bzl` - Shared build configuration logic

### 3. Development Tools
- `/tools/dev` - Developer environment setup tools:
  - Custom bazelrc config generation
  - LLDB debugger setup for Bazel builds
  - Python environment utilities
- `/tools` - Registry maintenance tools:
  - `update_integrity.py` - Updates SHA hashes for module files
  - `cleanup.sh` - Repository cache cleanup utility

## Key Workflows

### Building and Testing
```bash
# Debug build with source mapping for debugging
bazel build //demo:target-name -c dbg --spawn_strategy=local

# WASM build and run
bazel build //demo:target-name --platforms=@emsdk//:platform_wasm
bazel run //demo:target-name --platforms=@emsdk//:platform_wasm

# Run tests
bazel test //test:target --test_output=all
```

### Updating Module Dependencies
1. Add dependency to MODULE.bazel
2. Add module files to /modules/<module-name>/<version>/
3. Run `./tools/update_integrity.sh <module-name> <version>`

## Project Conventions

### Build Rules
- Always use `tx_binary` instead of `cc_binary` for executables
- Always use `tx_test` instead of `cc_test` for tests
- Set build options in MODULE.bazel, not in BUILD files

### Debug Support 
- Source file paths are normalized for debugging
- LLDB configurations handle both native and Bazel builds
- Debug builds automatically enable source mapping

### Cross-Platform Support
- All targets support both native and WASM builds
- Platform-specific code uses preprocessor defines
- WASM-specific patches are in module's patches/ directory

### Error Handling
- Use Log module for consistent error reporting
- Boot module provides standard startup diagnostics
- Test failures automatically include build/platform info

## Integration Points

### External Dependencies
1. Public dependencies from Bazel Central Registry
   - Version constraints in MODULE.bazel
   - Registry URL in .bazelrc

2. Private dependencies from tx-kit-repo registry
   - Managed in /modules
   - Integrity checks via update_integrity.py

### Cross-Component Communication
- Boot module coordinates startup sequence
- Log module provides centralized logging
- BUILD.bazel files control visibility between components

## Troubleshooting

### Common Issues
1. Missing source maps in debugger
   - Ensure -c dbg and --spawn_strategy=local are set
   - Check .lldbinit mappings match your workspace

2. WASM build failures
   - Verify emsdk platform is selected
   - Check for platform-specific code that needs patching

3. Dependency resolution failures
   - Run update_integrity.sh to update hashes
   - Verify module exists in registry path