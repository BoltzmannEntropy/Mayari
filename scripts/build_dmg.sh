#!/usr/bin/env bash
set -euo pipefail

# Compatibility wrapper so all app repos expose scripts/build_dmg.sh.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/build-dmg.sh" "$@"
