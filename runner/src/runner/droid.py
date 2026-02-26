#!/usr/bin/env python3
# This script is a helper to run an Android app on a connected device and capture its logs.
#
# DroidRunner provides make_command() for integration with the runner framework.
#
# Implementation details:
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
#   adb logcat --uid=$UID -T0
# Start the app:
#   adb shell monkey -p com.app -c android.intent.category.LAUNCHER 1
# Listen until the app is launched and then stop reading logs:
#   adb shell pidof -s com.app
import sys
import shlex
import argparse
import subprocess
import threading
import time
from typing import IO


try:
    from .log import info, trace, error, Fore, Style
    from .cmd import Command
except ImportError:
    from log import info, trace, error, Fore, Style
    from cmd import Command


_aapt_path = "/Users/rix/Library/Android/sdk/build-tools/36.0.0/aapt2"


class DroidRunner:
    """Runner for Android APK - installs and launches on connected device."""

    def __init__(self, ctx):
        self.ctx = ctx

    def make_command(self) -> Command:
        apk_path = str(self.ctx.found_file)
        return Command(
            cmd=[
                __import__("sys").executable,
                "-c",
                "import sys; from runner.droid import main; sys.exit(main(sys.argv[1:]) or 0)",
                apk_path,
            ],
        )


def _run(cmd, **kwargs):
    trace(f"_run: {shlex.join(cmd)}")
    return subprocess.run(cmd, **kwargs)


def _log_process_output(pipe: IO[str], prefix: str) -> None:
    for line in iter(pipe.readline, ""):
        if line:
            info(f"{prefix}{line.rstrip()}")
    pipe.close()


def main(args):
    """Run APK on device. Returns 0 on success, 1 on error (or None for backward compat)."""
    parser = argparse.ArgumentParser(description="Droid Runner - Run build on device and capture its native logs")
    parser.add_argument(
        'file',
        metavar='file [args ...]',
        help='.apk file to run on the device, followed by any additional arguments'
    )
    parsed_args, unknown_args = parser.parse_known_intermixed_args(args)
    trace(f"Droid: {parsed_args} {unknown_args}")

    file = parsed_args.file

    try:
        # Take the apk package name
        result = _run([_aapt_path, "dump", "packagename", file], check=True, capture_output=True, text=True)
        package_name = result.stdout.strip()
        trace(f"package: {package_name}")

        # Stop current activity
        _run(["adb", "shell", "am", "force-stop", package_name], check=True)

        # Install the app if not installed
        _run(["adb", "install", file], check=True)

        # Get uid of the installed app
        result = _run(["adb", "shell", "pm", "list", "package", "-U", package_name], check=True, capture_output=True, text=True)
        uid_line = result.stdout.strip()
        uid = uid_line.split("uid:")[1] if "uid:" in uid_line else None
        trace(f"uid: {uid}")
        if not uid:
            error(f"Could not find UID for package {package_name}.")
            return 1

        # Start reading logs for the app (without history)
        logcat_process: subprocess.Popen | None = None
        try:
            logcat_process = subprocess.Popen(
                ["adb", "logcat", f"--uid={uid}", "-T0"],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                bufsize=1,
            )
            log_thread = threading.Thread(
                target=_log_process_output,
                args=(logcat_process.stdout, "[LOGCAT] "),
                daemon=True,
            )
            log_thread.start()

            # Start the app
            _run(
                ["adb", "shell", "monkey", "-p", package_name, "-c", "android.intent.category.LAUNCHER", "1"],
                check=True,
            )

            # Listen until the app is launched and then stop reading logs
            while True:
                time.sleep(2)
                pid_result = subprocess.run(
                    ["adb", "shell", "pidof", "-s", package_name],
                    capture_output=True,
                    text=True,
                )
                trace(f'PIDOF: {pid_result.returncode} "{pid_result.stdout.strip()}"')
                if pid_result.returncode or not pid_result.stdout.strip():
                    info(f"PIDOF: {package_name} is not running anymore")
                    break

        except Exception as e:
            error(f"Error while running the app: {e}")
            return 1

        finally:
            if logcat_process:
                trace(f"Finishing logcat process...")
                logcat_process.terminate()

        return 0
    except Exception as e:
        error(f"Error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]) or 0)
