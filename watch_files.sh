#!/bin/bash
# watch_files.sh — lightweight file-integrity monitor. Hashes critical files on
# a loop and alerts on any change/add/delete. Poor-man's FIM for one round.
#
#   ./watch_files.sh                 # watch default set every 30s
#   INTERVAL=10 ./watch_files.sh     # custom interval (seconds)
#   ./watch_files.sh /path/a /path/b # watch a custom set of files/dirs
#
# Baseline + change log are written under /var/lib/bluewatch (falls back to /tmp).

INTERVAL="${INTERVAL:-30}"

STATE_DIR="/var/lib/bluewatch"
mkdir -p "$STATE_DIR" 2>/dev/null || STATE_DIR="/tmp/bluewatch"
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR" 2>/dev/null
BASELINE="$STATE_DIR/baseline.sha256"
CHANGELOG="$STATE_DIR/changes.log"

if [ "$#" -gt 0 ]; then
  TARGETS=("$@")
else
  TARGETS=(
    /etc/passwd /etc/shadow /etc/group /etc/gshadow /etc/sudoers
    /etc/ssh/sshd_config /etc/crontab /etc/hosts /etc/resolv.conf
    /etc/pam.d /etc/sudoers.d /etc/cron.d
    /root/.ssh/authorized_keys
  )
  for h in /home/*; do
    [ -f "$h/.ssh/authorized_keys" ] && TARGETS+=("$h/.ssh/authorized_keys")
  done
fi

snapshot() {
  for t in "${TARGETS[@]}"; do
    if [ -f "$t" ]; then
      sha256sum "$t" 2>/dev/null
    elif [ -d "$t" ]; then
      find "$t" -type f -print0 2>/dev/null | xargs -0 sha256sum 2>/dev/null
    fi
  done | sort -k2
}

echo "[*] Building baseline in $BASELINE ..."
snapshot > "$BASELINE"
echo "[+] Baseline has $(wc -l < "$BASELINE") files. Watching every ${INTERVAL}s."
echo "[i] Change log: $CHANGELOG   (Ctrl-C to stop)"
echo "----- $(date) : monitor started -----" >> "$CHANGELOG"

trap 'echo; echo "[+] Stopped."; exit 0' INT TERM

while true; do
  sleep "$INTERVAL"
  CUR="$(mktemp)"
  snapshot > "$CUR"
  if ! diff -q "$BASELINE" "$CUR" >/dev/null 2>&1; then
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "!!! [$ts] CHANGE DETECTED:"
    # Show what changed (added/removed/modified lines)
    diff <(awk '{print $2}' "$BASELINE") <(awk '{print $2}' "$CUR") | grep -E '^[<>]' \
      | sed 's/^</  REMOVED: /; s/^>/  ADDED:   /'
    # modified = same path, different hash
    join -j2 <(sort -k2 "$BASELINE") <(sort -k2 "$CUR") 2>/dev/null \
      | awk '$2 != $3 {print "  MODIFIED: "$1}'
    {
      echo "----- [$ts] change detected -----"
      diff "$BASELINE" "$CUR"
    } >> "$CHANGELOG"
    # roll baseline forward so we alert on each NEW change, not repeatedly
    cp "$CUR" "$BASELINE"
  fi
  rm -f "$CUR"
done
