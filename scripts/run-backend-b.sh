#!/bin/zsh
set -e
cd "$(dirname "$0")/../backend-b"
exec python3 server.py
