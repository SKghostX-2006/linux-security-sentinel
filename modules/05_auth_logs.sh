#!/usr/bin/env bash

echo "[+] Checking Authentication & Login Logs..."

if [ -f /var/log/auth.log ]; then
    FAILED_COUNT=$(grep -iE "failed password|authentication failure|invalid user" /var/log/auth.log 2>/dev/null | wc -l)
    echo "    - Source: /var/log/auth.log"
    echo "    - Recorded failed/invalid login events: $FAILED_COUNT"
    if [ "$FAILED_COUNT" -gt 0 ]; then
        echo "    - Recent failed/invalid entries (last 5):"
        grep -iE "failed password|authentication failure|invalid user" /var/log/auth.log 2>/dev/null | tail -n 5 | while read -r line; do
            echo "        * $line"
        done
    fi
elif command -v journalctl >/dev/null 2>&1; then
    FAILED_COUNT=$(journalctl -u ssh -u systemd-logind --no-pager 2>/dev/null | grep -iE "failed password|authentication failure|invalid user" | wc -l)
    echo "    - Source: journalctl (auth/ssh units)"
    echo "    - Recorded failed/invalid login events: $FAILED_COUNT"
else
    echo "    - Warning: No /var/log/auth.log or journalctl found on this system."
fi