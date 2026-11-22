#!/bin/zsh
set -e

# Phase 2 — Local Services Status Checker
# Audits local ports and running processes on the current Mac

echo "=========================================================="
echo "Phase 2 Service Status Audit — $(hostname)"
echo "=========================================================="

echo -e "\n1. Active Network Interfaces:"
ifconfig en0 | grep -E "inet |status:" || true

echo -e "\n2. Port Listening Audit (Ports 53, 8443, 3001, 3002):"
for PORT in 53 8443 3001 3002 5300; do
    printf "  Port %-5d : " "$PORT"
    LISTENER=$(lsof -nP -i :"$PORT" 2>/dev/null | grep -E "LISTEN" | head -n 1 || true)
    if [ -n "$LISTENER" ]; then
        echo "ACTIVE -> $LISTENER"
    else
        echo "INACTIVE / NOT LISTENING"
    fi
done

echo -e "\n3. Local Backend Health Checks:"
if curl -s -m 2 http://127.0.0.1:3001/health >/dev/null 2>&1; then
    echo "  [OK] Local Backend A (3001): $(curl -s http://127.0.0.1:3001/health)"
else
    echo "  [-] Local Backend A (3001) not responding locally"
fi

if curl -s -m 2 http://127.0.0.1:3002/health >/dev/null 2>&1; then
    echo "  [OK] Local Backend B (3002): $(curl -s http://127.0.0.1:3002/health)"
else
    echo "  [-] Local Backend B (3002) not responding locally"
fi

echo -e "\n4. macOS Packet Filter (PF) Status:"
if sudo pfctl -s info 2>/dev/null | grep -q "Enabled"; then
    echo "  PF is ENABLED"
    echo "  Project Anchor (com.apple/cnproject) rules:"
    sudo pfctl -a com.apple/cnproject -sr 2>/dev/null || echo "    (No project anchor rules loaded)"
else
    echo "  PF is DISABLED (or requires sudo)"
fi

echo -e "\n=========================================================="
