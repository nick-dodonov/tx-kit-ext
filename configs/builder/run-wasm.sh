#!/bin/bash
# Simple script to run WASM build via node or emrun
green="\033[32m"
red="\033[31m"
yellow="\033[1;33m"
light_blue="\033[1;34m"
reset="\033[0m"

echo -e "${yellow}🚀 WASM Runner:${reset}"
#env
echo "  cwd: $(pwd)"
echo "  exe: $0"
echo "  args: $@"
if test "${BUILD_WORKSPACE_DIRECTORY+x}"; then
    echo "    BUILD_WORKSPACE_DIRECTORY: $BUILD_WORKSPACE_DIRECTORY"
fi
if test "${BUILD_WORKING_DIRECTORY+x}"; then
    echo "    BUILD_WORKING_DIRECTORY: $BUILD_WORKING_DIRECTORY (cd into it)"
    cd $BUILD_WORKING_DIRECTORY
elif test "${RUNFILES_DIR+x}"; then
    echo "    RUNFILES_DIR: $RUNFILES_DIR (cd into it for test mode)"
    cd $RUNFILES_DIR
fi
if [ $# -lt 1 ]; then
    echo "Usage: $0 <html|wasm> <args>"
    exit 1
fi

_FILE="$1"
shift

# Check if next argument is --emrun or -e
_EMRUN=false
if [ "$1" = "--emrun" ] || [ "$1" = "-e" ]; then
    _EMRUN=true
    shift
    if test "${BAZEL_TEST+x}" && ! test "${BUILD_WORKING_DIRECTORY+x}"; then
        echo -e "${red}❌ Error: --emrun cannot be used in test mode${reset}"
        exit 1
    fi
fi

_FILE="${_FILE%.*}.html"

# Try to find the HTML file in multiple locations
if [ ! -f "$_FILE" ]; then
    # For bazel test mode, we need to convert the path to be relative to runfiles
    # The path comes as "bazel-out/.../test/log_test-wasm/file.wasm" 
    # But in runfiles it's at "_main/test/log_test-wasm/file.html"
    if test "${RUNFILES_DIR+x}"; then
        # Extract just the test part of the path
        RUNFILES_FILE="_main/${_FILE#*bin/}"
        RUNFILES_FILE="${RUNFILES_FILE%.*}.html"
        
        if [ -f "$RUNFILES_FILE" ]; then
            _FILE="$RUNFILES_FILE"
            echo "Found HTML file using RUNFILES_DIR: $_FILE"
        else
            echo "Error: HTML file not found: $_FILE"
            echo "  Tried: $RUNFILES_FILE"
            echo "  Original: $_FILE"
            echo "Current working directory: $(pwd)"
            echo "Please build first"
            exit 1
        fi
    else
        echo "Error: HTML file not found: $_FILE"
        echo "Current working directory: $(pwd)"
        echo "Please build first"
        exit 1
    fi
fi

# Check if we're in test mode (BAZEL_TEST is set but BUILD_WORKING_DIRECTORY is not)
if [ "$_EMRUN" = false ]; then
    echo -e "${yellow}🚀 Test mode (via node):${reset}"
    echo "  cwd: $(pwd)"
    echo "  html: $_FILE"
    
    # For test mode, run with Node.js directly using the JavaScript file
    _JS_FILE="${_FILE%.*}.js"
    if [ -f "$_JS_FILE" ]; then
        echo "  js: $_JS_FILE"
        if [ $# -gt 0 ]; then
            echo "  args: $@"
        fi
        _CMD="node $_JS_FILE $*"
        echo "  cmd: $_CMD"
    else
        echo "Error: JavaScript file not found: $_JS_FILE"
        exit 1
    fi
else
    echo -e "${yellow}🚀 Run mode (via emrun):${reset}"
    echo "  cwd: $(pwd)"
    echo "  html: $_FILE"
    if [ $# -gt 0 ]; then
        echo "  args: $@"
    fi
    _CMD="emrun --kill_start --kill_exit --browser=chrome --browser_args=-headless $_FILE $*"
    echo "  cmd: $_CMD"
fi

echo -e "${light_blue}>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>${reset}"
$_CMD
exitcode=$?
echo -e "${light_blue}<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<${reset}"

if [ "$exitcode" -eq 0 ]; then
    echo -e "${green}✅ Success: $exitcode${reset}"
else
    echo -e "${red}❌ Error: $exitcode${reset}"
fi
exit $exitcode
