#!/usr/bin/env bash
# scripts/run-backend-b.sh
# ─────────────────────────────────────────────────────────────
# Start Backend B (Node.js) on 0.0.0.0:3002
# Run from any directory; script resolves the correct path.
# ─────────────────────────────────────────────────────────────
set -euo pipefail
cd "$(dirname "$0")/../backend-b"
exec node server.js
