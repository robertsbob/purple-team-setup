# Blue Team Access Guide

---

## WireGuard VPN

Connect using the config file assigned to you (`blueteam_playerN.conf` from the Wazuh server's `/root/wg_configs_output/` directory).

Once connected:

| Machine | IP |
|---------|----|
| Target  | `10.10.0.2` |
| Wazuh (SIEM) | `10.10.0.1` |
| Your IP | see your config file |

---

## SSH Access

```
Host:  10.10.0.2
Port:  22
User:  grizzyadmin
Auth:  SSH key
```

Your private key was printed at the end of the target setup script output. The operator will provide it to you directly.

```bash
ssh -i /path/to/blue_team_ssh_key grizzyadmin@10.10.0.2
```

`grizzyadmin` has `sudo` rights.

---

## VNC Access (if enabled)

```
Host:     10.10.0.2
Port:     5901
Password: set during setup — see setup script output
```

Connect with any VNC client. Only available if the desktop option was enabled at setup time.

---

## Wazuh SIEM

```
URL:  https://10.10.0.1
```

Credentials were printed at the end of the Wazuh setup script.
