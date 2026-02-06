#!/usr/bin/env python3
"""WASM Runner - Python version of run-wasm.sh

A tool to run WebAssembly builds via Node.js or emrun.
Supports both test mode (bazel test) and run mode (bazel run).
"""

import argparse
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any
import runner.cmd


def _log(*args: Any, **kwargs: Any) -> None:
    """Print function with automatic flush."""
    print(*args, **kwargs)
    sys.stdout.flush()


@dataclass
class EmrunOptions:
    """emrun execution options."""
    show: bool
    nokill: bool
    devtool: bool
    
    def __str__(self) -> str:
        return f"(show={self.show}, nokill={self.nokill}, devtool={self.devtool})"


@dataclass
class Options:
    """Command line options."""
    file: str
    emrun: EmrunOptions | None
    args: list[str]


class Colors:
    """ANSI color codes for terminal output."""
    GREEN = "\033[32m"
    RED = "\033[31m"
    YELLOW = "\033[1;33m"
    LIGHT_BLUE = "\033[1;34m"
    RESET = "\033[0m"


class WasmRunner:
    """Main WASM runner class."""
    
    def __init__(self):
        self.build_workspace_dir = os.environ.get('BUILD_WORKSPACE_DIRECTORY')
        self.build_working_dir = os.environ.get('BUILD_WORKING_DIRECTORY')
        self.runfiles_dir = os.environ.get('RUNFILES_DIR')
        self.bazel_test = os.environ.get('BAZEL_TEST')
    
    def _extract_from_tar_if_needed(self, base_path: Path) -> Path | None:
        """Extract files from tar archive if the base file is a tar archive."""
        import tarfile
        import tempfile
        
        # Check if the base file (without extension) is a tar archive
        tar_path = base_path.with_suffix('')
        if tar_path.exists() and tarfile.is_tarfile(tar_path):
            _log(f"Found tar archive: {tar_path}")
            
            # Create temporary directory for extraction
            temp_dir = Path(tempfile.mkdtemp(prefix="wasm_runner_"))
            _log(f"Extracting to temporary directory: {temp_dir}")
            
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
                    _log(f"Successfully extracted HTML file: {extracted_html}")
                    return extracted_html
                else:
                    _log(f"HTML file not found in extracted archive: {html_name}")
                    return None
                    
            except Exception as e:
                _log(f"Error extracting tar archive: {e}")
                return None
        
        return None

    def find_html_file(self, file_path: str) -> Path:
        """Find the HTML file, handling different execution contexts."""
        html_file = Path(file_path).with_suffix('.html')
        
        # Strategy 1: Direct file access (common for bazel run)
        if html_file.exists():
            _log(f"Found HTML file directly: {html_file}")
            return html_file
        
        # Strategy 2: Try in build working directory (bazel run with BUILD_WORKING_DIRECTORY)
        if self.build_working_dir:
            # Try relative to build working directory
            build_html = Path(self.build_working_dir) / html_file
            if build_html.exists():
                _log(f"Found HTML file in build working directory: {build_html}")
                return build_html
            
            # Try in bazel-bin directory
            bazel_bin_html = Path(self.build_working_dir) / "bazel-bin" / html_file
            if bazel_bin_html.exists():
                _log(f"Found HTML file in bazel-bin: {bazel_bin_html}")
                return bazel_bin_html
            
            # Try extracting from tar in bazel-bin
            bazel_bin_base = Path(self.build_working_dir) / "bazel-bin" / Path(file_path)
            extracted = self._extract_from_tar_if_needed(bazel_bin_base)
            if extracted:
                return extracted
        
        # Strategy 3: Try in runfiles directory (bazel test)
        if self.runfiles_dir:
            # Try multiple runfiles paths for direct files
            possible_direct_paths = [
                Path("_main") / html_file,  # Direct path
                Path("_main") / Path(str(html_file).split("bin/", 1)[-1]),  # Remove bin/ prefix
                Path(str(html_file).replace("test/", "_main/test/")),  # Add _main prefix
            ]
            
            for runfiles_html in possible_direct_paths:
                if runfiles_html.exists():
                    _log(f"Found HTML file using RUNFILES_DIR: {runfiles_html}")
                    return runfiles_html
            
            # Try extracting from tar in runfiles
            # The tar file is typically at _main/path/to/target
            runfiles_tar_base = Path("_main") / Path(file_path)
            extracted = self._extract_from_tar_if_needed(runfiles_tar_base)
            if extracted:
                return extracted
        
        # Strategy 4: Look for tar archive in current directory
        current_tar_base = Path(file_path)
        extracted = self._extract_from_tar_if_needed(current_tar_base)
        if extracted:
            return extracted
        
        # If all strategies fail, provide comprehensive error message
        error_msg = f"HTML file not found: {html_file}\n"
        error_msg += f"  Original file path: {file_path}\n"
        error_msg += f"  Current working directory: {os.getcwd()}\n"
        
        if self.build_working_dir:
            error_msg += f"  BUILD_WORKING_DIRECTORY: {self.build_working_dir}\n"
            error_msg += f"  Tried bazel-bin paths\n"
        
        if self.runfiles_dir:
            error_msg += f"  RUNFILES_DIR: {self.runfiles_dir}\n"
            error_msg += f"  Tried runfiles paths and tar extraction\n"
        
        error_msg += f"Please ensure the target is built correctly"
        
        raise FileNotFoundError(error_msg)
    
    def make_cmd_with_node(self, html_file: Path, args: list[str]) -> list[str]:
        """Run WASM using Node.js (test mode)."""
        _log(f"{Colors.YELLOW}🚀 WASM Test mode (via node):{Colors.RESET}")
        _log(f"  cwd: {os.getcwd()}")
        _log(f"  html: {html_file}")
        
        js_file = html_file.with_suffix('.js')
        if not js_file.exists():
            raise FileNotFoundError(f"JavaScript file not found: {js_file}")
        
        _log(f"  js: {js_file}")
        if args:
            _log(f"  args: {' '.join(args)}")
        
        cmd = ['node', str(js_file)] + args
        return cmd

    def make_cmd_with_emrun(self, html_file: Path, args: list[str], emrun: EmrunOptions) -> list[str]:
        """Run WASM using emrun (run mode)."""
        _log(f"{Colors.YELLOW}🚀 WASM Run mode (via emrun):{Colors.RESET}")
        _log(f"  cwd: {os.getcwd()}")
        _log(f"  html: {html_file}")
        if args:
            _log(f"  args: {' '.join(args)}")
        
        cmd = ['emrun']
        
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

    def make_command(self, options: Options) -> runner.cmd.Command:
        """Print the runner header with environment information."""
        _log(f"{Colors.YELLOW}🚀 WASM Runner:{Colors.RESET}")

        #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        # TODO: replace with external runfiles support !!
        #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        cwd = None
        cwd_descr = None
        if self.build_working_dir:
            cwd = self.build_working_dir
            cwd_descr = "BUILD_WORKING_DIRECTORY"
        elif self.runfiles_dir:  # For test mode, we need to cd into the runfiles directory to access the files correctly
            cwd = self.runfiles_dir
            cwd_descr = "RUNFILES_DIR"

        # Validate emrun usage in test mode
        if options.emrun and self.bazel_test and not self.build_working_dir:
            raise ValueError("Cannot use --emrun in test mode without BUILD_WORKING_DIRECTORY")
        
        try:
            html_file = self.find_html_file(options.file)
        except FileNotFoundError as e:
            raise e

        if options.emrun:
            cmd = self.make_cmd_with_emrun(html_file, options.args, options.emrun)
        else:
            cmd = self.make_cmd_with_node(html_file, options.args)
            
        return runner.cmd.Command(
            cmd=cmd,
            cwd=cwd,
            cwd_descr=cwd_descr,
        )


def _get_runfiles_root() -> Path | None:
    """Detect if we're running in bazel runfiles context and return the root path.
    
    Returns:
        Path to runfiles root (_main directory) if detected, None otherwise
    """
    cwd = Path.cwd()
    # Check if we're in a runfiles directory structure
    # PWD will be something like: .../target.runfiles/_main
    if cwd.name == '_main' and cwd.parent.name.endswith('.runfiles'):
        return cwd
    return None


def _parse_env_file(env_file: Path) -> list[str]:
    """Parse .env file and extract WASM_RUNNER_ARGS.
    
    Args:
        env_file: Path to the .env file to parse
    
    Returns:
        List of parsed arguments
    """
    try:
        with open(env_file, 'r') as f:
            content = f.read()
            _log(f"  content: {content.strip()}")
            
            # Parse WASM_RUNNER_ARGS variable
            args = []
            for line in content.splitlines():
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                
                # Support WASM_RUNNER_ARGS
                if line.startswith('WASM_RUNNER_ARGS='):
                    # Extract value after '='
                    value = line.split('=', 1)[1].strip()
                    # Remove quotes if present
                    if value.startswith('"') and value.endswith('"'):
                        value = value[1:-1]
                    elif value.startswith("'") and value.endswith("'"):
                        value = value[1:-1]
                    
                    # Split value into arguments
                    import shlex
                    args.extend(shlex.split(value))
            
            if args:
                _log(f"  parsed args: {args}")
            else:
                _log(f"  no WASM_RUNNER_ARGS variable found")
            
            return args
            
    except Exception as e:
        _log(f"  {Colors.RED}❌ Error reading file: {e}{Colors.RESET}")
        return []


def read_env_file(file_path: str) -> list[str]:
    """Read .env file and extract WASM_RUNNER_ARGS arguments.
    
    Args:
        file_path: Path to the target file (will look for .env file in same directory)
    
    Returns:
        List of arguments parsed from .env file, or empty list if not found
    """
    _log(f"{Colors.YELLOW}📄 WASM Looking for .env:{Colors.RESET}")
    
    # Strategy 1: If we're in runfiles directory (bazel run), look for .env relative to runfiles root
    runfiles_root = _get_runfiles_root()
    if runfiles_root:
        _log(f"  Detected runfiles context: {runfiles_root}")
        
        # Extract relative path from file_path
        # file_path is like: /private/var/.../bazel-out/darwin_arm64-dbg-wasm/bin/demo/try-imgui-2/try-imgui-2
        # We need: demo/try-imgui-2
        file_path_str = str(file_path)
        if '/bin/' in file_path_str:
            # Extract everything after '/bin/'
            rel_path = file_path_str.split('/bin/', 1)[-1]
            # Remove the target name at the end to get directory
            rel_dir = str(Path(rel_path).parent)
            
            env_file = runfiles_root / rel_dir / ".env"
            _log(f"  .env runfiles path: {env_file}")
            
            if env_file.exists():
                _log(f"  {Colors.GREEN}.env found in runfiles{Colors.RESET}")
                return _parse_env_file(env_file)

    # Strategy 2: Look for .env in the same directory as the target file (direct execution)
    target_dir = Path(file_path).parent
    env_file = target_dir / ".env"
    if env_file.exists():
        _log(f"  {Colors.GREEN}.env found in direct path: {Colors.RESET} {env_file}")
        return _parse_env_file(env_file)

    _log(f"  .env not found")
    return []


def parse_arguments(args : list[str]) -> "Options":
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="WASM Runner - Run WebAssembly builds via Node.js or emrun",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s file.wasm                        # Run via Node.js
  %(prog)s file.tar                         # Extract archived .wasm/.html and run
  %(prog)s file.html --emrun                # Run via emrun (headless mode)
  %(prog)s file.wasm -s                     # Run via emrun and show browser
  %(prog)s file.wasm --show --arg1 value    # Run via emrun in browser passing arguments
  %(prog)s file.wasm -n                     # Run via emrun, show browser, no kill existing instances
  %(prog)s file.wasm -s -d                  # Run via emrun, show browser with DevTools
        """
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
    _log(f"{Colors.YELLOW}⚙️  WASM Parsing:{Colors.RESET} {args}")
    parsed_args, unknown_args = parser.parse_known_intermixed_args(args)
    _log(f"  parsed: {parsed_args}")
    if unknown_args:
        _log(f"  unknown: {unknown_args}")

    # Read .env file for WASM_RUNNER_ARGS variable and parse additional args from it
    env_args = read_env_file(parsed_args.file)
    if env_args:
        _log(f"Merging args from .env file with command line args:")
        # Parse env args with a dummy file argument to satisfy the parser
        # Command line args will override .env args
        env_parsed, env_unknown = parser.parse_known_intermixed_args(['dummy_file'] + env_args)
        _log(f"  env parsed: {env_parsed}")
        if env_unknown:
            _log(f"  env unknown: {env_unknown}")
        
        # Merge: command line args override .env args (only if not already set from command line)
        for key, value in vars(env_parsed).items():
            if key != 'file' and not getattr(parsed_args, key):  # Don't override if already set
                setattr(parsed_args, key, value)
        
        # Add env unknown args to the beginning (so they can be overridden by command line unknown args)
        unknown_args = env_unknown + unknown_args
        _log(f"  merged parsed: {parsed_args}")
        if unknown_args:
            _log(f"  merged unknown: {unknown_args}")


    # If nokill is enabled, automatically enable emrun and show
    # If show is enabled, automatically enable emrun
    # If devtool is enabled, automatically enable emrun
    if parsed_args.emrun or \
       parsed_args.show or \
       parsed_args.nokill or \
       parsed_args.devtool:
        emrun = EmrunOptions(
            show=parsed_args.show or parsed_args.nokill or parsed_args.devtool,
            nokill=parsed_args.nokill or parsed_args.devtool,
            devtool=parsed_args.devtool,
        )
    else:
        emrun = None

    options = Options(
        file=parsed_args.file,
        emrun=emrun,
        args=unknown_args
    )
    _log(f"""{Colors.YELLOW}⚙️  WASM Options:{Colors.RESET}
  emrun={options.emrun} 
  file={options.file} 
  args={options.args}""")

    return options


def make_wrapper_command(args: list[str]) -> runner.cmd.Command:
    options = parse_arguments(args)
    runner = WasmRunner()
    return runner.make_command(options)
