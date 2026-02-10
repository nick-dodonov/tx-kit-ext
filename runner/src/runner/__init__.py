import os
import re
import sys

from dataclasses import dataclass, field
from python.runfiles import Runfiles

from .log import *
from .platform import Platform
from . import cmd, detect, wasm


@dataclass
class Options:
    """Start options."""

    file: str
    args: list[str] = field(default_factory=list)
    platform: Platform = Platform.AUTO


ENV_REGEXP_FILTERS = [
    re.compile(r"^BUILD_"),
    re.compile(r"^RUNFILES_"),
    re.compile(r"^TEST_(?!.*(_FILE|DIR)$)"),  # Exclude TEST_*_FILE and TEST_*DIR to avoid leaking large unnecessary file paths
]


def _log_process_header() -> None:
    info(f"{Style.DIM}  CWD {os.getcwd()}{Style.RESET_ALL}")
    for index, arg in enumerate(sys.argv):
        info(f"{Style.DIM}  [{index}] {arg}{Style.RESET_ALL}")
    for key, value in sorted(os.environ.items()):
        if any(pattern.match(key) for pattern in ENV_REGEXP_FILTERS):
            info(f"{Style.DIM}  {key}={value}{Style.RESET_ALL}")


def _find_file(file: str) -> tuple[str | None, str]:
    if os.path.exists(file):
        return file, "AS-IS"

    build_working_dir = os.environ.get("BUILD_WORKING_DIRECTORY")
    if build_working_dir:
        candidate = os.path.join(build_working_dir, file)
        if os.path.exists(candidate):
            return candidate, "BUILD_WORKING_DIRECTORY"

    # Try runfiles
    runfiles = Runfiles.Create()
    if runfiles:
        rlocation = runfiles.Rlocation(file)
        if rlocation and os.path.exists(rlocation):
            return rlocation, "RUNFILES"

    return None, "NOT-FOUND"


def start(options: Options) -> None:
    info(f"{Fore.CYAN}{Style.BRIGHT}⭐ Runner:{Style.NORMAL} {options}{Style.RESET_ALL}")
    _log_process_header()

    try:
        file, found_in = _find_file(options.file)
        if not file:
            raise FileNotFoundError(f"Target file not found: {options.file}")
        info(f"{Style.DIM}{Style.BRIGHT}Target: ({found_in}){Style.NORMAL} {file or options.file}{Style.RESET_ALL}")
    except Exception as e:
        info(f"{Fore.RED}❌ {e}{Style.RESET_ALL}")
        sys.exit(1)

    platform = options.platform
    if platform == Platform.AUTO:
        platform = detect.detect_platform(file)
        info(f"{Style.BRIGHT}Detected: {platform}{Style.RESET_ALL}")

    cmd_with_args = [file] + options.args
    if platform == Platform.WASM:
        command = wasm.make_wrapper_command(cmd_with_args)
    else:
        command = cmd.Command(cmd=cmd_with_args)

    exit_code = command.scoped_execute(f"[{platform.value.upper()}]")
    sys.exit(exit_code)
