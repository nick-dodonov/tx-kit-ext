#!/bin/bash
#
# update_integrity.sh - Convenience wrapper for update_integrity.py
#
# Usage:
#   ./update_integrity.sh <module_name> [version]
#   ./update_integrity.sh lwlog
#   ./update_integrity.sh lwlog 1.4.0
#

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY_ROOT="$(dirname "$SCRIPT_DIR")"

# Check if module name is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <module_name> [version]"
    echo ""
    echo "Examples:"
    echo "  $0 lwlog"
    echo "  $0 lwlog 1.4.0"
    echo ""
    echo "Available modules:"
    if [ -d "$REGISTRY_ROOT/modules" ]; then
        ls -1 "$REGISTRY_ROOT/modules"
    else
        echo "  No modules found"
    fi
    exit 1
fi

MODULE_NAME="$1"
VERSION="${2:-}"

# Build command
CMD=(python3 "$SCRIPT_DIR/update_integrity.py")
CMD+=("$MODULE_NAME")

if [ -n "$VERSION" ]; then
    CMD+=(--version "$VERSION")
fi

CMD+=(--registry "$REGISTRY_ROOT")

echo "Running: ${CMD[*]}"
echo ""

# Execute the command
exec "${CMD[@]}"