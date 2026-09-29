#!/bin/zsh
set -e

echo "=== Backend A ==="
curl http://10.7.15.60:3001
echo
curl -I http://10.7.15.60:3001/api/status
echo

echo "=== Backend B ==="
curl http://10.7.21.116:3002
echo
curl -I http://10.7.21.116:3002/api/status
echo
