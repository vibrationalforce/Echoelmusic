#!/usr/bin/env bash
# review.sh — Surface decisions that are due for review
# Usage: ./review.sh [--flag]
#   --flag: Also update decisions.csv with REVIEW_DUE status
#
# Cron install (daily at 9 AM):
#   crontab -e
#   0 9 * * * /home/user/Echoelmusic/check-decisions.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV="$SCRIPT_DIR/decisions.csv"
TODAY=$(date +%Y-%m-%d)

if [[ ! -f "$CSV" ]]; then
    echo "No decisions.csv found at $CSV"
    exit 1
fi

echo "=== Decision Review — $TODAY ==="
echo ""

FOUND=0

is_due() {
    local review_date="$1"
    [[ "$review_date" < "$TODAY" || "$review_date" == "$TODAY" ]]
}

# Skip header, process each row
tail -n +2 "$CSV" | while IFS=, read -r date decision reasoning outcome review_date status; do
    # Strip quotes
    decision=$(echo "$decision" | tr -d '"')
    reasoning=$(echo "$reasoning" | tr -d '"')
    outcome=$(echo "$outcome" | tr -d '"')
    review_date=$(echo "$review_date" | tr -d '"')
    status=$(echo "$status" | tr -d '"')

    if is_due "$review_date" && [[ "$status" != "REVIEW_DUE" && "$status" != "REVIEWED" ]]; then
        FOUND=1
        echo "REVIEW DUE [$review_date]"
        echo "  Decision:  $decision"
        echo "  Reasoning: $reasoning"
        echo "  Expected:  $outcome"
        echo "  Made on:   $date"
        echo ""
    fi
done

if [[ "$FOUND" -eq 0 ]]; then
    echo "No decisions due for review."
fi

# If --flag is passed, update CSV in place
if [[ "${1:-}" == "--flag" ]]; then
    TMPFILE=$(mktemp)
    head -1 "$CSV" > "$TMPFILE"
    tail -n +2 "$CSV" | while IFS=, read -r date decision reasoning outcome review_date status; do
        review_date_clean=$(echo "$review_date" | tr -d '"')
        status_clean=$(echo "$status" | tr -d '"')
        if is_due "$review_date_clean" && [[ "$status_clean" != "REVIEW_DUE" && "$status_clean" != "REVIEWED" ]]; then
            echo "$date,$decision,$reasoning,$outcome,$review_date,REVIEW_DUE"
        else
            echo "$date,$decision,$reasoning,$outcome,$review_date,$status"
        fi
    done >> "$TMPFILE"
    mv "$TMPFILE" "$CSV"
    echo "Updated decisions.csv with REVIEW_DUE flags."
fi
