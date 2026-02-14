import os
import re
import sys

from dataclasses import dataclass, field
from pathlib import Path
from python.runfiles import Runfiles

from .log import *
from .platform import Platform
from . import cmd, detect, wasm


@dataclass
class Options:
    """Start options."""

    file: Path
    args: list[str] = field(default_factory=list)
    platform: Platform = Platform.AUTO


ENV_REGEXP_FILTERS = [
    # debug: re.compile(r".*"),
    re.compile(r"^BAZEL"),
    re.compile(r"^BUILD_"),
    re.compile(r"^RUNFILES_"),
    re.compile(r"^TEST_(?!.*(_FILE|DIR)$)"),  # Exclude TEST_*_FILE and TEST_*DIR to avoid leaking large unnecessary file paths
]


def _log_process_header() -> None:
    info(f"  {Style.DIM}CWD {os.getcwd()}{Style.RESET_ALL}")
    for index, arg in enumerate(sys.argv):
        info(f"  {Style.DIM}[{index}] {arg}{Style.RESET_ALL}")
    for key, value in sorted(os.environ.items()):
        if any(pattern.match(key) for pattern in ENV_REGEXP_FILTERS):
            info(f"  {Style.DIM}{key}={value}{Style.RESET_ALL}")


def _find_file(file: Path) -> tuple[Path | None, str]:
    if file.exists():
        return file, "CWD"

    build_working_dir = os.environ.get("BUILD_WORKING_DIRECTORY")
    if build_working_dir:
        candidate = Path(build_working_dir) / file
        if candidate.exists():
            return candidate, "BUILD_WORKING_DIRECTORY"

    # Try runfiles
    runfiles = Runfiles.Create()
    if runfiles:
        rlocation = runfiles.Rlocation(str(file))
        if rlocation:
            rlocation_path = Path(rlocation)
            if rlocation_path.exists():
                return rlocation_path, "<RUNFILES>"

    return None, "<NOT FOUND>"


def _find_file_logged(file: Path) -> Path | None:
    found_file, found_in = _find_file(file)
    if found_file:
        info(f"  {Style.DIM}File found: {found_file} ({found_in}){Style.RESET_ALL}")
    return found_file


def _main(options: Options) -> int:
    info(f"{Fore.CYAN}{Style.BRIGHT}⭐ Runner:{Style.NORMAL} {options}{Style.RESET_ALL}")
    _log_process_header()

    file = _find_file_logged(options.file)
    if not file:
        raise FileNotFoundError(f"File not found: {options.file}")

    platform = options.platform
    if platform == Platform.AUTO:
        platform = detect.detect_platform(file)

    cmd_with_args = [str(file)] + options.args
    if platform == Platform.WASM:
        command = wasm.make_wrapper_command(cmd_with_args)
    else:
        command = cmd.Command(cmd=cmd_with_args)

    return command.scoped_execute(f"[{platform.value.upper()}]")


def start(options: Options) -> None:
    try:
        exit_code = _main(options)
        sys.exit(exit_code)
    except Exception as e:
        info(f"{Fore.RED}❌ {e}{Style.RESET_ALL}")
        if isinstance(e, FileNotFoundError):
            sys.exit(1)
        raise
