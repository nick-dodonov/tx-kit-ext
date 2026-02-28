import logging
import os
import shlex
import subprocess
import sys
from abc import ABC, abstractmethod
from pathlib import Path

from .log import Fore, Style

__all__ = ["Command", "RunCommand"]

log = logging.getLogger(__name__)


class Command(ABC):
    """Base interface for executable commands."""

    @property
    @abstractmethod
    def descr(self) -> str:
        """Description for logging (e.g. executable name)."""
        ...

    @abstractmethod
    def scoped_execute(self, scope_prefix: str) -> int:
        """Execute and return exit code."""
        ...

    @staticmethod
    def _log_delimiter(symbol: str, color: str, length: int = 64) -> None:
        print(f"{color}{symbol * length}{Style.RESET_ALL}")

    @staticmethod
    def _log_delimiter_header(scope_prefix: str) -> None:
        log.info(f"{Fore.CYAN}➡️  {scope_prefix}{Style.RESET_ALL}")

    @staticmethod
    def _log_delimiter_start() -> None:
        Command._log_delimiter(">", Fore.LIGHTBLUE_EX)

    @staticmethod
    def _log_delimiter_finish(scope_prefix: str, exit_code: int) -> None:
        Command._log_delimiter("<", Fore.LIGHTBLUE_EX)
        finish_prefix = f"{Fore.CYAN}⬅️  {scope_prefix}{Style.RESET_ALL}"
        if exit_code == 0:
            log.info(f"{finish_prefix} {Fore.GREEN}✅ Success: {exit_code}{Style.RESET_ALL}")
        else:
            log.error(f"{finish_prefix} {Fore.RED}❌ Error: {exit_code}{Style.RESET_ALL}")


class RunCommand(Command):
    """Command that runs via subprocess."""

    def __init__(self, cmd: list[str], cwd: str | None = None, cwd_descr: str | None = None):
        self.cmd = cmd
        self.cwd = cwd
        self.cwd_descr = cwd_descr

    @property
    def descr(self) -> str:
        return Path(self.cmd[0]).name

    def scoped_execute(self, scope_prefix: str) -> int:
        Command._log_delimiter_header(scope_prefix)
        cwd = self.cwd or os.getcwd()
        cmd_str = shlex.join(self.cmd)
        cwd_descr = self.cwd_descr if self.cwd_descr else "CWD" if not self.cwd else None
        log.debug("cd %s%s", cwd, f" # {cwd_descr}" if cwd_descr else "")
        log.debug("%s", cmd_str)
        Command._log_delimiter_start()

        try:
            env = os.environ.copy()
            shell = sys.platform == "win32"
            result = subprocess.run(self.cmd, cwd=self.cwd, check=False, env=env, shell=shell)
            exit_code = result.returncode
        except FileNotFoundError as e:
            log.error("❌ Execute not found: %s", e)
            exit_code = 127
        except KeyboardInterrupt:
            log.warning("\n⚠️ Execute interrupted")
            exit_code = 130
        except Exception as e:
            log.error("❌ Execute error: %s", e)
            exit_code = 1

        Command._log_delimiter_finish(scope_prefix, exit_code)
        return exit_code
