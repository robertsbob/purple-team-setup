# Rules of Engagement


## Scope

**In scope:** The target machine at `10.10.0.2` and all services running on it.

**Out of scope:** The Wazuh/VPN server for the **red team** (`10.10.0.1`), team member WireGuard IPs, and any machine outside the `10.10.0.0/24` network.


## Red Team

- Attack only services on `10.10.0.2`
- No denial-of-service attacks (intentionally crashing services, flooding)
- No interference with other players
- All activity must originate from your assigned WireGuard IP
- All initiated reverse connections from the target must go only to your assigned WireGuard IP

## Blue Team

- Monitor, investigate, and harden the target
- Keep all services running and available
- May patch, reconfigure, or restart services at any time, but without impacting availability significantly
- May not use network-level blocks to wholesale drop the red team subnet or block the red-team IP addresses
- May configure Wazuh server if it does not impact availability


## Both Teams

- Stay on WireGuard for all exercise activity — no direct internet-side connections to the target
- Communication between teams and members is key to learning
- **AI use is permitted** but **automated AI tools (like Claude code) are NOT allowed**
