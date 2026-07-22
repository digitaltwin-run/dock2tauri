#!/usr/bin/env bash
# Thin compatibility launcher for the canonical taurido execution engine.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PYTHON_BIN="${DOCK2TAURI_PYTHON:-}"

if [ -z "$PYTHON_BIN" ]; then
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_BIN="python3"
    elif command -v python >/dev/null 2>&1; then
        PYTHON_BIN="python"
    else
        echo "Dock2Tauri requires Python 3 to run the canonical taurido engine." >&2
        exit 127
    fi
fi

export PYTHONPATH="$PROJECT_ROOT${PYTHONPATH:+:$PYTHONPATH}"
exec "$PYTHON_BIN" -m taurido.cli "$@"
