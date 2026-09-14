#!/bin/bash
# lock_critical.sh — set the immutable flag (chattr +i) on critical files so
# they can't be modified/deleted, even by root, until unlocked.
#
#   ./lock_critical.sh            # lock
#   ./lock_critical.sh --unlock   # remove immutable flag
#   ./lock_critical.sh --status   # show current flags
#
# NOTE: while locked, package updates / passwd / usermod that touch these files
# WILL FAIL. Unlock before making legitimate changes, then re-lock.

FILES=(
  /etc/passwd
  /etc/shadow
  /etc/group
  /etc/gshadow
  /etc/sudoers
  /etc/ssh/sshd_config
  /etc/hosts
  /etc/crontab
  /etc/resolv.conf
  /etc/pam.d/common-auth
  /etc/pam.d/sshd
)

# Include every authorized_keys we can find.
mapfile -t AK < <(
  for h in /root /home/*; do
    [ -f "$h/.ssh/authorized_keys" ] && echo "$h/.ssh/authorized_keys"
  done
)
FILES+=("${AK[@]}")

MODE="${1:-lock}"

case "$MODE" in
  --unlock)
    echo "[*] Removing immutable flag..."
    for f in "${FILES[@]}"; do
      [ -e "$f" ] || continue
      chattr -i "$f" 2>/dev/null && echo "    unlocked: $f"
    done
    echo "[+] Done. Files are now writable."
    ;;
  --status)
    for f in "${FILES[@]}"; do
      [ -e "$f" ] || continue
      lsattr "$f" 2>/dev/null
    done
    ;;
  lock|"")
    echo "[*] Setting immutable flag..."
    for f in "${FILES[@]}"; do
      [ -e "$f" ] || continue
      if chattr +i "$f" 2>/dev/null; then
        echo "    locked: $f"
      else
        echo "    [!] could not lock (unsupported fs?): $f"
      fi
    done
    echo "[+] Done. Remember: run '$0 --unlock' before legitimate edits/updates."
    ;;
  *)
    echo "usage: $0 [--unlock|--status]"; exit 1 ;;
esac
