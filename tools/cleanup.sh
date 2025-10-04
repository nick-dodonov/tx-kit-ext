#!/bin/bash
# Script allowing to use git_repository (or git_override) with branch setup to speedup some parts of development
red="\033[31m"
green="\033[32m"
yellow="\033[1;33m"
blue="\033[1;34m"
purple="\033[1;35m"
cyan="\033[1;36m"
bright="\033[1;37m"
reset="\033[0m"

set -euo pipefail

echo -e "${yellow}🧹 Cleanup workspace repository cache${reset}"
if [ $# -lt 1 ]; then
    echo "Usage: $0 <repo-names...>"
    exit 1
fi

# moving to the workspace directory to get correct output_base path
if [ -d "${BUILD_WORKSPACE_DIRECTORY:-}" ]; then
    echo "  Moving to BUILD_WORKSPACE_DIRECTORY: $BUILD_WORKSPACE_DIRECTORY"
    cd "$BUILD_WORKSPACE_DIRECTORY"
else
    echo "  BUILD_WORKSPACE_DIRECTORY does not exist or is not set - using current workspace"
fi

BAZEL_OUTPUT_BASE=$(bazel info output_base)
echo "  Found output_base: $BAZEL_OUTPUT_BASE"

# По всем аргументам (именам репозиториев) попробовать удалить маркер-файлы, 
#   именованные $output_base/external/@<repo-name>+.marker
for REPO in "$@"; do
    MARKER_FILE="$BAZEL_OUTPUT_BASE/external/@${REPO}+.marker"
    if [ -f "$MARKER_FILE" ]; then
        echo -e "🟢 ${purple}'$REPO'${green} marker file cleanup:${reset} $MARKER_FILE"
        rm -f "$MARKER_FILE"
    else
        echo -e "🔵 ${purple}'$REPO'${blue} marker file not found:${reset} $MARKER_FILE"
    fi
done
