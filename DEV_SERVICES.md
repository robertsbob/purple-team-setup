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

- Agent endpoint: `/api/agent.php`
- API key stored in environment / config
- Note: the LLM is pretty flexible with what it'll do if you ask nicely

### 3. Internal Order Dashboard

Internal-only web tool for Greg and me to manage orders. Runs on port 8888.

- Location: `/opt/grizzy/internal/`
- Started via systemd service `grizzy-internal`
- Login required (I use a variation of the usual pattern, Greg knows it)
- Features: order list, status updates, data export, webhook testing

### 4. MySQL Database

Stores all customer, order, and product data.

- Port: 3306
- Database: `grizzy_db`
- App user: `grizzy_app`
- Note: I opened port 3306 temporarily for remote debugging and haven't closed it yet, meant to do that

### 5. Redis

Installed for caching. Might use it for sessions later.

- Port: 6379
- Config: `/etc/redis/redis.conf`
- Haven't got round to setting auth up, it's behind the app so should be fine

### 6. FTP (vsftpd)

Gary uses this to upload product images from his laptop.

- Port: 21
- User: gary (password same as the FTP test account I set up, see my notes)
- Uploads go to `/var/www/grizzy/public/assets/food/`
- I set it up without chroot so I can get to other dirs if needed

### 7. SSH

For server admin. Key-based auth only.

- Port: 22
- Key-based login only

### 8. Wazuh Agent

Security monitoring agent. Reports to the Wazuh SIEM server.

---

## Scripts / Crons

- `/opt/grizzy/scripts/cleanup.sh` – tidies up old temp files, scheduled to run frequently
- `/opt/grizzy/scripts/export_orders.py` – used by internal dashboard to export CSV
- `/usr/local/bin/grizzbackup` – compiled backup utility, needs elevated access to reach all the web dirs
- I gave `www-data` a bit of extra access to the scripts folder so the app can manage its own maintenance files

---

## Notes

- greg if you're reading this please stop logging into the server as root, use grizzyadmin
- the phpinfo page is still up at /info.php (was debugging env vars), will remove it
- TODO: set up SSL (letsencrypt) properly
- TODO: tidy up the config files
