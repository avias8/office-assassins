#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command '$1' is not installed or not on PATH" >&2
    exit 1
  fi
}

require_cmd swift
require_cmd spacetime

if command -v cargo >/dev/null 2>&1; then
  echo "[bootstrap] validating Rust module"
  (cd "$ROOT_DIR/spacetimedb" && cargo check)
else
  echo "[bootstrap] cargo not found; skipping Rust check"
fi

echo "[bootstrap] resolving/building Swift package"
(cd "$ROOT_DIR/client-swift" && swift build)

echo "[bootstrap] done"
