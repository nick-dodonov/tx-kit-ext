#!/usr/bin/env python3
# This script is a helper to run an Android app on a connected device and capture its logs.
#
# DroidCommand for integration with universal runner.
#
# Exit detection: Android process may not die on crash. We use:
# - timeout
# - pidof to detect when app process exits
# - full logcat to detect FATAL EXCEPTION
#
# Implementation details for manual run:
# Take the apk package name
#   /Users/rix/Library/Android/sdk/build-tools/36.0.0/aapt2 dump packagename app.apk
# Get sure the device is connected and adb can see it
#   adb devices
# Run the command to stop current activity
#   adb shell am force-stop com.example.app
# Install the app if not installed
#   adb install app.apk
#
# Prepare to get logs only for given package name.
# Obtain uid of the installed app:
#   adb shell pm list package -U com.app | sed 's/.*uid://'
# Start reading logs for the app (without history):
#   adb logcat --uid=$UID -T1
# Start the app:
#   adb shell monkey -p com.app -c android.intent.category.LAUNCHER 1
# Listen until the app is launched and then stop reading logs:
#   adb shell pidof -s com.app

import argparse
import logging
import re
import shlex
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import IO
from colorama import Style

from .cmd import Command

log = logging.getLogger(__name__)


_aapt_path = "/Users/rix/Library/Android/sdk/build-tools/36.0.0/aapt2"
_DEFAULT_TIMEOUT = 5


def _run(cmd, **kwargs):
    if isinstance(cmd, list):
        cmd_str = shlex.join(cmd)
    else:
        cmd_str = str(cmd)
    log.debug(f"[run] {cmd_str}")
    return subprocess.run(cmd, **kwargs)


def _target_logcat_handler(pipe: IO[str], prefix: str, stop_event: threading.Event | None = None) -> None:
    for line in iter(pipe.readline, ""):
        if stop_event and stop_event.is_set():
            break
        if line:
            print(f"{prefix}{line.rstrip()}")
    pipe.close()


class DroidCommand(Command):
    """Command that runs droid main() directly."""

    def __init__(self, apk_path: Path, timeout: int = _DEFAULT_TIMEOUT):
        Command.__init__(self, f"[DROID: {apk_path.name}]")
        self.apk_path = apk_path
        self.timeout = timeout

    def execute(self) -> int:
        apk_path = str(self.apk_path)
        result = _run([_aapt_path, "dump", "packagename", apk_path], check=True, capture_output=True, text=True)
        package_name = result.stdout.strip()
        log.debug(f"package: {package_name}")

        _run(["adb", "shell", "am", "force-stop", package_name], check=True)
        _run(["adb", "install", apk_path], check=True)

        result = _run(
            ["adb", "shell", "pm", "list", "package", "-U", package_name],
            check=True,
            capture_output=True,
            text=True,
        )
        uid_line = result.stdout.strip()
        uid = uid_line.split("uid:")[1] if "uid:" in uid_line else None
        log.debug(f"uid: {uid}")
        if not uid:
            log.error(f"Could not find UID for package {package_name}.")
            return 1

        # Shared state for exit detection
        fatal_exception = threading.Event()
        app_exited = threading.Event()
        stop_event = threading.Event()

        def _system_logcat_handler(pipe: IO[str]) -> None:
            """Read full logcat, detect FATAL EXCEPTION."""
            fatal_re = re.compile(r"FATAL EXCEPTION:", re.IGNORECASE)
            for line in iter(pipe.readline, ""):
                if stop_event.is_set():
                    break
                if fatal_re.search(line):
                    log.debug(f"[FATAL] {line.rstrip()}")
                    fatal_exception.set()
                    break
            pipe.close()

        # App-specific logcat for output (--uid)
        logcat_app = subprocess.Popen(
            [
                "adb",
                "logcat",
                f"--uid={uid}",
                "-v", "color", 
                "-v", "usec",
                # "-v", "uid",  # too verbose, already logged by --uid
                "-T1",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            bufsize=1,
        )
        app_thread = threading.Thread(
            target=_target_logcat_handler,
            args=(logcat_app.stdout, f"{Style.DIM}[cat]{Style.RESET_ALL} ", stop_event),  # [cat] for short of logcat output
            daemon=True,
        )
        app_thread.start()

        # Full logcat for FATAL EXCEPTION detection (AndroidRuntime tag is key for crashes)
        logcat_fatal = subprocess.Popen(
            ["adb", "logcat", "AndroidRuntime:E", "-T1"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            bufsize=1,
        )
        fatal_thread = threading.Thread(
            target=_system_logcat_handler,
            args=(logcat_fatal.stdout,),
            daemon=True,
        )
        fatal_thread.start()

        timeout = self.timeout
        log.debug(f"[run] # adb install + monkey {Path(apk_path).name} (timeout={timeout}s)")
        Command._log_delimiter_start()

        try:
            _run(
                ["adb", "shell", "monkey", "-p", package_name, "-c", "android.intent.category.LAUNCHER", "1"],
                check=True,
            )

            # Wait for app to start (pidof returns pid)
            time.sleep(0.5)  # TODO: wait event in logcat

            start = time.monotonic()
            timeout_reached = False
            while True:
                pid_result = subprocess.run(
                    ["adb", "shell", "pidof", "-s", package_name],
                    capture_output=True,
                    text=True,
                )

                if fatal_exception.is_set():
                    log.error("FATAL EXCEPTION detected")
                    break

                if pid_result.returncode or not pid_result.stdout.strip():
                    log.debug(f'pidof: polling stopped: {pid_result.returncode} "{pid_result.stdout.strip()}"')
                    app_exited.set()
                    break
                log.debug(f'pidof: polling tick: {pid_result.returncode} "{pid_result.stdout.strip()}"')

                elapsed = time.monotonic() - start
                if elapsed >= timeout:
                    log.error(f"Timeout reached: {timeout}s")
                    timeout_reached = True
                    break
        finally:
            stop_event.set()
            logcat_app.terminate()
            logcat_fatal.terminate()
            app_thread.join(timeout=2)
            fatal_thread.join(timeout=2)

        exit_code = 1 if (fatal_exception.is_set() or timeout_reached) else 0
        return exit_code


def main(args):
    """Run APK on device (CLI entry point). Returns 0 on success, 1 on error."""
    parser = argparse.ArgumentParser(description="Droid Runner - Run build on device and capture its native logs")
    parser.add_argument(
        "file",
        metavar="file [args ...]",
        help=".apk file to run on the device",
    )
    parser.add_argument(
        "--timeout",
        "-t",
        type=int,
        default=_DEFAULT_TIMEOUT,
        help=f"Timeout in seconds (default: {_DEFAULT_TIMEOUT})",
    )
    parsed_args, _ = parser.parse_known_intermixed_args(args)
    log.debug(f"Droid: {parsed_args}")

    return DroidCommand(
        Path(parsed_args.file), 
        parsed_args.timeout
    ).scoped_execute("[DROID]")


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]) or 0)
