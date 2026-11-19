#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  echo "[-] Error: Please run this script with sudo (e.g., sudo ./sentinel.sh)"
  exit 1
fi

echo "====================================================="
echo "       LINUX SECURITY SENTINEL - AUDIT STARTED       "
echo "====================================================="
echo "Timestamp: $(date)"
echo "-----------------------------------------------------"

MODULES_DIR="./modules"
if [ ! -d "$MODULES_DIR" ]; then
  echo "[-] Error: Modules directory not found at $MODULES_DIR"
  exit 1
fi

for module in "$MODULES_DIR"/*.sh; do
  if [ -f "$module" ]; then
    echo "[*] Running module: $(basename "$module")"
    bash "$module"
    echo "-----------------------------------------------------"
  fi
done

echo "[+] Audit complete!"