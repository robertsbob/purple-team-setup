#!/bin/bash
# setup.sh — Grizzy's Gourmet Grub target machine setup
# Run as root on a fresh Ubuntu 24.04 LTS Hetzner VPS
# This script installs all services, deploys the application,
# and configures everything needed for the environment.
# At the end it deletes itself and the cloned repo.

set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[*]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
prompt()  { echo -e "${YELLOW}[?]${NC} $1"; }

trap 'echo -e "\n${RED}[ERROR]${NC} Script aborted at line $LINENO — command: $BASH_COMMAND" >&2' ERR

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
[[ -z "$WG_SERVER_IP" ]] && { echo "ERROR: WireGuard server IP is required." >&2; exit 1; }

prompt "Enter the WireGuard server public key (printed at end of setup_wazuh.sh output):"
read -r WG_SERVER_PUBKEY
[[ -z "$WG_SERVER_PUBKEY" ]] && { echo "ERROR: WireGuard server public key is required." >&2; exit 1; }

prompt "Enter the WireGuard private key for this machine (printed at end of setup_wazuh.sh output):"
read -r WG_PRIV_KEY
[[ -z "$WG_PRIV_KEY" ]] && { echo "ERROR: WireGuard private key is required." >&2; exit 1; }

prompt "Enter the OpenRouter API key (leave blank to skip — AI agent will show unavailable message):"
read -r OPENROUTER_KEY

prompt "Enable graphical desktop and VNC access for blue team? (y/n):"
read -r ENABLE_GUI

if [[ "$ENABLE_GUI" =~ ^[Yy] ]]; then
    prompt "Enter a VNC password for the blue team GUI access (min 6 chars):"
    read -r VNC_PASS
fi

prompt "Enter the Wazuh manager IP (same as WireGuard server, usually 10.10.0.1):"
read -r WAZUH_IP; WAZUH_IP="${WAZUH_IP:-10.10.0.1}"

echo ""
info "Starting setup..."

# Sync clock — stale clock after VM snapshot restore causes apt to reject repo timestamps
info "Syncing system clock..."
timedatectl set-ntp true
systemctl restart systemd-timesyncd 2>/dev/null || true
for i in $(seq 1 12); do
    timedatectl status | grep -q "synchronized: yes" && break
    sleep 5
done
timedatectl status | grep -q "synchronized: yes" \
    || warn "Clock may not be fully synced — continuing anyway"

# ── System update ────────────────────────────────────────────────────────────
info "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get upgrade -y -q

# ── Install packages ─────────────────────────────────────────────────────────
info "Installing packages..."
apt-get install -y -q \
    nginx \
    php8.3 php8.3-fpm php8.3-mysql php8.3-curl php8.3-mbstring php8.3-xml php8.3-zip \
    mysql-server \
    redis-server \
    vsftpd \
    python3 python3-pip python3-venv python3-pil fonts-dejavu-core \
    gcc \
    wireguard \
    iptables iptables-persistent \
    openssh-server \
    fail2ban \
    curl wget git jq \
    net-tools \
    auditd

if [[ "$ENABLE_GUI" =~ ^[Yy] ]]; then
    info "Installing desktop and VNC packages..."
    apt-get install -y -q \
        tigervnc-standalone-server tigervnc-common \
        xfce4 xfce4-terminal
fi

# ── Blue team admin user ─────────────────────────────────────────────────────
info "Creating blue team admin user..."
useradd -m -s /bin/bash grizzyadmin 2>/dev/null || true
usermod -aG sudo grizzyadmin

# Generate SSH key for blue team
mkdir -p /root/setup_output
ssh-keygen -t ed25519 -f /root/setup_output/blue_team_ssh_key -N "" -C "blueteam@grizzygourmetgrub"
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
MaxAuthTries 6
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
bantime  = 10
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
# Remove systemd sandbox restrictions so redis can write to arbitrary paths
mkdir -p /etc/systemd/system/redis-server.service.d
cat > /etc/systemd/system/redis-server.service.d/exercise.conf << 'EOF'
[Service]
PrivateTmp=false
ProtectSystem=false
EOF
systemctl daemon-reload
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

# Generate product food images (styled cards with gradient + name)
python3 - << 'PYEOF'
from PIL import Image, ImageDraw, ImageFont
import os

def hex2rgb(h):
    return tuple(int(h[i:i+2], 16) for i in (1, 3, 5))

def make_card(path, title, subtitle, top_hex, bot_hex):
    W, H = 400, 300
    top, bot = hex2rgb(top_hex), hex2rgb(bot_hex)
    img = Image.new('RGB', (W, H))
    draw = ImageDraw.Draw(img)
    # Vertical gradient
    for y in range(H):
        t = y / (H - 1)
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        draw.line([(0, y), (W - 1, y)], fill=c)
    # Subtle diagonal texture lines
    for i in range(-H, W + H, 24):
        draw.line([(i, 0), (i + H, H)], fill=tuple(min(255, c + 18) for c in bot), width=1)
    # Dark band across lower third for legibility
    band_y = H * 3 // 5
    region = img.crop((0, band_y, W, H))
    dark   = Image.new('RGB', (W, H - band_y), (0, 0, 0))
    img.paste(Image.blend(region, dark, 0.62), (0, band_y))
    draw = ImageDraw.Draw(img)
    # Try system bold fonts
    font_title = font_sub = None
    for p in [
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
        '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
        '/usr/share/fonts/truetype/ubuntu/Ubuntu-B.ttf',
        '/usr/share/fonts/truetype/freefont/FreeSansBold.ttf',
    ]:
        if os.path.exists(p):
            font_title = ImageFont.truetype(p, 26)
            font_sub   = ImageFont.truetype(p, 13)
            break
    if font_title is None:
        font_title = font_sub = ImageFont.load_default()
    # Title centred in dark band
    tb = draw.textbbox((0, 0), title, font=font_title)
    tx = (W - (tb[2] - tb[0])) // 2
    ty = band_y + 18
    draw.text((tx + 1, ty + 1), title,    fill=(0, 0, 0),       font=font_title)
    draw.text((tx,     ty),     title,    fill=(255, 255, 255),  font=font_title)
    # Subtitle (prep time / serves)
    sb = draw.textbbox((0, 0), subtitle, font=font_sub)
    sx = (W - (sb[2] - sb[0])) // 2
    sy = ty + (tb[3] - tb[1]) + 8
    draw.text((sx, sy), subtitle, fill=(210, 210, 210), font=font_sub)
    img.save(path, 'JPEG', quality=88)

dest = '/var/www/grizzy/public/assets/food'
os.makedirs(dest, exist_ok=True)

cards = [
    ('shakshuka.jpg',  'Smoky Shakshuka Kit',          'Vegetarian  •  25 mins  •  Serves 2',  '#D4622A', '#6B2000'),
    ('lamb_stew.jpg',  'Peak District Lamb Stew',      'Meat  •  2.5 hrs  •  Serves 2',        '#8B5520', '#3A1800'),
    ('thai_curry.jpg', 'Thai Green Curry',              'Meat  •  30 mins  •  Serves 2',        '#4A8A1A', '#1A4800'),
    ('aubergine.jpg',  'Roasted Aubergine Pasta',       'Vegetarian  •  35 mins  •  Serves 2',  '#7030A0', '#2A0848'),
    ('tikka.jpg',      'Paneer Tikka Masala',           'Vegetarian  •  40 mins  •  Serves 2',  '#C84818', '#600800'),
    ('salmon.jpg',     'Harissa Salmon Tray Bake',      'Fish  •  25 mins  •  Serves 2',        '#D07040', '#701800'),
    ('burger.jpg',     'Sheffield Street Burger',       'Meat  •  30 mins  •  Serves 2',        '#8B5010', '#402000'),
    ('risotto.jpg',    'Mushroom Risotto',              'Vegetarian  •  40 mins  •  Serves 2',  '#907050', '#403020'),
    ('jackfruit.jpg',  'BBQ Pulled Jackfruit Tacos',    'Vegan  •  45 mins  •  Serves 2',       '#A06820', '#502800'),
    ('fishchips.jpg',  'Classic Fish & Chips',          'Fish  •  35 mins  •  Serves 2',        '#C8A010', '#605000'),
    ('dahl.jpg',       'Vegan Dahl',                    'Vegan  •  30 mins  •  Serves 2',       '#C87020', '#603000'),
    ('steak.jpg',      'Steak Night Kit',               'Meat  •  25 mins  •  Serves 2',        '#902020', '#400000'),
    ('default.jpg',    "Grizzy's Gourmet Grub",         'Fresh  •  Delivered weekly',           '#2A5A30', '#102018'),
]
for filename, title, subtitle, top, bot in cards:
    make_card(os.path.join(dest, filename), title, subtitle, top, bot)
    print(f'  {filename}')
PYEOF

# Inject OpenRouter key into .env
sed -i "s|^OPENROUTER_KEY=.*|OPENROUTER_KEY=$OPENROUTER_KEY|" /var/www/grizzy/public/.env

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

# gary set this to 777 so the web app can write to it during deploys
chmod 777 /opt/grizzy/scripts/cleanup.sh

# web app needs write access to scripts dir for deploy process
chown -R www-data:www-data /opt/grizzy/scripts
chmod 775 /opt/grizzy/scripts

# ── Compile and install backup utility ──────────────────────────────────────
info "Compiling and installing backup utility..."
gcc -o /usr/local/bin/grizzbackup "$REPO_DIR/target/scripts/backup.c"
chmod 4755 /usr/local/bin/grizzbackup
info "Backup utility installed."

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
venv/bin/pip install -r requirements.txt
# Also install to system python3 — scripts invoked via os.system() use system interpreter, not venv
# --break-system-packages required on Ubuntu 24.04 (PEP 668)
pip3 install mysql-connector-python -q --break-system-packages
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
# Pass OpenRouter key and model as environment variables to PHP-FPM
OPENROUTER_MODEL=$(grep '^OPENROUTER_MODEL=' /var/www/grizzy/public/.env | cut -d= -f2)
cat >> /etc/php/8.3/fpm/pool.d/www.conf << EOF
env[OPENROUTER_KEY] = "$OPENROUTER_KEY"
env[OPENROUTER_MODEL] = "$OPENROUTER_MODEL"
EOF
systemctl restart php8.3-fpm

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
systemctl restart wg-quick@wg0

# ── Firewall ─────────────────────────────────────────────────────────────────
info "Applying firewall rules..."
bash "$REPO_DIR/target/configs/iptables.sh"

# ── VNC setup (optional) ─────────────────────────────────────────────────────
if [[ "$ENABLE_GUI" =~ ^[Yy] ]]; then
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
    info "VNC configured on port 5901."
fi

# ── Wazuh agent ──────────────────────────────────────────────────────────────
info "Installing Wazuh agent..."
curl -sSf https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
    > /etc/apt/sources.list.d/wazuh.list
apt-get update -q
WAZUH_MANAGER="$WAZUH_IP" apt-get install -y -q wazuh-agent

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
if [[ "$ENABLE_GUI" =~ ^[Yy] ]]; then
echo "  VNC password:       $VNC_PASS  (port 5901)"
fi
echo "  Wazuh agent:        reporting to $WAZUH_IP"
echo ""
echo -e "${GREEN}------------------------------------------------------------${NC}"
echo -e "${GREEN}  Blue team SSH private key${NC}"
echo -e "${GREEN}  Copy this to the Wazuh server or distribute to blue team${NC}"
echo -e "${GREEN}------------------------------------------------------------${NC}"
cat /root/setup_output/blue_team_ssh_key
echo -e "${GREEN}------------------------------------------------------------${NC}"
echo ""
echo "  Docs left on machine:"
echo "    /opt/grizzy/DEV_SERVICES.md"
echo "    /root/WAZUH.md"
echo ""
warn "Deleting cloned repository..."
rm -rf "$REPO_DIR"
echo -e "${GREEN}[+] Done. Repository deleted.${NC}"
