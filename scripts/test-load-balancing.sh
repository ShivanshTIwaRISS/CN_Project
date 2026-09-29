#!/bin/zsh
set -e

# Send 10 requests through nginx and show which backend handled each.
# Both backends should appear, demonstrating round-robin load balancing.
# NOTE: curl does NOT use -k here. The TeamX Local Root CA must be trusted
#       in macOS Keychain before running this script.

for i in {1..10}; do
    echo "===== REQUEST $i ====="
    curl -s -D - https://app.teamX.test:8443/api/status \
        -o /dev/null | grep -i "X-Backend"
done
