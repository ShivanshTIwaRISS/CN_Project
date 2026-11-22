#!/bin/zsh
set -e
# Run Backend B using Node.js runtime (TCP port 3002)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export BACKEND_ID="B"
export PORT="3002"
echo "Starting Backend B (Node.js) on port 3002..."
exec node "$SCRIPT_DIR/../node-backend/server.js"
