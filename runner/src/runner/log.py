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
    LEVEL_COLORS = {
        logging.DEBUG: Style.DIM,
        logging.INFO: "",
        logging.WARNING: Fore.YELLOW,
        logging.ERROR: Fore.RED,
        logging.CRITICAL: Fore.RED + Style.BRIGHT,
    }

    def __init__(self, *args: Any, isatty: bool = False, **kwargs: Any) -> None:
        self._isatty = isatty
        super().__init__(*args, **kwargs)

    def formatTime(self, record: logging.LogRecord, datefmt: str | None = None) -> str:
        ct = time.localtime(record.created)
        if datefmt:
            s = time.strftime(datefmt, ct)
            return f"{s}.{int(record.msecs):03d}"
        return super().formatTime(record, datefmt)

    def format(self, record: logging.LogRecord) -> str:
        record.levelname = self.LEVEL_ABBREV.get(record.levelno, record.levelname[0])
        s = super().format(record)
        if self._isatty:
            color = self.LEVEL_COLORS.get(record.levelno, "")
            s = f"{color}{s}{Style.RESET_ALL}"
        return s


def setup_logging(verbose: bool = False, show_time: bool = False) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    handler = logging.StreamHandler()
    if show_time:
        fmt = "%(asctime)s %(levelname)s [%(name)s] %(message)s"
        handler.setFormatter(LogFormatter(fmt, datefmt="%H:%M:%S", isatty=handler.stream.isatty()))
    else:
        fmt = "%(levelname)s [%(name)s] %(message)s"
        handler.setFormatter(LogFormatter(fmt, isatty=handler.stream.isatty()))
    logging.basicConfig(level=level, handlers=[handler])


def trace(*args: Any, **kwargs: Any) -> None:
    """Trace with automatic flush."""
    print(Style.DIM, end="")
    print(*args, **kwargs)
    print(Style.RESET_ALL, end="", flush=True)


def info(*args: Any, **kwargs: Any) -> None:
    """Info with automatic flush."""
    print(*args, **kwargs, flush=True)


def warning(*args: Any, **kwargs: Any) -> None:
    """Warning with automatic flush."""
    print(Fore.YELLOW, end="")
    print(*args, **kwargs)
    print(Style.RESET_ALL, end="", flush=True)


def error(*args: Any, **kwargs: Any) -> None:
    """Error with automatic flush."""
    print(Fore.RED, end="")
    print(*args, **kwargs)
    print(Style.RESET_ALL, end="", flush=True)


