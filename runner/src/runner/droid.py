#!/usr/bin/env python3
# This script is a helper to run an Android app on a connected device and capture its logs.
#
# DroidCommand for integration with universal runner.
#
# Exit detection: Android process may not die on crash. We use:
# - timeout
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

from __future__ import annotations

import argparse
import asyncio
import logging
import re
import shlex
import subprocess
import sys
from dataclasses import dataclass
from enum import Enum
from pathlib import Path

from colorama import Style

from .cmd import Command

log = logging.getLogger(__name__)


_aapt_path = "/Users/rix/Library/Android/sdk/build-tools/36.0.0/aapt2"
_DEFAULT_TIMEOUT = 5
_VM_EXITING_RE = re.compile(r"VM exiting with result code (\d+)", re.IGNORECASE)
_FATAL_EXCEPTION_RE = re.compile(r"FATAL EXCEPTION:", re.IGNORECASE)


class ExitReason(Enum):
    """Reason for run termination."""

    COMPLETED = "completed"
    TIMEOUT = "timeout"
    FATAL_EXCEPTION = "fatal_exception"
    CANCELLED = "cancelled"


class LogSource(Enum):
    """Source of logcat output."""

    APP = "app"
    SYSTEM = "sys"


@dataclass
class LogEvent:
    """Log line from app or system logcat."""

    source: LogSource
    line: str


@dataclass
class ExitEvent:
    """Signal to terminate the run."""

    reason: ExitReason
    descr: str | None = None
    exit_code: int | None = None

    def take_exit_code(self) -> int:
        msg = f"{self.reason}{self.descr and f' {self.descr}' or ''}"
        if self.reason == ExitReason.COMPLETED:
            code = self.exit_code if self.exit_code is not None else 0
            log.debug(msg) if code == 0 else log.error(msg)
            return code
        log.error(msg)
        return 1


def _log_cmd(cmd: list[str] | str) -> None:
    if isinstance(cmd, list):
        cmd_str = shlex.join(cmd)
    else:
        cmd_str = str(cmd)
    log.debug(f"[run] {cmd_str}")


def _run(cmd: list[str] | str, **kwargs) -> subprocess.CompletedProcess[str]:
    _log_cmd(cmd)
    return subprocess.run(cmd, **kwargs)


async def _run_async(cmd: list[str] | str, **kwargs) -> subprocess.CompletedProcess[str]:
    """Run blocking subprocess in thread pool."""
    _log_cmd(cmd)
    return await asyncio.to_thread(subprocess.run, cmd, **kwargs)


class DroidCommand(Command):
    """Command that runs droid main() directly."""

    def __init__(self, apk_path: Path, timeout: int = _DEFAULT_TIMEOUT):
        Command.__init__(self, f"[DROID: {apk_path.name}]")
        self.apk_path = apk_path
        self.timeout = timeout

        # Get package name from APK
        result = _run([_aapt_path, "dump", "packagename", str(apk_path)], check=True, capture_output=True, text=True)
        package_name = result.stdout.strip()
        log.debug(f"package: {package_name}")
        self.package_name = package_name

    def execute(self) -> int:
        """Execute and return exit code. Runs async logic via asyncio.run()."""
        return asyncio.run(self._execute_async())

    async def _execute_async(self) -> int:
        await _run_async(["adb", "shell", "am", "force-stop", self.package_name], check=True)
        await _run_async(["adb", "install", str(self.apk_path)], check=True)
        self.uid = await self._get_package_uid(self.package_name)

        Command._log_delimiter_start()
        try:
            await _run_async(
                ["adb", "shell", "monkey", "-p", self.package_name, "-c", "android.intent.category.LAUNCHER", "1"],
                check=True,
                capture_output=True,
                text=True,
            )
            exit_event = await self._run_logcat_and_wait()
            return exit_event.take_exit_code()
        finally:
            await _run_async(["adb", "shell", "am", "force-stop", self.package_name], check=True)

    async def _get_package_uid(self, package_name: str) -> str:
        """Get UID of installed package from pm list. Raises ValueError if not found."""
        result = await _run_async(
            ["adb", "shell", "pm", "list", "package", "-U", package_name],
            check=True,
            capture_output=True,
            text=True,
        )
        uid_line = result.stdout.strip()
        if "uid:" not in uid_line:
            raise ValueError(f"Could not find UID for package {package_name}")
        uid = uid_line.split("uid:")[1]
        log.debug(f"uid: {uid}")
        return uid

    async def _run_logcat_and_wait(self) -> ExitEvent:
        """Start logcat processes, wait for exit condition, return exit code."""
        event_queue: asyncio.Queue[LogEvent | ExitEvent] = asyncio.Queue()

        app_logcat_cmd = [
            "adb",
            "logcat",
            f"--uid={self.uid}",
            "-v", "color",
            "-v", "usec",
            "-v", "uid",
            "-T1",
        ]
        system_logcat_cmd = [
            "adb",
            "logcat",
            f"--uid={self.uid},1000,0",
            "-v", "color",
            "-v", "usec",
            "-v", "uid",
            "-T1",
            "-s",
            "ActivityTaskManager:V",
            "ActivityManager:V",
            "Zygote:V",
            "BootReceiver:I",
        ]

        app_proc = await asyncio.create_subprocess_exec(
            *app_logcat_cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )
        system_proc = await asyncio.create_subprocess_exec(
            *system_logcat_cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )

        async def emit_logcat_events(
            proc: asyncio.subprocess.Process,
            source: LogSource,
        ) -> None:
            assert proc.stdout is not None
            try:
                while True:
                    line = await proc.stdout.readline()
                    if not line:
                        break
                    line_str = line.decode("utf-8", errors="replace").rstrip()
                    if line_str:
                        await event_queue.put(LogEvent(source, line_str))
            except asyncio.CancelledError:
                pass
            finally:
                proc.terminate()

        async def emit_timeout_event() -> None:
            await asyncio.sleep(self.timeout)
            await event_queue.put(ExitEvent(ExitReason.TIMEOUT, f"{self.timeout}s timeout reached"))

        app_logcat_task = asyncio.create_task(emit_logcat_events(app_proc, LogSource.APP))
        system_logcat_task = asyncio.create_task(emit_logcat_events(system_proc, LogSource.SYSTEM))
        timeout_task = asyncio.create_task(emit_timeout_event())

        def _log_line(source: LogSource, line: str) -> None:
            prefix = f"{Style.DIM}[{source.value}]{Style.RESET_ALL}"
            log.info(f"{prefix} {line}")

        def _log_remaining_lines() -> None:
            while True:
                try:
                    remaining = event_queue.get_nowait()
                    if isinstance(remaining, LogEvent):
                        _log_line(remaining.source, remaining.line)
                except asyncio.QueueEmpty:
                    break

        try:
            while True:
                item = await event_queue.get()
                if isinstance(item, ExitEvent):
                    return item
                assert isinstance(item, LogEvent)

                _log_line(item.source, item.line)
                if item.source == LogSource.APP:
                    mo = _VM_EXITING_RE.search(item.line)
                    if mo:
                        exit_code = int(mo.group(1))
                        return ExitEvent(ExitReason.COMPLETED, f"'{_VM_EXITING_RE.pattern}' -> {mo.groups()}", exit_code)
                    if _FATAL_EXCEPTION_RE.search(item.line):
                        return ExitEvent(ExitReason.FATAL_EXCEPTION, f"'{_FATAL_EXCEPTION_RE.pattern}'")
        except asyncio.CancelledError:
            return ExitEvent(ExitReason.CANCELLED)
        finally:
            _log_remaining_lines()

            timeout_task.cancel()
            app_logcat_task.cancel()
            system_logcat_task.cancel()
            try:
                await asyncio.gather(timeout_task, app_logcat_task, system_logcat_task)
            except asyncio.CancelledError:
                pass


def main(args: list[str]) -> int:
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
        parsed_args.timeout,
    ).scoped_execute()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]) or 0)
