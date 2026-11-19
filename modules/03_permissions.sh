#!/usr/bin/env bash

echo "[+] Checking File Permission Misconfigurations..."

# Scan key system/user paths for SUID or SGID executables (capped for speed)
echo "    - SUID/SGID binaries (top 10 in /usr/bin and /usr/local/bin):"
find /usr/bin /usr/local/bin -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | head -n 10 | while read -r bin; do
    perms=$(stat -c "%a" "$bin" 2>/dev/null)
    echo "        * $bin (Mode: $perms)"
done

# Check for world-writable files in /etc and /var/tmp (excluding /proc, /sys, /dev)
echo "    - World-writable files in /etc and /var/tmp (up to 10):"
WW_FILES=$(find /etc /var/tmp -type f -perm -0002 2>/dev/null | head -n 10)
if [ -z "$WW_FILES" ]; then
    echo "        * None found in scanned paths."
else
    echo "$WW_FILES" | while read -r f; do
        echo "        * $f"
    done
fi