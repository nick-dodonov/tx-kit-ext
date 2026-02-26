import os
import subprocess
import shlex
import sys
from abc import ABC, abstractmethod
from pathlib import Path

from runner.log import *

__all__ = ["Command", "RunCommand"]


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
        info(f"{color}{symbol * length}{Style.RESET_ALL}")


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
        cwd = self.cwd or os.getcwd()
        cmd_str = shlex.join(self.cmd)
        info(f"{Fore.CYAN}➡️  {scope_prefix}{Style.RESET_ALL}")
        cwd_descr = self.cwd_descr if self.cwd_descr else "CWD" if not self.cwd else None
        info(f"  {Style.DIM}cd {cwd}{f' # {cwd_descr}' if cwd_descr else ''}{Style.RESET_ALL}")
        info(f"  {Style.DIM}{cmd_str}{Style.RESET_ALL}")
        self._log_delimiter('>', Fore.LIGHTBLUE_EX)

        try:
            env = os.environ.copy()
            shell = sys.platform == "win32"
            result = subprocess.run(self.cmd, cwd=self.cwd, check=False, env=env, shell=shell)
            exit_code = result.returncode
        except FileNotFoundError as e:
            info(f"{Fore.RED}❌ Execute not found: {e}{Style.RESET_ALL}")
            info(f"Error: {e}")
            exit_code = 127
        except KeyboardInterrupt:
            info(f"\n{Fore.YELLOW}⚠️ Execute interrupted{Style.RESET_ALL}")
            exit_code = 130
        except Exception as e:
            info(f"{Fore.RED}❌ Execute error: {e}{Style.RESET_ALL}")
            exit_code = 1

        self._log_delimiter('<', Fore.LIGHTBLUE_EX)
        finish_prefix = f"{Fore.CYAN}⬅️  {scope_prefix}{Style.RESET_ALL}"
        if exit_code == 0:
            info(f"{finish_prefix} {Fore.GREEN}✅ Success: {exit_code}{Style.RESET_ALL}")
        else:
            info(f"{finish_prefix} {Fore.RED}❌ Error: {exit_code}{Style.RESET_ALL}")

        return exit_code
