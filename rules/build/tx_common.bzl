"""Common utilities for building Tx binaries and tests."""

def get_default_copts():
    """Returns default platform-specific copts for tx targets."""
    return select({
        "@platforms//cpu:wasm32": [
            # Keep exceptions disabled for WASM - causes issues with shared memory
            "-fno-exceptions",
            # Disable threading support to avoid shared memory issues
            "-mthread-model",
            "single",
        ],
        "//conditions:default": [],
    })

def get_default_linkopts():
    """Returns default platform-specific linkopts for tx targets."""
    return select({
        "@platforms//cpu:wasm32": [
            "--oformat=html",
            "--emrun",  # Поддержка emrun для headless запуска
            # Need for exit(status)
            # - https://emscripten.org/docs/api_reference/emscripten.h.html#c.emscripten_force_exit
            # - https://emscripten.org/docs/getting_started/FAQ.html#what-does-exiting-the-runtime-mean-why-don-t-atexit-s-run
            # - https://github.com/emscripten-core/emscripten/blob/main/src/settings.js
            "-sEXIT_RUNTIME=1",
            # Disable threading and shared memory completely
            "-sUSE_PTHREADS=0",
            "-sPROXY_TO_PTHREAD=0",
        ],
        # "@platforms//os:windows": [
        #     "/SUBSYSTEM:CONSOLE",
        # ],
        # "@platforms//os:macos": [
        #     "-framework", "CoreFoundation",
        #     "-lc++",
        # ],
        "//conditions:default": [],
    })

def merge_copts(user_copts):
    """Merges user copts with default platform-specific ones."""
    return get_default_copts() + user_copts

def merge_linkopts(user_linkopts):
    """Merges user linkopts with default platform-specific ones."""
    return get_default_linkopts() + user_linkopts

_YELLOW = "\033[1;33m"
_RESET = "\033[0m"
def log_warning(message):
    """Logs a warning message during the build."""
    print(_YELLOW + "\n⚠️  WARNING: " + _RESET + message)
