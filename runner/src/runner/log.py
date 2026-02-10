from typing import Any
import sys

# https://github.com/tartley/colorama
# from colorama import init
# init(autoreset=True) # make termcolor work on windows and simplify usage by auto-resetting styles after each print
# init() # don't auto-reset to allow multi-line styled output
from colorama import just_fix_windows_console
just_fix_windows_console() # make termcolor work on windows without auto-resetting styles after each print

# exported for use in other modules
from colorama import Fore, Style, Back


# Fix encoding for piped stdout/stderr on Windows (when used in subprocess.Popen)
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except (AttributeError, OSError):
        # Python < 3.7 or stream doesn't support reconfigure
        pass


def info(*args: Any, **kwargs: Any) -> None:
    """Print function with automatic flush."""
    print(*args, **kwargs, flush=True)
