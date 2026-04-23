#!/bin/bash
# Firewall rules for Grizzy target machine
# Applied during setup

IPT="iptables"
WG_NET="10.10.0.0/24"

# Flush existing rules
$IPT -F
$IPT -X
$IPT -t nat -F
$IPT -t nat -X

# Default policies
$IPT -P INPUT DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT ACCEPT

# Allow loopback
$IPT -A INPUT -i lo -j ACCEPT

# Allow established/related connections
$IPT -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow HTTP/HTTPS from anywhere (public website)
$IPT -A INPUT -p tcp --dport 80  -j ACCEPT
$IPT -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow all from WireGuard network (management + red team)
$IPT -A INPUT -s $WG_NET -j ACCEPT

# Allow WireGuard interface traffic
$IPT -A INPUT -i wg0 -j ACCEPT

# Save rules
iptables-save > /etc/iptables/rules.v4

echo "Firewall rules applied."
