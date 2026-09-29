#!/usr/bin/env bash
# scripts/run-backend-a.sh
# ─────────────────────────────────────────────────────────────
# Start Backend A (Python) on 0.0.0.0:3001
# Run from any directory; script resolves the correct path.
# ─────────────────────────────────────────────────────────────
set -euo pipefail
cd "$(dirname "$0")/../backend-a"
exec python3 server.py
