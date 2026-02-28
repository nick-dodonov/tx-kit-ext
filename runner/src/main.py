#!/usr/bin/env python3
import argparse
import logging
import sys
import os

from colorama import Fore, Style
from pathlib import Path

import runner
from runner.log import setup_logging
from runner.context import Options, Platform

log = logging.getLogger("main")


def _parse_args() -> Options:
    parser = argparse.ArgumentParser(
        description="Runner - executor of binary file for target platform",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--platform",
        "-p",
        choices=[p.value for p in Platform],
        default=Platform.AUTO.value,
        help="Target platform to run the binary for (default: auto-detect)",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="count",
        default=0,
        help="-v debug, -vv debug+time",
    )
    parser.add_argument("file", help="Target binary file to execute")

    # Don't use optional positional nargs='*' allowing to capture -x/--x options after file (captured by parse_known_intermixed_args)
    # parser.add_argument('args', nargs='*', help="Arguments to pass to the target binary")
    args = sys.argv[1:]
    parsed_args, remain_args = parser.parse_known_intermixed_args(args)
    remain_args = list[str](remain_args)

    setup_logging(
        verbose=parsed_args.verbose >= 1, 
        show_time=parsed_args.verbose >= 2,
    )
    log.debug("parsing %s", args)
    log.debug("parsed %s", parsed_args)
    if remain_args:
        log.debug("remain %s", remain_args)

    return Options(
        platform=Platform(parsed_args.platform),
        file=Path(parsed_args.file),
        args=remain_args,
    )


if __name__ == "__main__":
    print(f"{Fore.CYAN}{Style.BRIGHT}⭐ Runner {Style.DIM}(Python {sys.version.split()[0]}, PID {os.getpid()}){Style.RESET_ALL}")
    options = _parse_args()
    log.debug("starting runner: %s", options)
    runner.start(options)
