# Blue Team Access Guide

This document contains all access information for the blue team.
**Keep this document confidential.**

---

## WireGuard VPN

All access to the target machine is via the WireGuard VPN.

Your WireGuard config file: `blueteam_player.conf`
(Generated during setup — see the `wg_configs_output/` directory on the Wazuh server.)

Import it into your WireGuard client and connect. Once connected, you will be on the
`10.10.0.0/24` network.

- Target machine: `10.10.0.2`
- Wazuh server: `10.10.0.1`
- Your IP: `10.10.0.20`
- Red team IP: `10.10.0.10`

---

## SSH Access (Command Line)

```
Host:     10.10.0.2
Port:     22
User:     grizzyadmin
Auth:     SSH key (see below)
```

During setup, an SSH key pair was generated. Your private key is at:
```
/root/blue_team_ssh_key
```
(On the Wazuh server, in the setup output directory.)

Connect with:
```bash
ssh -i /path/to/blue_team_ssh_key grizzyadmin@10.10.0.2
```

`grizzyadmin` has `sudo` rights and can become root if needed for hardening.

---

## GUI / VNC Access

A VNC server runs on the target machine (accessible only from WireGuard).

```
Host:   10.10.0.2
Port:   5901
Password: (set during setup — see SETUP.md output)
```

Connect with any VNC client (e.g., TigerVNC, RealVNC Viewer):
```
10.10.0.2:5901
```

The VNC session runs as `grizzyadmin` and provides a full desktop environment.

---

## Wazuh SIEM

The Wazuh web interface is available at:
```
https://10.10.0.1
```

Default credentials were set during Wazuh server setup.
See the Wazuh server SETUP output for the admin password.

---

## Engagement Rules

- The red team player's WireGuard IP is `10.10.0.10`
- SSH (`grizzyadmin`) and VNC access paths are **not** part of the engagement and must not be targeted by the red team (agreed by both teams)
- The red team will use only WireGuard IPs for all activity
- The exercise window is agreed separately between both teams

---

## Key Accounts Summary

| Account | Where | Purpose |
|---------|-------|---------|
| `grizzyadmin` | Target SSH/VNC | Blue team admin access |
| `gary` | FTP | Developer FTP (part of target environment) |
| `admin` | Internal dashboard (port 8888) | Internal tool access |
| `greg_grizzy` / `gary_dev` | Website customer accounts | Seed accounts |

---

## Notes

- The `grizzyadmin` user is separate from the application accounts and was created specifically for this exercise. It should not normally appear in application logs.
- All other accounts/services on the target machine are part of the target environment.
- Wazuh collects logs from: nginx, auth.log, syslog, MySQL error log, vsftpd, Redis, and file integrity events.
