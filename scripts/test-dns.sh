#!/bin/zsh
set -e

PRIMARY_DNS="${PRIMARY_DNS:-10.7.19.246}"
BACKUP_DNS="${BACKUP_DNS:-10.7.18.254}"

echo "=== Querying Primary DNS (${PRIMARY_DNS}:53) ==="
echo "--- app.team1.test ---"
dig "@${PRIMARY_DNS}" app.team1.test +noall +answer
echo "--- api.team1.test ---"
dig "@${PRIMARY_DNS}" api.team1.test +noall +answer
echo

echo "=== Querying Backup DNS (${BACKUP_DNS}:53) ==="
echo "--- app.team1.test ---"
dig "@${BACKUP_DNS}" app.team1.test +noall +answer
echo "--- api.team1.test ---"
dig "@${BACKUP_DNS}" api.team1.test +noall +answer
echo

echo "=== Querying System Resolver (no @) ==="
dig app.team1.test +noall +answer || true
echo
