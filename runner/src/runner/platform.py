from enum import Enum

class Platform(Enum):
    """Target platform for execution."""

    AUTO = "auto"

    EXEC = "exec"
    WASM = "wasm"
    PYTHON = "python"

    def __repr__(self) -> str:
        return str(self)
