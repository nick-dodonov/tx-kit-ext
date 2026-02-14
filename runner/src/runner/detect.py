from pathlib import Path

import filetype

from .log import *
from . import Platform

_wasm_exts = (".html", ".js", ".wasm")


def _read_shebang(file: Path) -> str | None:
    """Read and return shebang line from file if present."""
    try:
        with open(file, "rb") as f:
            first_line = f.readline()
            if not first_line:
                return None

            # Try UTF-8, fall back to latin-1 for wider compatibility
            try:
                line = first_line.decode("utf-8").strip()
            except UnicodeDecodeError:
                line = first_line.decode("latin-1", errors="ignore").strip()

            if line.startswith("#!"):
                return line
    except (OSError, IOError):
        pass

    return None


def _detect_platform(file: Path) -> Platform:
    # print(f"{Style.DIM}Detecting platform...{Style.RESET_ALL}")

    real_file = file.resolve()
    if real_file != file:
        info(f"  {Style.DIM}Real: {real_file}{Style.RESET_ALL}")

    kind = filetype.guess(real_file)
    if kind:
        info(f"  {Style.DIM}Type: {kind.mime} ({kind.extension}){Style.RESET_ALL}")

    shebang = _read_shebang(real_file)
    if shebang:
        info(f"  {Style.DIM}Shebang: {shebang}{Style.RESET_ALL}")

    if kind:
        if kind.extension == "tar":
            # TODO: check if it contains wasm files
            info(f"  {Style.DIM}Revealed: tar with WASM content{Style.RESET_ALL}")
            return Platform.WASM

    if real_file.suffix in _wasm_exts:
        info(f"  {Style.DIM}Found WASM extension in realpath{Style.RESET_ALL}")
        return Platform.WASM

    for ext in _wasm_exts:
        
        if real_file.with_suffix(ext).exists():
            info(
                f"  {Style.DIM}Found WASM extension in realpath+ext: {file.stem}{ext}{Style.RESET_ALL}"
            )
            return Platform.WASM

    return Platform.AUTO


def detect_platform(file: Path) -> Platform:
    platform = _detect_platform(file)
    info(f"  {Style.DIM}Detected: {platform}{Style.RESET_ALL}")
    return platform
