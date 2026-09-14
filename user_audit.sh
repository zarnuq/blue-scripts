#!/bin/bash
# user_audit.sh — report suspicious accounts and privilege state. Report-only.

hr() { printf '\n===== %s =====\n' "$1"; }

hr "UID 0 ACCOUNTS (should be root only)"
awk -F: '$3 == 0 {print $1" (uid=0, shell="$7")"}' /etc/passwd

hr "ACCOUNTS WITH EMPTY PASSWORD FIELD (/etc/shadow)"
sudo awk -F: '($2 == "" ) {print $1" -> EMPTY PASSWORD"}' /etc/shadow 2>/dev/null

hr "ACCOUNTS WITH A LOGIN SHELL"
awk -F: '$7 !~ /(nologin|false|sync|halt|shutdown)$/ {print $1" -> "$7}' /etc/passwd

hr "ACCOUNTS WITH PASSWORD SET BUT UID < 1000 (service accts shouldn't log in)"
sudo awk -F: '$2 ~ /^\$/ {print $1}' /etc/shadow 2>/dev/null | while read -r u; do
  uid=$(id -u "$u" 2>/dev/null)
  [ -n "$uid" ] && [ "$uid" -lt 1000 ] && [ "$u" != "root" ] && echo "$u (uid=$uid) has a password hash"
done

hr "MEMBERS OF sudo / wheel / admin / docker"
for g in sudo wheel admin docker adm; do
  m=$(getent group "$g" 2>/dev/null | cut -d: -f4)
  [ -n "$m" ] && echo "$g: $m"
done

hr "SUDOERS RULES (NOPASSWD / ALL highlighted)"
sudo grep -RhnE '^[^#]' /etc/sudoers /etc/sudoers.d 2>/dev/null \
  | grep -vE '^\s*(Defaults|#|$)' \
  | sed 's/^/  /'
echo "  --- NOPASSWD entries ---"
sudo grep -RhnE 'NOPASSWD' /etc/sudoers /etc/sudoers.d 2>/dev/null | sed 's/^/  /'

hr "ACCOUNTS NEVER-EXPIRE / NO AGING (root excluded)"
sudo awk -F: '$1!="root"{print $1}' /etc/shadow 2>/dev/null | while read -r u; do
  info=$(sudo chage -l "$u" 2>/dev/null | grep -i 'never' | head -1)
  [ -n "$info" ] && printf '  %-16s %s\n' "$u" "$info"
done

hr "RECENTLY MODIFIED /etc/passwd /etc/shadow /etc/sudoers"
ls -l --time-style=+%Y-%m-%d\ %H:%M /etc/passwd /etc/shadow /etc/sudoers 2>/dev/null

echo ""
echo "[+] User audit complete. Cross-check every login-shell and UID-0 account against your team's known-good list."
