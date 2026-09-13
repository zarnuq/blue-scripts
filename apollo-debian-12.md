# Debian 12 — Apollo `10.x.2.10`

**Scored: SSH (22), DNS (53), HTTP-DNSGui, distcc (3632).**
Start with [_common-linux.md](_common-linux.md), then the below.

Apollo is the most dangerous box you own, because **distcc is remote code execution by
design** and it is scored. You cannot turn it off.

## distcc — the one that will get you rooted

`distccd` compiles whatever it is handed. Anyone who can reach 3632 can run commands as
the user it runs as. Historically CVE-2004-2687, but it is not really a bug — it is the
product working.

```sh
systemctl cat distcc 2>/dev/null | grep -E 'ExecStart|User='
ps -o user:20,pid,cmd -C distccd
cat /etc/default/distcc 2>/dev/null
```

What to do, in order of value:

1. **Never let it run as root.** If `User=` is root or the process list shows root, that
   is a full compromise waiting. Run it as the `distccd`/`_distcc` user.
2. **Restrict clients with `--allow`.** distcc has no authentication; `--allow` is the
   only access control it has.
   ```sh
   # /etc/default/distcc
   ALLOWEDNETS="10.x.2.0/24"      # your own subnet only
   LISTENER="10.x.2.10"
   ```
3. **Do not move the port and do not stop the service** — the check stays on 3632.
4. Firewall 3632 to the hosts that legitimately build, and nothing else.

bluesweep raises `SRV001`, `SRV004` and `SRV005` for exactly these; `SRV005` (distccd as
root) is CRIT and should be your first fix on this box.

## DNS

Identify which server is in play first:

```sh
ss -tlnp 'sport = :53'; systemctl list-units --type=service --state=running | grep -iE 'bind|named|dnsmasq|technitium|unbound'
```

**BIND / named** — the two classic giveaways:

```sh
sudo grep -rE 'allow-transfer|allow-recursion|allow-query' /etc/bind/ 2>/dev/null
```

- `allow-transfer { any; };` hands your whole zone to anyone. Restrict to your secondaries.
- Open recursion makes you an amplifier. `allow-recursion { 10.x.0.0/16; };`
- Check for zone files edited to point a scored name somewhere else.

**Technitium (the likely HTTP-DNSGui)** — admin web GUI, usually 5380/5000:

```sh
ss -tlnp | grep -E ':5380|:5000|:53443'
```

Change the admin password immediately (it ships weak), and confirm the GUI is not
reachable from the user subnet if the check does not require it. **Verify how the
HTTP-DNSGui check connects before you restrict it** — if the scoring engine hits that
web port, locking it down fails the check.

## Debian 12 specifics

```sh
# iptables here is the nftables shim
update-alternatives --display iptables | head -3
iptables -V                                # expect "(nf_tables)"

# Provenance: which running binaries does no package own?
sudo ./bluesweep.sh --full --raw | grep -E 'PRV00[123]'
sudo dpkg --verify                         # modified packaged files
```

`dpkg -S` works properly on Debian 12, so bluesweep's provenance check is at full strength
here — "running, listening, and owned by no package" is your strongest unknown-binary
signal on this box.

## Apollo firewall skeleton

```sh
sudo ufw allow 22/tcp
sudo ufw allow 53
sudo ufw allow 3632/tcp
sudo ufw allow <dns-gui-port>/tcp
sudo ufw default deny incoming
sudo ufw enable
```
