"""Common utilities for building tx binaries and tests."""

def _get_default_copts():
    """Returns default platform-specific copts for tx targets."""
    return select({
        # https://emscripten.org/docs/tools_reference/emcc.html
        "@platforms//cpu:wasm32": [
            # # Disable threading support to avoid shared memory issues
            # "-mthread-model",
            # "single",
            # https://emscripten.org/docs/porting/pthreads.html
            "-pthread",
        ],
        "//conditions:default": [],
    })

def _get_default_cxxopts():
    """Returns default platform-specific cxxopts for tx targets."""
    return [
        "-std=c++20",  # Use C++20 standard
        "-fno-exceptions",  # Disable exceptions globally
    ] + select({
        "@platforms//cpu:wasm32": [
            # Keep exceptions disabled for WASM - causes issues with shared memory
            # "-fno-exceptions",
            "-pthread",
        ],
        "//conditions:default": [],
    })

def _get_default_linkopts():
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
            # # Disable threading and shared memory completely
            # "-sUSE_PTHREADS=0",
            # "-sPROXY_TO_PTHREAD=0",
            "-pthread",
            "-sPTHREAD_POOL_SIZE=4",
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

def _get_copts(user_copts):
    """Merges user copts with default platform-specific ones."""
    return _get_default_copts() + user_copts

def _get_cxxopts(user_cxxopts):
    """Merges user cxxopts with default platform-specific ones."""
    return _get_default_cxxopts() + user_cxxopts

def _get_linkopts(user_linkopts):
    """Merges user linkopts with default platform-specific ones."""
    return _get_default_linkopts() + user_linkopts

tx_cc = struct(
    get_default_copts = _get_default_copts,
    get_default_cxxopts = _get_default_cxxopts,
    get_default_linkopts = _get_default_linkopts,
    get_copts = _get_copts,
    get_cxxopts = _get_cxxopts,
    get_linkopts = _get_linkopts,
)

def log_warning(message):
    """Logs a warning message during the build."""
    _YELLOW = "\033[1;33m"
    _RESET = "\033[0m"
    print(_YELLOW + "\n⚠️  WARNING: " + _RESET + message)  # buildifier: disable=print
