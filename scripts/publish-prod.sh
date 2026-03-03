#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_NAME="${1:-officeassassins}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command '$1' is not installed or not on PATH" >&2
    exit 1
  fi
}

require_cmd spacetime

echo "[publish-prod] publishing module to maincloud database '$DB_NAME'"
(cd "$ROOT_DIR" && spacetime publish -s maincloud -p spacetimedb "$DB_NAME" -c -y)

echo "[publish-prod] done. App default environment is now Production DB."
echo "[publish-prod] open Xcode with: cd $ROOT_DIR/client-swift && open Package.swift"
