#!/bin/bash
# ssh_keys.sh — enumerate every authorized_keys and print fingerprints.
# Optionally strip keys NOT listed in an allowlist file.
#
#   ./ssh_keys.sh                       # list all keys + fingerprints
#   ./ssh_keys.sh --strip allow.txt     # keep only keys whose fingerprint or
#                                        # full line appears in allow.txt; the
#                                        # rest are removed (a .bak is kept)
#
# allow.txt may contain full pubkey lines OR SHA256 fingerprints (one per line).

STRIP=0
ALLOWFILE=""
if [ "$1" = "--strip" ]; then
  STRIP=1
  ALLOWFILE="$2"
  [ -z "$ALLOWFILE" ] && { echo "usage: $0 --strip <allowlist-file>"; exit 1; }
  [ -f "$ALLOWFILE" ] || { echo "allowlist not found: $ALLOWFILE"; exit 1; }
fi

# Build list of candidate authorized_keys locations.
find_ak_files() {
  # standard home locations
  for home in /root /home/*; do
    [ -d "$home" ] || continue
    for f in "$home/.ssh/authorized_keys" "$home/.ssh/authorized_keys2"; do
      [ -f "$f" ] && echo "$f"
    done
  done
  # any custom AuthorizedKeysFile paths in sshd_config
  grep -hriE '^\s*AuthorizedKeysFile' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null \
    | awk '{$1=""; print}' | tr ' ' '\n' | grep -E '^/' | while read -r p; do
      [ -f "$p" ] && echo "$p"
    done
  # catch-all: any authorized_keys anywhere (slow but thorough)
  find / -xdev -name 'authorized_keys*' -type f 2>/dev/null
}

mapfile -t AK_FILES < <(find_ak_files | sort -u)

fp_of_line() {
  # SHA256 fingerprint of a single pubkey line
  printf '%s\n' "$1" | ssh-keygen -lf /dev/stdin 2>/dev/null | awk '{print $2}'
}

for f in "${AK_FILES[@]}"; do
  printf '\n===== %s =====\n' "$f"
  ln=0
  while IFS= read -r line; do
    ln=$((ln+1))
    case "$line" in ''|\#*) continue ;; esac
    fp=$(fp_of_line "$line")
    comment=$(echo "$line" | awk '{print $NF}')
    printf '  [%d] %s  (%s)\n' "$ln" "${fp:-<unparseable>}" "$comment"
  done < "$f"
done

if [ "$STRIP" = 1 ]; then
  echo ""
  echo "[*] Stripping keys not present in $ALLOWFILE ..."
  for f in "${AK_FILES[@]}"; do
    tmp="$(mktemp)"
    removed=0
    while IFS= read -r line; do
      case "$line" in ''|\#*) printf '%s\n' "$line" >> "$tmp"; continue ;; esac
      fp=$(fp_of_line "$line")
      if grep -qxF "$line" "$ALLOWFILE" 2>/dev/null || { [ -n "$fp" ] && grep -qF "$fp" "$ALLOWFILE" 2>/dev/null; }; then
        printf '%s\n' "$line" >> "$tmp"
      else
        removed=$((removed+1))
        echo "    removed from $f : ${fp:-$line}"
      fi
    done < "$f"
    if [ "$removed" -gt 0 ]; then
      cp -p "$f" "${f}.bak.$(date +%s)"
      cat "$tmp" > "$f"
    fi
    rm -f "$tmp"
  done
  echo "[+] Strip complete. Backups saved as <file>.bak.<epoch>."
else
  echo ""
  echo "[i] List only. Re-run with --strip <allowlist-file> to remove unknown keys."
fi
