#!/bin/bash
# kick_users.sh — show logged-in users; optionally kill sessions / lock accounts
# for anyone NOT on the allowlist.
#
#   ./kick_users.sh                         # just list sessions
#   ALLOW="miles blueteam" ./kick_users.sh --kick   # kill+lock everyone else
#
# --kick terminates the sessions AND locks (passwd -l) the offending accounts.

KICK=0
[ "$1" = "--kick" ] && KICK=1
ALLOW="${ALLOW:-root}"

hr() { printf '\n===== %s =====\n' "$1"; }

hr "CURRENTLY LOGGED IN (w)"
w -h 2>/dev/null

hr "LOGIN SESSIONS (loginctl)"
loginctl list-sessions --no-legend 2>/dev/null

hr "ACTIVE TTY / PTS OWNERS"
who 2>/dev/null

if [ "$KICK" = 1 ]; then
  hr "KICKING NON-ALLOWLISTED USERS"
  # Unique set of logged-in usernames
  for u in $(who 2>/dev/null | awk '{print $1}' | sort -u); do
    skip=0
    for a in $ALLOW; do [ "$u" = "$a" ] && skip=1; done
    if [ "$skip" = 1 ]; then
      echo "    keep: $u"
      continue
    fi
    echo "    kicking: $u"
    # terminate loginctl sessions for this user
    for s in $(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="$u" '$3==u{print $1}'); do
      loginctl terminate-session "$s" 2>/dev/null
    done
    loginctl terminate-user "$u" 2>/dev/null
    # kill any remaining processes owned by the user
    pkill -9 -u "$u" 2>/dev/null
    # lock the account so they can't log back in
    passwd -l "$u" 2>/dev/null && echo "        locked account: $u"
  done
  echo "[+] Done. Unlock later with: passwd -u <user>"
else
  echo ""
  echo "[i] Report only. Re-run with:  ALLOW=\"user1 user2\" $0 --kick"
fi
