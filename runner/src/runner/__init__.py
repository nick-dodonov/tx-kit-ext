import os
import re
import sys

from dataclasses import dataclass, field
from enum import Enum
from python.runfiles import Runfiles

from runner.log import *
import runner.wasm
import runner.cmd


class Platform(Enum):
    """Target platform for execution."""

    AUTO = "auto"
    WASM = "wasm"


@dataclass
class Options:
    """Start options."""

    file: str
    args: list[str] = field(default_factory=list)
    platform: Platform = Platform.AUTO


def _test_runfiles() -> None:
    # https://github.com/bazel-contrib/rules_python/tree/main/python/runfiles
    (r, rwhere) = (Runfiles.Create(), "default")
    if not r:
        (r, rwhere) = (
            Runfiles.Create(
                env={"RUNFILES_MANIFEST_FILE": sys.argv[0] + ".runfiles_manifest"}
            ),
            "relative",
        )

    if len(sys.argv) < 2:
        info(">>> No program specified to run")
        sys.exit(1)

    if r:
        rlocation = r.Rlocation(sys.argv[1])
        info(f">>> Rlocation ({rwhere}):")
        info(rlocation)
        if rlocation is None:
            rlocation = sys.argv[1]
    else:
        info(">>> No runfiles found")
        rlocation = sys.argv[1]


ENV_REGEXP_FILTERS = [
    re.compile(r"^BUILD_"),
    re.compile(r"^RUNFILES_"),
    re.compile(r"^TEST_(?!.*(_FILE|DIR)$)"),  # Exclude TEST_*_FILE and TEST_*DIR to avoid leaking large unnecessary file paths
]


def _log_process_header() -> None:
    info(f"{Fore.CYAN}⭐ Runner{Style.RESET_ALL}")
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
    _log_process_header()
    info(f"{Style.DIM}  {options}{Style.RESET_ALL}")

    try:
        file, found_in = _find_file(options.file)
        if not file:
            raise FileNotFoundError(f"Target file not found: {options.file}")
        info(f"{Style.DIM}  Target({found_in}): {file or options.file}{Style.RESET_ALL}")

        cmd = [file] + options.args
        if options.platform == Platform.WASM:
            command = runner.wasm.make_wrapper_command(cmd)
        else:
            command = runner.cmd.Command(cmd=cmd)
    except Exception as e:
        info(f"{Fore.RED}❌ {e}{Style.RESET_ALL}")
        sys.exit(1)

    exit_code = command.scoped_execute(f"[{options.platform.value.upper()}]")
    sys.exit(exit_code)
