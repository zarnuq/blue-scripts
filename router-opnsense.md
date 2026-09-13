# OPNsense — Router `172.16.x.3`

**Scored: SSH (22), HTTPS (443).** In scope for the first time this year.

The router is the one box where a single compromise gives the red team everything: they can
re-route, port-forward into your subnets, or watch traffic. It is also the box with the
best defensive property on the board — **nearly all of its state lives in one file**,
`/conf/config.xml`, and every change bumps a `<revision>`.

## 1. Rotate credentials and check accounts

System > Access > Users in the GUI, or:

```sh
# on the router
cat /conf/config.xml | grep -A6 '<user>'
```

Change the `root`/`admin` password immediately. Then look for what you did not create:
accounts with `<priv>page-all</priv>` (full admin) or `<priv>user-shell-access</priv>`
(shell), any `<authorizedkeys>` block, and any account with **no** `<*-hash>` element at
all — that is a key-only backdoor account.

## 2. Baseline it with bluesweep

The appliance ships no bash and mounts no procfs, so bluesweep cannot run on it. Copy the
tree to a Linux box and scan it there:

```sh
# from a Linux host - run the tar AS ROOT or you lose file ownership
ssh root@172.16.x.3 tar -cf - /conf /etc /usr/local/etc /var/cron /root \
  | sudo tar -xf - -C /mnt/opn

sudo ./bluesweep.sh --root /mnt/opn --baseline router.snap      # before T+30
sudo ./bluesweep.sh --root /mnt/opn --diff router.snap          # repeatedly after
```

A router account added by the red team shows up as:

```
DIF001  CRIT  ADDED OPNUSER | svc_backup
OPN011  CRIT  OPNsense account has no password hash in the configuration | svc_backup
```

Hashes and key material are deliberately not recorded in the snapshot — user records carry
the hash *type* and a yes/no for keys, never the values. The snapshot is safe to keep.

Everything `/proc`-derived SKIPs and says so; the filesystem and config checks are what run.

## 3. What the config diff will not catch

Anything done from a shell that bypasses the configuration system:

```sh
ls -la /usr/local/etc/rc.syshook.d/*/          # runs at boot, not in config.xml
crontab -l -u root                             # direct crontab edits
ls -la /etc/periodic/daily /usr/local/etc/periodic/*
cat /etc/rc.local 2>/dev/null
```

bluesweep scores these with the same command grammar as Linux cron, so a `curl | sh`
dropped in `rc.syshook.d/start` comes back CRIT. Check them by hand too.

## 4. Firewall and NAT — the high-value review

In the GUI: Firewall > Rules, and Firewall > NAT > Port Forward.

```sh
grep -c '<rule>' /conf/config.xml
```

What to hunt:

- **Any NAT port forward you did not create.** Every forward is an inbound path into a
  subnet. bluesweep lists them as `OPN021`.
- **A pass rule with `any` source on the WAN interface** — `OPN020` HIGH.
- **Disabled rules.** A red team disabling your block rule is quieter than deleting it,
  and the GUI shows it greyed rather than gone.
- **Rule order.** A permit inserted above your deny wins. Check position, not just presence.

Blocking an attacker — single IPs only, subnets are against the rules:

Firewall > Aliases, make a host-type alias `blocked`, add individual IPs, then one block
rule at the **top** of the WAN rule list referencing the alias. One rule you reorder once
beats twenty rules you have to re-sort under pressure.

## 5. Lock down management access

- **Web GUI (443) is scored — leave it reachable.** Restrict *where* from if the check
  allows it, but verify before you do.
- SSH (22) is scored too. System > Settings > Administration:
  - Disable root login if you have another admin account that works.
  - Prefer key-only, but only if you have confirmed the SSH check is not password-based.
- Turn off any "Listen Interfaces: All" for management if the check comes from one place.

## 6. Watch it

```sh
# on the router
sockstat -l                                    # BSD equivalent of ss -tlnp
pfctl -s rules 2>/dev/null | head -40          # active ruleset
pfctl -s states | head                         # live connections
tail -f /var/log/system/latest.log
clog /var/log/filter.log 2>/dev/null | tail -50
```

`configctl firmware changelog` and the GUI's System > Configuration > History show every
config revision with who made it — that history is direct incident-report evidence.

## 7. Config backups are a free timeline

`/conf/backup/` keeps prior revisions. Each one is a snapshot of the whole box:

```sh
ls -la /conf/backup/ | tail -20
```

If something changed and you want to know exactly what, diff two revisions. This is the
fastest root-cause path on the whole board.

**Download a known-good backup to your own machine at T-30** (System > Configuration >
Backups). If the router is badly compromised, restoring it is minutes rather than a rebuild.

## Do not

- Do not "mess with competition infrastructure beyond what you've been given." The router
  is yours this year; the Wiretap, Scoring Engine and OpenStack are not.
- Do not block subnets.
- Do not change the WAN interface config or the management VLAN without a console path
  back — you will lock yourself out of a scored box and there is no undo.
