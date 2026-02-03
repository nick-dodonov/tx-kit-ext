from typing import Any


def info(*args: Any, **kwargs: Any) -> None:
    """Print function with automatic flush."""
    print(*args, **kwargs, flush=True)
