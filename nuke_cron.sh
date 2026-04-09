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

echo "[*] Disabling cron on boot..."
systemctl disable cron    2>/dev/null
systemctl disable crond   2>/dev/null
systemctl disable anacron 2>/dev/null

echo "[+] Done. All cron jobs removed and daemons stopped."
