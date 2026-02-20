#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

SCHEME="Runner"
WORKSPACE="$PROJECT_DIR/ios/Runner.xcworkspace"
EXPORT_OPTIONS="$PROJECT_DIR/ios/ExportOptions.plist"
DIST_MODE="testflight"
UPLOAD=false
NO_CODESIGN=false

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release-ios.sh [options]

Options:
  --scheme <name>            Xcode scheme (default: Runner)
  --workspace <path>         Xcode workspace path
  --export-options <path>    ExportOptions.plist path
  --dist <testflight|appstore>
  --upload                   Upload with asc CLI (requires ASC_APP_ID)
  --no-codesign              Build unsigned archive (local validation)
  -h, --help                 Show help

Environment:
  ASC_APP_ID                 App Store Connect app id (required with --upload)
  ASC_TESTFLIGHT_GROUP       TestFlight group id/name for testflight uploads
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme)
      SCHEME="${2:-}"
      shift 2
      ;;
    --workspace)
      WORKSPACE="${2:-}"
      shift 2
      ;;
    --export-options)
      EXPORT_OPTIONS="${2:-}"
      shift 2
      ;;
    --dist)
      DIST_MODE="${2:-}"
      shift 2
      ;;
    --upload)
      UPLOAD=true
      shift
      ;;
    --no-codesign)
      NO_CODESIGN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$DIST_MODE" != "testflight" && "$DIST_MODE" != "appstore" ]]; then
  echo "--dist must be one of: testflight, appstore" >&2
  exit 2
fi

if [[ "$UPLOAD" == "true" && "$NO_CODESIGN" == "true" ]]; then
  echo "--upload cannot be combined with --no-codesign" >&2
  exit 2
fi

if [[ ! -f "$EXPORT_OPTIONS" ]]; then
  echo "Export options file not found: $EXPORT_OPTIONS" >&2
  exit 1
fi

echo "== iOS/iPad preflight =="
bash "$SCRIPT_DIR/check-ios-dist.sh" --scheme "$SCHEME"

VERSION_NAME="$(grep 'version:' "$PROJECT_DIR/pubspec.yaml" | head -1 | cut -d'+' -f1 | cut -d':' -f2 | xargs)"
BUILD_NUMBER="$(grep 'version:' "$PROJECT_DIR/pubspec.yaml" | head -1 | cut -d'+' -f2 | xargs)"

echo "== Building IPA =="
echo "Version: $VERSION_NAME+$BUILD_NUMBER"
echo "Workspace: $WORKSPACE"
echo "Scheme: $SCHEME"
echo "Export options: $EXPORT_OPTIONS"

(
  cd "$PROJECT_DIR"
  flutter pub get
  BUILD_CMD=(flutter build ipa \
    --release \
    --build-name="$VERSION_NAME" \
    --build-number="$BUILD_NUMBER" \
    --export-options-plist="$EXPORT_OPTIONS")
  if [[ "$NO_CODESIGN" == "true" ]]; then
    BUILD_CMD+=(--no-codesign)
  fi
  "${BUILD_CMD[@]}"
)

IPA_PATH=""
if [[ -d "$PROJECT_DIR/build/ios/ipa" ]]; then
  IPA_PATH="$(find "$PROJECT_DIR/build/ios/ipa" -maxdepth 1 -type f -name "*.ipa" | head -n 1 || true)"
fi
if [[ "$NO_CODESIGN" == "true" ]]; then
  ARCHIVE_PATH="$PROJECT_DIR/build/ios/archive/Runner.xcarchive"
  if [[ ! -d "$ARCHIVE_PATH" ]]; then
    echo "Archive not found: $ARCHIVE_PATH" >&2
    exit 1
  fi
  echo "Unsigned archive ready: $ARCHIVE_PATH"
  echo "Re-run without --no-codesign after setting Team ID for IPA export/upload."
  exit 0
fi

if [[ -z "$IPA_PATH" ]]; then
  echo "IPA not found in build/ios/ipa" >&2
  exit 1
fi

echo "IPA ready: $IPA_PATH"

if [[ "$UPLOAD" == "true" ]]; then
  if ! command -v asc >/dev/null 2>&1; then
    echo "asc CLI is required for --upload." >&2
    exit 1
  fi
  if [[ -z "${ASC_APP_ID:-}" ]]; then
    echo "ASC_APP_ID is required for --upload." >&2
    exit 1
  fi

  if [[ "$DIST_MODE" == "testflight" ]]; then
    if [[ -z "${ASC_TESTFLIGHT_GROUP:-}" ]]; then
      echo "ASC_TESTFLIGHT_GROUP is required for TestFlight upload." >&2
      exit 1
    fi
    asc publish testflight --app "$ASC_APP_ID" --ipa "$IPA_PATH" --group "$ASC_TESTFLIGHT_GROUP" --wait
  else
    asc publish appstore --app "$ASC_APP_ID" --ipa "$IPA_PATH" --version "$VERSION_NAME" --wait
  fi
fi

echo "== iOS release prep complete =="
echo "Next: verify the build in App Store Connect processing + metadata/screenshots."
