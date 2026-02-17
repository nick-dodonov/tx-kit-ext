#!/usr/bin/env python3
"""
Setup developer environment for using repo's ~/.lldbinit file for LLDB debugging.
"""

import datetime
import argparse
from pathlib import Path
from dataclasses import dataclass
from termcolor import colored


@dataclass
class Config:
    force: bool = False
    dryrun: bool = False


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Initialize developer environment for using repo's ~/.lldbinit file for LLDB debugging."
    )
    parser.add_argument(
        "-f", "--force", action="store_true", help="Force regeneration of config files"
    )
    parser.add_argument(
        "-d",
        "--dryrun",
        action="store_true",
        help="Show what would be created/modified without making any changes",
    )

    args = parser.parse_args()
    if args.dryrun:
        print(colored("🔍 Dry run:", "blue"), "showing what would be done without making changes.")
    if args.force:
        print(colored("⚠️  Warning:", "yellow"), "Force flag is set, existing files will be overwritten.")
    return args


def create_config(target_path: Path, default_path: Path, config: Config) -> None:
    """Create a config file by copying the default template."""
    print(f'⚙️  {"Would create" if config.dryrun else "Creating"}: {target_path}')
    if not config.dryrun:
        # Remove broken symlink if it exists
        if target_path.is_symlink() and not target_path.exists():
            target_path.unlink()
        target_path.write_text(default_path.read_text())


def backup_file(file_path: Path) -> Path:
    """Create a timestamped backup of a file."""
    timestamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_path = file_path.with_suffix(f".{timestamp}.bak")
    file_path.rename(backup_path)
    return backup_path


def setup_config_file(target_path: Path, template_path: Path, config: Config) -> None:
    """Set up a configuration file from a template, handling backups if needed."""
    if target_path.exists():
        if config.force:
            print(
                f'⚙️  {"Would overwrite" if config.dryrun else "Overwriting"} existing \'{target_path.name}\' due to --force flag'
            )
            if not config.dryrun:
                backup_path = backup_file(target_path)
                print(f"⚙️  Backed up existing '{target_path.name}' to {backup_path}")
            else:
                print(f"⚙️  Would backup existing '{target_path.name}'")

            create_config(target_path, template_path, config)
        else:
            print(
                colored(f"⚠️  Warning:", "yellow"),
                f"'{target_path.name}' already exists, skipping creation at {target_path}",
            )
    else:
        create_config(target_path, template_path, config)


def setup_user_lldbinit(config: Config) -> None:
    """Set up user's .lldbinit file in home directory."""
    user_lldbinit_path = Path.home() / ".lldbinit"
    default_user_lldbinit_path = Path(__file__).parent / "default.user.lldbinit"
    setup_config_file(user_lldbinit_path, default_user_lldbinit_path, config)


def main() -> None:
    print(colored("🚀 Initialize user's environment for LLDB debugging", "yellow"))
    args = parse_args()
    config = Config(force=args.force, dryrun=args.dryrun)

    setup_user_lldbinit(config)
    print(colored("✅ Initialization done", "light_green"))


if __name__ == "__main__":
    main()
