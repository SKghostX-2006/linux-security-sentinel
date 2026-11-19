#!/usr/bin/env bash

echo "[+] Checking Listening Network Ports & Sockets..."

if command -v ss >/dev/null 2>&1; then
    echo "    - Tool: ss (listening TCP/UDP sockets)"
    LISTENERS=$(ss -tulnp 2>/dev/null | tail -n +2)
    if [ -z "$LISTENERS" ]; then
        echo "        * No listening sockets detected."
    else
        echo "$LISTENERS" | while read -r line; do
            echo "        * $line"
        done
    fi
elif command -v netstat >/dev/null 2>&1; then
    echo "    - Tool: netstat (listening TCP/UDP sockets)"
    netstat -tulnp 2>/dev/null | tail -n +3 | while read -r line; do
        echo "        * $line"
    done
else
    echo "    - Warning: Neither 'ss' nor 'netstat' is installed."
fi