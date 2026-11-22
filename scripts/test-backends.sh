#!/bin/zsh
set -e

MAC1_IP="${MAC1_IP:-10.7.19.246}"
MAC2_IP="${MAC2_IP:-10.7.18.254}"

echo "=== Backend A (${MAC1_IP}:3001) ==="
curl -s "http://${MAC1_IP}:3001/"
echo
curl -I -s "http://${MAC1_IP}:3001/api/status"
echo

echo "=== Backend B (${MAC2_IP}:3002) ==="
curl -s "http://${MAC2_IP}:3002/"
echo
curl -I -s "http://${MAC2_IP}:3002/api/status"
echo
