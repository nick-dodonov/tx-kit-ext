#!/usr/bin/env python3
"""WASM Runner - Python version of run-wasm.sh

A tool to run WebAssembly builds via Node.js or emrun.
Supports both test mode (bazel test) and run mode (bazel run).
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path
from typing import List, Optional, Tuple


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
        print(f"{Colors.YELLOW}🚀 WASM Runner:{Colors.RESET}")
        print(f"  cwd: {os.getcwd()}")
        print(f"  exe: {sys.argv[0]}")
        print(f"  args: {' '.join(sys.argv[1:])}")
        
        if self.build_workspace_dir:
            print(f"    BUILD_WORKSPACE_DIRECTORY: {self.build_workspace_dir}")
        
        if self.build_working_dir:
            print(f"    BUILD_WORKING_DIRECTORY: {self.build_working_dir} (cd into it)")
            os.chdir(self.build_working_dir)
        elif self.runfiles_dir:
            print(f"    RUNFILES_DIR: {self.runfiles_dir} (cd into it for test mode)")
            os.chdir(self.runfiles_dir)
    
    def find_html_file(self, file_path: str) -> Path:
        """Find the HTML file, handling different execution contexts."""
        html_file = Path(file_path).with_suffix('.html')
        
        if html_file.exists():
            return html_file
        
        # For bazel test mode, try to find file in runfiles
        if self.runfiles_dir:
            # Convert path from "bazel-out/.../test/file.wasm" to "_main/test/file.html"
            runfiles_path = Path("_main") / Path(str(html_file).split("bin/", 1)[-1])
            runfiles_html = runfiles_path.with_suffix('.html')
            
            if runfiles_html.exists():
                print(f"Found HTML file using RUNFILES_DIR: {runfiles_html}")
                return runfiles_html
            
            raise FileNotFoundError(
                f"HTML file not found: {html_file}\n"
                f"  Tried: {runfiles_html}\n"
                f"  Original: {html_file}\n"
                f"Current working directory: {os.getcwd()}\n"
                f"Please build first"
            )
        
        raise FileNotFoundError(
            f"HTML file not found: {html_file}\n"
            f"Current working directory: {os.getcwd()}\n"
            f"Please build first"
        )
    
    def run_with_node(self, html_file: Path, args: List[str]) -> int:
        """Run WASM using Node.js (test mode)."""
        print(f"{Colors.YELLOW}🚀 Test mode (via node):{Colors.RESET}")
        print(f"  cwd: {os.getcwd()}")
        print(f"  html: {html_file}")
        
        js_file = html_file.with_suffix('.js')
        if not js_file.exists():
            raise FileNotFoundError(f"JavaScript file not found: {js_file}")
        
        print(f"  js: {js_file}")
        if args:
            print(f"  args: {' '.join(args)}")
        
        cmd = ['node', str(js_file)] + args
        print(f"  cmd: {' '.join(cmd)}")
        
        return self._execute_command(cmd)
    
    def run_with_emrun(self, html_file: Path, args: List[str]) -> int:
        """Run WASM using emrun (run mode)."""
        print(f"{Colors.YELLOW}🚀 Run mode (via emrun):{Colors.RESET}")
        print(f"  cwd: {os.getcwd()}")
        print(f"  html: {html_file}")
        if args:
            print(f"  args: {' '.join(args)}")
        
        cmd = [
            'emrun',
            '--kill_start',
            '--kill_exit', 
            '--browser=chrome',
            '--browser_args=-headless',
            str(html_file)
        ] + args
        print(f"  cmd: {' '.join(cmd)}")
        
        return self._execute_command(cmd)
    
    def _execute_command(self, cmd: List[str]) -> int:
        """Execute command with proper output formatting."""
        print(f"{Colors.LIGHT_BLUE}{'>' * 64}{Colors.RESET}")
        
        try:
            result = subprocess.run(cmd, check=False)
            exit_code = result.returncode
        except FileNotFoundError as e:
            print(f"{Colors.RED}❌ Command not found: {cmd[0]}{Colors.RESET}")
            print(f"Error: {e}")
            exit_code = 127
        except Exception as e:
            print(f"{Colors.RED}❌ Execution error: {e}{Colors.RESET}")
            exit_code = 1
        
        print(f"{Colors.LIGHT_BLUE}{'<' * 64}{Colors.RESET}")
        
        if exit_code == 0:
            print(f"{Colors.GREEN}✅ Success: {exit_code}{Colors.RESET}")
        else:
            print(f"{Colors.RED}❌ Error: {exit_code}{Colors.RESET}")
        
        return exit_code
    
    def run(self, file_path: str, use_emrun: bool, args: List[str]) -> int:
        """Main run method."""
        self.print_header()
        
        # Validate emrun usage in test mode
        if use_emrun and self.bazel_test and not self.build_working_dir:
            print(f"{Colors.RED}❌ Error: --emrun cannot be used in test mode{Colors.RESET}")
            return 1
        
        try:
            html_file = self.find_html_file(file_path)
        except FileNotFoundError as e:
            print(f"{Colors.RED}❌ {e}{Colors.RESET}")
            return 1
        
        if use_emrun:
            return self.run_with_emrun(html_file, args)
        else:
            return self.run_with_node(html_file, args)


def parse_arguments() -> Tuple[str, bool, List[str]]:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="WASM Runner - Run WebAssembly builds via Node.js or emrun",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s file.wasm                    # Run with Node.js
  %(prog)s file.html --emrun           # Run with emrun
  %(prog)s file.wasm -e --arg1 value   # Run with emrun and arguments
        """
    )
    
    parser.add_argument(
        'file',
        help='HTML or WASM file to run'
    )
    
    parser.add_argument(
        '--emrun', '-e',
        action='store_true',
        help='Use emrun instead of Node.js'
    )
    
    parser.add_argument(
        'args',
        nargs='*',
        help='Additional arguments to pass to the runner'
    )
    
    parsed_args = parser.parse_args()
    return parsed_args.file, parsed_args.emrun, parsed_args.args


def main() -> int:
    """Main entry point."""
    try:
        file_path, use_emrun, args = parse_arguments()
        runner = WasmRunner()
        return runner.run(file_path, use_emrun, args)
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}⚠️  Interrupted by user{Colors.RESET}")
        return 130
    except Exception as e:
        print(f"{Colors.RED}❌ Unexpected error: {e}{Colors.RESET}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
