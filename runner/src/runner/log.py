import logging
import sys
import time
from typing import Any

# https://github.com/tartley/colorama
# from colorama import init
# init(autoreset=True) # make termcolor work on windows and simplify usage by auto-resetting styles after each print
# init() # don't auto-reset to allow multi-line styled output
from colorama import just_fix_windows_console

just_fix_windows_console()  # make termcolor work on windows without auto-resetting styles after each print

# exported for use in other modules
from colorama import Fore, Style, Back


# Fix encoding for piped stdout/stderr on Windows (when used in subprocess.Popen)
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # pyright: ignore[reportAttributeAccessIssue]
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")  # pyright: ignore[reportAttributeAccessIssue]
    except (AttributeError, OSError):
        # Python < 3.7 or stream doesn't support reconfigure
        pass


class LogFormatter(logging.Formatter):
    LEVEL_ABBREV = {
        logging.DEBUG: "D",
        logging.INFO: "I",
        logging.WARNING: "W",
        logging.ERROR: "E",
        logging.CRITICAL: "C",
    }
    LEVEL_NORMAL = {
        logging.DEBUG: "[DEBUG] ",
        logging.INFO: "",
        logging.WARNING: "[WARNING] ",
        logging.ERROR: "[ERROR] ",
        logging.CRITICAL: "[CRITICAL] ",
    }
    LEVEL_COLORS = {
        logging.DEBUG: Style.DIM,
        logging.INFO: "",
        logging.WARNING: Fore.YELLOW,
        logging.ERROR: Fore.RED,
        logging.CRITICAL: Fore.RED + Style.BRIGHT,
    }

    def __init__(self, *args: Any, verbose: bool = False, isatty: bool = False, **kwargs: Any) -> None:
        self._isatty = isatty
        self._level_map = self.LEVEL_ABBREV if verbose else self.LEVEL_NORMAL
        super().__init__(*args, **kwargs)

    def formatTime(self, record: logging.LogRecord, datefmt: str | None = None) -> str:
        ct = time.localtime(record.created)
        if datefmt:
            s = time.strftime(datefmt, ct)
            return f"{s}.{int(record.msecs):03d}"
        return super().formatTime(record, datefmt)

    def format(self, record: logging.LogRecord) -> str:
        record.levelname = self._level_map.get(record.levelno, record.levelname[0])
        s = super().format(record)
        if self._isatty:
            color = self.LEVEL_COLORS.get(record.levelno, "")
            s = f"{color}{s}{Style.RESET_ALL}"
        return s


def _supports_color() -> bool:
    """Return True if stdout supports ANSI color escape codes."""
    import os
    if os.environ.get("NO_COLOR"):
        return False
    if os.environ.get("FORCE_COLOR"):
        return True
    if os.environ.get("TERM") == "dumb":
        return False
    return sys.stdout.isatty()


def setup_logging(verbose: bool = False, show_time: bool = False) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    isatty = _supports_color()
    if show_time:
        fmt = "%(asctime)s %(levelname)s [%(name)s] %(message)s"
    elif verbose:
        fmt = "%(levelname)s [%(name)s] %(message)s"
    else:
        fmt = "%(levelname)s%(message)s"

    handler = logging.StreamHandler()
    handler.setFormatter(LogFormatter(
        fmt,
        datefmt="%H:%M:%S" if show_time else None,
        verbose=verbose,
        isatty=isatty,
    ))
    logging.basicConfig(level=level, handlers=[handler])
