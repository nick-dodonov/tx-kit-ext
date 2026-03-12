#!/usr/bin/env bash
# Unfortunately, hybrid script execution fails sometimes with SIGSEGV w/o shebang when executed from Bazel test-setup.sh. =(
# So split runner wrapper execution scripts for platforms now.

# Setup terminal colors/formatting if supported
if [ -t 1 ] && [ -n "$TERM" ] && [ "$TERM" != "dumb" ]; then
    _DIM=$'\033[2m'
    _RESET=$'\033[0m'
else
    _DIM=""
    _RESET=""
fi

_basename=$(basename "$0")
echo "## [$_basename] Shell ($(uname -sm) $SHELL)"
# read -esp "Press Enter to continue..."

echo -n "$_DIM"
# print execution environment
{
    echo "## PWD $(pwd)"
    echo "## [0] $0"
    index=1
    for arg in "$@"; do
        echo "## [$index] $arg"
        index=$((index + 1))
    done
    # print environment variables if set
    _ENV_VARS=(
        "BUILD_WORKING_DIRECTORY"
        "BUILD_WORKSPACE_DIRECTORY"
        "RUNFILES_DIR"
        "RUNFILES_MANIFEST_FILE"
        # "PATH"
    )
    for var in "${_ENV_VARS[@]}"; do
        if [ -n "${!var}" ]; then
            echo "## $var=${!var}"
        fi
    done
}

# --- begin runfiles initialization ---
if [[ ! -d "${RUNFILES_DIR:-/dev/null}" && ! -f "${RUNFILES_MANIFEST_FILE:-/dev/null}" ]]; then
    if [[ -f "$0.runfiles_manifest" ]]; then
        export RUNFILES_MANIFEST_FILE="$0.runfiles_manifest"
        echo "## export RUNFILES_MANIFEST_FILE=$RUNFILES_MANIFEST_FILE"
    elif [[ -f "$0.runfiles/MANIFEST" ]]; then
        export RUNFILES_MANIFEST_FILE="$0.runfiles/MANIFEST"
        echo "## export RUNFILES_MANIFEST_FILE=$RUNFILES_MANIFEST_FILE"
    elif [[ -f "$0.runfiles/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
        export RUNFILES_DIR="$0.runfiles"
        echo "## export RUNFILES_DIR=$RUNFILES_DIR"
    fi
fi
# --- end runfiles initialization ---

# Try to load arguments from .args file (prepend to provided args)
ARGS_FILE="${0%.*}.args"
if [ -f "$ARGS_FILE" ]; then
    echo "## Loading: $ARGS_FILE"
    read -r ARGS_LINE < "$ARGS_FILE"
    echo "## Loaded: $ARGS_LINE"
    # Prepend file args before provided args
    set -- $ARGS_LINE "$@"
fi
echo -n "$_RESET"

# Check if we have any arguments after loading
if [ $# -eq 0 ]; then
    echo "## ERROR: No arguments provided and args file not found or empty: $ARGS_FILE" >&2
    echo -n "$_RESET"
    exit 1
fi

echo "## Execute: $@"
# exec "$@"
"$@"
_ERR=$?
echo "## [$_basename] Exitcode: $_ERR"
exit $_ERR
