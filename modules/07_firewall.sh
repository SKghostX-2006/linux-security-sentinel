#!/usr/bin/env bash

echo "[+] Checking Host Firewall Status..."

if command -v ufw >/dev/null 2>&1; then
    UFW_STATUS=$(ufw status 2>/dev/null | head -n 1)
    echo "    - UFW Status: ${UFW_STATUS:-unknown}"
    if echo "$UFW_STATUS" | grep -qi "active"; then
        RULE_COUNT=$(ufw status numbered 2>/dev/null | grep -c "^\[" || true)
        echo "    - Active UFW rules: $RULE_COUNT"
    fi
else
    echo "    - UFW: Not installed."
fi

if command -v iptables >/dev/null 2>&1; then
    IPTABLES_RULES=$(iptables -S 2>/dev/null | grep -v "^-P " | wc -l)
    echo "    - Non-default iptables rules: $IPTABLES_RULES"
else
    echo "    - iptables: Not available."
fi