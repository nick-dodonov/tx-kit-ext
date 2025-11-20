#!/usr/bin/env python3
"""WASM Runner - Python version of run-wasm.sh

A tool to run WebAssembly builds via Node.js or emrun.
Supports both test mode (bazel test) and run mode (bazel run).
"""

import argparse
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Any


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
    args: List[str]


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
        
    def print_header(self) -> None:
        """Print the runner header with environment information."""
        _log(f"{Colors.YELLOW}🚀 WASM Runner:{Colors.RESET}")
        _log(f"  cwd: {os.getcwd()}")
        _log(f"  exe: {sys.argv[0]}")
        _log(f"  args: {' '.join(sys.argv[1:])}")

        if self.build_workspace_dir:
            _log(f"    BUILD_WORKSPACE_DIRECTORY: {self.build_workspace_dir}")
        
        if self.build_working_dir:
            _log(f"    BUILD_WORKING_DIRECTORY: {self.build_working_dir} (cd into it)")
            os.chdir(self.build_working_dir)
        elif self.runfiles_dir:
            _log(f"    RUNFILES_DIR: {self.runfiles_dir} (cd into it for test mode)")
            os.chdir(self.runfiles_dir)
    
    def _extract_from_tar_if_needed(self, base_path: Path) -> Optional[Path]:
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
    
    def run_with_node(self, html_file: Path, args: List[str]) -> int:
        """Run WASM using Node.js (test mode)."""
        _log(f"{Colors.YELLOW}🚀 Test mode (via node):{Colors.RESET}")
        _log(f"  cwd: {os.getcwd()}")
        _log(f"  html: {html_file}")
        
        js_file = html_file.with_suffix('.js')
        if not js_file.exists():
            raise FileNotFoundError(f"JavaScript file not found: {js_file}")
        
        _log(f"  js: {js_file}")
        if args:
            _log(f"  args: {' '.join(args)}")
        
        cmd = ['node', str(js_file)] + args
        _log(f"  cmd: {' '.join(cmd)}")
        
        return self._execute_command(cmd)

    def run_with_emrun(self, html_file: Path, args: List[str], emrun: EmrunOptions) -> int:
        """Run WASM using emrun (run mode)."""
        _log(f"{Colors.YELLOW}🚀 Run mode (via emrun):{Colors.RESET}")
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

        _log(f"  cmd: {' '.join(cmd)}")
        
        return self._execute_command(cmd)
    
    def _execute_command(self, cmd: List[str]) -> int:
        """Execute command with proper output formatting."""
        _log(f"{Colors.LIGHT_BLUE}{'>' * 64}{Colors.RESET}")
        
        try:
            result = subprocess.run(cmd, check=False)
            exit_code = result.returncode
        except FileNotFoundError as e:
            _log(f"{Colors.RED}❌ Command not found: {cmd[0]}{Colors.RESET}")
            _log(f"Error: {e}")
            exit_code = 127
        except Exception as e:
            _log(f"{Colors.RED}❌ Execution error: {e}{Colors.RESET}")
            exit_code = 1
        
        _log(f"{Colors.LIGHT_BLUE}{'<' * 64}{Colors.RESET}")
        
        if exit_code == 0:
            _log(f"{Colors.GREEN}✅ Success: {exit_code}{Colors.RESET}")
        else:
            _log(f"{Colors.RED}❌ Error: {exit_code}{Colors.RESET}")
        
        return exit_code
    
    def run(self, options: Options) -> int:
        """Main run method."""
        self.print_header()
        
        # Validate emrun usage in test mode
        if options.emrun and self.bazel_test and not self.build_working_dir:
            _log(f"{Colors.RED}❌ Error: --emrun cannot be used in test mode{Colors.RESET}")
            return 1
        
        try:
            html_file = self.find_html_file(options.file)
        except FileNotFoundError as e:
            _log(f"{Colors.RED}❌ {e}{Colors.RESET}")
            return 1

        if options.emrun:
            return self.run_with_emrun(html_file, options.args, options.emrun)
        else:
            return self.run_with_node(html_file, options.args)


def parse_arguments() -> "Options":
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
        help='Use emrun without killing existing browser instances (implies --emrun and --show)'
    )
    
    parser.add_argument(
        '--devtool', '-d',
        action='store_true',
        help='Use emrun and open browser DevTools automatically (implies --emrun)'
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
    args = sys.argv[1:]
    if args and args[0] == '--':
        args = args[1:]

    # Use parse_known_intermixed_args() instead of parse_args() allowing to use --emrun after positional (file) args
    #   and also to ignore unknown args (passed to the WASM program)
    _log(f"Parsing: {args}")
    parsed_args, unknown_args = parser.parse_known_intermixed_args(args)
    _log(f"  parsed: {parsed_args}")
    _log(f"  unknown: {unknown_args}")

    # If nokill is enabled, automatically enable emrun and show
    # If show is enabled, automatically enable emrun
    # If devtool is enabled, automatically enable emrun
    if parsed_args.emrun or parsed_args.show or parsed_args.nokill or parsed_args.devtool:
        emrun = EmrunOptions(
            show=parsed_args.show or parsed_args.nokill or parsed_args.devtool,
            nokill=parsed_args.nokill,
            devtool=parsed_args.devtool,
        )
    else:
        emrun = None

    options = Options(
        file=parsed_args.file,
        emrun=emrun,
        args=unknown_args
    )
    _log(f"""Options:
  emrun={options.emrun} 
  file={options.file} 
  args={options.args}""")

    return options


def main() -> int:
    """Main entry point."""
    try:
        options = parse_arguments()
        runner = WasmRunner()
        return runner.run(options)
    except KeyboardInterrupt:
        _log(f"\n{Colors.YELLOW}⚠️  Interrupted by user{Colors.RESET}")
        return 130
    except Exception as e:
        _log(f"{Colors.RED}❌ Unexpected error: {e}{Colors.RESET}")
        return 1


if __name__ == "__main__":
    # TODO: pass TESTBRIDGE_TEST_ONLY environment variable to executor supporting bazel run/test --test_filter=
    # import pprint
    # pprint.pprint(dict(os.environ))
    sys.exit(main())
