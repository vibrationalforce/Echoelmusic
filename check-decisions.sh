#!/usr/bin/env bash
# check-decisions.sh — Daily cron job to flag overdue decisions
# Install: crontab -e → 0 9 * * * /home/user/Echoelmusic/check-decisions.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$SCRIPT_DIR/decision_reviews.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running daily decision review check" >> "$LOG"
"$SCRIPT_DIR/review.sh" --flag >> "$LOG" 2>&1
