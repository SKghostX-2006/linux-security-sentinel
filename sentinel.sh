#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  echo "[-] Error: Please run this script with sudo (e.g., sudo ./sentinel.sh)"
  exit 1
fi

MODULES_DIR="./modules"
REPORTS_DIR="./reports"
mkdir -p "$REPORTS_DIR"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_FILE="$REPORTS_DIR/audit_${TIMESTAMP}.txt"

if [ ! -d "$MODULES_DIR" ]; then
  echo "[-] Error: Modules directory not found at $MODULES_DIR"
  exit 1
fi

RAW_OUTPUT=$(mktemp)
trap 'rm -f "$RAW_OUTPUT"' EXIT

{
  echo "====================================================="
  echo "       LINUX SECURITY SENTINEL - AUDIT REPORT        "
  echo "====================================================="
  echo "Timestamp: $(date)"
  echo "-----------------------------------------------------"

  for module in "$MODULES_DIR"/*.sh; do
    if [ -f "$module" ]; then
      echo "[*] Running module: $(basename "$module")"
      bash "$module"
      echo "-----------------------------------------------------"
    fi
  done
} > "$RAW_OUTPUT"

# Baseline score of 100; subtract points for detected findings
SCORE=100

# 1. Extra UID 0 users beyond root (-30 each)
UID0_LINE=$(grep -E "Accounts with UID 0:" "$RAW_OUTPUT" | head -n 1)
UID0_LIST=$(echo "$UID0_LINE" | sed 's/.*Accounts with UID 0:[[:space:]]*//')
for u in $UID0_LIST; do
  if [ "$u" != "root" ]; then
    SCORE=$((SCORE - 30))
  fi
done

# 2. World-writable files (-15)
if grep -q "World-writable files in /etc and /var/tmp" "$RAW_OUTPUT" && ! grep -q "None found in scanned paths." "$RAW_OUTPUT"; then
  SCORE=$((SCORE - 15))
fi

# 3. File integrity mismatch (-25)
if grep -q "WARNING: Hash mismatch or missing file detected" "$RAW_OUTPUT"; then
  SCORE=$((SCORE - 25))
fi

# 4. Failed login attempts (-2 each, max -20)
FAILED_LOGINS=$(grep -E "Recorded failed/invalid login events:" "$RAW_OUTPUT" | awk -F: '{print $NF}' | tr -d ' ' | head -n 1)
if [[ "$FAILED_LOGINS" =~ ^[0-9]+$ ]] && [ "$FAILED_LOGINS" -gt 0 ]; then
  PENALTY=$((FAILED_LOGINS * 2))
  [ "$PENALTY" -gt 20 ] && PENALTY=20
  SCORE=$((SCORE - PENALTY))
fi

# 5. Firewall inactive, unknown, or not installed (-10)
if grep -qE "UFW Status:.*(inactive|unknown)|UFW: Not installed" "$RAW_OUTPUT"; then
  SCORE=$((SCORE - 10))
fi

# Clamp score between 0 and 100
[ "$SCORE" -lt 0 ] && SCORE=0
[ "$SCORE" -gt 100 ] && SCORE=100

if [ "$SCORE" -ge 80 ]; then
  RATING="LOW RISK"
elif [ "$SCORE" -ge 50 ]; then
  RATING="MODERATE RISK"
else
  RATING="HIGH RISK"
fi

{
  cat "$RAW_OUTPUT"
  echo "Security Score: $SCORE / 100 ($RATING)"
  echo "Report Saved To: $REPORT_FILE"
  echo "[+] Audit complete!"
} | tee "$REPORT_FILE"