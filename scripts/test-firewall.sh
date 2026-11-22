#!/bin/zsh
set -e

# Phase 2 Extension C — Service Isolation / Backend Firewall Test Helper
# Safely inspects macOS Packet Filter (PF) anchor rules and verifies isolation.

MAC1_IP="${MAC1_IP:-10.7.19.246}"
MAC2_IP="${MAC2_IP:-10.7.18.254}"

echo "=========================================================="
echo "Phase 2 Extension C — Service Isolation Verification"
echo "=========================================================="

echo -e "\n1. Current PF Status and Project Anchor Rules:"
if command -v pfctl >/dev/null 2>&1; then
    sudo pfctl -s info 2>/dev/null | grep -E "Status|Enabled" || echo "Note: Run with sudo to inspect PF status."
    echo "--- Anchor com.apple/cnproject rules ---"
    sudo pfctl -a com.apple/cnproject -sr 2>/dev/null || true
fi

echo -e "\n2. Testing Backend Connectivity from Local Host:"
echo "--- Testing Mac 1 Backend A (3001) ---"
curl -s -m 3 "http://${MAC1_IP}:3001/health" && echo " [REACHABLE]" || echo " [BLOCKED / TIMEOUT / OFFLINE]"

echo "--- Testing Mac 2 Backend B (3002) ---"
curl -s -m 3 "http://${MAC2_IP}:3002/health" && echo " [REACHABLE]" || echo " [BLOCKED / TIMEOUT (Expected from external host)]"

echo -e "\n3. Testing End-to-End Reverse Proxy (Mac 2 Nginx -> Backends):"
curl -s -m 4 "https://app.team1.test:8443/api/status" && echo " [EDGE ACCESS HEALTHY]" || echo " [EDGE ACCESS FAILED]"

echo -e "\n=========================================================="
echo "Firewall Management Commands:"
echo "Apply Mac 1 PF Rules:"
echo "  sudo pfctl -a com.apple/cnproject -f firewall/pf-mac1.conf.example"
echo "  sudo pfctl -e"
echo ""
echo "Apply Mac 2 PF Rules:"
echo "  sudo pfctl -a com.apple/cnproject -f firewall/pf-mac2.conf.example"
echo "  sudo pfctl -e"
echo ""
echo "Safe Rollback / Flush Anchor Rules (leaves main macOS firewall untouched):"
echo "  sudo pfctl -a com.apple/cnproject -F all"
echo "=========================================================="
