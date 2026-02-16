@goto(){
# Shell script here
# TODO: via runfiles and fallback: $(dirname "$0")/sh_wrapper.sh

# Setup terminal colors/formatting if supported
if [ -t 1 ] && [ -n "$TERM" ] && [ "$TERM" != "dumb" ]; then
    _DIM=$'\033[2m'
    _RESET=$'\033[0m'
else
    _DIM=""
    _RESET=""
fi

_basename=$(basename "$0")
echo "## Shell ($(uname -sm) $SHELL): $_basename"
# read -esp "Press Enter to continue..."

echo -n "$_DIM"
# print execution environment
{
    echo "  PWD $(pwd)"
    echo "  [0] $0"
    index=1
    for arg in "$@"; do
        echo "  [$index] $arg"
        index=$((index + 1))
    done
    # print environment variables if set
    _ENV_VARS=(
        "BUILD_WORKING_DIRECTORY"
        "BUILD_WORKSPACE_DIRECTORY"
        "RUNFILES_DIR"
        "RUNFILES_MANIFEST_FILE"
    )
    for var in "${_ENV_VARS[@]}"; do
        if [ -n "${!var}" ]; then
            echo "  $var=${!var}"
        fi
    done
}

# Try to load arguments from .args file (prepend to provided args)
ARGS_FILE="${0%.cmd}.args"
if [ -f "$ARGS_FILE" ]; then
    echo "  ## Loading arguments: $ARGS_FILE"
    read -r ARGS_LINE < "$ARGS_FILE"
    echo "  ## Loaded from file: $ARGS_LINE"
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
echo "## [$_basename] Errorcode: $_ERR"
exit $_ERR
}

@goto $@
exit

:(){
:: Batch script here
@echo off
set "_basename=%~nx0"
:: TODO: via runfiles and fallback: call "%~dp0sh_wrapper.bat"
echo ## Batch (%OS% %PROCESSOR_ARCHITECTURE% %ComSpec%): %_basename%
:: pause # "Press any key to continue..."

REM print execution environment
setlocal enabledelayedexpansion
echo   PWD %CD%
echo   [0] %0
set index=1
for %%a in (%*) do (
    echo   [!index!] %%a
    set /a index+=1
)
echo   BUILD_WORKING_DIRECTORY=%BUILD_WORKING_DIRECTORY%
echo   BUILD_WORKSPACE_DIRECTORY=%BUILD_WORKSPACE_DIRECTORY%
echo   RUNFILES_DIR=%RUNFILES_DIR%
echo   RUNFILES_MANIFEST_FILE=%RUNFILES_MANIFEST_FILE%

REM Try to load arguments from .args file (prepend to provided args)
set "ARGS_FILE=%~dpn0.args"
set "ARGS_LINE="
if exist "!ARGS_FILE!" (
    echo   ## Loading arguments: !ARGS_FILE!
    set /p ARGS_LINE=<"!ARGS_FILE!"
    echo   ## Loaded from file: !ARGS_LINE!
    
    REM Convert forward slashes to backslashes for Windows
    REM TODO: generate with backslashes in the first place to avoid this step
    set "ARGS_LINE=!ARGS_LINE:/=\!"
)

REM Combine file args with provided args
set "FULL_ARGS=!ARGS_LINE! %*"
set "FULL_ARGS=!FULL_ARGS:~0,-1!"
for /f "tokens=* delims= " %%a in ("!FULL_ARGS!") set "FULL_ARGS=%%a"

REM Check if we have any arguments after loading
if "!FULL_ARGS!"=="" (
    echo ## ERROR: No arguments provided and args file not found or empty: !ARGS_FILE! >&2
    exit /b 1
)

echo ## Execute: !FULL_ARGS!
cmd /c !FULL_ARGS!
set _ERR=!ERRORLEVEL!
echo ## [%_basename%] Errorcode: !_ERR!
exit /b !_ERR!
