import os
import sys
import subprocess

from dataclasses import dataclass, field
from enum import Enum
from typing import List
from python.runfiles import Runfiles

from runner.log import *
import runner.wasm


class Platform(Enum):
    """Target platform for execution."""

    AUTO = "auto"
    WASM = "wasm"


@dataclass
class Options:
    """Start options."""

    file: str
    args: List[str] = field(default_factory=list)
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


_ENV_PREFIXES = ["BUILD_", "RUNFILES_"] #, "TEST_"]


def _log_process_header() -> None:
    info(f"{Fore.CYAN}⭐ Runner{Style.RESET_ALL}")
    info(f"{Style.DIM}  CWD {os.getcwd()}{Style.RESET_ALL}")
    for index, arg in enumerate(sys.argv):
        info(f"{Style.DIM}  [{index}] {arg}{Style.RESET_ALL}")
    for key, value in sorted(os.environ.items()):
        if any(key.startswith(prefix) for prefix in _ENV_PREFIXES):
            info(f"{Style.DIM}  {key}={value}{Style.RESET_ALL}")


def _find_file(file: str) -> tuple[str | None, str]:
    if os.path.exists(file):
        return file, "AS-IS"

    build_working_dir = os.environ.get("BUILD_WORKING_DIRECTORY")
    if build_working_dir:
        candidate = os.path.join(build_working_dir, file)
        if os.path.exists(candidate):
            return candidate, "BUILD_WORKING_DIRECTORY"

    return None, "NOT-FOUND"


def _execute_command(platform: Platform, cmd: List[str]) -> int:
    platform_str = platform.value.upper()
    info(f"{Fore.LIGHTBLUE_EX}➡️ [{platform_str}]:{Style.RESET_ALL} {cmd}") # ⬇️
    info(f"{Fore.LIGHTBLUE_EX}{'>' * 64}{Style.RESET_ALL}")

    try:
        result = subprocess.run(cmd, check=False)
        exit_code = result.returncode
    except FileNotFoundError as e:
        info(f"{Fore.RED}❌ Command not found: {cmd[0]}{Style.RESET_ALL}")
        info(f"Error: {e}")
        exit_code = 127
    except KeyboardInterrupt:
        info(f"\n{Fore.YELLOW}⚠️ Interrupted by user{Style.RESET_ALL}")
        exit_code = 130
    except Exception as e:
        info(f"{Fore.RED}❌ Execution error: {e}{Style.RESET_ALL}")
        exit_code = 1

    info(f"{Fore.LIGHTBLUE_EX}{'<' * 64}{Style.RESET_ALL}")
    finish_prefix = f"{Fore.LIGHTBLUE_EX}⬅️ [{platform_str}]:{Style.RESET_ALL}" # ⬆️ 🏁
    if exit_code == 0:
        info(f"{finish_prefix} {Fore.GREEN}✅ Success: {exit_code}{Style.RESET_ALL}")
    else:
        info(f"{finish_prefix} {Fore.RED}❌ Error: {exit_code}{Style.RESET_ALL}")

    return exit_code


def start(options: Options) -> None:
    _log_process_header()
    info(f"{Style.DIM}  {options}{Style.RESET_ALL}")

    try:
        file, found_in = _find_file(options.file)
        if not file:
            raise FileNotFoundError(f"Target file not found: {options.file}")
        info(f"{Style.DIM}  Target({found_in}): {file or options.file}")

        cmd = [file] + options.args
        if options.platform == Platform.WASM:
            cmd = runner.wasm.make_wrapper_cmd(cmd)

    except Exception as e:
        info(f"{Fore.RED}❌ {e}{Style.RESET_ALL}")
        sys.exit(1)

    exit_code = _execute_command(options.platform, cmd)
    sys.exit(exit_code)
