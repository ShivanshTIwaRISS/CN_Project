#!/bin/zsh
set -e

echo "=== app.teamX.test ==="
dig @10.7.15.60 app.teamX.test

echo
echo "=== api.teamX.test ==="
dig @10.7.15.60 api.teamX.test
