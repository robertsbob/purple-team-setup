# Grizzy's Gourmet Grub – Developer Services Overview

**Last updated:** Gary, March 2024

This document gives a quick overview of what's running on the production server.
It's mostly for me (Gary) so I don't forget stuff, but Greg might read it too.

---

## Server

Single VPS on Hetzner. Ubuntu 24.04 LTS. 4 vCPU, 8GB RAM, 80GB SSD.

---

## Services

### 1. Public Website (Grizzy's Gourmet Grub)

The main customer-facing site. Runs on PHP 8.3 with nginx.

- Web root: `/var/www/grizzy/public`
- Config: `/var/www/grizzy/config/`
- nginx config: `/etc/nginx/sites-enabled/grizzy`
- Runs as: `www-data`

The site has:
- Product browsing and search
- Customer login / registration
- Shopping cart and checkout
- Order history
- Profile / avatar upload
- AI chat assistant (see below)

### 2. AI Chat Assistant

Integrated into the website as a floating chat widget. Handles customer queries
about orders and products. Uses OpenRouter API (cheap LLM).

The assistant has tools to look up order status and search the product catalogue.

- Agent endpoint: `/api/agent.php`
- Helper script: `/opt/grizzy/scripts/get_order.py`
- API key stored in environment / config

### 3. Internal Order Dashboard

Internal-only web tool for Greg and me to manage orders. Runs on port 8888.

- Location: `/opt/grizzy/internal/`
- Started via systemd service `grizzy-internal`
- Login required (ask Gary for credentials)
- Features: order list, status updates, data export, webhook testing

### 4. MySQL Database

Stores all customer, order, and product data.

- Port: 3306
- Database: `grizzy_db`
- App user: `grizzy_app`

### 5. Redis

Installed for caching. Might use it for sessions later.

- Port: 6379
- Config: `/etc/redis/redis.conf`

### 6. FTP (vsftpd)

Gary uses this to upload product images from his laptop.

- Port: 21
- User: `gary` (ask Gary for password)
- Uploads go to `/var/www/grizzy/public/assets/food/`

### 7. SSH

For server admin. Key-based auth only.

- Port: 22
- Key-based login only

### 8. Wazuh Agent

Security monitoring agent. Reports to the Wazuh SIEM server.

---

## Scripts / Crons

- `/opt/grizzy/scripts/cleanup.sh` – cleans old temp files, runs every 5 minutes as root
- `/opt/grizzy/scripts/backup.c` – compiled as `/usr/local/bin/grizzbackup`, run manually to backup web files
- `/opt/grizzy/scripts/export_orders.py` – used by internal dashboard to export CSV

---

## Notes

- greg if you're reading this please stop logging into the server as root, use grizzyadmin
- the uploads directory has an htaccess for extra protection
- TODO: set up SSL (letsencrypt) properly
- TODO: tidy up the config files
