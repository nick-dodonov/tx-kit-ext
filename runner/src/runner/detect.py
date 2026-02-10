import os.path

import filetype

from .log import *
from . import Platform

_wasm_exts = (".html", ".js", ".wasm")

def detect_platform(file: str) -> Platform:
    #print(f"{Style.DIM}Detecting platform...{Style.RESET_ALL}")

    real_file = os.path.realpath(file)
    if real_file != file:
        info(f"{Style.DIM}  Resolved real path: {real_file}{Style.RESET_ALL}")

    if real_file.endswith(_wasm_exts):
        info(f"{Style.DIM}  Found WASM extension in realpath{Style.RESET_ALL}")
        return Platform.WASM

    for ext in _wasm_exts:
        if os.path.exists(real_file + ext):
            info(f"{Style.DIM}  Found WASM extension in realpath+ext: {ext}{Style.RESET_ALL}")
            return Platform.WASM

    kind = filetype.guess(real_file)
    if kind and kind.extension == 'tar':
        info(f"{Style.DIM}  Detected 'tar' file (guessing WASM content){Style.RESET_ALL}")
        #TODO: check if it contains wasm files
        return Platform.WASM

    return Platform.AUTO
