#!/bin/bash
# nuke_firewall.sh — flush all iptables rules and reset UFW

echo "[*] Flushing iptables rules..."
iptables  -F 2>/dev/null
iptables  -X 2>/dev/null
iptables  -Z 2>/dev/null
iptables  -t nat    -F 2>/dev/null
iptables  -t nat    -X 2>/dev/null
iptables  -t mangle -F 2>/dev/null
iptables  -t mangle -X 2>/dev/null
iptables  -t raw    -F 2>/dev/null
iptables  -t raw    -X 2>/dev/null

echo "[*] Setting default iptables policies to ACCEPT..."
iptables  -P INPUT   ACCEPT 2>/dev/null
iptables  -P FORWARD ACCEPT 2>/dev/null
iptables  -P OUTPUT  ACCEPT 2>/dev/null

echo "[*] Flushing ip6tables rules..."
ip6tables -F 2>/dev/null
ip6tables -X 2>/dev/null
ip6tables -Z 2>/dev/null
ip6tables -t nat    -F 2>/dev/null
ip6tables -t nat    -X 2>/dev/null
ip6tables -t mangle -F 2>/dev/null
ip6tables -t mangle -X 2>/dev/null
ip6tables -t raw    -F 2>/dev/null
ip6tables -t raw    -X 2>/dev/null
ip6tables -P INPUT   ACCEPT 2>/dev/null
ip6tables -P FORWARD ACCEPT 2>/dev/null
ip6tables -P OUTPUT  ACCEPT 2>/dev/null

echo "[*] Resetting UFW..."
ufw --force reset   2>/dev/null
ufw disable         2>/dev/null

echo "[*] Stopping firewall services..."
systemctl stop  ufw        2>/dev/null
systemctl stop  firewalld  2>/dev/null
systemctl stop  nftables   2>/dev/null

echo "[*] Disabling firewall services on boot..."
systemctl disable ufw       2>/dev/null
systemctl disable firewalld 2>/dev/null
systemctl disable nftables  2>/dev/null

echo "[*] Flushing nftables rulesets..."
nft flush ruleset 2>/dev/null

echo "[*] Flushing ebtables / arptables..."
ebtables  -F 2>/dev/null
ebtables  -X 2>/dev/null
arptables -F 2>/dev/null
arptables -X 2>/dev/null

echo "[*] Removing saved iptables rule files..."
# Debian/Ubuntu — iptables-persistent
rm -f /etc/iptables/rules.v4           2>/dev/null
rm -f /etc/iptables/rules.v6           2>/dev/null
rm -f /etc/iptables/ipv4.rules         2>/dev/null
rm -f /etc/iptables/ipv6.rules         2>/dev/null
rm -rf /etc/iptables/                  2>/dev/null

# RHEL/CentOS/Fedora
rm -f /etc/sysconfig/iptables          2>/dev/null
rm -f /etc/sysconfig/ip6tables         2>/dev/null
rm -f /etc/sysconfig/iptables-config   2>/dev/null
rm -f /etc/sysconfig/ip6tables-config  2>/dev/null

# nftables saved ruleset
rm -f /etc/nftables.conf               2>/dev/null
rm -f /etc/nftables.d/*                2>/dev/null

# firewalld zones and rules
rm -rf /etc/firewalld/zones/*          2>/dev/null
rm -rf /etc/firewalld/direct.xml       2>/dev/null
rm -rf /etc/firewalld/lockdown-whitelist.xml 2>/dev/null

# UFW saved rules
rm -rf /etc/ufw/user.rules             2>/dev/null
rm -rf /etc/ufw/user6.rules            2>/dev/null
rm -rf /etc/ufw/before.rules           2>/dev/null
rm -rf /etc/ufw/after.rules            2>/dev/null
rm -rf /etc/ufw/before6.rules          2>/dev/null
rm -rf /etc/ufw/after6.rules           2>/dev/null

# Generic fallback locations
rm -f /etc/iptables.rules              2>/dev/null
rm -f /etc/iptables.up.rules           2>/dev/null
rm -f /etc/iptables-save               2>/dev/null

# network-scripts / ifup hooks that reload iptables on interface up
rm -f /etc/network/if-pre-up.d/iptables   2>/dev/null
rm -f /etc/network/if-pre-up.d/ip6tables  2>/dev/null
rm -f /etc/network/if-up.d/iptables       2>/dev/null
rm -f /etc/network/if-up.d/ufw            2>/dev/null

echo "[+] Done. All firewall rules cleared, services stopped, and saved rule files removed."

# ── SETUP ALLOWLIST FIREWALL ─────────────────────────────────────────────────

echo ""
echo "[*] Setting up allowlist firewall..."
echo "    Enter ports to allow, one per line."
echo "    Format: 22 or 22/tcp or 80/udp"
echo "    Press ENTER on a blank line when done."
echo ""

PORTS=()
while true; do
    read -rp "    Allow port: " port
    [[ -z "$port" ]] && break
    PORTS+=("$port")
done

if [[ ${#PORTS[@]} -eq 0 ]]; then
    echo "[!] No ports entered — firewall will block ALL incoming traffic."
fi

echo ""
echo "[*] Applying iptables default DROP policies (input, forward, AND output)..."
iptables -P INPUT   DROP 2>/dev/null
iptables -P FORWARD DROP 2>/dev/null
iptables -P OUTPUT  DROP 2>/dev/null

echo "[*] Allowing loopback traffic..."
iptables -A INPUT  -i lo -j ACCEPT 2>/dev/null
iptables -A OUTPUT -o lo -j ACCEPT 2>/dev/null

echo "[*] Allowing established/related traffic on allowed ports only..."
iptables -A INPUT  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null

echo "[*] Allowing outbound DNS (53) so name resolution keeps working..."
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT 2>/dev/null
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT 2>/dev/null

echo "[*] Allowing ICMP (ping/path-MTU)..."
iptables -A INPUT  -p icmp -j ACCEPT 2>/dev/null
iptables -A OUTPUT -p icmp -j ACCEPT 2>/dev/null

echo "[*] Allowing specified ports (inbound and outbound)..."
for port in "${PORTS[@]}"; do
    proto="tcp"
    p="$port"
    if [[ "$port" == *"/"* ]]; then
        p="${port%%/*}"
        proto="${port##*/}"
    fi
    iptables -A INPUT  -p "$proto" --dport "$p" -j ACCEPT 2>/dev/null
    iptables -A OUTPUT -p "$proto" --sport "$p" -j ACCEPT 2>/dev/null
    echo "    allowed: $p/$proto"
done

echo "[*] Applying same rules to ip6tables..."
ip6tables -P INPUT   DROP 2>/dev/null
ip6tables -P FORWARD DROP 2>/dev/null
ip6tables -P OUTPUT  DROP 2>/dev/null
ip6tables -A INPUT  -i lo -j ACCEPT 2>/dev/null
ip6tables -A OUTPUT -o lo -j ACCEPT 2>/dev/null
ip6tables -A INPUT  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null
ip6tables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null
ip6tables -A OUTPUT -p udp --dport 53 -j ACCEPT 2>/dev/null
ip6tables -A OUTPUT -p tcp --dport 53 -j ACCEPT 2>/dev/null
ip6tables -A INPUT  -p ipv6-icmp -j ACCEPT 2>/dev/null
ip6tables -A OUTPUT -p ipv6-icmp -j ACCEPT 2>/dev/null

for port in "${PORTS[@]}"; do
    proto="tcp"
    p="$port"
    if [[ "$port" == *"/"* ]]; then
        p="${port%%/*}"
        proto="${port##*/}"
    fi
    ip6tables -A INPUT  -p "$proto" --dport "$p" -j ACCEPT 2>/dev/null
    ip6tables -A OUTPUT -p "$proto" --sport "$p" -j ACCEPT 2>/dev/null
done

echo ""
echo "[*] Persisting ruleset so it survives reboot..."
if [ -d /etc/iptables ] || mkdir -p /etc/iptables 2>/dev/null; then
    iptables-save  > /etc/iptables/rules.v4 2>/dev/null && echo "    saved: /etc/iptables/rules.v4"
    ip6tables-save > /etc/iptables/rules.v6 2>/dev/null && echo "    saved: /etc/iptables/rules.v6"
fi
if [ -d /etc/sysconfig ]; then
    iptables-save  > /etc/sysconfig/iptables  2>/dev/null && echo "    saved: /etc/sysconfig/iptables"
    ip6tables-save > /etc/sysconfig/ip6tables 2>/dev/null && echo "    saved: /etc/sysconfig/ip6tables"
fi

echo ""
echo "[+] Firewall active. All traffic blocked except allowed ports. Current rules:"
echo "--- INPUT ---"
iptables -L INPUT  -n --line-numbers 2>/dev/null
echo "--- OUTPUT ---"
iptables -L OUTPUT -n --line-numbers 2>/dev/null
