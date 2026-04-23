#!/bin/bash
# WireGuard configuration generator
# Run on the Wazuh/VPN server to generate all WireGuard configs
# and player .conf files.
#
# Network layout:
#   10.10.0.1  - Wazuh/VPN server (WG server)
#   10.10.0.2  - Target machine
#   10.10.0.10 - Red team player
#   10.10.0.20 - Blue team player

set -e

WG_DIR="/etc/wireguard"
OUT_DIR="./wg_configs_output"
mkdir -p "$OUT_DIR"

echo "[*] Generating WireGuard keys..."

# Server keys
SERVER_PRIV=$(wg genkey)
SERVER_PUB=$(echo "$SERVER_PRIV" | wg pubkey)

# Target machine keys
TARGET_PRIV=$(wg genkey)
TARGET_PUB=$(echo "$TARGET_PRIV" | wg pubkey)

# Red team keys
RED_PRIV=$(wg genkey)
RED_PUB=$(echo "$RED_PRIV" | wg pubkey)

# Blue team keys
BLUE_PRIV=$(wg genkey)
BLUE_PUB=$(echo "$BLUE_PRIV" | wg pubkey)

read -rp "[?] Enter this server's PUBLIC IP address: " SERVER_PUBLIC_IP

echo "[*] Writing server config /etc/wireguard/wg0.conf ..."
cat > "$WG_DIR/wg0.conf" << EOF
[Interface]
Address    = 10.10.0.1/24
ListenPort = 51820
PrivateKey = $SERVER_PRIV

PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Target machine
[Peer]
PublicKey  = $TARGET_PUB
AllowedIPs = 10.10.0.2/32

# Red team
[Peer]
PublicKey  = $RED_PUB
AllowedIPs = 10.10.0.10/32

# Blue team
[Peer]
PublicKey  = $BLUE_PUB
AllowedIPs = 10.10.0.20/32
EOF
chmod 600 "$WG_DIR/wg0.conf"

echo "[*] Writing target machine config..."
cat > "$OUT_DIR/target_wg0.conf" << EOF
[Interface]
Address    = 10.10.0.2/24
PrivateKey = $TARGET_PRIV

[Peer]
PublicKey  = $SERVER_PUB
Endpoint   = ${SERVER_PUBLIC_IP}:51820
AllowedIPs = 10.10.0.0/24
PersistentKeepalive = 25
EOF

echo "[*] Writing red team player config..."
cat > "$OUT_DIR/redteam_player.conf" << EOF
[Interface]
Address    = 10.10.0.10/24
PrivateKey = $RED_PRIV
DNS        = 1.1.1.1

[Peer]
PublicKey  = $SERVER_PUB
Endpoint   = ${SERVER_PUBLIC_IP}:51820
AllowedIPs = 10.10.0.0/24
PersistentKeepalive = 25
EOF

echo "[*] Writing blue team player config..."
cat > "$OUT_DIR/blueteam_player.conf" << EOF
[Interface]
Address    = 10.10.0.20/24
PrivateKey = $BLUE_PRIV
DNS        = 1.1.1.1

[Peer]
PublicKey  = $SERVER_PUB
Endpoint   = ${SERVER_PUBLIC_IP}:51820
AllowedIPs = 10.10.0.0/24
PersistentKeepalive = 25
EOF

echo ""
echo "[+] Done! Files written to $OUT_DIR/"
echo "    - target_wg0.conf   → copy to target machine as /etc/wireguard/wg0.conf"
echo "    - redteam_player.conf  → give to red team player"
echo "    - blueteam_player.conf → give to blue team player"
echo ""
echo "[*] Starting WireGuard server..."
systemctl enable wg-quick@wg0
systemctl start  wg-quick@wg0
echo "[+] WireGuard started. Status:"
wg show
