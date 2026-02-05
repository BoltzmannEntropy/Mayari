#!/usr/bin/env sh
set -e

usage() {
  cat <<'USAGE'
Usage:
  scripts/flutter.sh run [platform] [-- flutter run args]
  scripts/flutter.sh build [platform] [-- flutter build args]

Examples:
  scripts/flutter.sh run
  scripts/flutter.sh run macos
  scripts/flutter.sh run --release
  scripts/flutter.sh build windows
  scripts/flutter.sh build --release

Notes:
  - If platform is omitted, the script chooses based on the host OS.
  - Set SKIP_PUB_GET=1 to skip 'flutter pub get'.
USAGE
}

detect_platform() {
  uname_s=$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)
  case "$uname_s" in
    darwin*) echo "macos" ;;
    linux*) echo "linux" ;;
    msys*|mingw*|cygwin*) echo "windows" ;;
    *)
      echo "" ;;
  esac
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

cmd="$1"
shift

platform=""
if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
  platform="$1"
  shift
fi

if [ -z "$platform" ]; then
  platform=$(detect_platform)
  if [ -z "$platform" ]; then
    echo "Unable to infer platform from host OS. Pass one of: macos, windows, linux." >&2
    exit 1
  fi
fi

if [ "${SKIP_PUB_GET:-}" != "1" ]; then
  flutter pub get
fi

case "$cmd" in
  run)
    flutter run -d "$platform" "$@"
    ;;
  build)
    flutter build "$platform" "$@"
    ;;
  *)
    usage
    exit 1
    ;;
esac
