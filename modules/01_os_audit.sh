#!/usr/bin/env bash

echo "[+] Checking Operating System Details..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "    - Distribution: $NAME $VERSION"
else
    echo "    - Warning: /etc/os-release not found."
fi

KERNEL=$(uname -r)
echo "    - Kernel Version: $KERNEL"

UPTIME=$(uptime -p)
echo "    - System Uptime: $UPTIME"