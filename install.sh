#!/bin/sh

# This script configures the services so that 
# Pathfinder acts as an access point.
# Alpine Linux is expected: openrc and apk.

set -e


trap 'echo "[ERROR] in $LINENO. Aborting."' ERR

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# For installing dns-crypt, you require to activate the community repo.
echo "[1/7] Installing packages..."
apk add --no-cache hostapd dnsmasq dnscrypt-proxy nftables iw logrotate gettext tcpdump wget

# This is crucial for routing to work. 
# It forwards packets from wlan0 to eth0.
echo "[2/7] Configuring IP forwarding..."
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-forwarding.conf
sysctl -p /etc/sysctl.d/99-forwarding.conf

. "$REPO_DIR/secrets.env"
export WPA_PASSPHRASE
envsubst < "$REPO_DIR/etc/hostapd.conf" > /etc/hostapd/hostapd.conf

echo "[3/7] Copying paths..."
cp "$REPO_DIR/etc/dnsmasq.conf"               /etc/dnsmasq.conf
cp "$REPO_DIR/etc/dnscrypt-proxy.toml"        /etc/dnscrypt-proxy/dnscrypt-proxy.toml
cp "$REPO_DIR/etc/nftables.nft"               /etc/nftables.nft
cp "$REPO_DIR/etc/logrotate.d/dnscrypt-proxy" /etc/logrotate.d/dnscrypt-proxy

echo "[4/7] Installing blocklist..."
wget -O /etc/dnscrypt-proxy/blocked-names.txt \
  https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/pro.txt

# Check wlan0 state.
echo "[5/7] Checking wlan0..."
if ip link show wlan0 | grep -q "DOWN"; then
    echo "wlan0 down, setting up..."
    ip link set wlan0 up
else
    echo "wlan0 up"
fi

# Static IP.
if ! grep -q "auto wlan0" /etc/network/interfaces; then
    cat >> /etc/network/interfaces << EOF

auto wlan0
iface wlan0 inet static
    address 192.168.2.1
    netmask 255.255.255.0
EOF
fi
rc-update add networking boot

# Services will fail if the host didn't have an IP.
ip addr add 192.168.2.1/24 dev wlan0 2>/dev/null || true 

# The services will start automatically.
echo "[6/7] Enabling services..."
for svc in hostapd dnsmasq dnscrypt-proxy nftables; do
    rc-update add "$svc" default
done

echo "[7/7] Launching services..."
rc-service nftables start
rc-service dnscrypt-proxy start
rc-service dnsmasq start
rc-service hostapd start

# Logrotate.
rc-update add crond default
rc-service crond start

echo "All done. Do: iw dev wlan0 info"
