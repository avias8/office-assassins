#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DB_NAME=""
if [[ -f "$ROOT_DIR/spacetime.local.json" ]]; then
  CONFIG_DB_NAME="$(sed -n 's/.*"database"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$ROOT_DIR/spacetime.local.json" | head -n1)"
fi
DB_NAME="${1:-${CONFIG_DB_NAME:-officeassassins}}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command '$1' is not installed or not on PATH" >&2
    exit 1
  fi
}

require_cmd spacetime

if [[ -n "$CONFIG_DB_NAME" && "$DB_NAME" != "$CONFIG_DB_NAME" ]]; then
  echo "[run-local] requested database '$DB_NAME' conflicts with spacetime.local.json database '$CONFIG_DB_NAME'"
  echo "[run-local] using configured database '$CONFIG_DB_NAME'"
  DB_NAME="$CONFIG_DB_NAME"
fi

SPACETIME_PID=""
cleanup() {
  if [[ -n "$SPACETIME_PID" ]] && kill -0 "$SPACETIME_PID" >/dev/null 2>&1; then
    kill "$SPACETIME_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if curl -sf http://127.0.0.1:3000/v1/ping >/dev/null 2>&1; then
  echo "[run-local] local SpacetimeDB already running"
else
  echo "[run-local] starting local SpacetimeDB (Ctrl+C to stop)"
  spacetime start > /tmp/officeassassins-spacetime.log 2>&1 &
  SPACETIME_PID=$!

  # Wait for local server
  for _ in {1..30}; do
    if curl -sf http://127.0.0.1:3000/v1/ping >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
  done
fi

if ! curl -sf http://127.0.0.1:3000/v1/ping >/dev/null 2>&1; then
  echo "error: local SpacetimeDB did not become ready. Check /tmp/officeassassins-spacetime.log" >&2
  exit 1
fi

echo "[run-local] publishing module to database '$DB_NAME'"
(cd "$ROOT_DIR" && spacetime publish -s local -p spacetimedb "$DB_NAME" -c -y)

echo "[run-local] done. Open Xcode with:"
echo "  cd $ROOT_DIR/client-swift && open Package.swift"
if [[ -n "$SPACETIME_PID" ]]; then
  echo "[run-local] keeping local server running; press Ctrl+C to stop"
  wait "$SPACETIME_PID"
else
  echo "[run-local] server was already running; leaving it running"
fi
