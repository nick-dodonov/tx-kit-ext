import os
import subprocess
import shlex

from dataclasses import dataclass
from runner.log import *

@dataclass
class Command:
    cmd: list[str]
    cwd: str | None = None
    cwd_descr: str | None = None

    def scoped_execute(self, scope_prefix: str) -> int:
        cwd = self.cwd or os.getcwd()
        cmd_str = shlex.join(self.cmd)
        info(f"{Fore.CYAN}➡️  {scope_prefix}{Style.RESET_ALL}") # ⬇️
        cwd_descr = self.cwd_descr if self.cwd_descr else "CWD" if not self.cwd else None
        info(f"{Style.DIM}  {f'({cwd_descr}) ' if cwd_descr else ''}cd {cwd}{Style.RESET_ALL}")
        info(f"{Style.DIM}  {cmd_str}{Style.RESET_ALL}")
        info(f"{Fore.LIGHTBLUE_EX}{'>' * 64}{Style.RESET_ALL}")

        try:
            result = subprocess.run(self.cmd, cwd=self.cwd, check=False)
            exit_code = result.returncode
        except FileNotFoundError as e:
            info(f"{Fore.RED}❌ Command not found: {self.cmd[0]}{Style.RESET_ALL}")
            info(f"Error: {e}")
            exit_code = 127
        except KeyboardInterrupt:
            info(f"\n{Fore.YELLOW}⚠️ Interrupted by user{Style.RESET_ALL}")
            exit_code = 130
        except Exception as e:
            info(f"{Fore.RED}❌ Execution error: {e}{Style.RESET_ALL}")
            exit_code = 1

        info(f"{Fore.LIGHTBLUE_EX}{'<' * 64}{Style.RESET_ALL}")
        finish_prefix = f"{Fore.CYAN}⬅️  {scope_prefix}{Style.RESET_ALL}" # ⬆️ 🏁
        if exit_code == 0:
            info(f"{finish_prefix} {Fore.GREEN}✅ Success: {exit_code}{Style.RESET_ALL}")
        else:
            info(f"{finish_prefix} {Fore.RED}❌ Error: {exit_code}{Style.RESET_ALL}")

        return exit_code
