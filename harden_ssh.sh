#!/bin/bash
# harden_ssh.sh — back up and harden sshd_config, validate, then reload.
# Set KEEP_PASSWORD_AUTH=1 to leave PasswordAuthentication enabled
# (e.g. if you still rely on password logins for scoring).

CFG="/etc/ssh/sshd_config"
[ -f "$CFG" ] || { echo "[!] $CFG not found"; exit 1; }

BAK="${CFG}.bak.$(date +%Y%m%d_%H%M%S)"
cp -p "$CFG" "$BAK"
echo "[+] Backed up $CFG -> $BAK"

# set_opt <Key> <Value> : replace existing (commented or not), else append.
set_opt() {
  local key="$1" val="$2"
  if grep -qiE "^\s*#?\s*${key}\b" "$CFG"; then
    sed -ri "s|^\s*#?\s*(${key})\b.*|\1 ${val}|I" "$CFG"
  else
    printf '%s %s\n' "$key" "$val" >> "$CFG"
  fi
  echo "    set: $key $val"
}

echo "[*] Applying hardening options..."
set_opt PermitRootLogin no
set_opt PermitEmptyPasswords no
set_opt X11Forwarding no
set_opt AllowTcpForwarding no
set_opt ClientAliveInterval 300
set_opt ClientAliveCountMax 2
set_opt MaxAuthTries 3
set_opt LoginGraceTime 30
set_opt UsePAM yes
set_opt IgnoreRhosts yes
set_opt HostbasedAuthentication no
set_opt Protocol 2

if [ "${KEEP_PASSWORD_AUTH:-0}" = "1" ]; then
  echo "    (leaving PasswordAuthentication as-is per KEEP_PASSWORD_AUTH=1)"
else
  set_opt PasswordAuthentication no
  set_opt PubkeyAuthentication yes
fi

echo "[*] Validating config with sshd -t..."
if sshd -t 2>/tmp/sshd_test.$$; then
  echo "[+] Config valid. Reloading sshd..."
  systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null \
    || service ssh reload 2>/dev/null || service sshd reload 2>/dev/null
  echo "[+] Done."
else
  echo "[!] sshd -t FAILED — NOT reloading. Restoring backup."
  cat /tmp/sshd_test.$$
  cp -p "$BAK" "$CFG"
  echo "[+] Restored $CFG from $BAK"
fi
rm -f /tmp/sshd_test.$$

echo ""
echo "[i] Reminder: if you disabled PasswordAuthentication, confirm your key"
echo "    login works in a SEPARATE session before closing this one."
