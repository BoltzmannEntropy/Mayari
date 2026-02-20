#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

log() { echo -e "${BLUE}[install]${NC} $*"; }
ok() { echo -e "${GREEN}[ok]${NC} $*"; }

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

log "Checking dependencies"
require_cmd flutter

log "Installing Flutter packages"
cd "$ROOT_DIR"
flutter pub get
ok "Flutter packages installed"

ok "Mayari install complete"
echo ""
echo "Next steps:"
echo "  flutter run -d macos"
echo ""
echo "Note: TTS model (~340MB) downloads automatically on first use."
