#!/usr/bin/env bash

echo "[+] Checking File Integrity Monitoring (SHA-256)..."

BASELINE_FILE="./baselines/critical_files.sha256"
TARGET_FILES="/etc/passwd /etc/group /etc/sudoers"

if [ ! -f "$BASELINE_FILE" ]; then
    sha256sum $TARGET_FILES > "$BASELINE_FILE" 2>/dev/null
    echo "    - Baseline created at $BASELINE_FILE"
    echo "    - Run again to compare current hashes against this baseline."
else
    MISMATCHES=$(sha256sum -c "$BASELINE_FILE" 2>/dev/null | grep -v ": OK$")
    if [ -z "$MISMATCHES" ]; then
        echo "    - Integrity check passed: all baselined files match."
    else
        echo "    - WARNING: Hash mismatch or missing file detected:"
        echo "$MISMATCHES" | while read -r line; do
            echo "        * $line"
        done
    fi
fi