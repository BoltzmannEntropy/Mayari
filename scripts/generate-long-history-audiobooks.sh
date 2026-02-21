#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

VOICES="${MAYARI_LONG_TEST_VOICES:-bf_emma,bm_george}"
MAX_CHARS="${MAYARI_LONG_TEST_MAX_CHARS:-90000}"
SPEED="${MAYARI_LONG_TEST_SPEED:-1.0}"
OUTPUT_DIR="${MAYARI_LONG_TEST_OUTPUT_DIR:-}"

cd "$ROOT_DIR"

echo "Running long-history audiobook generation"
echo "Voices: $VOICES"
echo "Max chars: $MAX_CHARS"
echo "Speed: $SPEED"
if [[ -n "$OUTPUT_DIR" ]]; then
  echo "Output dir: $OUTPUT_DIR"
fi

flutter run -d macos -t tool/long_history_audiobook_runner.dart \
  --dart-define=MAYARI_LONG_TEST_VOICES="$VOICES" \
  --dart-define=MAYARI_LONG_TEST_MAX_CHARS="$MAX_CHARS" \
  --dart-define=MAYARI_LONG_TEST_SPEED="$SPEED" \
  --dart-define=MAYARI_LONG_TEST_OUTPUT_DIR="$OUTPUT_DIR"
