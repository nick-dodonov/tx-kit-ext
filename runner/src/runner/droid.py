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
_aapt_badging_path = "/Users/rix/Library/Android/sdk/build-tools/36.0.0/aapt"
_DEFAULT_TIMEOUT = 5
_TX_ARGV_EXTRA = "tx.argv"
_LAUNCHABLE_ACTIVITY_RE = re.compile(r"launchable-activity: name='([^']+)'")
_DEFAULT_TAIL_SECONDS = 0.1
_CRASH_TAIL_SECONDS = 0.3
# With -v color, logcat may prefix lines with ANSI escape codes, so use search() not match()
_VM_EXITING_RE = re.compile(r"VM exiting with result code (\d+)", re.IGNORECASE)
_FATAL_EXCEPTION_RE = re.compile(r"FATAL EXCEPTION:", re.IGNORECASE)
_FATAL_SIGNAL_RE = re.compile(r"Fatal signal (\d+)", re.IGNORECASE)
# logcat format: MM-DD HH:MM:SS.uuuuuuu uid pid tid level tag: message
_APP_LOG_PID_RE = re.compile(r"\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+\s+\d+\s+(\d+)\s+\d+\s+")
_START_PROC_RE = re.compile(r"Start proc (\d+):(.+)/", re.IGNORECASE)  # 03-01 18:52:29.862054  1000   586   623 I ActivityManager: Start proc 19859:com.tx/u0a153 for next-top-activity {com.tx/tx.DroidActivity}
_PROCESS_EXITED_CLEANLY_RE = re.compile(r"Process (\d+) exited cleanly \((\d+)\)", re.IGNORECASE)
_PROCESS_EXITED_SIGNAL_RE = re.compile(r"Process (\d+) exited due to signal (\d+)", re.IGNORECASE)


class ExitReason(Enum):
    """Reason for run termination."""

    COMPLETED = "completed"
    TIMEOUT = "timeout"
    FATAL_EXCEPTION = "fatal_exception"
    CANCELLED = "cancelled"
    PROCESS_DIED = "process_died"

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
        log.info(f"{self.reason}{self.descr and f' {self.descr}' or ''}")
        if self.reason == ExitReason.COMPLETED:
            code = self.exit_code if self.exit_code is not None else 0
            return code
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


async def _run_asyncio(cmd: list[str] | str, **kwargs) -> asyncio.subprocess.Process:
    _log_cmd(cmd)
    return await asyncio.create_subprocess_exec(*cmd, **kwargs)


def _get_launcher_activity(apk_path: Path) -> str:
    """Get launchable activity name from APK via aapt dump badging."""
    result = _run(
        [_aapt_badging_path, "dump", "badging", str(apk_path)],
        check=True,
        capture_output=True,
        text=True,
    )
    mo = _LAUNCHABLE_ACTIVITY_RE.search(result.stdout)
    if not mo:
        raise ValueError(f"No launchable-activity in {apk_path}")
    return mo.group(1)


class DroidCommand(Command):
    """Command that runs droid main() directly."""

    def __init__(
        self,
        apk_path: Path,
        args: list[str] | None = None,
        timeout: int = _DEFAULT_TIMEOUT,
    ):
        Command.__init__(self, f"[DROID: {apk_path.name}]")
        self.apk_path = apk_path
        self.args = args or []
        self.timeout = timeout

        # Get package name from APK
        result = _run([_aapt_path, "dump", "packagename", str(apk_path)], check=True, capture_output=True, text=True)
        package_name = result.stdout.strip()
        log.debug(f"package: {package_name}")
        self.package_name = package_name

        # Get launcher activity from APK
        self.launcher_activity = _get_launcher_activity(apk_path)
        self.component = f"{package_name}/{self.launcher_activity}"
        log.debug(f"launcher_activity: {self.launcher_activity}, component: {self.component}")

    def execute(self) -> int:
        """Execute and return exit code. Runs async logic via asyncio.run()."""
        return asyncio.run(self._execute_async())

    async def _execute_async(self) -> int:
        await _run_async(["adb", "shell", "am", "force-stop", self.package_name], check=True)
        await _run_async(["adb", "install", str(self.apk_path)], check=True)

        self.uid = self._get_package_uid(self.package_name)
        log.debug(f"UID {self.uid} for package {self.package_name}")

        Command._log_delimiter_start()
        try:
            exit_event = await self._run_app_and_handle_logs()
            return exit_event.take_exit_code()
        finally:
            #await _run_async(["adb", "shell", "am", "force-stop", self.package_name], check=True)
            pass

    @staticmethod
    def _get_package_uid(package_name: str) -> str:
        """Get UID of installed package from pm list. Raises ValueError if not found."""
        result = _run(
            ["adb", "shell", "pm", "list", "package", "-U", package_name],
            check=True,
            capture_output=True,
            text=True,
        )
        uid_line = result.stdout.strip()
        if "uid:" not in uid_line:
            raise ValueError(f"Could not find UID for package {package_name}")
        uid = uid_line.split("uid:")[1]
        return uid

    def _run_app(self) -> None:
        """Launch app via am start. Passes tx.argv extra when args are provided."""
        if self.args:
            args_str = " ".join(self.args)
            # Pass as single shell string so "foo bar" survives device shell parsing
            am_cmd = f"am start -n {self.component} --es {_TX_ARGV_EXTRA} {shlex.quote(args_str)}"
            cmd = ["adb", "shell", am_cmd]
        else:
            cmd = ["adb", "shell", "am", "start", "-n", self.component]
        log.debug(f"am start: component={self.component}, args={self.args}")
        _run(cmd, check=True, capture_output=True, text=True)

    async def _run_app_and_handle_logs(self) -> ExitEvent:
        """Start logcat processes, wait for exit condition, return exit code."""
        self.app_pid = None
        event_queue: asyncio.Queue[LogEvent | ExitEvent] = asyncio.Queue()

        app_proc = await _run_asyncio([
                "adb",
                "logcat",
                f"--uid={self.uid}",
                "-v", "color",
                "-v", "usec",
                "-v", "uid",
                "-T1",
            ],
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )
        system_proc = await _run_asyncio([
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
            ],
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

        self._run_app()

        def _log_line(source: LogSource, line: str) -> None:
            prefix = f"{Style.DIM}[{source.value}]{Style.RESET_ALL}"
            if log.isEnabledFor(logging.DEBUG):
                if source == LogSource.APP:
                    log.info(f"{prefix} {line}")
                else:
                    log.debug(f"{prefix} {line}")
            else:
                # strip logcat line heads like 
                #   "03-03 18:26:33.635544 10126  5118  5118 "
                #   "03-03 18:32:44.810636  root   356   356 "
                if source == LogSource.APP:
                    line = re.sub(r"\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+\s+.+\s+\d+\s+\d+\s+", "", line)
                    log.info(f"{line}")


        def _log_remaining_lines() -> None:
            while True:
                try:
                    remaining = event_queue.get_nowait()
                    if isinstance(remaining, LogEvent):
                        _log_line(remaining.source, remaining.line)
                except asyncio.QueueEmpty:
                    break

        def _ensure_app_pid_from_app_log(line: str) -> None:
            if self.app_pid is not None:
                return
            mo = _APP_LOG_PID_RE.search(line)
            if mo:
                self.app_pid = int(mo.group(1))
                log.debug(f"PID {self.app_pid} from app log '{_APP_LOG_PID_RE.pattern}' -> {mo.groups()}")

        def _ensure_app_pid_from_system_log(line: str) -> None:
            if self.app_pid is not None:
                return
            mo = _START_PROC_RE.search(line)
            if mo and self.package_name in line:
                self.app_pid = int(mo.group(1))
                log.debug(f"PID {self.app_pid} from system log '{_START_PROC_RE.pattern}' -> {mo.groups()}")

        # Handle events from app and system logcat until exit condition is detected (normal or abnormal)
        tail_seconds = _DEFAULT_TAIL_SECONDS
        try:
            while True:
                item = await event_queue.get()
                if isinstance(item, ExitEvent):
                    return item
                assert isinstance(item, LogEvent)

                _log_line(item.source, item.line)
                if item.source == LogSource.APP:
                    _ensure_app_pid_from_app_log(item.line)
                    mo = _VM_EXITING_RE.search(item.line)
                    if mo:
                        exit_code = int(mo.group(1))
                        return ExitEvent(ExitReason.COMPLETED, f"'{_VM_EXITING_RE.pattern}' -> {mo.groups()}", exit_code)
                    if _FATAL_EXCEPTION_RE.search(item.line):
                        return ExitEvent(ExitReason.FATAL_EXCEPTION, f"'{_FATAL_EXCEPTION_RE.pattern}'")
                    mo = _FATAL_SIGNAL_RE.search(item.line)
                    if mo:
                        signal_num = int(mo.group(1))
                        tail_seconds = _CRASH_TAIL_SECONDS
                        return ExitEvent(ExitReason.PROCESS_DIED, f"'{_FATAL_SIGNAL_RE.pattern}' -> {mo.groups()}", 128 + signal_num)
                else:
                    _ensure_app_pid_from_system_log(item.line)
                    mo = _PROCESS_EXITED_CLEANLY_RE.search(item.line)
                    if mo and self.app_pid is not None and int(mo.group(1)) == self.app_pid:
                        exit_code = int(mo.group(2))
                        tail_seconds = _CRASH_TAIL_SECONDS
                        return ExitEvent(ExitReason.COMPLETED, f"'{_PROCESS_EXITED_CLEANLY_RE.pattern}' -> {mo.groups()}", exit_code)
                    mo = _PROCESS_EXITED_SIGNAL_RE.search(item.line)
                    if mo and self.app_pid is not None and int(mo.group(1)) == self.app_pid:
                        signal_num = int(mo.group(2))
                        tail_seconds = _CRASH_TAIL_SECONDS
                        return ExitEvent(ExitReason.PROCESS_DIED, f"'{_PROCESS_EXITED_SIGNAL_RE.pattern}' -> {mo.groups()}", 128 + signal_num)
        except asyncio.CancelledError:
            return ExitEvent(ExitReason.CANCELLED)
        finally:
            await asyncio.sleep(tail_seconds)  # Wait for logcat to flush latest lines (i.e. from crashhandler)

            timeout_task.cancel()
            app_logcat_task.cancel()
            system_logcat_task.cancel()
            try:
                await asyncio.gather(timeout_task, app_logcat_task, system_logcat_task)
            except asyncio.CancelledError:
                pass

            # Ensure subprocess transports are closed before event loop shuts down
            await asyncio.gather(app_proc.wait(), system_proc.wait())

            _log_remaining_lines()


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
    parsed_args, remain_args = parser.parse_known_intermixed_args(args)
    log.debug(f"Droid: {parsed_args}, args for app: {remain_args}")

    return DroidCommand(
        Path(parsed_args.file),
        args=remain_args,
        timeout=parsed_args.timeout,
    ).scoped_execute()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]) or 0)
