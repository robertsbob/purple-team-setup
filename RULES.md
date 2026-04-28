# Rules of Engagement

---

## Scope

**In scope:** The target machine at `10.10.0.2` and all services running on it.

**Out of scope:** The Wazuh/VPN server (`10.10.0.1`), blue team WireGuard IPs, and any machine outside the `10.10.0.0/24` network.

---

## Red Team

- Attack only in-scope services on `10.10.0.2`
- No denial-of-service attacks (crashing services, flooding)
- No interference with other red team players
- All activity must originate from your assigned WireGuard IP

---

## Blue Team

- Monitor, investigate, and harden the target freely
- May patch, reconfigure, or restart services at any time
- May not use network-level blocks to wholesale drop the red team subnet — individual IP blocks are permitted
- May not alter or interfere with the Wazuh agent or its configuration on the target

---

## Both Teams

- Stay on WireGuard for all exercise activity — no direct internet-side connections to the target
- No out-of-band communication between teams during the exercise window
- Exercise window: agreed separately before the session starts
- When time is called, all active connections must be terminated

---

## Flags

Successful exploitation of a weakness constitutes a red team point. The exercise debrief covers all findings from both teams.
