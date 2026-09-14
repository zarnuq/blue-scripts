#!/bin/bash
# kill_shells.sh — hunt (and optionally kill) reverse shells / suspicious procs.
# Default: report only.  Pass --kill to terminate what it finds.
#
# Allowlist outbound peers (space-separated) via ALLOW_IPS to reduce noise:
#   ALLOW_IPS="10.0.0.5 8.8.8.8" ./kill_shells.sh

KILL=0
[ "$1" = "--kill" ] && KILL=1
ALLOW_IPS="${ALLOW_IPS:-}"

pids_to_kill=()

note() { printf '%s\n' "$*"; }
hr()   { printf '\n===== %s =====\n' "$1"; }

hr "INTERACTIVE-SHELL PATTERNS"
# Match classic reverse-shell command lines.
while read -r pid cmd; do
  [ -z "$pid" ] && continue
  note "PID $pid : $cmd"
  pids_to_kill+=("$pid")
done < <(ps -eo pid=,args= 2>/dev/null | grep -E \
    'bash -i|sh -i|nc .*-e|ncat .*-e|socat .*(exec|system)|python[0-9.]* -c.*socket|perl -e.*socket|/dev/tcp/' \
    | grep -vE 'grep -E|kill_shells' \
    | awk '{pid=$1; $1=""; sub(/^ /,""); print pid" "$0}')

hr "PROCESSES RUNNING A DELETED BINARY"
for exe in /proc/[0-9]*/exe; do
  target=$(readlink "$exe" 2>/dev/null) || continue
  case "$target" in
    *"(deleted)")
      pid=$(basename "$(dirname "$exe")")
      cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
      note "PID $pid : $target : $cmd"
      pids_to_kill+=("$pid")
      ;;
  esac
done

hr "PROCESSES EXECUTING FROM /tmp, /dev/shm, /var/tmp"
while read -r pid; do
  [ -z "$pid" ] && continue
  target=$(readlink "/proc/$pid/exe" 2>/dev/null)
  case "$target" in
    /tmp/*|/dev/shm/*|/var/tmp/*)
      cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
      note "PID $pid : $target : $cmd"
      pids_to_kill+=("$pid")
      ;;
  esac
done < <(ls /proc | grep -E '^[0-9]+$')

hr "OUTBOUND CONNECTIONS TO NON-ALLOWLISTED PEERS"
ss -tanp state established 2>/dev/null | awk 'NR>1{print}' | while read -r line; do
  peer=$(echo "$line" | awk '{print $4}')     # local:port (col varies) — show full line
  ip=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | tail -n1)
  skip=0
  for a in $ALLOW_IPS 127.0.0.1; do [ "$ip" = "$a" ] && skip=1; done
  [ "$skip" = 1 ] && continue
  echo "$line"
done

if [ "$KILL" = 1 ] && [ "${#pids_to_kill[@]}" -gt 0 ]; then
  hr "KILLING FLAGGED PIDS"
  # de-dup
  for pid in $(printf '%s\n' "${pids_to_kill[@]}" | sort -un); do
    [ "$pid" = "$$" ] && continue
    kill -9 "$pid" 2>/dev/null && note "killed $pid"
  done
else
  echo ""
  echo "[i] Report only. Re-run with --kill to terminate the flagged PIDs above."
fi
