# Purple Team Exercise — Setup Instructions

## Overview

Two Hetzner machines required:
1. **Wazuh server** — also acts as the WireGuard VPN server
2. **Target machine** — runs the vulnerable application stack

Both machines should be Ubuntu 22.04 LTS. Recommended specs: 4 vCPU, 8 GB RAM, 80 GB SSD.

---

## Step 1 — Create Hetzner machines

Create two servers. Note each machine's public IP.

**Target machine:** Enable the firewall. During setup the firewall script will configure iptables — you do not need Hetzner's cloud firewall for anything beyond basic protection during the setup process.

---

## Step 2 — Set up the Wazuh / VPN server (do this first)

SSH into the Wazuh machine as root and run:

```bash
git clone https://github.com/robertsbob/purple-team-setup.git
cd purple-team-setup
chmod +x setup_wazuh.sh
./setup_wazuh.sh
```

When prompted, enter this machine's **public IP address**.

The script will:
- Install and configure WireGuard VPN
- Generate all WireGuard keys and peer configs
- Install the Wazuh manager, indexer, and dashboard
- Apply firewall rules (WireGuard + established only)

**When it finishes, note these values from the output:**
- WireGuard server public key
- Target machine WireGuard private key

**Collect from the output directory:**
```bash
# Give to red team:
cat /root/wg_configs_output/redteam_player.conf

# Give to blue team:
cat /root/wg_configs_output/blueteam_player.conf
```

---

## Step 3 — Set up the target machine

SSH into the target machine as root and run:

```bash
git clone https://github.com/robertsbob/purple-team-setup.git
cd purple-team-setup
chmod +x setup.sh
./setup.sh
```

You will be prompted for:

| Prompt | Value |
|--------|-------|
| Target WireGuard IP | `10.10.0.2` (press Enter for default) |
| WireGuard server public IP | The Wazuh machine's public IP |
| WireGuard server public key | From Step 2 output |
| WireGuard private key (for this machine) | From Step 2 output |
| OpenRouter API key | Your capped API key (or leave blank to disable AI agent) |
| VNC password | Choose any password (min 6 chars) — give to blue team |
| Wazuh manager IP | `10.10.0.1` (press Enter for default) |

The script will:
- Install all application services (nginx, PHP, MySQL, Redis, FTP, etc.)
- Deploy the web application and internal dashboard
- Configure all services and firewall rules
- Install the Wazuh agent
- Generate an SSH key pair for blue team access
- **Delete the cloned repository and all SYSTEM_ files**

**When it finishes, collect:**
```bash
# Blue team SSH private key:
cat /root/setup_output/blue_team_ssh_key
```

---

## Step 4 — Distribute access credentials

**Red team receives:**
- `redteam_player.conf` (WireGuard)

**Blue team receives:**
- `blueteam_player.conf` (WireGuard)
- `blue_team_ssh_key` (SSH private key)
- VNC password (from Step 3)
- `BLUE_ACCESS.md` (from this repository)

---

## Step 5 — Verify everything is running

Connect to WireGuard as blue team and check:

```bash
# SSH to target
ssh -i blue_team_ssh_key grizzyadmin@10.10.0.2

# On target — check services
systemctl status nginx php8.1-fpm mysql redis-server vsftpd grizzy-internal wazuh-agent wg-quick@wg0

# Public website reachable
curl -s http://10.10.0.2/ | grep Grizzy

# Internal dashboard reachable (from WireGuard)
curl -s http://10.10.0.2:8888/login | grep Grizzy
```

Wazuh dashboard: `https://10.10.0.1` (check WAZUH.md for credentials after first login)

---

## OpenRouter API Key

The AI agent on the website requires an OpenRouter API key using model `meta-llama/llama-3-8b-instruct`.

Get a key at https://openrouter.ai — create a key with a very small spending cap (e.g., $1) for testing.

If the key is left blank, the chat widget will show "Assistant is currently unavailable." and the AI agent will be non-functional.

---

## Notes

- The setup script deletes the repository after completing — the machine is clean afterward.
- All `SYSTEM_` files are deleted by the setup script and are never left on the machine.
- `DEV_SERVICES.md` is left at `/opt/grizzy/DEV_SERVICES.md`.
- `BLUE_ACCESS.md` and `WAZUH.md` are left at `/root/`.
- The VNC server runs on port 5901 (accessible from the WireGuard network only).
- The target machine public IP should only expose ports 80 and 443 after setup.
