#!/usr/bin/env python3
"""
Initialize developer environment for tx bazel repo.
Handles configuration file setup and workspace initialization.
"""

import os
import sys
import datetime
import argparse
from pathlib import Path
from termcolor import colored  # TODO: use colorama for windows support

def parse_args() -> argparse.Namespace:
    """Parse and return command line arguments."""
    parser = argparse.ArgumentParser(
        description='Initialize developer environment for tx bazel repo.'
    )
    parser.add_argument(
        '-f', '--force',
        action='store_true',
        help='Force regeneration of config files'
    )
    return parser.parse_args()

def find_workspace_root() -> Path:
    """
    Find the Bazel workspace root directory containing MODULE.bazel.
    
    Returns:
        Path: Path to the workspace root
    
    Raises:
        SystemExit: If MODULE.bazel is not found
    """
    workspace_root = Path(os.getenv('BUILD_WORKSPACE_DIRECTORY', os.getcwd()))
    
    while not (workspace_root / 'MODULE.bazel').exists():
        parent = workspace_root.parent
        if parent == workspace_root:
            print(colored('❌ Error: MODULE.bazel not found. Are you in a Bazel workspace?', 'red'))
            sys.exit(1)
        workspace_root = parent
    
    return workspace_root

def create_user_bazelrc(target_path: Path, default_path: Path) -> None:
    """
    Create a user bazelrc file by copying the default template.
    
    Args:
        target_path: Path where the user bazelrc should be created
        default_path: Path to the default template file
    """
    print(f'⚙️  Creating user bazelrc: {target_path}')
    target_path.write_text(default_path.read_text())

def backup_file(file_path: Path) -> Path:
    """
    Create a timestamped backup of a file.
    
    Args:
        file_path: Path to the file to backup
    
    Returns:
        Path: Path to the backup file
    """
    timestamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    backup_path = file_path.with_suffix(f'.{timestamp}.bak')
    file_path.rename(backup_path)
    return backup_path

def setup_user_bazelrc(workspace_root: Path, force: bool = False) -> None:
    """
    Set up the user's bazelrc file, handling backups if needed.
    
    Args:
        workspace_root: Path to the workspace root
        force: Whether to force overwrite existing files
    """
    user_bazelrc = '.user3.bazelrc'
    user_bazelrc_path = workspace_root / user_bazelrc
    default_bazelrc_path = Path(__file__).parent / 'default.user.bazelrc'

    if user_bazelrc_path.exists():
        if force:
            print(f'⚙️  Overwriting existing \'{user_bazelrc}\' due to --force flag')
            backup_path = backup_file(user_bazelrc_path)
            print(f'⚙️  Backed up existing \'{user_bazelrc}\' to {backup_path}')
            create_user_bazelrc(user_bazelrc_path, default_bazelrc_path)
        else:
            print(colored(f'⚠️  Warning:', 'yellow'),
                  f'\'{user_bazelrc}\' already exists, skipping creation at {user_bazelrc_path}')
    else:
        create_user_bazelrc(user_bazelrc_path, default_bazelrc_path)

def main() -> None:
    """Main entry point for the initialization script."""
    print(colored('🚀 Initialize developer environment for tx bazel repo', 'yellow'))
    args = parse_args()
    
    workspace_root = find_workspace_root()
    print(f'📂 Detected bazel workspace: {workspace_root}')

    if args.force:
        print(colored('⚠️  Warning:', 'yellow'),
              'Force flag is set. Existing files will be overwritten.')

    setup_user_bazelrc(workspace_root, args.force)
    
    # TODO: make useful .lldbinit
    print(colored('✅ Initialization done', 'light_green'))

if __name__ == '__main__':
    main()
