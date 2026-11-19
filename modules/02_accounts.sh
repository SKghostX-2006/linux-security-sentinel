#!/usr/bin/env bash

echo "[+] Checking User Accounts & Privileges..."

# Find all accounts with UID 0 (only 'root' should normally have UID 0)
UID0_USERS=$(awk -F: '$3 == 0 {print $1}' /etc/passwd)
echo "    - Accounts with UID 0: $UID0_USERS"

# List human/interactive users (UID >= 1000 with a valid login shell)
echo "    - Interactive users (UID >= 1000):"
awk -F: '$3 >= 1000 && $7 !~ /(nologin|false)$/ {print "        * " $1 " (UID: " $3 ", Shell: " $7 ")"}' /etc/passwd

# Check if root account has a locked or set password
ROOT_STATUS=$(passwd -S root 2>/dev/null | awk '{print $2}')
echo "    - Root password status: ${ROOT_STATUS:-unknown}"