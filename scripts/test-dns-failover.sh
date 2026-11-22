#!/bin/zsh
set -e

# Phase 2 Extension A — Backup DNS Resolver Verification
# Tests both Primary DNS (Mac 1: 10.7.19.246) and Backup DNS (Mac 2: 10.7.18.254)

PRIMARY_DNS="${PRIMARY_DNS:-10.7.19.246}"
BACKUP_DNS="${BACKUP_DNS:-10.7.18.254}"
DOMAIN="${DOMAIN:-app.team1.test}"

echo "=========================================================="
echo "Phase 2 Extension A — DNS Resolver Redundancy Verification"
echo "=========================================================="

echo -e "\n1. Checking Primary DNS ($PRIMARY_DNS:53)..."
if dig "@$PRIMARY_DNS" "$DOMAIN" +time=2 +tries=1 +noall +answer | grep -q "$DOMAIN"; then
    echo "  [OK] Primary DNS is ACTIVE and resolving $DOMAIN:"
    dig "@$PRIMARY_DNS" "$DOMAIN" +noall +answer
else
    echo "  [FAIL/DOWN] Primary DNS at $PRIMARY_DNS did not answer."
fi

echo -e "\n2. Checking Backup DNS ($BACKUP_DNS:53)..."
if dig "@$BACKUP_DNS" "$DOMAIN" +time=2 +tries=1 +noall +answer | grep -q "$DOMAIN"; then
    echo "  [OK] Backup DNS is ACTIVE and resolving $DOMAIN:"
    dig "@$BACKUP_DNS" "$DOMAIN" +noall +answer
else
    echo "  [FAIL/DOWN] Backup DNS at $BACKUP_DNS did not answer."
fi

echo -e "\n3. Testing System Resolver Failover..."
echo "Configured system DNS servers:"
scutil --dns | grep "nameserver\[" | head -n 4 || true

echo -e "\nResolution via system resolver (dig $DOMAIN):"
dig "$DOMAIN" +noall +answer +comments | grep -E "SERVER:|ANSWER SECTION|$DOMAIN" || true

echo -e "\n=========================================================="
echo "Failover Test Instructions:"
echo "1. To demonstrate failure: stop primary dnsmasq on Mac 1:"
echo "     sudo brew services stop dnsmasq"
echo "2. Run this script again: the client will seamlessly resolve via Backup DNS ($BACKUP_DNS)."
echo "3. Restart primary dnsmasq on Mac 1:"
echo "     sudo brew services start dnsmasq"
echo "=========================================================="
