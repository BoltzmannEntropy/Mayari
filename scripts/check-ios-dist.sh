#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SKILL_CHECKER="$PROJECT_DIR/../../OsxSkills/skills/osx-ios/scripts/check_ios_dist.sh"

PRIVACY_URL_DEFAULT="${MAYARI_PRIVACY_URL:-https://boltzmannentropy.github.io/mayari-web/privacy.html}"
SUPPORT_URL_DEFAULT="${MAYARI_SUPPORT_URL:-https://boltzmannentropy.github.io/mayari-web/}"

if [[ ! -f "$SKILL_CHECKER" ]]; then
  echo "WARN: Skill checker not found at $SKILL_CHECKER" >&2
  echo "Running minimal local fallback checks..." >&2
  [[ -d "$PROJECT_DIR/ios" ]] || { echo "FAIL: missing ios/ directory" >&2; exit 1; }
  [[ -f "$PROJECT_DIR/ios/Runner/Info.plist" ]] || { echo "FAIL: missing ios/Runner/Info.plist" >&2; exit 1; }
  [[ -f "$PROJECT_DIR/ios/ExportOptions.plist" ]] || { echo "FAIL: missing ios/ExportOptions.plist" >&2; exit 1; }
  [[ -f "$PROJECT_DIR/ios/Runner/PrivacyInfo.xcprivacy" ]] || { echo "FAIL: missing ios/Runner/PrivacyInfo.xcprivacy" >&2; exit 1; }
  plutil -lint "$PROJECT_DIR/ios/ExportOptions.plist" >/dev/null
  plutil -lint "$PROJECT_DIR/ios/Runner/PrivacyInfo.xcprivacy" >/dev/null
  echo "PASS: minimal local iOS distribution checks"
  exit 0
fi

bash "$SKILL_CHECKER" \
  --app-root "$PROJECT_DIR" \
  --privacy-url "$PRIVACY_URL_DEFAULT" \
  --support-url "$SUPPORT_URL_DEFAULT" \
  "$@"
