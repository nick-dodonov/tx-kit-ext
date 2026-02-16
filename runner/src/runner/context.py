from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path

from . import find


class Platform(Enum):
    """Target platform for execution."""

    AUTO = "auto"

    EXEC = "exec"
    WASM = "wasm"
    PYTHON = "python"

    def __repr__(self) -> str:
        return str(self)


@dataclass
class Options:
    """Start options."""

    file: Path
    args: list[str] = field(default_factory=list)
    platform: Platform = Platform.AUTO


class Context:
    """Execution context."""

    def __init__(self, options: Options, finder: find.Finder, found_file: Path):
        self.options = options
        self.finder = finder
        self.found_file = found_file
