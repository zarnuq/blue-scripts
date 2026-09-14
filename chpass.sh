#!/bin/bash
# chpass.sh — set a common password on all interactive (login-shell) accounts.
# Excludes root and non-login accounts (nologin / false) so scored service
# accounts and root are left alone.

read -rsp "New password for all interactive users: " P
echo

# Accounts with a real login shell, minus root and the nologin/false shells.
awk -F: '$7 !~ /(nologin|false)$/ && $1 != "root" {print $1}' /etc/passwd \
  | while read -r user; do
      echo "${user}:${P}" | sudo chpasswd && echo "    changed: $user"
    done
