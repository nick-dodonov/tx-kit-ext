"""Common utilities for building tx binaries and tests."""

def log_warning(message):
    """Logs a warning message during the build."""
    _YELLOW = "\033[1;33m"
    _RESET = "\033[0m"
    print(_YELLOW + "\n⚠️  WARNING: " + _RESET + message)  # buildifier: disable=print


# GNU-like compilers (GCC, Clang) - not MSVC
_COPTS_GNU = [
    "-Werror=return-type",              # Functions without return
    # "-Werror=unused-variable",          # Unused variables
    # "-Werror=unused-parameter",         # Unused parameters
    "-Werror=uninitialized",            # Uninitialized variables
    "-Werror=delete-non-virtual-dtor",  # Deletion through base class without virtual destructor
]
_COPTS_CLANG = [
    "-ffile-compilation-dir=."  # For reproducible builds (debug info paths)
]
#TODO: -Werror and /WX or /WX:NNNN

def _get_default_copts():
    """Returns default platform-specific copts for tx targets."""
    return select({
        # # https://emscripten.org/docs/tools_reference/emcc.html
        # "@platforms//cpu:wasm32": [
        #     # # Disable threading support to avoid shared memory issues
        #     # "-mthread-model", "single",
        # ],
        "@platforms//os:linux": _COPTS_GNU,
        "@platforms//os:macos": _COPTS_GNU + _COPTS_CLANG,
        "@platforms//os:android": _COPTS_GNU + _COPTS_CLANG,
        "@platforms//cpu:wasm32": _COPTS_GNU + _COPTS_CLANG,
        "//conditions:default": [],
    })

def _get_default_cxxopts():
    """Returns default platform-specific cxxopts for tx targets."""
    return select({
        "//conditions:default": [
            # # Prefer setting via env for rules_cc (BAZEL_CXXOPTS not via --cxxopt) to disable default C++17 applied
            # build:linux --repo_env=BAZEL_CXXOPTS=-std=c++23
            # build:macos --repo_env=BAZEL_CXXOPTS=-std=c++23
            "-std=c++23",  # Use C++23 standard
            "-fno-exceptions",  # Disable exceptions globally
        ],
        "@platforms//os:windows": [
            "/std:c++latest",  # Use C++23 standard
            #TODO: Find equivalent for MSVC - how to disable default /EHsc? also enable _HAS_EXCEPTIONS=0 for stl
        ]
    })

def _get_default_linkopts():
    """Returns default platform-specific linkopts for tx targets."""
    return select({
        "@platforms//cpu:wasm32": [
            "--oformat=html",
            "--emrun",  # Support for emrun for headless execution
            # Need for exit(status)
            # - https://emscripten.org/docs/api_reference/emscripten.h.html#c.emscripten_force_exit
            # - https://emscripten.org/docs/getting_started/FAQ.html#what-does-exiting-the-runtime-mean-why-don-t-atexit-s-run
            # - https://github.com/emscripten-core/emscripten/blob/main/src/settings.js
            "-sEXIT_RUNTIME=1",
            # # # Disable threading and shared memory completely
            # # "-sUSE_PTHREADS=0",
            # # "-sPROXY_TO_PTHREAD=0",

            # "-pthread",  # use_pthreads feature already used
            "-sPTHREAD_POOL_SIZE=2",  # Workaround for "Tried to spawn a new thread, but the thread pool is exhausted."
            #"-sPTHREAD_POOL_SIZE_STRICT=2",  # "If you want to throw an explicit error instead of the risk of deadlocking in those cases."

            # Workaround for "emcc: warning: running limited binaryen optimizations because DWARF info requested (or indirectly required) [-Wlimited-postlink-optimizations]"
            "-Wno-limited-postlink-optimizations"
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

def _get_default_features():
    """Returns default platform-specific features of toolchains."""
    return select({
        "@platforms//os:windows": [
            # MSVC rules_cc for Windows defaults std flag (/std:c++17) that can be disabled by feature
            #   https://bazel.build/configure/windows
            # As cxxopts specifies its own, this fixes compile warnings of multiple options
            "-default_cpp_std",
        ],
        "//conditions:default": [],
    })

def _get_copts(copts):
    """Merges user copts with default platform-specific ones."""
    return _get_default_copts() + (copts if copts != None else [])

def _get_cxxopts(cxxopts):
    """Merges user cxxopts with default platform-specific ones."""
    return _get_default_cxxopts() + (cxxopts if cxxopts != None else [])

def _get_linkopts(linkopts):
    """Merges user linkopts with default platform-specific ones."""
    return _get_default_linkopts() + (linkopts if linkopts != None else [])

def _get_features(features):
    """Merges user features with default platform-specific ones."""
    return _get_default_features() + (features if features != None else [])

def _get_wasm_cc_kwargs(kwargs):
    """Update and returns platform-specific kwargs for wasm cc_library/cc_binary targets."""
    wasm_kwargs = {k: v for k, v in kwargs.items()}
    wasm_kwargs["copts"] = _get_copts(kwargs.get("copts", []))
    wasm_kwargs["cxxopts"] = _get_cxxopts(kwargs.get("cxxopts", []))
    wasm_kwargs["linkopts"] = _get_linkopts(kwargs.get("linkopts", []))
    wasm_kwargs["features"] = [
        "exit_runtime",  # runner wrapper needs to exit runtime
        # "use_pthreads",  # WASM boost.asio / boost.container requires pthreads #TODO: patch them
    ]
    return wasm_kwargs

cc_common = struct(
    get_default_copts = _get_default_copts,
    get_default_cxxopts = _get_default_cxxopts,
    get_default_linkopts = _get_default_linkopts,
    get_default_features = _get_default_features,
    get_copts = _get_copts,
    get_cxxopts = _get_cxxopts,
    get_linkopts = _get_linkopts,
    get_features = _get_features,
    get_wasm_cc_kwargs = _get_wasm_cc_kwargs,
)
