#!/bin/bash
# nuke_cron.sh — stop cron, wipe all cron jobs and files

echo "[*] Stopping cron daemon..."
systemctl stop cron    2>/dev/null
systemctl stop crond   2>/dev/null
systemctl stop anacron 2>/dev/null

echo "[*] Removing all user crontabs..."
for user in $(cut -f1 -d: /etc/passwd); do
  crontab -r -u "$user" 2>/dev/null && echo "    removed: $user"
done

echo "[*] Wiping cron spool files..."
rm -rf /var/spool/cron/crontabs/*
rm -rf /var/spool/cron/*

echo "[*] Wiping /etc/cron.*  and /etc/crontab..."
rm -f  /etc/crontab
rm -rf /etc/cron.d/*
rm -rf /etc/cron.hourly/*
rm -rf /etc/cron.daily/*
rm -rf /etc/cron.weekly/*
rm -rf /etc/cron.monthly/*

echo "[*] Wiping anacron jobs..."
rm -rf /etc/anacrontab
rm -rf /var/spool/anacron/*

echo "[*] Removing cron.allow / cron.deny..."
rm -f /etc/cron.allow /etc/cron.deny 2>/dev/null

echo "[*] Disabling and removing suspicious systemd timers..."
# List timers before nuking, for the record
systemctl list-timers --all 2>/dev/null
for timer in $(systemctl list-unit-files --type=timer --no-legend 2>/dev/null | awk '{print $1}'); do
  # Leave core system timers alone; drop anything not shipped under /usr/lib or /lib
  unit_path=$(systemctl show -p FragmentPath --value "$timer" 2>/dev/null)
  case "$unit_path" in
    /lib/systemd/*|/usr/lib/systemd/*) : ;;   # distro-shipped, keep
    *)
      systemctl stop "$timer" 2>/dev/null
      systemctl disable "$timer" 2>/dev/null
      [ -n "$unit_path" ] && [ -e "$unit_path" ] && rm -f "$unit_path" && echo "    removed timer: $unit_path"
      ;;
  esac
done
systemctl daemon-reload 2>/dev/null

echo "[*] Disabling and masking cron on boot..."
for svc in cron crond anacron atd; do
  systemctl disable "$svc" 2>/dev/null
  systemctl mask    "$svc" 2>/dev/null
done

echo "[*] Removing cron/at binaries and packages..."
# Kill anything still running first
pkill -9 -x cron    2>/dev/null
pkill -9 -x crond   2>/dev/null
pkill -9 -x anacron 2>/dev/null
pkill -9 -x atd     2>/dev/null

# Remove the binaries wherever they live on PATH or common locations
for bin in cron crond crontab anacron at atd atq atrm batch; do
  for path in $(command -v -a "$bin" 2>/dev/null) \
              "/usr/sbin/$bin" "/usr/bin/$bin" "/sbin/$bin" "/bin/$bin"; do
    [ -e "$path" ] && rm -f "$path" && echo "    removed binary: $path"
  done
done

# Remove packages so nothing gets reinstalled/repaired on update
if command -v apt-get >/dev/null 2>&1; then
  apt-get purge -y cron cronie anacron at 2>/dev/null
elif command -v dnf >/dev/null 2>&1; then
  dnf remove -y cronie cronie-anacron at 2>/dev/null
elif command -v yum >/dev/null 2>&1; then
  yum remove -y cronie cronie-anacron at 2>/dev/null
elif command -v zypper >/dev/null 2>&1; then
  zypper --non-interactive remove cron cronie at 2>/dev/null
elif command -v apk >/dev/null 2>&1; then
  apk del dcron cronie busybox-suid at 2>/dev/null
elif command -v emerge >/dev/null 2>&1; then
  emerge --unmerge sys-process/cronie sys-process/dcron sys-process/at 2>/dev/null
fi

echo "[*] Wiping at spool and job files..."
rm -rf /var/spool/cron/atjobs/* /var/spool/cron/atspool/* /var/spool/at/* 2>/dev/null
rm -f  /etc/at.allow /etc/at.deny 2>/dev/null

echo "[+] Done. All cron/at jobs removed, daemons stopped, binaries and packages purged."
