#!/usr/bin/env bash
# scripts/test-services.sh
# ─────────────────────────────────────────────────────────────
# Smoke-test both backends over localhost.
#
# Usage (run on the respective VM, or locally if port-forwarded):
#   bash scripts/test-services.sh
#
# Expected: each check prints the HTTP status code and JSON body.
# ─────────────────────────────────────────────────────────────
set -euo pipefail

SEP="────────────────────────────────────────"

pass() { echo "  ✅  $*"; }
fail() { echo "  ❌  $*"; }

check() {
    local label="$1"
    local url="$2"

    echo ""
    echo "$SEP"
    echo "  $label"
    echo "  URL: $url"
    echo "$SEP"

    # Capture HTTP status code and body separately
    local http_code body
    body=$(curl -s -w "\n__STATUS__%{http_code}" "$url" 2>&1) || true
    http_code=$(echo "$body" | tail -1 | sed 's/__STATUS__//')
    body=$(echo "$body" | head -n -1)

    echo "  Status : $http_code"
    echo "  Body   : $body"

    if [[ "$http_code" == "200" ]]; then
        pass "OK"
    else
        fail "Expected 200, got $http_code"
    fi
}

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Phase 1 — Local Service Smoke Tests    ║"
echo "╚══════════════════════════════════════════╝"

# ── Backend A ──────────────────────────────────────────────
echo ""
echo "▶  BACKEND A  (localhost:3001)"

check "GET /" "http://localhost:3001/"
check "GET /api/status" "http://localhost:3001/api/status"

# ── Backend B ──────────────────────────────────────────────
echo ""
echo "▶  BACKEND B  (localhost:3002)"

check "GET /" "http://localhost:3002/"
check "GET /api/status" "http://localhost:3002/api/status"

echo ""
echo "$SEP"
echo "  Done."
echo "$SEP"
echo ""
