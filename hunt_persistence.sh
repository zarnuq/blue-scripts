#!/bin/bash
# hunt_persistence.sh — report common Linux persistence mechanisms.
# Report-only; makes no changes. Companion to nuke_cron.sh.

hr() { printf '\n===== %s =====\n' "$1"; }

hr "RC / STARTUP FILES"
for f in /etc/rc.local /etc/rc.d/rc.local; do
  [ -s "$f" ] && { echo "[$f]"; grep -vE '^\s*(#|$)' "$f"; }
done

hr "PROFILE / SHELL INIT (system-wide)"
for f in /etc/profile /etc/bash.bashrc; do
  [ -e "$f" ] && { echo "[$f]"; grep -nE 'curl|wget|nc |ncat|/dev/tcp|base64|python.*-c|bash -i|LD_PRELOAD' "$f" 2>/dev/null; }
done
for d in /etc/profile.d; do
  [ -d "$d" ] && ls -la "$d"
done

hr "PER-USER SHELL INIT BACKDOORS"
for home in /root /home/*; do
  [ -d "$home" ] || continue
  for rc in .bashrc .bash_profile .profile .bash_login .zshrc; do
    f="$home/$rc"
    [ -e "$f" ] || continue
    hits=$(grep -nE 'curl|wget|/dev/tcp|nc |ncat|socat|bash -i|python.*-c|base64 -d|LD_PRELOAD' "$f" 2>/dev/null)
    [ -n "$hits" ] && { echo "[$f]"; echo "$hits"; }
  done
done

hr "LD_PRELOAD / LD.SO.PRELOAD"
[ -s /etc/ld.so.preload ] && { echo "[/etc/ld.so.preload]"; cat /etc/ld.so.preload; }
grep -RsnE 'LD_PRELOAD' /etc/environment /etc/profile /etc/profile.d 2>/dev/null

hr "SYSTEMD SERVICES WITH SUSPICIOUS ExecStart"
for unit_path in /etc/systemd/system/*.service /etc/systemd/system/*/*.service; do
  [ -e "$unit_path" ] || continue
  exec_line=$(grep -h '^ExecStart' "$unit_path" 2>/dev/null)
  case "$exec_line" in
    *tmp/*|*/dev/shm*|*curl*|*wget*|*/dev/tcp*|*nc\ *|*ncat*|*socat*|*base64*|*python*-c*|*bash\ -i*|*-e\ /bin*)
      echo "[$unit_path]"; echo "  $exec_line" ;;
  esac
done

hr "SYSTEMD TIMERS NOT SHIPPED BY DISTRO"
for t in $(systemctl list-unit-files --type=timer --no-legend 2>/dev/null | awk '{print $1}'); do
  p=$(systemctl show -p FragmentPath --value "$t" 2>/dev/null)
  case "$p" in /lib/systemd/*|/usr/lib/systemd/*) : ;; *) [ -n "$p" ] && echo "$t -> $p" ;; esac
done

hr "@reboot CRON ENTRIES"
grep -RsE '@reboot' /etc/cron* /var/spool/cron 2>/dev/null

hr "INIT.D SCRIPTS (non-package, mtime last 30d)"
find /etc/init.d -type f -mtime -30 2>/dev/null

hr "SUID BINARIES IN UNUSUAL LOCATIONS"
find / -xdev -perm -4000 -type f 2>/dev/null | grep -vE '^/(usr/)?(s?bin)/'

hr "MOTD / update-motd HOOKS"
ls -la /etc/update-motd.d 2>/dev/null

echo ""
echo "[+] Persistence sweep complete. Review anything above by hand."
