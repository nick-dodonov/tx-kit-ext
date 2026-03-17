"""Logging helpers for Bazel/Starlark build output in analysis phase."""

def _log_info(enabled = False):
    return _info if enabled else _info_stub

def _info_stub(*args):
    """Stub for info logging when logging is disabled."""
    pass

def _info(*args):
    """Logs an info message during the build."""
    _LOG_COLOR = "\033[1;34m"  # blue
    _LOG_RESET = "\033[0m"
    message = " ".join([str(arg) for arg in args])
    print(_LOG_COLOR + message + _LOG_RESET)  # buildifier: disable=print

log = struct(
    info = _log_info,
)
