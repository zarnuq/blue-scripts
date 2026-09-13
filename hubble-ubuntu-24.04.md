# Hubble — Ubuntu 24.04 `10.x.2.11`

**Scored: SSH (22), SMTP (25), HTTP (80), VNC (5900).**
Start with [_common-linux.md](_common-linux.md), then the below.

Hubble also runs the **HMI/PLC that is the only way to control the Satellite**. Losing
Hubble loses the satellite too, so treat its availability as double-weighted.

## VNC — the weakest thing on the board

VNC has an 8-character password limit and a challenge-response that has been broken for
twenty years, and it is often deployed with no password at all.

```sh
ps -o user:20,pid,cmd -C Xvnc -C x11vnc -C vncserver 2>/dev/null
ps aux | grep -iE 'vnc' | grep -v grep
```

Look for `-nopw`, `SecurityTypes=None`, `-localhost no`. bluesweep raises `SRV002` CRIT for
the first two.

What to do:

1. **Set a password** if there is none: `vncpasswd`. This is the single highest-value fix.
2. Check the password file is not world-readable: `ls -l ~/.vnc/passwd` → `600`.
3. **Do not move it off 5900** and do not bind it to localhost-only unless you have
   confirmed the check tunnels in. The scoring engine almost certainly connects direct.
4. Firewall 5900 to the scoring engine and your own hosts.
5. `-localhost yes` plus an SSH tunnel is the right answer in real life and the wrong
   answer here if the check connects directly. **Verify before you change it.**

## SMTP — do not become an open relay

```sh
sudo postconf -n | grep -E 'mynetworks|relay_domains|smtpd_recipient_restrictions|inet_interfaces'
```

- `mynetworks = 0.0.0.0/0` is an open relay. bluesweep flags it `SMTP002`.
- Keep `smtpd_recipient_restrictions` containing `reject_unauth_destination`.
- Check for aliases piping to a command — classic persistence:

```sh
sudo grep -E '\|' /etc/aliases /etc/postfix/aliases 2>/dev/null
sudo find /home /root -name '.forward' -ls 2>/dev/null
```

A `.forward` or alias containing `|/path/to/script` runs on every delivered mail. Then
`sudo newaliases`.

## HMI / PLC

```sh
sudo ss -tlnp | grep -vE ':22|:25|:80|:5900'     # anything else listening is a lead
sudo ss -tnp state established 'dport = :502'    # Hubble talking to the satellite
```

Do not break this path. If you firewall Sat's 502 to Hubble only (see [sat-ubuntu-22.04.md](sat-ubuntu-22.04.md)),
confirm Hubble can still reach it after every firewall change.

## HTTP

Same as [Pathfinder](pathfinder-ubuntu-22.04.md) — webshell scan, recent file check, `.htaccess`/`.user.ini`.

## Hubble firewall

```sh
sudo ufw allow 22/tcp; sudo ufw allow 25/tcp; sudo ufw allow 80/tcp; sudo ufw allow 5900/tcp
sudo ufw default deny incoming; sudo ufw enable
```
