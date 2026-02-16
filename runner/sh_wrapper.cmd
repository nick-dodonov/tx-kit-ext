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
echo "## [$_basename] Shell ($(uname -sm) $SHELL)"
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
    echo "  ## Loading: $ARGS_FILE"
    read -r ARGS_LINE < "$ARGS_FILE"
    echo "  ## Loaded: $ARGS_LINE"
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
echo ## [%_basename%] Batch (%OS% %PROCESSOR_ARCHITECTURE% %ComSpec%)
:: pause # "Press any key to continue..."

REM print execution environment
setlocal enabledelayedexpansion

REM Setup ANSI escape sequences if terminal supports it
set "_DIM="
set "_RESET="
if defined WT_SESSION (
    REM Windows Terminal detected
    for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
    if defined ESC (
        set "_DIM=!ESC![2m"
        set "_RESET=!ESC![0m"
    )
) else (
    REM Enable Virtual Terminal Processing via PowerShell
    for /f %%a in ('powershell -NoProfile -Command "$h=[System.Console]::OutputEncoding;[System.Console]::OutputEncoding=[System.Text.Encoding]::UTF8;try{$m=[System.Runtime.InteropServices.Marshal];$k=$m::GetStdHandle(-11);$c=0;$p=$m::AllocHGlobal(4);$m::WriteInt32($p,0);[void](Add-Type -Name c -Member '[DllImport(\"kernel32.dll\")]public static extern bool GetConsoleMode(IntPtr h,out int m);[DllImport(\"kernel32.dll\")]public static extern bool SetConsoleMode(IntPtr h,int m);' -PassThru)::GetConsoleMode($k,[ref]$c);[void]([c]::SetConsoleMode($k,$c -bor 4));'OK'}catch{'FAIL'}finally{[System.Console]::OutputEncoding=$h;if($p){$m::FreeHGlobal($p)}}"') do set "VT_RESULT=%%a"

    REM Get ESC character
    for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
)
REM Set ANSI codes
if defined ESC (
    set "_DIM=!ESC![2m"
    set "_RESET=!ESC![0m"
)

echo !_DIM!  PWD %CD%
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
    echo   ## Loading: !ARGS_FILE!
    set /p ARGS_LINE=<"!ARGS_FILE!"
    echo   ## Loaded: !ARGS_LINE!
    
    REM Convert forward slashes to backslashes for Windows
    REM TODO: generate with backslashes in the first place to avoid this step
    set "ARGS_LINE=!ARGS_LINE:/=\!"
)

REM Combine file args with provided args
if "%*"=="" (
    set "FULL_ARGS=!ARGS_LINE!"
) else (
    set "FULL_ARGS=!ARGS_LINE! %*"
)

REM Check if we have any arguments after loading
if "!FULL_ARGS!"=="" (
    echo !_RESET!## ERROR: No arguments provided and args file not found or empty: !ARGS_FILE! >&2
    exit /b 1
)

echo !_RESET!## Execute: !FULL_ARGS!
cmd /c !FULL_ARGS!
set _ERR=!ERRORLEVEL!
echo ## [%_basename%] Errorcode: !_ERR!
exit /b !_ERR!
