#!/bin/bash
# restore.sh — verify a backups.sh archive and restore paths from it.
# Companion to backups.sh.
#
#   ./restore.sh <archive.tar.gz>                 # verify checksum + list contents
#   ./restore.sh <archive.tar.gz> --extract DIR   # extract whole tree to DIR (no overwrite of live system)
#   ./restore.sh <archive.tar.gz> --restore /etc/ssh /etc/passwd   # copy listed paths back onto the live system
#
# --restore backs up each live target to <target>.prerestore.<epoch> first.

ARCHIVE="$1"; shift 2>/dev/null
[ -z "$ARCHIVE" ] && { echo "usage: $0 <archive.tar.gz> [--extract DIR | --restore PATH...]"; exit 1; }
[ -f "$ARCHIVE" ] || { echo "[!] archive not found: $ARCHIVE"; exit 1; }

echo "[*] Verifying checksum..."
if [ -f "${ARCHIVE}.sha256" ]; then
  if sha256sum -c "${ARCHIVE}.sha256" 2>/dev/null; then
    echo "[+] Checksum OK."
  else
    echo "[!] CHECKSUM MISMATCH — archive may be tampered. Aborting."
    exit 1
  fi
else
  echo "[i] No .sha256 alongside archive; skipping integrity check."
fi

# The tarball contains a single top dir: backup_YYYYMMDD_HHMMSS/
TOPDIR=$(tar -tzf "$ARCHIVE" 2>/dev/null | head -1 | cut -d/ -f1)

case "$1" in
  ""|--list)
    echo "[*] Contents:"
    tar -tzf "$ARCHIVE" | sed 's/^/    /' | head -200
    echo "    (showing first 200 entries)"
    ;;
  --extract)
    DEST="$2"; [ -z "$DEST" ] && { echo "usage: $0 $ARCHIVE --extract DIR"; exit 1; }
    mkdir -p "$DEST"
    tar -xzf "$ARCHIVE" -C "$DEST"
    echo "[+] Extracted to $DEST/$TOPDIR"
    ;;
  --restore)
    shift
    [ "$#" -eq 0 ] && { echo "usage: $0 $ARCHIVE --restore /path ..."; exit 1; }
    STAGE=$(mktemp -d)
    tar -xzf "$ARCHIVE" -C "$STAGE"
    SRC="$STAGE/$TOPDIR"
    for target in "$@"; do
      src="$SRC$target"     # backup preserved absolute paths under top dir
      if [ ! -e "$src" ]; then
        echo "    [skip] not in archive: $target"
        continue
      fi
      if [ -e "$target" ]; then
        mv "$target" "${target}.prerestore.$(date +%s)" 2>/dev/null \
          && echo "    saved live copy: ${target}.prerestore.*"
      fi
      mkdir -p "$(dirname "$target")"
      cp -a "$src" "$target" && echo "    restored: $target"
    done
    rm -rf "$STAGE"
    echo "[+] Restore complete. Live copies saved as <path>.prerestore.<epoch>."
    ;;
  *)
    echo "unknown option: $1"; exit 1 ;;
esac
