#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$ROOT_DIR/runs/diagnostics"
mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/issues_$(date +%Y%m%d_%H%M%S).txt"

{
  echo "Mayari Diagnostics"
  echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "== System =="
  uname -a || true
  echo "Disk:"
  df -h . || true
  echo

  echo "== Tool Versions =="
  python3 --version || true
  flutter --version | head -n 1 || true
  echo

  echo "== Ports =="
  lsof -iTCP:8787 -sTCP:LISTEN -n -P || true
  lsof -iTCP:8086 -sTCP:LISTEN -n -P || true
  echo

  echo "== Health Checks =="
  echo "Backend /health:"
  curl -s --connect-timeout 3 http://127.0.0.1:8787/health || echo "unreachable"
  echo
  echo "MCP tools/list:"
  curl -s --connect-timeout 3 -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":1}' \
    http://127.0.0.1:8086 || echo "unreachable"
  echo

  echo "== Recent Logs (.logs) =="
  for f in "$ROOT_DIR/.logs"/*.log; do
    [ -f "$f" ] || continue
    echo "--- $f (last 50 lines) ---"
    tail -n 50 "$f" || true
  done

  echo
  echo "== Recent Logs (runs/logs) =="
  for f in "$ROOT_DIR/runs/logs"/*.log; do
    [ -f "$f" ] || continue
    echo "--- $f (last 50 lines) ---"
    tail -n 50 "$f" || true
  done
} > "$OUT_FILE" 2>&1

echo "$OUT_FILE"
