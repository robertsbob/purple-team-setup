#!/bin/bash
# setup.sh — Grizzy's Gourmet Grub target machine setup
# Run as root on a fresh Ubuntu 22.04 LTS Hetzner VPS
# This script installs all services, deploys the application,
# and configures all misconfigurations and vulnerabilities.
# At the end it deletes itself and the cloned repo.

set -e
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[*]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
prompt()  { echo -e "${YELLOW}[?]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    echo "Run as root." && exit 1
fi

info "Grizzy's Gourmet Grub — Target Machine Setup"
echo "================================================"

# ── Collect required inputs ──────────────────────────────────────────────────
prompt "Enter this machine's WireGuard IP to receive from the VPN server (default: 10.10.0.2):"
read -r TARGET_WG_IP; TARGET_WG_IP="${TARGET_WG_IP:-10.10.0.2}"

prompt "Enter the WireGuard server public IP (Wazuh machine):"
read -r WG_SERVER_IP

prompt "Enter the WireGuard server public key (from generate_configs.sh output):"
read -r WG_SERVER_PUBKEY

prompt "Enter the WireGuard private key for this machine (from generate_configs.sh output):"
read -r WG_PRIV_KEY

prompt "Enter the OpenRouter API key (leave blank to skip — AI agent will show unavailable message):"
read -r OPENROUTER_KEY

prompt "Enter a VNC password for the blue team GUI access (min 6 chars):"
read -r VNC_PASS

prompt "Enter the Wazuh manager IP (same as WireGuard server, usually 10.10.0.1):"
read -r WAZUH_IP; WAZUH_IP="${WAZUH_IP:-10.10.0.1}"

echo ""
info "Starting setup..."

# ── System update ────────────────────────────────────────────────────────────
info "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

# ── Install packages ─────────────────────────────────────────────────────────
info "Installing packages..."
apt-get install -y -qq \
    nginx \
    php8.1 php8.1-fpm php8.1-mysql php8.1-curl php8.1-mbstring php8.1-xml php8.1-zip \
    mysql-server \
    redis-server \
    vsftpd \
    python3 python3-pip python3-venv \
    gcc \
    wireguard \
    iptables iptables-persistent \
    openssh-server \
    tigervnc-standalone-server tigervnc-common \
    xfce4 xfce4-terminal \
    fail2ban \
    curl wget git jq \
    net-tools \
    auditd

# ── Blue team admin user ─────────────────────────────────────────────────────
info "Creating blue team admin user..."
useradd -m -s /bin/bash grizzyadmin 2>/dev/null || true
usermod -aG sudo grizzyadmin

# Generate SSH key for blue team
mkdir -p /root/setup_output
ssh-keygen -t ed25519 -f /root/setup_output/blue_team_ssh_key -N "" -C "blueteam@grizzygourmetgrub" 2>/dev/null
mkdir -p /home/grizzyadmin/.ssh
cat /root/setup_output/blue_team_ssh_key.pub >> /home/grizzyadmin/.ssh/authorized_keys
chmod 700 /home/grizzyadmin/.ssh
chmod 600 /home/grizzyadmin/.ssh/authorized_keys
chown -R grizzyadmin:grizzyadmin /home/grizzyadmin/.ssh
info "Blue team SSH key saved to /root/setup_output/blue_team_ssh_key"

# ── SSH hardening ────────────────────────────────────────────────────────────
info "Hardening SSH..."
cat > /etc/ssh/sshd_config.d/99-hardened.conf << 'EOF'
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
X11Forwarding no
AllowUsers grizzyadmin
MaxAuthTries 3
EOF
systemctl restart ssh

# ── fail2ban ─────────────────────────────────────────────────────────────────
info "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled = true
port    = ssh
filter  = sshd
maxretry = 5
bantime  = 600
findtime = 300
EOF
systemctl enable fail2ban
systemctl restart fail2ban

# ── Application user: gary ───────────────────────────────────────────────────
info "Creating application user gary..."
useradd -m -s /bin/bash gary 2>/dev/null || true
echo "gary:grizzy2024" | chpasswd
usermod -aG www-data gary

# ── MySQL setup ──────────────────────────────────────────────────────────────
info "Configuring MySQL..."
systemctl enable mysql
systemctl start mysql

# Allow remote connections (bind to all interfaces)
sed -i 's/^bind-address\s*=.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf

# Enable query logging (for Wazuh)
cat >> /etc/mysql/mysql.conf.d/mysqld.cnf << 'EOF'
general_log = 1
general_log_file = /var/log/mysql/mysql.log
log_error = /var/log/mysql/error.log
EOF

systemctl restart mysql

mysql < "$REPO_DIR/target/configs/mysql_setup.sql"
info "Database created and seeded."

# ── Redis setup ──────────────────────────────────────────────────────────────
info "Configuring Redis..."
cp "$REPO_DIR/target/configs/redis.conf" /etc/redis/redis.conf
chown redis:redis /etc/redis/redis.conf
systemctl enable redis-server
systemctl restart redis-server

# ── FTP setup ────────────────────────────────────────────────────────────────
info "Configuring vsftpd..."
cp "$REPO_DIR/target/configs/vsftpd.conf" /etc/vsftpd.conf

# Add gary to FTP userlist
echo "gary" > /etc/vsftpd.userlist

# Gary's FTP home is set to web assets dir (no chroot)
mkdir -p /var/www/grizzy/public/assets/food

# Enable vsftpd logging
cat >> /etc/vsftpd.conf << 'EOF'
xferlog_file=/var/log/vsftpd.log
vsftpd_log_file=/var/log/vsftpd.log
log_ftp_protocol=YES
EOF

systemctl enable vsftpd
systemctl restart vsftpd

# ── Application directories ──────────────────────────────────────────────────
info "Setting up application directories..."
mkdir -p /var/www/grizzy/public/uploads
mkdir -p /var/www/grizzy/public/assets/food
mkdir -p /var/www/grizzy/config
mkdir -p /var/www/grizzy/public/api
mkdir -p /var/www/grizzy/public/partials
mkdir -p /opt/grizzy/scripts
mkdir -p /opt/grizzy/internal
mkdir -p /var/backups/grizzy

# ── Deploy website ───────────────────────────────────────────────────────────
info "Deploying public website..."
cp -r "$REPO_DIR/target/website/public/." /var/www/grizzy/public/
cp -r "$REPO_DIR/target/website/config/." /var/www/grizzy/config/

# Inject OpenRouter key into .env
sed -i "s/^OPENROUTER_KEY=.*/OPENROUTER_KEY=$OPENROUTER_KEY/" /var/www/grizzy/public/.env

# Set ownership
chown -R www-data:www-data /var/www/grizzy
# gary needs write access to web root for FTP uploads
chown -R gary:www-data /var/www/grizzy/public
chmod -R 775 /var/www/grizzy/public
chmod 775 /var/www/grizzy/public/uploads

# ── Deploy scripts ───────────────────────────────────────────────────────────
info "Deploying scripts..."
cp "$REPO_DIR/target/scripts/get_order.py"    /opt/grizzy/scripts/
cp "$REPO_DIR/target/scripts/db_query.sh"     /opt/grizzy/scripts/
cp "$REPO_DIR/target/scripts/export_orders.py" /opt/grizzy/scripts/
cp "$REPO_DIR/target/scripts/cleanup.sh"      /opt/grizzy/scripts/

chmod +x /opt/grizzy/scripts/*.sh
chmod +x /opt/grizzy/scripts/*.py

# INTENTIONAL: cleanup.sh world-writable (privilege escalation vector)
chmod 777 /opt/grizzy/scripts/cleanup.sh

# /opt/grizzy/scripts writable by www-data (for sudo wildcard exploit)
chown -R www-data:www-data /opt/grizzy/scripts
chmod 775 /opt/grizzy/scripts

# ── Compile and install SUID binary ─────────────────────────────────────────
info "Compiling and installing backup utility..."
gcc -o /usr/local/bin/grizzbackup "$REPO_DIR/target/scripts/backup.c"
chmod u+s /usr/local/bin/grizzbackup
chmod 755 /usr/local/bin/grizzbackup
info "SUID binary installed at /usr/local/bin/grizzbackup"

# ── Cron job ─────────────────────────────────────────────────────────────────
info "Installing cron jobs..."
cat > /etc/cron.d/grizzy-cleanup << 'EOF'
*/5 * * * * root /opt/grizzy/scripts/cleanup.sh
EOF
chmod 644 /etc/cron.d/grizzy-cleanup

# ── Internal Flask dashboard ─────────────────────────────────────────────────
info "Deploying internal dashboard..."
cp -r "$REPO_DIR/target/internal/." /opt/grizzy/internal/
chown -R gary:gary /opt/grizzy/internal

cd /opt/grizzy/internal
python3 -m venv venv
venv/bin/pip install -q -r requirements.txt
cd "$REPO_DIR"

# systemd service for internal dashboard
cat > /etc/systemd/system/grizzy-internal.service << 'EOF'
[Unit]
Description=Grizzy Internal Order Dashboard
After=network.target mysql.service

[Service]
User=gary
WorkingDirectory=/opt/grizzy/internal
ExecStart=/opt/grizzy/internal/venv/bin/python3 /opt/grizzy/internal/app.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable grizzy-internal
systemctl start grizzy-internal

# ── nginx configuration ──────────────────────────────────────────────────────
info "Configuring nginx..."
rm -f /etc/nginx/sites-enabled/default
cp "$REPO_DIR/target/configs/nginx_grizzy.conf" /etc/nginx/sites-available/grizzy
ln -sf /etc/nginx/sites-available/grizzy /etc/nginx/sites-enabled/grizzy

systemctl enable nginx
systemctl restart nginx

# ── PHP-FPM config ───────────────────────────────────────────────────────────
info "Configuring PHP..."
# Pass OpenRouter key as environment variable
cat >> /etc/php/8.1/fpm/pool.d/www.conf << EOF
env[OPENROUTER_KEY] = "$OPENROUTER_KEY"
EOF
systemctl restart php8.1-fpm

# ── Sudo misconfiguration ────────────────────────────────────────────────────
info "Configuring sudo rules..."
cat > /etc/sudoers.d/grizzy-scripts << 'EOF'
# Allow www-data to run grizzy python scripts as root
# gary: needed for the deploy process
www-data ALL=(root) NOPASSWD: /usr/bin/python3 /opt/grizzy/scripts/*.py
EOF
chmod 440 /etc/sudoers.d/grizzy-scripts

# grizzyadmin gets full sudo
echo "grizzyadmin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/grizzyadmin
chmod 440 /etc/sudoers.d/grizzyadmin

# ── WireGuard setup ──────────────────────────────────────────────────────────
info "Configuring WireGuard..."
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
Address    = ${TARGET_WG_IP}/24
PrivateKey = ${WG_PRIV_KEY}

[Peer]
PublicKey  = ${WG_SERVER_PUBKEY}
Endpoint   = ${WG_SERVER_IP}:51820
AllowedIPs = 10.10.0.0/24
PersistentKeepalive = 25
EOF
chmod 600 /etc/wireguard/wg0.conf
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# ── Firewall ─────────────────────────────────────────────────────────────────
info "Applying firewall rules..."
bash "$REPO_DIR/target/configs/iptables.sh"

# ── VNC setup ────────────────────────────────────────────────────────────────
info "Configuring VNC for blue team..."
mkdir -p /home/grizzyadmin/.vnc
echo "$VNC_PASS" | tigervncpasswd -f > /home/grizzyadmin/.vnc/passwd
chmod 600 /home/grizzyadmin/.vnc/passwd
chown -R grizzyadmin:grizzyadmin /home/grizzyadmin/.vnc

cat > /home/grizzyadmin/.vnc/xstartup << 'EOF'
#!/bin/bash
export XDG_SESSION_TYPE=x11
exec startxfce4
EOF
chmod +x /home/grizzyadmin/.vnc/xstartup

cat > /etc/systemd/system/vncserver@.service << 'EOF'
[Unit]
Description=TigerVNC server
After=network.target

[Service]
Type=forking
User=grizzyadmin
PAMName=login
PIDFile=/home/grizzyadmin/.vnc/%H:%i.pid
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/vncserver :%i -geometry 1280x800 -depth 24 -localhost no
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable vncserver@1
systemctl start vncserver@1

# ── Wazuh agent ──────────────────────────────────────────────────────────────
info "Installing Wazuh agent..."
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
    > /etc/apt/sources.list.d/wazuh.list
apt-get update -qq
WAZUH_MANAGER="$WAZUH_IP" apt-get install -y -qq wazuh-agent

cp "$REPO_DIR/target/configs/wazuh_ossec.conf" /var/ossec/etc/ossec.conf
sed -i "s/WAZUH_SERVER_IP/$WAZUH_IP/g" /var/ossec/etc/ossec.conf

systemctl daemon-reload
systemctl enable wazuh-agent
systemctl start wazuh-agent

# ── auditd rules ─────────────────────────────────────────────────────────────
info "Configuring auditd..."
cat > /etc/audit/rules.d/grizzy.rules << 'EOF'
-a always,exit -F arch=b64 -S execve -F euid=0 -F auid!=0 -k priv_exec
-w /usr/local/bin/grizzbackup -p x -k suid_exec
-w /etc/sudoers -p wa -k sudoers_change
-w /etc/passwd -p wa -k passwd_change
-w /tmp -p x -k tmp_exec
EOF
systemctl enable auditd
systemctl restart auditd

# ── Copy docs to machine ──────────────────────────────────────────────────────
info "Installing documentation..."
cp "$REPO_DIR/DEV_SERVICES.md"  /opt/grizzy/DEV_SERVICES.md
cp "$REPO_DIR/BLUE_ACCESS.md"   /root/BLUE_ACCESS.md
cp "$REPO_DIR/WAZUH.md"         /root/WAZUH.md

# ── Clean up ──────────────────────────────────────────────────────────────────
info "Cleaning up — removing repo and SYSTEM_ files..."

# Delete SYSTEM_ docs (never leave on machine)
rm -f "$REPO_DIR"/SYSTEM_*.md

# Final output
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo "  WireGuard IP (this machine): $TARGET_WG_IP"
echo "  Blue team SSH key:  /root/setup_output/blue_team_ssh_key"
echo "  VNC password:       $VNC_PASS  (port 5901)"
echo "  Wazuh agent:        reporting to $WAZUH_IP"
echo ""
echo "  Docs left on machine:"
echo "    /opt/grizzy/DEV_SERVICES.md"
echo "    /root/BLUE_ACCESS.md"
echo "    /root/WAZUH.md"
echo ""
warn "Deleting cloned repository..."
rm -rf "$REPO_DIR"
echo -e "${GREEN}[+] Done. Repository deleted.${NC}"
