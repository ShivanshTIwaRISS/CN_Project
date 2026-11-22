#!/bin/zsh
set -e

# Phase 2 Extension B — DNS TTL and Controlled Record Change Demo
# Demonstrates 30-second TTL caching, TTL decrement, and manual cache flushing.

CACHE_RESOLVER="127.0.0.1"
CACHE_PORT="5300"
AUTHORITATIVE_DNS="${AUTHORITATIVE_DNS:-10.7.19.246}"
DOMAIN="app.team1.test"

echo "=========================================================="
echo "Phase 2 Extension B — DNS TTL & Cache Expiry Demonstration"
echo "=========================================================="

echo -e "\n1. Checking Authoritative DNS ($AUTHORITATIVE_DNS:53)..."
dig "@$AUTHORITATIVE_DNS" "$DOMAIN" +noall +answer

echo -e "\n2. Checking Local Caching Resolver ($CACHE_RESOLVER:$CACHE_PORT)..."
if ! lsof -nP -i :"$CACHE_PORT" 2>/dev/null | grep -q LISTEN; then
    echo "Caching resolver is not running on port $CACHE_PORT."
    echo "To start the local caching resolver on Mac 1:"
    echo "  dnsmasq --conf-file=dns/dnsmasq-client-cache.conf.example"
    echo ""
    echo "Using direct authoritative query to demonstrate configured local-ttl=30:"
    dig "@$AUTHORITATIVE_DNS" "$DOMAIN" +noall +answer
    exit 0
fi

echo -e "\nInitial query to caching resolver:"
dig "@$CACHE_RESOLVER" -p "$CACHE_PORT" "$DOMAIN" +noall +answer

echo -e "\nWaiting 5 seconds to demonstrate TTL decrement..."
sleep 5

echo -e "\nSubsequent query to caching resolver (observing decreasing TTL):"
dig "@$CACHE_RESOLVER" -p "$CACHE_PORT" "$DOMAIN" +noall +answer

echo -e "\n=========================================================="
echo "Extension B Experiment Summary (from evidence/dns/ttl-proof.txt):"
echo "  1. Initial Cached Answer : 10.7.18.254 (TTL 30)"
echo "  2. Authoritative Changed : 10.7.19.246 (TTL 30)"
echo "  3. Stale Cache Returned  : 10.7.18.254 (TTL 25 -> decreasing)"
echo "  4. After TTL Expiry (30s): 10.7.19.246 (TTL 30)"
echo "  5. Authoritative Reset   : 10.7.18.254 (TTL 30)"
echo "  6. Before Manual Flush   : 10.7.19.246 (TTL 26)"
echo "  7. SIGHUP Sent to Cache  : 10.7.18.254 (TTL 30 - updated immediately)"
echo "=========================================================="
