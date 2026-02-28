import logging
from pathlib import Path

import filetype

from .context import Platform

log = logging.getLogger(__name__)

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


def _detect_platform(file: Path) -> tuple[Platform, str]:
    real_file = file.resolve()
    if real_file != file:
        log.debug("Real: %s", real_file)

    if real_file.is_dir():
        log.debug("Type: <directory>")
        # TODO: check if it contains wasm files
        return Platform.WASM, "directory detected"

    kind = filetype.guess(real_file)
    if kind:
        log.debug("Type: %s (%s)", kind.mime, kind.extension)

    shebang = _read_shebang(real_file)
    if shebang:
        log.debug("Shebang: %s", shebang)
        if "python" in shebang:
            return Platform.PYTHON, "found Python shebang"

    if kind:
        if kind.extension == "tar":
            # TODO: check if it contains wasm files
            return Platform.WASM, "revealed tar with WASM content"

    if real_file.suffix == ".apk":
        return Platform.DROID, "found APK extension"

    if real_file.suffix in _wasm_exts:
        return Platform.WASM, "found WASM extension in realpath"

    for ext in _wasm_exts:
        if real_file.with_suffix(ext).exists():
            return Platform.WASM, str.format("found WASM extension in realpath+ext: %s%s", file.stem, ext)

    return Platform.EXEC, "no platform detected"


def detect_platform(file: Path) -> Platform:
    platform, reason = _detect_platform(file)
    log.debug("detected %s (%s)", platform, reason)
    assert platform != Platform.AUTO, "Detection should never return AUTO"
    return platform
