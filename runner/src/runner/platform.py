from enum import Enum

class Platform(Enum):
    """Target platform for execution."""

    AUTO = "auto"
    WASM = "wasm"

    def __repr__(self) -> str:
        return str(self)
