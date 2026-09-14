#!/usr/bin/bash
# discovery.sh — sweep for common red-team artifacts and suspicious state.

LOG="sussy.log"
: > "$LOG"

section() { printf '\n--- %s ---\n' "$1" >> "$LOG"; }

section "BEACON SEARCH"
sudo find / -name "*beacon*" 2>/dev/null >> "$LOG"

section "RED-TEAM SEARCH"
sudo find / -name "*red-team*" 2>/dev/null >> "$LOG"

section "SUID / SGID BINARIES"
sudo find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null >> "$LOG"

section "WORLD-WRITABLE FILES"
sudo find / -xdev -type f -perm -0002 2>/dev/null >> "$LOG"

section "FILES MODIFIED IN LAST 24h (excluding /proc /sys /run)"
sudo find / -xdev -type f -mmin -1440 2>/dev/null \
  | grep -vE '^/(proc|sys|run)/' >> "$LOG"

section "LISTENING SOCKETS"
sudo ss -tulpn 2>/dev/null >> "$LOG"

section "ESTABLISHED CONNECTIONS"
sudo ss -tanp state established 2>/dev/null >> "$LOG"

section "SYSTEMD TIMERS"
systemctl list-timers --all 2>/dev/null >> "$LOG"

echo "[+] Done. Results in $LOG"
