#!/bin/sh

# This script configures the services so that 
# Pathfinder acts as an access point.
# Alpine Linux is expected: openrc and apk.

set -e


trap 'echo "[ERROR] in $LINENO. Aborting."' ERR

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[1/6] Installing packages..."
apk add --no-cache hostapd dnsmasq dnscrypt-proxy nftables iw logrotate gettext tcpdump

# This is crucial for routing to work. 
# It forwards packets from wlan0 to eth0.
echo "[2/6] Configuring IP forwarding..."
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-forwarding.conf
sysctl -p /etc/sysctl.d/99-forwarding.conf

. "$REPO_DIR/secrets.env"
envsubst < "$REPO_DIR/etc/hostapd.conf.template" > /etc/hostapd/hostapd.conf

echo "[3/6] Copying paths..."
cp "$REPO_DIR/etc/dnsmasq.conf"               /etc/dnsmasq.conf
cp "$REPO_DIR/etc/dnscrypt-proxy.toml"        /etc/dnscrypt-proxy/dnscrypt-proxy.toml
cp "$REPO_DIR/etc/nftables.nft"               /etc/nftables.nft
cp "$REPO_DIR/etc/logrotate.d/dnscrypt-proxy" /etc/logrotate.d/dnscrypt-proxy

curl -o /etc/dnscrypt-proxy/blocked-names.txt \
  https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/pro.txt

# Check wlan0 state.
echo "[4/6] Checking wlan0..."
if ip link show wlan0 | grep -q "DOWN"; then
    echo "wlan0 down, setting up..."
    ip link set wlan0 up
else
    echo "wlan0 up"
fi

# Static IP.
cat >> /etc/network/interfaces << EOF

auto wlan0
iface wlan0 inet static
    address 192.168.2.1
    netmask 255.255.255.0
EOF
rc-update add networking boot

# The services will start automatically.
echo "[5/6] Enabling services..."
for svc in hostapd dnsmasq dnscrypt-proxy nftables; do
    rc-update add "$svc" default
done

echo "[6/6] Launching services..."
rc-service nftables start
rc-service dnscrypt-proxy start
rc-service dnsmasq start
rc-service hostapd start

# Logrotate.
rc-update add crond default
rc-service crond start

echo "All done. Do: iw dev wlan0 info"
