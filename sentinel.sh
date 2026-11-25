#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run with sudo so all system checks can read logs and firewall rules: sudo ./sentinel.sh"
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
REMEDIATIONS=$(mktemp)
trap 'rm -f "$RAW_OUTPUT" "$REMEDIATIONS"' EXIT

{
  echo "=================================================================="
  echo "              LINUX SECURITY SENTINEL - SECURITY REPORT           "
  echo "=================================================================="
  echo "  Date & Time : $(date)"
  echo "  Host / OS   : $(hostname) ($(lsb_release -ds 2>/dev/null || uname -s))"
  echo "=================================================================="
  echo ""

  for module in "$MODULES_DIR"/*.sh; do
    if [ -f "$module" ]; then
      echo ">>> Module: $(basename "$module")"
      bash "$module"
      echo "------------------------------------------------------------------"
    fi
  done
} > "$RAW_OUTPUT"

SCORE=100
FINDINGS_COUNT=0

# 1. Extra UID 0 accounts beyond root (-30 each)
UID0_LINE=$(grep -E "Accounts with UID 0:" "$RAW_OUTPUT" | head -n 1)
UID0_LIST=$(echo "$UID0_LINE" | sed 's/.*Accounts with UID 0:[[:space:]]*//')
for u in $UID0_LIST; do
  if [ "$u" != "root" ]; then
    SCORE=$((SCORE - 30))
    FINDINGS_COUNT=$((FINDINGS_COUNT + 1))
    echo "  * [Privileged Accounts] Extra admin/UID 0 user '$u' found (-30 pts): Verify if '$u' should have full root privileges." >> "$REMEDIATIONS"
  fi
done

# 2. World-writable files (-15)
if grep -q "World-writable files in /etc and /var/tmp" "$RAW_OUTPUT" && ! grep -q "None found in scanned paths." "$RAW_OUTPUT"; then
  SCORE=$((SCORE - 15))
  FINDINGS_COUNT=$((FINDINGS_COUNT + 1))
  echo "  * [File Permissions] World-writable files detected (-15 pts): Restrict write permissions (chmod o-w) on unexpected files." >> "$REMEDIATIONS"
fi

# 3. File integrity mismatch (-25)
if grep -q "WARNING: Hash mismatch or missing file detected" "$RAW_OUTPUT"; then
  SCORE=$((SCORE - 25))
  FINDINGS_COUNT=$((FINDINGS_COUNT + 1))
  echo "  * [File Integrity] Monitored file changed or missing (-25 pts): Inspect changed files and refresh baseline if intentional." >> "$REMEDIATIONS"
fi

# 4. Failed login attempts (-2 each, max -20)
FAILED_LOGINS=$(grep -E "Recorded failed/invalid login events:" "$RAW_OUTPUT" | awk -F: '{print $NF}' | tr -d ' ' | head -n 1)
if [[ "$FAILED_LOGINS" =~ ^[0-9]+$ ]] && [ "$FAILED_LOGINS" -gt 0 ]; then
  PENALTY=$((FAILED_LOGINS * 2))
  [ "$PENALTY" -gt 20 ] && PENALTY=20
  SCORE=$((SCORE - PENALTY))
  FINDINGS_COUNT=$((FINDINGS_COUNT + 1))
  echo "  * [Login Activity] $FAILED_LOGINS failed login attempt(s) seen (-$PENALTY pts): Check if typos or unauthorized sign-in attempts occurred." >> "$REMEDIATIONS"
fi

# 5. Firewall inactive, unknown, or not installed (-10)
if grep -qE "UFW Status:.*(inactive|unknown)|UFW: Not installed" "$RAW_OUTPUT"; then
  SCORE=$((SCORE - 10))
  FINDINGS_COUNT=$((FINDINGS_COUNT + 1))
  echo "  * [Firewall Protection] Firewall is inactive or unavailable (-10 pts): Enable UFW ('sudo ufw enable') if appropriate for your setup." >> "$REMEDIATIONS"
fi

# Optional safe demo mode for live presentations (does not modify the host)
if [ "${1:-}" = "--demo" ]; then
  SCORE=$((SCORE - 25))
  FINDINGS_COUNT=$((FINDINGS_COUNT + 1))
  echo "  * [Demo: File Integrity] Simulated hash change in /etc/ssh/sshd_config (-25 pts): Inspect file diff and restore or re-baseline." >> "$REMEDIATIONS"

  SCORE=$((SCORE - 15))
  FINDINGS_COUNT=$((FINDINGS_COUNT + 1))
  echo "  * [Demo: File Permissions] Simulated world-writable file in /var/tmp (-15 pts): Remove world-write permission with 'chmod o-w'." >> "$REMEDIATIONS"
fi

[ "$SCORE" -lt 0 ] && SCORE=0
[ "$SCORE" -gt 100 ] && SCORE=100

if [ "$SCORE" -ge 80 ]; then
  BADGE="[LOW RISK]"
  SUMMARY_MSG="Your system looks healthy overall with only minor or routine items."
elif [ "$SCORE" -ge 50 ]; then
  BADGE="[MODERATE RISK]"
  SUMMARY_MSG="Some security items need attention soon to lower exposure."
else
  BADGE="[HIGH RISK]"
  SUMMARY_MSG="Important security issues were found and should be reviewed right away."
fi

# Build visual progress bar (20 segments)
FILLED=$((SCORE / 5))
[ "$FILLED" -gt 20 ] && FILLED=20
[ "$FILLED" -lt 0 ] && FILLED=0
EMPTY=$((20 - FILLED))
BAR=$(printf "%${FILLED}s" | tr ' ' '#')
SPACE=$(printf "%${EMPTY}s" | tr ' ' '-')

{
  cat "$RAW_OUTPUT"
  echo ""
  echo "=================================================================="
  echo "                        EXECUTIVE SUMMARY                         "
  echo "=================================================================="
  echo "  Security Score : $SCORE / 100  $BADGE"
  echo "  Health Bar     : [$BAR$SPACE]"
  echo "  Overview       : $SUMMARY_MSG"
  echo "  Items Flagged  : $FINDINGS_COUNT"
  echo "------------------------------------------------------------------"
  if [ -s "$REMEDIATIONS" ]; then
    echo "  Suggested Next Steps:"
    cat "$REMEDIATIONS"
  else
    echo "  Suggested Next Steps:"
    echo "  * No scored risk penalties triggered on this run."
  fi
  echo "------------------------------------------------------------------"
  echo "  Report File    : $REPORT_FILE"
  echo "=================================================================="
  echo "[+] Audit complete!"
} | tee "$REPORT_FILE"