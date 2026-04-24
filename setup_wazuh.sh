#!/bin/bash
# setup_wazuh.sh — Wazuh SIEM + WireGuard VPN server setup
# Run as root on a fresh Ubuntu 24.04 LTS Hetzner VPS
# This machine acts as both the Wazuh manager and WireGuard VPN server.

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()   { echo -e "${GREEN}[*]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
prompt() { echo -e "${YELLOW}[?]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then echo "Run as root." && exit 1; fi

info "Wazuh SIEM + WireGuard VPN Server Setup"
echo "========================================="

prompt "Enter this machine's IP address (public or local — used as the WireGuard endpoint):"
read -r PUBLIC_IP

echo ""
info "Starting setup..."

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl wget gnupg2 wireguard iptables iptables-persistent net-tools

# ── WireGuard VPN setup ──────────────────────────────────────────────────────
info "Setting up WireGuard VPN server..."

mkdir -p /etc/wireguard
mkdir -p /root/wg_configs_output

# Generate keys for all peers
SERVER_PRIV=$(wg genkey)
SERVER_PUB=$(echo "$SERVER_PRIV" | wg pubkey)

TARGET_PRIV=$(wg genkey)
TARGET_PUB=$(echo "$TARGET_PRIV" | wg pubkey)

RED_PRIV=$(wg genkey)
RED_PUB=$(echo "$RED_PRIV" | wg pubkey)

BLUE_PRIV=$(wg genkey)
BLUE_PUB=$(echo "$BLUE_PRIV" | wg pubkey)

# Detect primary network interface
PRIMARY_IF=$(ip route | grep default | awk '{print $5}' | head -1)
info "Primary interface: $PRIMARY_IF"

# Write server config
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
Address    = 10.10.0.1/24
ListenPort = 51820
PrivateKey = $SERVER_PRIV

PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $PRIMARY_IF -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $PRIMARY_IF -j MASQUERADE

# Target machine
[Peer]
PublicKey  = $TARGET_PUB
AllowedIPs = 10.10.0.2/32

# Red team player
[Peer]
PublicKey  = $RED_PUB
AllowedIPs = 10.10.0.10/32

# Blue team player
[Peer]
PublicKey  = $BLUE_PUB
AllowedIPs = 10.10.0.20/32
EOF
chmod 600 /etc/wireguard/wg0.conf

# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-wireguard.conf
sysctl -p /etc/sysctl.d/99-wireguard.conf

systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

# Write target machine config
cat > /root/wg_configs_output/target_wg0.conf << EOF
[Interface]
Address    = 10.10.0.2/24
PrivateKey = $TARGET_PRIV

[Peer]
PublicKey  = $SERVER_PUB
Endpoint   = ${PUBLIC_IP}:51820
AllowedIPs = 10.10.0.0/24
PersistentKeepalive = 25
EOF

# Write red team config
cat > /root/wg_configs_output/redteam_player.conf << EOF
[Interface]
Address    = 10.10.0.10/24
PrivateKey = $RED_PRIV

[Peer]
PublicKey  = $SERVER_PUB
Endpoint   = ${PUBLIC_IP}:51820
AllowedIPs = 10.10.0.0/24
PersistentKeepalive = 25
EOF

# Write blue team config
cat > /root/wg_configs_output/blueteam_player.conf << EOF
[Interface]
Address    = 10.10.0.20/24
PrivateKey = $BLUE_PRIV

[Peer]
PublicKey  = $SERVER_PUB
Endpoint   = ${PUBLIC_IP}:51820
AllowedIPs = 10.10.0.0/24
PersistentKeepalive = 25
EOF

echo ""
info "WireGuard configs written to /root/wg_configs_output/"
info "Target machine public key: $TARGET_PUB"
info "  → You will need this when running setup.sh on the target."
echo ""

# ── Wazuh manager install ────────────────────────────────────────────────────
info "Installing Wazuh manager (this takes several minutes)..."

curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
    > /etc/apt/sources.list.d/wazuh.list
apt-get update -qq
apt-get install -y wazuh-manager

# ── Install Wazuh indexer + dashboard (single-node) ─────────────────────────
info "Installing Wazuh indexer..."
apt-get install -y wazuh-indexer

info "Installing Wazuh dashboard..."
apt-get install -y wazuh-dashboard

# Run Wazuh installer certificates generation
info "Generating Wazuh certificates..."
rm -rf ./wazuh-certificates ./wazuh-certificates.tar
curl -sO https://packages.wazuh.com/4.7/wazuh-certs-tool.sh
curl -sO https://packages.wazuh.com/4.7/config.yml

# Patch config.yml for single-node with this server's IP
cat > config.yml << EOF
nodes:
  indexer:
    - name: node-1
      ip: "10.10.0.1"
  server:
    - name: wazuh-1
      ip: "10.10.0.1"
  dashboard:
    - name: dashboard
      ip: "10.10.0.1"
EOF

bash wazuh-certs-tool.sh -A

# Locate generated certs — tool outputs either a tar or a directory depending on version
if [ -f ./wazuh-certificates.tar ]; then
    mkdir -p ./wazuh-certs-work
    tar -xf ./wazuh-certificates.tar -C ./wazuh-certs-work
    CERTS=$(find ./wazuh-certs-work -name "root-ca.pem" -exec dirname {} \; | head -1)
elif [ -d ./wazuh-certificates ]; then
    CERTS=./wazuh-certificates
else
    echo "ERROR: wazuh-certs-tool.sh produced no output. Check logs above." && exit 1
fi
info "Certificates found at: $CERTS"

# Deploy indexer certificates
mkdir -p /etc/wazuh-indexer/certs
cp "$CERTS/node-1.pem"     /etc/wazuh-indexer/certs/indexer.pem
cp "$CERTS/node-1-key.pem" /etc/wazuh-indexer/certs/indexer-key.pem
cp "$CERTS/admin.pem"      /etc/wazuh-indexer/certs/admin.pem
cp "$CERTS/admin-key.pem"  /etc/wazuh-indexer/certs/admin-key.pem
cp "$CERTS/root-ca.pem"    /etc/wazuh-indexer/certs/root-ca.pem
chmod 500 /etc/wazuh-indexer/certs
chmod 400 /etc/wazuh-indexer/certs/*
chown -R wazuh-indexer:wazuh-indexer /etc/wazuh-indexer/certs

# Deploy filebeat certificates (used by wazuh-manager to ship to indexer)
mkdir -p /etc/filebeat/certs
cp "$CERTS/wazuh-1.pem"     /etc/filebeat/certs/filebeat.pem
cp "$CERTS/wazuh-1-key.pem" /etc/filebeat/certs/filebeat-key.pem
cp "$CERTS/root-ca.pem"     /etc/filebeat/certs/root-ca.pem
chmod 500 /etc/filebeat/certs
chmod 400 /etc/filebeat/certs/*
chown -R root:root /etc/filebeat/certs

# Deploy dashboard certificates
mkdir -p /etc/wazuh-dashboard/certs
cp "$CERTS/dashboard.pem"     /etc/wazuh-dashboard/certs/dashboard.pem
cp "$CERTS/dashboard-key.pem" /etc/wazuh-dashboard/certs/dashboard-key.pem
cp "$CERTS/root-ca.pem"       /etc/wazuh-dashboard/certs/root-ca.pem
chmod 500 /etc/wazuh-dashboard/certs
chmod 400 /etc/wazuh-dashboard/certs/*
chown -R wazuh-dashboard:wazuh-dashboard /etc/wazuh-dashboard/certs

# Configure indexer bind address
NODE_IP="10.10.0.1"
sed -i "s/0.0.0.0/$NODE_IP/" /etc/wazuh-indexer/opensearch.yml

systemctl daemon-reload
systemctl enable wazuh-indexer
systemctl start wazuh-indexer

info "Waiting for indexer to be ready (this takes 2-4 minutes)..."
TRIES=0
until curl -sk -o /dev/null -w "%{http_code}" https://10.10.0.1:9200 | grep -qE "^[0-9]"; do
    TRIES=$((TRIES + 1))
    if [ $TRIES -ge 48 ]; then
        warn "Indexer did not respond after 4 minutes — continuing anyway"
        break
    fi
    sleep 5
done
# Give it 10 more seconds to fully settle before running security init
sleep 10
info "Running indexer security initialisation..."
/usr/share/wazuh-indexer/bin/indexer-security-init.sh || warn "Security init returned non-zero — may already be initialised"

# Configure manager
sed -i "s/<address>.*<\/address>/<address>0.0.0.0<\/address>/" /var/ossec/etc/ossec.conf

systemctl enable wazuh-manager
systemctl start wazuh-manager

# ── Install custom Wazuh rules ───────────────────────────────────────────────
info "Installing custom Wazuh rules..."

cat > /var/ossec/etc/rules/grizzy_rules.xml << 'WAZUHRULES'
<!-- Grizzy's Gourmet Grub — Custom Wazuh Rules -->
<group name="grizzy,web,">

  <!-- Web scanner / enumeration -->
  <rule id="100001" level="10" frequency="20" timeframe="60">
    <if_matched_sid>31101</if_matched_sid>
    <same_source_ip/>
    <description>Possible web directory enumeration from $(srcip)</description>
    <group>web,scanning</group>
  </rule>

  <!-- Sensitive file access -->
  <rule id="100002" level="9">
    <if_sid>31100</if_sid>
    <url>\.env|\.git|\.bak|\.sql|\.conf|\.ini|\.log|phpinfo|backup|dump</url>
    <description>Request for potentially sensitive file: $(url)</description>
    <group>web,info-disclosure</group>
  </rule>

  <!-- SQL injection patterns -->
  <rule id="100003" level="12">
    <if_sid>31100</if_sid>
    <url>union.*select|select.*from|insert.*into|drop.*table|or.*1.*=.*1|information_schema|%27|%3D</url>
    <description>Possible SQL injection attempt: $(url)</description>
    <group>web,sqli,attack</group>
  </rule>

  <!-- XSS patterns -->
  <rule id="100004" level="10">
    <if_sid>31100</if_sid>
    <url>&lt;script|javascript:|onerror=|onload=|%3Cscript|alert\(|document\.cookie</url>
    <description>Possible XSS attempt in request: $(url)</description>
    <group>web,xss,attack</group>
  </rule>

  <!-- File upload -->
  <rule id="100005" level="7">
    <if_sid>31100</if_sid>
    <url>/account\.php|/upload</url>
    <match>POST</match>
    <description>File upload request to $(url)</description>
    <group>web,upload</group>
  </rule>

  <!-- New file in uploads -->
  <rule id="100006" level="12">
    <if_sid>554</if_sid>
    <field name="file">/var/www/grizzy/public/uploads</field>
    <description>New file added to web uploads directory: $(file)</description>
    <group>fim,web,upload</group>
  </rule>

  <!-- SSH brute force -->
  <rule id="100007" level="14" frequency="5" timeframe="60">
    <if_matched_sid>5716</if_matched_sid>
    <same_source_ip/>
    <description>SSH brute force from $(srcip)</description>
    <group>ssh,brute_force,attack</group>
  </rule>

  <!-- FTP login failure -->
  <rule id="100008" level="6">
    <decoded_as>vsftpd</decoded_as>
    <match>FAIL LOGIN</match>
    <description>FTP login failure from $(srcip)</description>
    <group>ftp,authentication</group>
  </rule>

  <!-- FTP brute force -->
  <rule id="100009" level="12" frequency="5" timeframe="60">
    <if_matched_sid>100008</if_matched_sid>
    <same_source_ip/>
    <description>FTP brute force from $(srcip)</description>
    <group>ftp,brute_force,attack</group>
  </rule>

  <!-- Sudo execution -->
  <rule id="100010" level="8">
    <if_sid>5401</if_sid>
    <description>Sudo command executed: $(command)</description>
    <group>sudo,privilege</group>
  </rule>

  <!-- Sudo by unexpected user -->
  <rule id="100011" level="13">
    <if_sid>5401</if_sid>
    <user>^(?!grizzyadmin$)</user>
    <description>Sudo by unexpected user $(user): $(command)</description>
    <group>sudo,privilege,suspicious</group>
  </rule>

  <!-- Cron job modified -->
  <rule id="100013" level="12">
    <if_sid>550</if_sid>
    <field name="file">/etc/cron.d</field>
    <description>Cron job modified: $(file)</description>
    <group>fim,cron,suspicious</group>
  </rule>

  <!-- Sudoers modified -->
  <rule id="100014" level="15">
    <if_sid>550</if_sid>
    <field name="file">/etc/sudoers</field>
    <description>sudoers modified: $(file)</description>
    <group>fim,sudo,privilege,critical</group>
  </rule>

  <!-- Reverse shell indicators -->
  <rule id="100015" level="15">
    <if_sid>531</if_sid>
    <match>bash -i|nc -e|python.*-c.*import socket|/dev/tcp|ncat|mkfifo</match>
    <description>Possible reverse shell process detected</description>
    <group>attack,reverse_shell,critical</group>
  </rule>

  <!-- 5xx spike -->
  <rule id="100016" level="10" frequency="50" timeframe="120">
    <if_matched_sid>31103</if_matched_sid>
    <description>High rate of web 5xx errors</description>
    <group>web,availability</group>
  </rule>

  <!-- Redis from non-localhost -->
  <rule id="100017" level="11">
    <decoded_as>redis</decoded_as>
    <match>Accepted</match>
    <description>Redis connection from non-localhost</description>
    <group>redis,suspicious</group>
  </rule>

  <!-- AI agent endpoint -->
  <rule id="100018" level="5">
    <if_sid>31100</if_sid>
    <url>/api/agent\.php</url>
    <match>POST</match>
    <description>AI agent endpoint accessed</description>
    <group>web,agent</group>
  </rule>

  <!-- Shell metacharacters in request -->
  <rule id="100019" level="13">
    <if_sid>31100</if_sid>
    <url>%3B|%7C|/bin/bash|/bin/sh|cmd=|exec=|shell_exec|passthru</url>
    <description>Shell metacharacters in web request — possible command injection</description>
    <group>web,cmdi,attack</group>
  </rule>

  <!-- SUID binary execution -->
  <rule id="100020" level="10">
    <if_sid>80700</if_sid>
    <field name="audit.exe">/usr/local/bin/grizzbackup</field>
    <description>SUID backup binary executed by $(audit.auid)</description>
    <group>audit,suid,suspicious</group>
  </rule>

</group>
WAZUHRULES

systemctl restart wazuh-manager

# ── Dashboard startup ─────────────────────────────────────────────────────────
info "Starting Wazuh dashboard (may take a minute to become ready)..."
systemctl enable wazuh-dashboard
systemctl start wazuh-dashboard
# Dashboard takes ~90s to fully load after start — this is normal
sleep 15

# ── Firewall for Wazuh server ────────────────────────────────────────────────
info "Applying firewall rules for Wazuh server..."
iptables -F INPUT
iptables -P INPUT DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p udp --dport 51820 -j ACCEPT   # WireGuard
iptables -A INPUT -i wg0 -j ACCEPT                   # All WireGuard peers
iptables-save > /etc/iptables/rules.v4

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Wazuh + WireGuard setup complete!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "${GREEN}  Wazuh dashboard:${NC}  https://10.10.0.1"
echo -e "${GREEN}  Wazuh login:${NC}      admin / SecretPassword  (change after first login)"
echo ""
echo -e "${GREEN}  WireGuard configs written to:${NC}"
echo "    /root/wg_configs_output/target_wg0.conf      ← copy to target machine"
echo "    /root/wg_configs_output/redteam_player.conf  ← give to red team"
echo "    /root/wg_configs_output/blueteam_player.conf ← give to blue team"
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Values to enter when running setup.sh on the target${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo "  Prompt: Target WireGuard IP"
echo "  Answer: 10.10.0.2  (just press Enter for default)"
echo ""
echo "  Prompt: WireGuard server public IP"
echo "  Answer: $PUBLIC_IP"
echo ""
echo "  Prompt: WireGuard server public key"
echo "  Answer: $SERVER_PUB"
echo ""
echo "  Prompt: WireGuard private key for this machine"
echo "  Answer: $TARGET_PRIV"
echo ""
echo "  Prompt: OpenRouter API key"
echo "  Answer: (your key — obtain from openrouter.ai, or leave blank)"
echo ""
echo "  Prompt: Enable GUI / VNC?"
echo "  Answer: y or n (your choice)"
echo ""
echo "  Prompt: Wazuh manager IP"
echo "  Answer: 10.10.0.1  (just press Enter for default)"
echo ""
echo -e "${YELLOW}  Tip: the target WireGuard config is also pre-written at:${NC}"
echo "       /root/wg_configs_output/target_wg0.conf"
echo "       (contains the private key above — copy it to the target machine)"
