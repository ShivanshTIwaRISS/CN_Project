#!/bin/zsh
set -e
cd "$(dirname "$0")/../backend-a"
exec python3 server.py
