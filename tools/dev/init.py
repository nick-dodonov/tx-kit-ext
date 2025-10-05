import os
import datetime
import argparse
from termcolor import * #TODO: use colorama for windows support

print(colored('🚀 Initialize developer environemnt for tx bazel repo', 'yellow'))
#TODO: make useful .lldbinit

def create_user_bazelrc(target_path, default_path):
    """Create a user bazelrc file by copying the default template.
    
    Args:
        target_path: Path where the user bazelrc should be created
        default_path: Path to the default template file
    """
    print(f'⚙️  Creating user bazelrc: {target_path}')
    with open(default_path, 'r') as f:
        default_content = f.read()
    with open(target_path, 'w') as f:
        f.write(default_content)

# argparse for --force
parser = argparse.ArgumentParser(description='Initialize developer environment for tx bazel repo.')
parser.add_argument('--force', action='store_true', help='Force regeneration of config files.')
args = parser.parse_args()
if args.force:
    print(colored('⚠️  Warning:', 'yellow'), 'Force flag is set. Existing files will be overwritten.')

# detect bazel workspace root (bzlmod)
workspace_root = os.getcwd()
if os.getenv('BUILD_WORKSPACE_DIRECTORY'):
    workspace_root = os.getenv('BUILD_WORKSPACE_DIRECTORY')

while not os.path.exists(os.path.join(workspace_root, 'MODULE.bazel')):
    parent = os.path.dirname(workspace_root)
    if parent == workspace_root:
        print(colored('❌ Error: MODULE.bazel not found. Are you in a Bazel workspace?', 'red'))
        exit(1)
    workspace_root = parent
print(f'📂 Detected bazel workspace: {workspace_root}')

# Generate .user.bazelrc
user_bazelrc = '.user3.bazelrc'
user_bazelrc_path = os.path.join(workspace_root, user_bazelrc)
script_dir = os.path.dirname(os.path.abspath(__file__))
default_bazelrc_path = os.path.join(script_dir, 'default.user.bazelrc')

if os.path.exists(user_bazelrc_path):
    if args.force:
        print(f'⚙️  Overwriting existing \'{user_bazelrc}\' due to --force flag')
        # backup existing file with timestamp
        timestamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
        backup_path = f'{user_bazelrc_path}.{timestamp}.bak'
        os.rename(user_bazelrc_path, backup_path)
        print(f'⚙️  Backed up existing \'{user_bazelrc}\' to {backup_path}')
        create_user_bazelrc(user_bazelrc_path, default_bazelrc_path)
    else:
        print(colored(f'⚠️  Warning:', 'yellow'), f'\'{user_bazelrc}\' already exists, skipping creation at {user_bazelrc_path}')
else:
    create_user_bazelrc(user_bazelrc_path, default_bazelrc_path)

print(colored('✅ Initialization done', 'light_green'))
