#!/bin/zsh
set -e

# Full HTTPS test through the domain name.
# NOTE: curl does NOT use -k here.
# The TeamX Local Root CA must be trusted in macOS Keychain before running.
#
# To trust the CA (run once per machine):
#   sudo security add-trusted-cert -d -r trustRoot \
#       -k /Library/Keychains/System.keychain teamX-rootCA.crt

curl https://app.teamX.test:8443/api/status
echo

curl -I https://app.teamX.test:8443/api/status
