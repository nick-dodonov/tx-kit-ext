import os
from termcolor import * #TODO: use colorama for windows support

print(colored('🚀 Dev: Init tx repo developer environemnt tool', 'yellow'))

#TODO: allow --force regeneration

#TODO: ⚙️ make useful .user.bazelrc
#TODO: make useful .lldbinit

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

# detect .user.bazelrc already exists
user_bazelrc = '.user3.bazelrc'
user_bazelrc_path = os.path.join(workspace_root, user_bazelrc)
if os.path.exists(user_bazelrc_path):
    print(colored(f'⚠️  Warning:', 'yellow'), f'\'{user_bazelrc}\' already exists, skipping creation at {user_bazelrc_path}')
else:
    print(f'⚙️ Creating {user_bazelrc}...')
    # copy default default.user.bazelrc from the script directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    default_bazelrc_path = os.path.join(script_dir, 'default.user.bazelrc')
    with open(default_bazelrc_path, 'r') as f:
        default_bazelrc_content = f.read()
    with open(user_bazelrc_path, 'w') as f:
        f.write(default_bazelrc_content)
    print(colored(f'✅ Created {user_bazelrc} at {user_bazelrc_path}', 'light_green'))

print(colored('✅ Done', 'light_green'))
