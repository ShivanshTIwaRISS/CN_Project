#!/bin/zsh
set -e

# Safely restore normal DNS state for Phase 1 / Phase 2 Baseline
# Normal State:
#   app.team1.test -> 10.7.18.254 (Active Edge on Mac 2)
#   api.team1.test -> 10.7.18.254 (Active Edge on Mac 2)

NORMAL_EDGE="10.7.18.254"

echo "=========================================================="
echo "Restoring Normal DNS Configuration"
echo "=========================================================="
echo "Target: app.team1.test and api.team1.test -> $NORMAL_EDGE"

# If running on Mac 1 where dnsmasq is installed:
if [ -f /opt/homebrew/etc/dnsmasq.conf ]; then
    echo "Found dnsmasq configuration at /opt/homebrew/etc/dnsmasq.conf"
    echo "Updating address records to $NORMAL_EDGE..."
    sudo sed -i '' -e "s|^address=/app\.team1\.test/.*|address=/app.team1.test/$NORMAL_EDGE|" /opt/homebrew/etc/dnsmasq.conf
    sudo sed -i '' -e "s|^address=/api\.team1\.test/.*|address=/api.team1.test/$NORMAL_EDGE|" /opt/homebrew/etc/dnsmasq.conf
    echo "Reloading dnsmasq..."
    sudo killall -HUP dnsmasq || sudo brew services restart dnsmasq
elif [ -f /usr/local/etc/dnsmasq.conf ]; then
    echo "Found dnsmasq configuration at /usr/local/etc/dnsmasq.conf"
    echo "Updating address records to $NORMAL_EDGE..."
    sudo sed -i '' -e "s|^address=/app\.team1\.test/.*|address=/app.team1.test/$NORMAL_EDGE|" /usr/local/etc/dnsmasq.conf
    sudo sed -i '' -e "s|^address=/api\.team1\.test/.*|address=/api.team1.test/$NORMAL_EDGE|" /usr/local/etc/dnsmasq.conf
    echo "Reloading dnsmasq..."
    sudo killall -HUP dnsmasq || sudo brew services restart dnsmasq
else
    echo "No local dnsmasq configuration file found at standard Homebrew paths."
    echo "Ensure your dnsmasq configuration has:"
    echo "  address=/app.team1.test/$NORMAL_EDGE"
    echo "  address=/api.team1.test/$NORMAL_EDGE"
fi

echo -e "\nFlushing macOS DNS cache..."
sudo dscacheutil -flushcache || true
sudo killall -HUP mDNSResponder || true

echo -e "\nVerifying resolution:"
dig app.team1.test +noall +answer || true
echo "=========================================================="
echo "Normal DNS restoration complete."
echo "=========================================================="
