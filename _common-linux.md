# Common Linux playbook

Everything here applies to Apollo, Hubble, Pathfinder, Sat and Wazuh. The per-OS sheets
only carry what is specific to that box.

## 1. Rotate credentials (first, before anything else)

Every account ships as `Passw0rd123!`. Replaces the broken `chpass.sh`:

```sh
# Human accounts only: UID >= 1000 plus root, and only accounts with a real shell.
read -rsp 'New password: ' P; echo
awk -F: '($3>=1000 || $3==0) && $7 !~ /(nologin|false|sync|halt|shutdown)$/ {print $1}' /etc/passwd \
  | while read -r u; do printf '%s:%s\n' "$u" "$P"; done | sudo chpasswd
unset P
```

Then verify nothing was missed and nothing has an empty password:

```sh
sudo awk -F: '$2==""{print "EMPTY PASSWORD: "$1}' /etc/shadow
sudo awk -F: '$3==0{print "UID 0: "$1}' /etc/passwd        # should be root only
```

## 2. Accounts, keys and sudo

```sh
# Anyone who can become root
getent group sudo wheel adm 2>/dev/null
sudo grep -rvE '^\s*(#|$)' /etc/sudoers /etc/sudoers.d/ 2>/dev/null

# Every SSH key on the box, with its owner
sudo awk -F: '$6 ~ /^\//{print $1" "$6}' /etc/passwd | while read -r u h; do
  for f in "$h"/.ssh/authorized_keys*; do
    [ -f "$f" ] && sed "s|^|$u $f: |" "$f"
  done
done

# Forced-command and restricted keys hide backdoors in the options field
sudo grep -rE 'command=|no-pty|permitopen' /root/.ssh /home/*/.ssh 2>/dev/null
```

Remove what you did not put there. Note the key **before** deleting it — it is incident
report evidence.

## 3. Who is on the box right now

```sh
who -a; w
sudo last -20
sudo ss -tnp state established            # every live TCP session with its PID
sudo ss -tlnp                             # every listener
```

Anything you cannot attribute to a scored service is a lead. Kill a session only after
recording user, source IP, PID and start time.

## 4. Baseline, then diff (the single highest-value habit)

```sh
sudo ./bluesweep.sh --full --baseline /root/base-$(hostname).snap   # before T+30
sudo ./bluesweep.sh --diff /root/base-$(hostname).snap              # every 15-20 min
```

Watch for `ADDED` at CRIT: `SSHKEY`, `USER`, `CRON`, `KERNELEXEC`, `BPFPIN`, `BINFMT`,
`HIDDENSYS`, `TCPWRAP`. None of those appear on a healthy running host.

## 5. Persistence sweep

Capture evidence before deleting anything.

```sh
sudo ./bluesweep.sh --full --ir /root/ir-$(hostname)
```

Places people forget, all of which bluesweep now checks:

```sh
cat /proc/sys/kernel/core_pattern      # a leading | means the kernel runs that program as root
cat /proc/sys/kernel/modprobe          # should be /sbin/modprobe
cat /sys/kernel/uevent_helper          # should be empty
ls -la /etc/network/if-up.d /etc/update-motd.d /etc/profile.d /etc/cron.*
ls -la /proc/sys/fs/binfmt_misc/ 2>/dev/null
cat /etc/hosts.allow                   # spawn/twist run shell commands
sudo ls -la /sys/fs/bpf/               # pinned eBPF objects
sudo cat /etc/ld.so.preload            # should not exist
grep -rE 'ProxyCommand|LocalCommand' /etc/ssh/ssh_config* /root/.ssh/config 2>/dev/null
```

## 6. Firewall — correct order, so you do not lock yourself out

```sh
sudo cp /etc/nftables.conf /root/nftables.conf.bak 2>/dev/null
sudo ufw allow 22/tcp                  # ALLOW FIRST
# ...then every scored port for this host (see its sheet)
sudo ufw default deny incoming
sudo ufw enable
sudo ufw status numbered
```

Blocking an attacker (single IPs only — subnets are against the rules):

```sh
sudo ufw insert 1 deny from 10.x.x.x
```

**Check both backends.** On Debian/Ubuntu `iptables` is the nftables shim, but legacy
x_tables can still hold rules, and neither tool shows the other's:

```sh
sudo nft list ruleset | head -40
sudo iptables-legacy-save 2>/dev/null | grep -c '^-A'    # non-zero = legacy rules ALSO live
```

Making a ruleset stick against a flush — re-apply on a timer rather than trusting one write:

```sh
sudo nft -f /etc/nftables.conf        # atomic; run from a 60s systemd timer
```

## 7. Block module loading (do this LAST)

The direct defence against a kernel rootkit, at zero downtime and no reboot:

```sh
sudo modprobe nf_conntrack_ftp nf_nat_ftp      # preload what you still need
sudo sysctl -w kernel.modules_disabled=1       # one-way until reboot
```

It blocks *all* autoloading, so anything needing a module later fails. Do it after every
service is up and your firewall is loaded. On Pathfinder this matters: FTP data
connections need `nf_conntrack_ftp`.

## 8. Kernel privilege-escalation exploits (Dirty Pipe / Dirty COW class)

**First: check whether you are even vulnerable.** These are old bugs and the comp images
are almost certainly already patched.

```sh
uname -r
```

| Exploit | Fixed in | Your boxes |
|---|---|---|
| Dirty COW (CVE-2016-5195) | 4.8.3 / backports, 2016 | Patched everywhere |
| Dirty Pipe (CVE-2022-0847) | 5.16.11, 5.15.25, 5.10.102 | Debian 12 is 6.1, Ubuntu 22.04 is 5.15.0-25+, Ubuntu 24.04 is 6.8 — all patched |

DirtyCred and Dirty Pagetable are exploitation *techniques* rather than single CVEs; there
is no single patch for them, which is why the mitigations below matter more than chasing a
version number.

**You cannot patch your way out of this mid-game.** A kernel update needs a reboot, which
is guaranteed downtime against a 50% uptime score. Don't.

**The premise is the real defence.** Every one of these is *local* privilege escalation —
it needs the attacker to already be running code as some user. They almost never come in
through a kernel 0-day; they come in through `Passw0rd123!`, a sudo misconfiguration, a
SUID GTFOBin, or a webshell. Fix those and the kernel bug never gets a chance.

**Mitigations that need no reboot.** Apply after services are up:

```sh
# Kills a large class of kernel exploits that get CAP_SYS_ADMIN via a user namespace
sudo sysctl -w kernel.unprivileged_userns_clone=0          # Debian 12 / Ubuntu 22.04
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=1   # Ubuntu 24.04

# eBPF verifier bugs are one of the most productive privesc sources going
sudo sysctl -w kernel.unprivileged_bpf_disabled=1
sudo sysctl -w net.core.bpf_jit_harden=2

# Deny the info leaks exploits need to defeat KASLR
sudo sysctl -w kernel.kptr_restrict=2
sudo sysctl -w kernel.dmesg_restrict=1
sudo sysctl -w kernel.perf_event_paranoid=3

# Stop one process reading another's memory (credential theft, injection)
sudo sysctl -w kernel.yama.ptrace_scope=1

# Classic symlink/hardlink race protections
sudo sysctl -w fs.protected_symlinks=1 fs.protected_hardlinks=1
sudo sysctl -w fs.protected_fifos=2 fs.protected_regular=2
```

Check each took effect — some are unavailable depending on kernel config:

```sh
for k in kernel.unprivileged_userns_clone kernel.unprivileged_bpf_disabled          kernel.kptr_restrict kernel.yama.ptrace_scope; do
  printf '%-40s %s\n' "$k" "$(sysctl -n $k 2>/dev/null || echo 'not available')"
done
```

**Block the drop-and-run pattern.** Most exploits land in `/tmp` or `/dev/shm` and are
executed there:

```sh
sudo mount -o remount,noexec,nosuid,nodev /tmp
sudo mount -o remount,noexec,nosuid,nodev /dev/shm
sudo mount -o remount,noexec,nosuid,nodev /var/tmp
```

Caveat: some package operations need exec on `/tmp`. If `apt` starts failing, that is why —
remount exec, do the work, remount noexec.

**Remove the SUID binaries that make privesc trivial.** bluesweep flags these as `SUI010`
(CRIT — a SUID shell or interpreter), `SUI011` and `SUI012`:

```sh
sudo ./bluesweep.sh --full --raw | grep -E 'SUI01[012]'
sudo find / -xdev -perm -4000 -type f -ls 2>/dev/null
```

Anything on GTFOBins with the setuid bit is game over. Strip the bit rather than deleting
the file: `sudo chmod u-s /path/to/binary`.

**Detect rather than only prevent.** Successful exploitation usually modifies a system
binary or drops a SUID file, and your baseline catches both:

```sh
sudo ./bluesweep.sh --diff /root/base-$(hostname).snap | grep -E 'ADDED SUID|CHANGED FILE'
```

## 9. Monitoring for the rest of the game

```sh
sudo tail -f /var/log/auth.log                       # Debian/Ubuntu
watch -n5 'ss -tlnp; echo; ss -tnp state established'
sudo journalctl -f -u ssh -u sshd
```

Wazuh is on the management subnet and red team will not touch it — use its alerts.
**Never stop or remove `wazuh-agent`.**

## 10. Kernel replacement — don't

A kernel swap needs a reboot, which is guaranteed downtime against a 50% uptime score plus
the risk of not coming back. `kexec` still tears down every process. Live patching only
applies vendor CVE patches and cannot evict a rootkit — and if they still hold root, the
module gets reloaded anyway. Use `kernel.modules_disabled=1` above instead.
