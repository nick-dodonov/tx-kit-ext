import os
import sys
import subprocess

from dataclasses import dataclass, field
from enum import Enum
from typing import List
from python.runfiles import Runfiles

from .log import info as _log
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
        _log(">>> No program specified to run")
        sys.exit(1)

    if r:
        rlocation = r.Rlocation(sys.argv[1])
        _log(f">>> Rlocation ({rwhere}):")
        _log(rlocation)
        if rlocation is None:
            rlocation = sys.argv[1]
    else:
        _log(">>> No runfiles found")
        rlocation = sys.argv[1]


def _find_file(file: str) -> tuple[str | None, str]:
    if os.path.exists(file):
        return file, "AS-IS"

    build_working_dir = os.environ.get("BUILD_WORKING_DIRECTORY")
    if build_working_dir:
        candidate = os.path.join(build_working_dir, file)
        if os.path.exists(candidate):
            return candidate, "BUILD_WORKING_DIRECTORY"

    return None, "NOT-FOUND"


def start(options: Options) -> None:
    file, found_in = _find_file(options.file)
    _log(f">>> File ({found_in}): {file or options.file}")
    if not file:
        sys.exit(1)

    cmd = [file] + options.args
    platform_str = str.upper(options.platform.value)
    _log(f">>> Executing ({platform_str}): {cmd}")

    if options.platform == Platform.WASM:
        result = runner.wasm.main(cmd)
    else:
        result = subprocess.call(cmd)

    _log(f">>> Result ({platform_str}): {result}")
    sys.exit(result)
