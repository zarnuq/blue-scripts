# Blue Crew field notes — RVB 2026 (Artemis Ground Station)

Per-OS cheatsheets for the six distinct platforms on the board. Open the one for the
box you are on; everything here applies everywhere.

| Box | OS | Address | Scored services |
|---|---|---|---|
| [Apollo](apollo-debian-12.md) | Debian 12 | `10.x.2.10` | SSH, DNS, HTTP-DNSGui, distcc |
| [Hubble](hubble-ubuntu-24.04.md) | Ubuntu 24.04 | `10.x.2.11` | SSH, SMTP, HTTP, VNC — also the satellite HMI |
| [Pathfinder](pathfinder-ubuntu-22.04.md) | Ubuntu 22.04 | `10.x.2.12` | SSH, FTP, HTTP, MySQL |
| [Sat](sat-ubuntu-22.04.md) | Ubuntu 22.04 | `10.x.2.13` | Modbus TCP |
| [Wazuh](wazuh-ubuntu-24.04.md) | Ubuntu 24.04 | mgmt | none — your telemetry |
| [Columbia](columbia-windows-server-2022.md) | Windows Server 2022 | `10.x.1.10` | LDAP/LDAPS, SMB, WinRM — likely the DC |
| [Odyssey](odyssey-windows-server-2022.md) | Windows Server 2022 | `10.x.1.11` | MSSQL, SMB, WinRM |
| [Sputnik](sputnik-windows-10.md) | Windows 10 | `10.x.1.12` | SMB, WinRM |
| [Router](router-opnsense.md) | OPNsense | `172.16.x.3` | SSH, HTTPS |

## Start here

- **[00-DANGER.md](00-DANGER.md)** — corrections to the scripts already in this folder.
  Three of them will cost you uptime if run as-is. Read it before running them.
- **[_common-linux.md](_common-linux.md)** — shared Linux playbook. Every Linux box sheet
  assumes you have done this first.
- **[_common-windows.md](_common-windows.md)** — shared Windows playbook. Same deal for the
  three Windows boxes.
- `hardening cheat sheet.md` — the original NCAE notes, kept for reference. Its ufw,
  vsftpd and MySQL advice is wrong *for this competition*; 00-DANGER explains why.

## The five rules that decide your score

1. **Uptime is 50%.** Every action below is subordinate to that. A service you hardened
   into unavailability scores identically to one the red team took down.
2. **Every account ships as `Passw0rd123!`.** This is how you lose in the first ten
   minutes. Rotate before anything else.
3. **Never remove `wazuh-agent`.** It is not red team. It is your telemetry and the
   packet forbids touching it.
4. **Block single IPs only.** Subnet blocks are against the rules.
5. **No incident report scores without proof:** processes they ran, intruder IPs,
   accounts used, sessions hijacked.

## T-30: the only thing you must not skip

Red goes active 30 minutes after start. Baseline every box *before* that, or you spend
the rest of the day guessing what was always there.

```sh
# On each Linux host
sudo ./bluesweep.sh --full --baseline /root/base-$(hostname).snap

# Then, repeatedly, for the rest of the game
sudo ./bluesweep.sh --diff /root/base-$(hostname).snap
```

A diff turns "is this weird?" into "this was not here at 10:00." That is the difference
between a hunch and an incident report that scores.

## Order of work, first 30 minutes

1. Rotate every password (each cheatsheet has the command).
2. Inventory and remove unexpected accounts, SSH keys, sudoers entries.
3. Baseline with bluesweep.
4. Harden the scored service *without moving it* — you may relocate services, but the
   checks stay the same, so relocation buys risk and no points.
5. Only then: firewall, auditing, module lockdown.

## Flags

Store tokens come from `ARTEMIS{...}` flags planted on the systems.

```sh
sudo ./bluesweep.sh --full --hunt 'ARTEMIS\{'
sudo grep -rIal 'ARTEMIS{' / --exclude-dir={proc,sys,dev} 2>/dev/null
```

## What bluesweep will not tell you

It reads the kernel and the filesystem. It does not inspect process memory, cannot
verify a packaged binary that was modified in place beyond what `dpkg --verify` sees,
and has no view of MySQL internals or Windows. Clean output means "nothing sloppy
found," never "clean host."
