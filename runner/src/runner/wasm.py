#!/usr/bin/env python3
"""WASM Runner - Python version of run-wasm.sh

A tool to run WebAssembly builds via Node.js or emrun.
Supports both test mode (bazel test) and run mode (bazel run).
"""

import argparse
import os
from dataclasses import dataclass
from pathlib import Path

import runner.cmd
from .log import info, trace, error, Fore, Style
from .context import Context


@dataclass
class EmrunOptions:
    """emrun execution options."""

    show: bool
    nokill: bool
    devtool: bool

    def __str__(self) -> str:
        return f"(show={self.show}, nokill={self.nokill}, devtool={self.devtool})"


@dataclass
class WasmOptions:
    """WASM run options."""

    file: str
    emrun: EmrunOptions | None
    args: list[str]


def _parse_env_file(env_file: Path) -> list[str]:
    """Parse .env file and extract arguments in WASM_RUNNER_ARGS= variable."""
    try:
        with open(env_file, 'r') as f:
            content = f.read()
            trace(f"  content: {content.strip()}")

            # Parse WASM_RUNNER_ARGS variable
            args = []
            for line in content.splitlines():
                line = line.strip()
                if not line or line.startswith('#'):
                    continue

                if line.startswith('WASM_RUNNER_ARGS='):
                    value = line.split('=', 1)[1].strip()

                    # Remove quotes if present
                    if value.startswith('"') and value.endswith('"'):
                        value = value[1:-1]
                    elif value.startswith("'") and value.endswith("'"):
                        value = value[1:-1]

                    # Split value into arguments
                    import shlex
                    args.extend(shlex.split(value))

            return args

    except Exception as e:
        error(f"❌ Failed reading/parsing: {e}")
        return []


def _read_env_file(ctx: Context) -> list[str]:
    """Read .env file (in the same directory as the target file) and extract WASM_RUNNER_ARGS arguments."""

    env_path = Path(ctx.options.file).with_name('.env')
    found_path = ctx.finder.find_file_logged(env_path)

    if found_path:
        return _parse_env_file(found_path)
    return []


def _parse_arguments(ctx: Context, args: list[str]) -> WasmOptions:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="WASM Runner - Run WebAssembly builds via Node.js or emrun",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s file                     # Extract archived .wasm/.html and run
  %(prog)s file --emrun             # Run via emrun (headless mode)
  %(prog)s file -s                  # Run via emrun and show browser
  %(prog)s file --show --arg1 value # Run via emrun in browser passing arguments
  %(prog)s file -n                  # Run via emrun, show browser, no kill existing instances
  %(prog)s file -s -d               # Run via emrun, show browser with DevTools
        """,
    )

    parser.add_argument(
        '--emrun', '-e',
        action='store_true',
        help='Use emrun instead of Node.js'
    )

    parser.add_argument(
        '--show', '-s',
        action='store_true',
        help='Use emrun and show browser window (not headless, implies --emrun)'
    )

    parser.add_argument(
        '--nokill', '-n',
        action='store_true',
        help='Use emrun without killing existing browser instances (implies --show)'
    )

    parser.add_argument(
        '--devtool', '-d',
        action='store_true',
        help='Use emrun and open browser DevTools automatically (implies --nokill)'
    )

    parser.add_argument(
        'file',
        metavar='file [args ...]',
        help='html, wasm or tar file to run w/ optional arguments passed to the WASM program'
    )
    # Don't use optional positional nargs='*' allowing to capture -x/--x options after file (captured by parse_known_intermixed_args)
    # parser.add_argument('args', nargs='*', help='Additional arguments to pass to the WASM program')

    # Remove leading '--' if present because Bazel run requires it to separate own and tool args but unfortunately leaves passing to tool,
    #   so argparse sees it as a start of positional arguments
    if args and args[0] == '--':
        args = args[1:]

    # Use parse_known_intermixed_args() instead of parse_args() allowing to use --emrun after positional (file) args
    #   and also to ignore unknown args (passed to the WASM program)
    parsed_args, unknown_args = parser.parse_known_intermixed_args(args)
    trace(f"  parsed: {parsed_args}")
    if unknown_args:
        trace(f"  unknown: {unknown_args}")

    # Read .env file for WASM_RUNNER_ARGS variable and parse additional args from it
    env_args = _read_env_file(ctx)
    if env_args:
        # Parse env args with a dummy file argument to satisfy the parser
        # Command line args will override .env args
        env_parsed, env_unknown = parser.parse_known_intermixed_args(['dummy_file'] + env_args)
        trace(f"  env parsed: {env_parsed}")
        if env_unknown:
            trace(f"  env unknown: {env_unknown}")

        # Merge: command line args override .env args (only if not already set from command line)
        for key, value in vars(env_parsed).items():
            if key != 'file' and not getattr(parsed_args, key):  # Don't override if already set
                setattr(parsed_args, key, value)

        # Add env unknown args to the beginning (so they can be overridden by command line unknown args)
        unknown_args = env_unknown + unknown_args
        trace(f"  merged parsed: {parsed_args}")
        if unknown_args:
            trace(f"  merged unknown: {unknown_args}")

    # If nokill is enabled, automatically enable emrun and show
    # If show is enabled, automatically enable emrun
    # If devtool is enabled, automatically enable emrun
    if (
        parsed_args.emrun
        or parsed_args.show
        or parsed_args.nokill
        or parsed_args.devtool
    ):
        emrun = EmrunOptions(
            show=parsed_args.show or parsed_args.nokill or parsed_args.devtool,
            nokill=parsed_args.nokill or parsed_args.devtool,
            devtool=parsed_args.devtool,
        )
    else:
        emrun = None

    options = WasmOptions(
        file=parsed_args.file,
        emrun=emrun,
        args=unknown_args
    )
    trace(f"  {options}")

    return options


def _log_important(msg: str) -> None:
    info(f"{Fore.MAGENTA}{msg}{Style.RESET_ALL}")


class WasmRunner:
    """Main WASM runner class."""

    def __init__(self, ctx: Context):
        args = [str(ctx.found_file.resolve())] + ctx.options.args

        _log_important(f"{Style.BRIGHT}⚙️  WASM Runner {Style.DIM}{args}")
        self.options = _parse_arguments(ctx, args)

    def _extract_from_tar_if_needed(self, base_path: Path) -> Path | None:
        """Extract files from tar archive if the base file is a tar archive."""
        import tarfile
        import tempfile

        # Check if the base file (without extension) is a tar archive
        tar_path = base_path
        if tarfile.is_tarfile(tar_path):
            trace(f"Found tar archive: {tar_path}")

            # Create temporary directory for extraction
            temp_dir = Path(tempfile.mkdtemp(prefix="wasm_runner_"))
            trace(f"Extracting to temporary directory: {temp_dir}")

            try:
                with tarfile.open(tar_path, 'r') as tar:
                    # Use filter='data' to avoid deprecation warning in Python 3.14+
                    if hasattr(tarfile, 'data_filter'):
                        tar.extractall(temp_dir, filter='data')
                    else:
                        tar.extractall(temp_dir)

                # Return the HTML file path from extracted files
                html_name = base_path.with_suffix('.html').name
                extracted_html = temp_dir / html_name

                if extracted_html.exists():
                    trace(f"Successfully extracted HTML file: {extracted_html}")
                    return extracted_html
                else:
                    trace(f"HTML file not found in extracted archive: {html_name}")
                    return None

            except Exception as e:
                trace(f"Error extracting tar archive: {e}")
                return None

        return None

    def _find_html_file(self, file_path: str) -> Path:
        """Find the HTML file, handling different execution contexts."""

        # Expect path as tar archive
        current_tar_base = Path(file_path)
        extracted = self._extract_from_tar_if_needed(current_tar_base)
        if extracted:
            return extracted

        raise FileNotFoundError(f"HTML file not found in TAR: {file_path}")

    def _make_cmd_with_node(self, html_file: Path, args: list[str]) -> list[str]:
        """Run WASM using Node.js (console mode)."""
        _log_important(f"🚀 WASM Console mode (via node)")
        trace(f"  cwd: {os.getcwd()}")
        trace(f"  html: {html_file}")

        js_file = html_file.with_suffix('.js')
        if not js_file.exists():
            raise FileNotFoundError(f"JavaScript file not found: {js_file}")

        trace(f"  js: {js_file}")
        if args:
            trace(f"  args: {' '.join(args)}")

        cmd = ['node', str(js_file)] + args
        return cmd

    def _make_cmd_with_emrun(self, html_file: Path, args: list[str], emrun: EmrunOptions) -> list[str]:
        """Run WASM using emrun (browser mode)."""
        _log_important(f"🚀 WASM Browser mode (via emrun)")
        trace(f"  cwd: {os.getcwd()}")
        trace(f"  html: {html_file}")
        if args:
            trace(f"  args: {' '.join(args)}")

        # https://emscripten.org/docs/compiling/Running-html-files-with-emrun.html#controlling-log-output
        cmd = [
            'emrun',
            # '--verbose',  # Print detailed information about emrun internal steps.
            # '--system_info',  # Print detailed information about the current system before launching.
            # '--browser_info',  # Print information about which browser is about to be launched.
        ]

        # Only add kill arguments if nokill is not enabled
        if not emrun.nokill:
            cmd.extend(['--kill_start', '--kill_exit'])

        cmd.append('--browser=chrome')

        # https://peter.sh/experiments/chromium-command-line-switches/
        browser_args = [
            "--disable-background-networking", # Disable various network services (including prefetching and update checks)
            "--allow-insecure-localhost", # Allow insecure connections to localhost
            # "--cors-exempt-headers", # Disable CORS for all headers (to allow local file access)
            # "--disable-web-security", # Disable same-origin policy (to allow local file access)
        ]

        # Add devtools if enabled
        if emrun.devtool:
            browser_args.append("--auto-open-devtools-for-tabs") # Open devtools for each tab (intended to be used by developers and automation to not require user interaction for opening DevTools)

        # Add headless mode unless show is enabled
        if not emrun.show:
            browser_args.append("--headless")

        cmd.append('--browser_args="{}"'.format(' '.join(browser_args)))

        cmd.append(str(html_file))
        if args:
            cmd.append('--') # Separator for emrun to pass subsequent args to the WASM program
            cmd.extend(args)
        return cmd

    def make_command(self) -> runner.cmd.Command:
        options = self.options
        html_file = self._find_html_file(options.file)

        if options.emrun:
            cmd = self._make_cmd_with_emrun(html_file, options.args, options.emrun)
        else:
            cmd = self._make_cmd_with_node(html_file, options.args)

        return runner.cmd.Command(
            cmd=cmd,
            cwd=None,
            cwd_descr=None,
        )
