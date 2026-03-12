import logging
import os
import re
import sys

from . import find, detect, cmd, wasm, droid
from . import context
from .context import Platform, Options

log = logging.getLogger(__name__)


ENV_REGEXP_FILTERS = [
    # debug: re.compile(r".*"),
    re.compile(r"^BAZEL(?!ISK_SKIP_WRAPPER$)"),
    re.compile(r"^BUILD_"),
    re.compile(r"^RUNFILES_"),
    re.compile(r"^TEST_(?!.*(_FILE|DIR)$)"),  # Exclude TEST_*_FILE and TEST_*DIR to avoid leaking large unnecessary file paths
]


def _log_process_info() -> None:
    log.debug("CWD %s", os.getcwd())
    for index, arg in enumerate(sys.argv):
        log.debug("[%s] %s", index, arg)
    for key, value in sorted(os.environ.items()):
        if any(pattern.match(key) for pattern in ENV_REGEXP_FILTERS):
            log.debug("  %s=%s", key, value)


def _main(options: Options) -> int:
    _log_process_info()

    finder = find.Finder()
    found_file, found_in = finder.find_file(options.file)
    if not found_file:
        raise FileNotFoundError(f"File not found: {options.file}")
    log.debug(f"Found: {found_file} # {found_in}")

    platform = options.platform
    if platform == Platform.AUTO:
        platform = options.platform = detect.detect_platform(found_file)
    log.debug("starting specific: %s", platform)

    if platform == Platform.WASM:
        ctx = context.Context(
            options=options,
            finder=finder,
            found_file=found_file,
        )
        command = wasm.WasmRunner(ctx).make_command()
    elif platform == Platform.DROID:
        ctx = context.Context(
            options=options,
            finder=finder,
            found_file=found_file,
        )
        command = droid.DroidCommand(ctx.found_file, ctx.options.args)
    elif platform == Platform.EXEC:
        command = cmd.RunCommand(
            scope_prefix=f"[EXEC: {found_file.name}]",
            cmd=[str(found_file)] + options.args)
    elif platform == Platform.PYTHON:
        command = cmd.RunCommand(
            scope_prefix=f"[PYTHON: {found_file.name}]",
            cmd=["python3", str(found_file)] + options.args)
    else:
        raise ValueError(f"Unsupported platform: {platform}")

    return command.scoped_execute()


def start(options: Options) -> None:
    try:
        exit_code = _main(options)
        sys.exit(exit_code)
    except Exception as e:
        log.error("❌ %s", e)
        if isinstance(e, FileNotFoundError):
            sys.exit(1)
        raise
