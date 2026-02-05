from typing import Any
# https://github.com/tartley/colorama
from colorama import init, Fore, Back, Style
#init(autoreset=True) # make termcolor work on windows and simplify usage by auto-resetting styles after each print
init() # don't auto-reset to allow multi-line styled output


def info(*args: Any, **kwargs: Any) -> None:
    """Print function with automatic flush."""
    print(*args, **kwargs, flush=True)

# print(Fore.RED + 'some red text')
# print(Back.GREEN + 'and with a green background')
# print(Style.DIM + 'and in dim text' + Style.RESET_ALL)
# print(Style.RESET_ALL)
# print('back to normal now')
