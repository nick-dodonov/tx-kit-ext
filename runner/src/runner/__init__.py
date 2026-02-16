import os
import re
import sys

from pathlib import Path

from . import find, detect, cmd, wasm
from .log import info, Fore, Style
from .context import Platform, Options


ENV_REGEXP_FILTERS = [
    # debug: re.compile(r".*"),
    re.compile(r"^BAZEL(?!ISK_SKIP_WRAPPER$)"),
    re.compile(r"^BUILD_"),
    re.compile(r"^RUNFILES_"),
    re.compile(r"^TEST_(?!.*(_FILE|DIR)$)"),  # Exclude TEST_*_FILE and TEST_*DIR to avoid leaking large unnecessary file paths
]


_logged_header = False
def log_header_once() -> None:
    global _logged_header

    if not _logged_header:
        _logged_header = True
        #TODO: also add stamp info
        info(f"{Fore.CYAN}{Style.BRIGHT}⭐ Runner {Style.DIM}(Python {sys.version.split()[0]}, PID {os.getpid()}){Style.RESET_ALL}")


def _log_process_info() -> None:
    info(f"  {Style.DIM}CWD {os.getcwd()}{Style.RESET_ALL}")
    for index, arg in enumerate(sys.argv):
        info(f"  {Style.DIM}[{index}] {arg}{Style.RESET_ALL}")
    for key, value in sorted(os.environ.items()):
        if any(pattern.match(key) for pattern in ENV_REGEXP_FILTERS):
            info(f"  {Style.DIM}{key}={value}{Style.RESET_ALL}")


def _log_options(options: Options) -> None:
    info(f"  {Style.DIM}{options}{Style.RESET_ALL}")


def _main(options: Options) -> int:
    log_header_once()
    _log_process_info()
    _log_options(options)

    finder = find.Finder()
    found_file = finder.find_file_logged(options.file)
    if not found_file:
        raise FileNotFoundError(f"File not found: {options.file}")

    platform = options.platform
    if platform == Platform.AUTO:
        platform = options.platform = detect.detect_platform(found_file)

    cmd_with_args = [str(found_file)] + options.args
    if platform == Platform.WASM:
        ctx = context.Context(
            options=options, 
            finder=finder,
            found_file=found_file,
        )
        command = wasm.make_wrapper_command(ctx)
    elif platform == Platform.EXEC:
        command = cmd.Command(cmd=cmd_with_args)
    elif platform == Platform.PYTHON:
        command = cmd.Command(cmd=["python3"] + cmd_with_args)
    else:
        raise ValueError(f"Unsupported platform: {platform}")

    descr = Path(command.cmd[0]).name
    return command.scoped_execute(f"[{platform.value.upper()}: {descr}]")


def start(options: Options) -> None:
    try:
        exit_code = _main(options)
        sys.exit(exit_code)
    except Exception as e:
        info(f"{Fore.RED}❌ {e}{Style.RESET_ALL}")
        if isinstance(e, FileNotFoundError):
            sys.exit(1)
        raise
