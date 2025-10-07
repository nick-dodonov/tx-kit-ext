#!/usr/bin/env python3
"""
Initialize developer environment for tx bazel repo.
Handles configuration file setup and workspace initialization.
"""
#TODO: find and setup tools in .dev.bazelr to simplify local-tools configuration: 
#   --action_env for MAKE CMAKE PKG_CONFIG NINJA EMSDK EMSCRIPTEN_ROOT EM_CACHE

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
    parser.add_argument(
        '-d', '--dryrun',
        action='store_true',
        help='Show what would be created/modified without making any changes'
    )
    parser.add_argument(
        '-s', '--symlink',
        action='store_true',
        help='Create symbolic links to config files instead of copying them'
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

def create_symlink(target_path: Path, default_path: Path, dryrun: bool = False) -> None:
    """
    Create a symbolic link to the default template.
    
    Args:
        target_path: Path where the symlink should be created
        default_path: Path to the default template file to link to
        dryrun: If True, only show what would be done without making changes
    """
    print(f'⚙️  {"Would create symlink" if dryrun else "Creating symlink"}: {target_path} -> {default_path.resolve()}')
    if not dryrun:
        target_path.symlink_to(default_path.resolve())

def create_config(target_path: Path, default_path: Path, dryrun: bool = False, use_symlink: bool = False) -> None:
    """
    Create a config file by copying the default template or creating a symlink.
    
    Args:
        target_path: Path where the config should be created
        default_path: Path to the default template file
        dryrun: If True, only show what would be done without making changes
        use_symlink: If True, create a symbolic link instead of copying
    """
    if use_symlink:
        create_symlink(target_path, default_path, dryrun)
    else:
        print(f'⚙️  {"Would create" if dryrun else "Creating"}: {target_path}')
        if not dryrun:
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

def setup_config_file(target_path: Path, template_path: Path, force: bool = False, dryrun: bool = False, use_symlink: bool = False) -> None:
    """
    Set up a configuration file from a template, handling backups if needed.
    
    Args:
        target_path: Path where the config file should be created
        template_path: Path to the template file
        force: Whether to force overwrite existing files
        dryrun: If True, only show what would be done without making changes
        use_symlink: If True, create a symbolic link instead of copying
    """
    if target_path.exists():
        if force:
            print(f'⚙️  {"Would overwrite" if dryrun else "Overwriting"} existing \'{target_path.name}\' due to --force flag')
            if not dryrun:
                backup_path = backup_file(target_path)
                print(f'⚙️  Backed up existing \'{target_path.name}\' to {backup_path}')
            else:
                print(f'⚙️  Would backup existing \'{target_path.name}\'')
            create_config(target_path, template_path, dryrun, use_symlink)
        else:
            print(colored(f'⚠️  Warning:', 'yellow'),
                  f'\'{target_path.name}\' already exists, skipping creation at {target_path}')
    else:
        create_config(target_path, template_path, dryrun, use_symlink)

def setup_dev_bazelrc(workspace_root: Path, force: bool = False, dryrun: bool = False, use_symlink: bool = False) -> None:
    """
    Set up the dev's bazelrc file, handling backups if needed.
    
    Args:
        workspace_root: Path to the workspace root
        force: Whether to force overwrite existing files
        dryrun: If True, only show what would be done without making changes
    """
    workspace_bazelrc = '.dev.bazelrc'

    # Validate that workspace .bazelrc exists and try-include .dev.bazelrc
    bazelrc_path = workspace_root / '.bazelrc'
    if not bazelrc_path.exists():
        print(colored('⚠️  Warning:', 'yellow'), f'Workspace root \'.bazelrc\' not found at {bazelrc_path}')
    else:
        bazelrc_content = bazelrc_path.read_text()
        try_import_line = f'try-import %workspace%/{workspace_bazelrc}'
        if try_import_line not in bazelrc_content:
            print(colored('⚠️  Warning:', 'yellow'), f'\'.bazelrc\' does not include \'{try_import_line}\'')
            print(f'💡 Add the following line to your {bazelrc_path}:')
            print(colored(f'    {try_import_line}', 'cyan'))

    workspace_bazelrc_path = workspace_root / workspace_bazelrc
    default_bazelrc_path = Path(__file__).parent / 'default.dev.bazelrc'
    setup_config_file(workspace_bazelrc_path, default_bazelrc_path, force, dryrun, use_symlink)

def setup_lldbinit(workspace_root: Path, force: bool = False, dryrun: bool = False, use_symlink: bool = False) -> None:
    """
    Set up LLDB initialization files.
    
    Args:
        workspace_root: Path to the workspace root
        force: Whether to force overwrite existing files
        dryrun: If True, only show what would be done without making changes
    """
    # Setup user's .lldbinit in $HOME
    user_lldbinit_path = Path.home() / '.lldbinit'
    default_user_lldbinit_path = Path(__file__).parent / 'default.user.lldbinit'
    setup_config_file(user_lldbinit_path, default_user_lldbinit_path, force, dryrun, use_symlink)

    # Setup workspace .lldbinit
    workspace_lldbinit_path = workspace_root / '.lldbinit'
    default_workspace_lldbinit_path = Path(__file__).parent / 'default.dev.lldbinit'
    setup_config_file(workspace_lldbinit_path, default_workspace_lldbinit_path, force, dryrun, use_symlink)

def main() -> None:
    """Main entry point for the initialization script."""
    print(colored('🚀 Initialize developer environment for tx bazel repo', 'yellow'))
    args = parse_args()
    
    workspace_root = find_workspace_root()
    print(f'📂 Detected bazel workspace: {workspace_root}')

    if args.dryrun:
        print(colored('🔍 Dry run:', 'blue'),
              'showing what would be done without making changes.')

    if args.force:
        print(colored('⚠️  Warning:', 'yellow'),
              'Force flag is set, existing files will be overwritten.')

    if args.symlink:
        print(colored('🔗 Symlink mode:', 'magenta'),
              'creating symbolic links instead of copying files.')

    setup_dev_bazelrc(workspace_root, args.force, args.dryrun, args.symlink)
    setup_lldbinit(workspace_root, args.force, args.dryrun, args.symlink)
    
    print(colored('✅ Initialization done', 'light_green'))

if __name__ == '__main__':
    main()
