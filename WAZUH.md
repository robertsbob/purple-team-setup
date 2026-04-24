# Wazuh SIEM Configuration Documentation

This document describes all custom Wazuh rules, decoders, and configuration
choices made for this engagement. The assumption is that the security team
knows what services are running but has no knowledge of specific vulnerabilities
or misconfigurations.

---

## Architecture

- **Wazuh Manager:** Wazuh/VPN server (10.10.0.1)
- **Wazuh Agent:** Target machine (10.10.0.2)
- **Agent communication:** TCP port 1514
- **Web UI:** HTTPS port 443 (Wazuh dashboard)

---

## Log Sources Collected

| Source | Format | Location |
|--------|--------|----------|
| Nginx access log | Apache/Combined | `/var/log/nginx/grizzy_access.log` |
| Nginx error log | Syslog | `/var/log/nginx/grizzy_error.log` |
| Auth log | Syslog | `/var/log/auth.log` |
| Syslog | Syslog | `/var/log/syslog` |
| MySQL error log | Syslog | `/var/log/mysql/error.log` |
| vsftpd log | Syslog | `/var/log/vsftpd.log` |
| Redis log | Syslog | `/var/log/redis/redis-server.log` |
| Process list | Command | `ps -aux` (every 2 min) |
| Listening ports | Command | `netstat -tlnp` (every 5 min) |

---

## File Integrity Monitoring (FIM)

Monitored directories (real-time where noted):

| Path | Mode | Notes |
|------|------|-------|
| `/var/www/grizzy/public` | Real-time + diff | Web root — any new/changed file alerted |
| `/opt/grizzy` | Real-time | App scripts and internal tool |
| `/etc/nginx` | Real-time | Web server config |
| `/etc/cron.d` | Real-time | Cron job definitions |
| `/etc/passwd` | Polling | User account changes |
| `/etc/shadow` | Polling | Password hash changes |
| `/etc/sudoers`, `/etc/sudoers.d` | Polling | Sudo privilege changes |
| `/tmp` | Real-time | Temporary file creation |
| `/usr/local/bin` | Polling | Custom binary changes |
| `/home` | Polling | Home directory changes |
| `/root` | Polling | Root home directory |

Ignored: `/var/www/grizzy/public/uploads` (user upload area — noisy)

---

## Custom Decoders

### Decoder: nginx-grizzy-4xx
Matches nginx access log lines with 4xx status codes to extract the URL and source IP for correlation with scanning activity.

```xml
<decoder name="nginx-grizzy-4xx">
  <parent>web-accesslog</parent>
  <prematch>HTTP/\d\.\d" [45]</prematch>
  <regex>(\S+) - \S+ \[.*\] "\S+ (\S+) HTTP/\S+" (\d{3})</regex>
  <order>srcip, url, status</order>
</decoder>
```

### Decoder: vsftpd-auth
Extracts FTP login events from vsftpd syslog output.

```xml
<decoder name="vsftpd-auth">
  <program_name>vsftpd</program_name>
  <regex>FAIL LOGIN: Client "(\d+\.\d+\.\d+\.\d+)"</regex>
  <order>srcip</order>
</decoder>

<decoder name="vsftpd-auth-ok">
  <program_name>vsftpd</program_name>
  <regex>OK LOGIN: Client "(\d+\.\d+\.\d+\.\d+)", anon_password "(\S+)"</regex>
  <order>srcip, extra_data</order>
</decoder>
```

---

## Custom Rules

All custom rules are in `/var/ossec/etc/rules/grizzy_rules.xml`.

### Rule 100001 — Web Scanner / Directory Enumeration
**Trigger:** 20+ 404 responses from the same IP within 60 seconds.

```xml
<rule id="100001" level="10" frequency="20" timeframe="60">
  <if_matched_sid>31101</if_matched_sid>
  <same_source_ip/>
  <description>Possible web directory enumeration from $(srcip)</description>
  <group>web,scanning</group>
</rule>
```

### Rule 100002 — Suspicious File Extension in URL
**Trigger:** Request for `.php`, `.bak`, `.env`, `.git`, `.sql`, `.conf`, `.ini`, `.log` files that are not normally served.

```xml
<rule id="100002" level="9">
  <if_sid>31100</if_sid>
  <url>\.env|\.git|\.bak|\.sql|\.conf|\.ini|\.log|phpinfo|backup|dump</url>
  <description>Request for potentially sensitive file: $(url)</description>
  <group>web,info-disclosure</group>
</rule>
```

### Rule 100003 — SQL Injection Pattern in URL or POST
**Trigger:** Common SQL injection patterns detected in web access logs.

```xml
<rule id="100003" level="12">
  <if_sid>31100</if_sid>
  <url>union.*select|select.*from|insert.*into|drop.*table|or.*1.*=.*1|'.*--|%27|%3D|information_schema</url>
  <description>Possible SQL injection attempt: $(url)</description>
  <group>web,sqli,attack</group>
</rule>
```

### Rule 100004 — XSS Pattern in URL
**Trigger:** Common XSS patterns in HTTP requests.

```xml
<rule id="100004" level="10">
  <if_sid>31100</if_sid>
  <url>&lt;script|javascript:|onerror=|onload=|%3Cscript|alert\(|document\.cookie</url>
  <description>Possible XSS attempt in request: $(url)</description>
  <group>web,xss,attack</group>
</rule>
```

### Rule 100005 — File Upload to Uploads Directory
**Trigger:** POST request to an upload endpoint.

```xml
<rule id="100005" level="7">
  <if_sid>31100</if_sid>
  <url>/account\.php|/upload</url>
  <match>POST</match>
  <description>File upload request to $(url)</description>
  <group>web,upload</group>
</rule>
```

### Rule 100006 — New File in Web Root (FIM)
**Trigger:** Wazuh FIM detects a new file added to `/var/www/grizzy/public`.

Built-in FIM rule 554 (file added) scoped to the web root via the monitored path. Level raised to 12 for uploads directory due to risk.

```xml
<rule id="100006" level="12">
  <if_sid>554</if_sid>
  <field name="file">/var/www/grizzy/public/uploads</field>
  <description>New file added to web uploads directory: $(file)</description>
  <group>fim,web,upload</group>
</rule>
```

### Rule 100007 — SSH Brute Force
**Trigger:** 5+ failed SSH logins from the same IP within 60 seconds.

Built on standard rule 5763. Wazuh built-in brute-force detection covers this — rule raised to level 14 for this engagement.

```xml
<rule id="100007" level="14" frequency="5" timeframe="60">
  <if_matched_sid>5716</if_matched_sid>
  <same_source_ip/>
  <description>SSH brute force from $(srcip)</description>
  <group>ssh,brute_force,attack</group>
</rule>
```

### Rule 100008 — FTP Login Failure
**Trigger:** FTP authentication failure.

```xml
<rule id="100008" level="6">
  <decoded_as>vsftpd-auth</decoded_as>
  <description>FTP login failure from $(srcip)</description>
  <group>ftp,authentication</group>
</rule>
```

### Rule 100009 — FTP Brute Force
**Trigger:** 5+ FTP failures from the same IP within 60 seconds.

```xml
<rule id="100009" level="12" frequency="5" timeframe="60">
  <if_matched_sid>100008</if_matched_sid>
  <same_source_ip/>
  <description>FTP brute force from $(srcip)</description>
  <group>ftp,brute_force,attack</group>
</rule>
```

### Rule 100010 — Sudo Command Execution
**Trigger:** Any sudo command executed on the target machine.

```xml
<rule id="100010" level="8">
  <if_sid>5401</if_sid>
  <description>Sudo command executed: $(command)</description>
  <group>sudo,privilege</group>
</rule>
```

### Rule 100011 — Sudo by Non-Standard User
**Trigger:** Sudo used by a user who is not `grizzyadmin`.

```xml
<rule id="100011" level="13">
  <if_sid>5401</if_sid>
  <user>^(?!grizzyadmin$)</user>
  <description>Sudo executed by unexpected user $(user): $(command)</description>
  <group>sudo,privilege,suspicious</group>
</rule>
```

### Rule 100012 — New User Account Created
**Trigger:** FIM detects `/etc/passwd` change or useradd/adduser command.

Built on standard rule 5902 (user added). Level 14 for this engagement.

### Rule 100013 — Cron Job Modified (FIM)
**Trigger:** FIM detects change in `/etc/cron.d/`.

```xml
<rule id="100013" level="12">
  <if_sid>550</if_sid>
  <field name="file">/etc/cron.d</field>
  <description>Cron job file modified: $(file)</description>
  <group>fim,cron,suspicious</group>
</rule>
```

### Rule 100014 — Sudoers File Modified (FIM)
**Trigger:** FIM detects change to `/etc/sudoers` or `/etc/sudoers.d/`.

```xml
<rule id="100014" level="15">
  <if_sid>550</if_sid>
  <field name="file">/etc/sudoers</field>
  <description>sudoers file modified: $(file)</description>
  <group>fim,sudo,privilege,critical</group>
</rule>
```

### Rule 100015 — Reverse Shell Indicators (Process Monitor)
**Trigger:** Process monitor detects known reverse shell patterns (`nc`, `bash -i`, `python3 -c`, `/dev/tcp`).

```xml
<rule id="100015" level="15">
  <if_sid>531</if_sid>
  <match>bash -i|nc -e|python.*-c.*import socket|/dev/tcp|ncat|mkfifo</match>
  <description>Possible reverse shell process detected</description>
  <group>attack,reverse_shell,critical</group>
</rule>
```

### Rule 100016 — Web App Error Spike
**Trigger:** 50+ 5xx errors within 120 seconds (may indicate active exploitation causing crashes).

```xml
<rule id="100016" level="10" frequency="50" timeframe="120">
  <if_matched_sid>31103</if_matched_sid>
  <description>High rate of web server 5xx errors — possible exploitation</description>
  <group>web,availability</group>
</rule>
```

### Rule 100017 — Redis Command via Non-Standard Client
**Trigger:** Redis log shows a connection from an IP other than localhost.

```xml
<rule id="100017" level="11">
  <decoded_as>redis</decoded_as>
  <match>Accepted.*:(?!127\.0\.0\.1)</match>
  <description>Redis connection from non-localhost address</description>
  <group>redis,suspicious</group>
</rule>
```

### Rule 100018 — Nginx Accessing AI Agent Endpoint
**Trigger:** POST request to `/api/agent.php` logged for correlation with downstream command execution.

```xml
<rule id="100018" level="5">
  <if_sid>31100</if_sid>
  <url>/api/agent\.php</url>
  <match>POST</match>
  <description>AI agent endpoint accessed</description>
  <group>web,agent</group>
</rule>
```

### Rule 100019 — Shell Command in Web Log (Command Injection Indicator)
**Trigger:** Shell metacharacters or command names appear in web access log URLs or error logs.

```xml
<rule id="100019" level="13">
  <if_sid>31100</if_sid>
  <url>%3B|%7C|\|;|`|/bin/bash|/bin/sh|cmd=|exec=|system\(|passthru|shell_exec</url>
  <description>Shell metacharacters detected in web request — possible command injection</description>
  <group>web,cmdi,attack</group>
</rule>
```

### Rule 100020 — SUID Binary Execution (Auditd)
**Trigger:** Auditd (if configured) logs execution of the custom SUID binary.

Note: Requires auditd with a watch rule on `/usr/local/bin/grizzbackup`.

```xml
<rule id="100020" level="10">
  <if_sid>80700</if_sid>
  <field name="audit.exe">/usr/local/bin/grizzbackup</field>
  <description>Custom SUID backup binary executed by $(audit.auid)</description>
  <group>audit,suid,suspicious</group>
</rule>
```

---

## Correlation Notes for Blue Team

The following sequences of events are particularly meaningful:

1. **Web scan → specific URL hit → FIM alert** — active attack sequence; correlate source IP across all three
2. **Agent endpoint POST → new process in error log → new file in /tmp** — AI agent misuse; review request body and spawned process
3. **Auth.log sudo by non-grizzyadmin** — unexpected privilege use; check command and context
4. **Redis connection from 10.10.0.10** — red team directly accessing Redis
5. **FTP login from 10.10.0.10** — red team attempting FTP access
6. **FIM alert in /etc/cron.d** — potential persistence mechanism

---

## Auditd Rules (Optional Enhancement)

If `auditd` is installed, add these watches:

```
-a always,exit -F arch=b64 -S execve -F euid=0 -F auid!=0 -k priv_exec
-w /usr/local/bin/grizzbackup -p x -k suid_exec
-w /etc/sudoers -p wa -k sudoers_change
-w /etc/passwd -p wa -k passwd_change
-w /tmp -p x -k tmp_exec
```

---

## Alert Levels Reference

| Level | Meaning |
|-------|---------|
| 1-4 | Informational |
| 5-7 | Low — worth noting |
| 8-10 | Medium — investigate |
| 11-13 | High — likely attack activity |
| 14-15 | Critical — requires immediate investigation |
