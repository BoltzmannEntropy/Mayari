#!/usr/bin/env bash
set -euo pipefail

# Compatibility wrapper so legacy invocations still work.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/build_dmg.sh" "$@"
