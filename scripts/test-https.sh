#!/bin/zsh
set -e

# Full HTTPS test through the private domain name.
# NOTE: curl does NOT use -k here.
# The local Root CA (mkcert / local CA) must be trusted in macOS Keychain.

TARGET_HOST="${TARGET_HOST:-app.team1.test}"
TARGET_PORT="${TARGET_PORT:-8443}"

echo "=== 1. GET /api/status over HTTPS ==="
curl "https://${TARGET_HOST}:${TARGET_PORT}/api/status"
echo -e "\n"

echo "=== 2. Response Headers (curl -I) ==="
curl -I -s "https://${TARGET_HOST}:${TARGET_PORT}/api/status"
echo

echo "=== 3. Caching & ETag Demonstration (/api/info) ==="
echo "First request (Full 200 OK):"
INFO_HEADERS=$(curl -s -i "https://${TARGET_HOST}:${TARGET_PORT}/api/info")
echo "$INFO_HEADERS" | grep -E "HTTP/|X-Backend|Cache-Control|ETag"
echo

ETAG_VAL=$(echo "$INFO_HEADERS" | grep -i "ETag" | awk '{print $2}' | tr -d '\r\n')
if [ -n "$ETAG_VAL" ]; then
    echo "Conditional request with If-None-Match: $ETAG_VAL (Expecting 304 Not Modified):"
    curl -s -i -H "If-None-Match: $ETAG_VAL" "https://${TARGET_HOST}:${TARGET_PORT}/api/info" | head -n 8
fi
echo
