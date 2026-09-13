# Read before running anything already in this folder

These scripts were written for NCAE, where the scored service list is different. Three of
them will cost you uptime points here if run as-is.

## `nuke_firewall.sh` — pre-game only

Sets every policy to ACCEPT, disables ufw/firewalld/nftables, and deletes the saved
rulesets. That is a *clean slate* tool, correct for starting fresh at T-30 and wrong at
any other moment. Run it, then immediately build rules. Never run it after red is active
without a ruleset ready to paste.

It also deletes `/etc/nftables.conf` and `/etc/iptables/rules.v4`, which are exactly the
files you want to diff later for tampering. Copy them somewhere first.

## `nuke_cron.sh` — destroys your evidence

`rm -rf /etc/cron.d/*` and `crontab -r` for every user removes the attacker's persistence
*and* the proof of it. Incident reports score 15% and need evidence. Capture first:

```sh
sudo ./bluesweep.sh --full --ir /root/ir-$(hostname)   # then nuke
```

It also disables cron entirely, which breaks anything legitimate that depends on it.

## `chpass.sh` — broken shebang, and it misses accounts

```sh
!#/bin/bash        # reversed: should be #!/bin/bash
```

It also filters on `nologin` only, so accounts with `/bin/false`, `/usr/sbin/nologin`, or
an empty shell field are skipped or clobbered depending on the box. Prefer the explicit
per-OS rotation in each cheatsheet, which targets accounts with real shells and a UID
in the human range.

## The hardening sheet's `ufw` block will lock you out

```sh
sudo ufw reset
sudo ufw default deny incoming     # <- SSH is now dead
sudo ufw enable
```

Allow your service ports *before* enabling. Every per-OS sheet has the correct order.

## Three items in that sheet break a SCORED service here

| Their advice | Why it loses points |
|---|---|
| `systemctl disable vsftpd` | FTP is a **scored service** on Pathfinder |
| MySQL `bind-address = 127.0.0.1` | MySQL is **scored remotely** on Pathfinder — localhost-only fails the check |
| SSH `PasswordAuthentication no` | Fine *only* if the scoring check uses keys. Confirm first, or you fail SSH on four hosts |

Same logic for `distccd` on Apollo and VNC on Hubble: both are indefensible by design and
both are scored. Harden their configuration; do not stop them.
