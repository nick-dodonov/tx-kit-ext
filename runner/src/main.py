#!/usr/bin/env python3
import os
import sys
import argparse

import runner
from runner.log import info as _log


_ENV_PREFIXES = ["BUILD_", "RUNFILES_", "TEST_", "TESTBRIDGE_"]


def _log_header() -> None:
    _log(">>> Directory:")
    _log(f"  CWD {os.getcwd()}")
    _log(">>> Arguments:")
    for index, arg in enumerate(sys.argv):
        _log(f"  [{index}] {arg}")
    _log(">>> Environment (specific):")
    for key, value in sorted(os.environ.items()):
        if any(key.startswith(prefix) for prefix in _ENV_PREFIXES):
            _log(f"  {key}={value}")


def _parse_args() -> runner.Options:
    parser = argparse.ArgumentParser(
        description="Runner - executor of binary file for target platform",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--platform",
        "-p",
        choices=[p.value for p in runner.Platform],
        default=runner.Platform.AUTO.value,
        help="Target platform to run the binary for (default: auto-detect)",
    )
    parser.add_argument("file", help="Target binary file to execute")

    # Don't use optional positional nargs='*' allowing to capture -x/--x options after file (captured by parse_known_intermixed_args)
    # parser.add_argument('args', nargs='*', help="Arguments to pass to the target binary")

    args = sys.argv[1:]
    _log(f">>> Parsing: {args}")
    parsed_args, remain_args = parser.parse_known_intermixed_args(args)
    remain_args: list[str] = remain_args  # type hint for mypy
    _log(f"  parsed: {parsed_args}")
    if remain_args:
        _log(f"  remain: {remain_args}")

    return runner.Options(
        platform=runner.Platform(parsed_args.platform),
        file=parsed_args.file,
        args=remain_args,
    )


if __name__ == "__main__":
    _log_header()
    options = _parse_args()
    runner.start(options)
