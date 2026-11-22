#!/bin/zsh
set -e

# Send 10 requests through nginx and show which backend handled each.
# Both backends should appear, demonstrating round-robin load balancing.
# NOTE: curl does NOT use -k. The Root CA must be trusted in macOS Keychain.

TARGET_HOST="${TARGET_HOST:-app.team1.test}"
TARGET_PORT="${TARGET_PORT:-8443}"
COUNT="${COUNT:-10}"

echo "Sending $COUNT requests to https://${TARGET_HOST}:${TARGET_PORT}/api/status..."
echo "--------------------------------------------------------"

for i in {1..$COUNT}; do
    printf "Request %2d: " "$i"
    BACKEND_HDR=$(curl -s -D - "https://${TARGET_HOST}:${TARGET_PORT}/api/status" -o /dev/null | grep -i "^X-Backend:" | tr -d '\r\n')
    if [ -n "$BACKEND_HDR" ]; then
        echo "$BACKEND_HDR"
    else
        echo "FAILED (No X-Backend header returned)"
    fi
done
echo "--------------------------------------------------------"
