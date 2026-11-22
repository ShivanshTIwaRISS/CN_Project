#!/bin/zsh
set -e
# Run Backend A using Node.js runtime (TCP port 3001)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export BACKEND_ID="A"
export PORT="3001"
echo "Starting Backend A (Node.js) on port 3001..."
exec node "$SCRIPT_DIR/../node-backend/server.js"
