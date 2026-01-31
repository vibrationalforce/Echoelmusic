#!/bin/bash
# =============================================================================
# SECRETS VALIDATION SCRIPT
# =============================================================================
# Usage:
#   export ASC_KEY_ID=xxx && export ASC_ISSUER_ID=xxx && ./check-secrets.sh
# =============================================================================

echo "============================================"
echo "  APP STORE CONNECT SECRETS CHECK"
echo "============================================"
echo ""

ERRORS=0

# Check ASC_KEY_ID (or APP_STORE_CONNECT_KEY_ID)
KEY_ID="${ASC_KEY_ID:-$APP_STORE_CONNECT_KEY_ID}"
if [ -z "$KEY_ID" ]; then
    echo "[FAIL] ASC_KEY_ID: Not set"
    ERRORS=$((ERRORS + 1))
elif [ ${#KEY_ID} -lt 8 ]; then
    echo "[FAIL] ASC_KEY_ID: Too short (${#KEY_ID} chars, need 8+)"
    ERRORS=$((ERRORS + 1))
else
    echo "[OK] ASC_KEY_ID: ${#KEY_ID} chars (${KEY_ID:0:4}...)"
fi

# Check ASC_ISSUER_ID (or APP_STORE_CONNECT_ISSUER_ID)
ISSUER_ID="${ASC_ISSUER_ID:-$APP_STORE_CONNECT_ISSUER_ID}"
if [ -z "$ISSUER_ID" ]; then
    echo "[FAIL] ASC_ISSUER_ID: Not set"
    ERRORS=$((ERRORS + 1))
elif [ ${#ISSUER_ID} -lt 32 ]; then
    echo "[FAIL] ASC_ISSUER_ID: Too short (${#ISSUER_ID} chars, need 32+)"
    ERRORS=$((ERRORS + 1))
else
    echo "[OK] ASC_ISSUER_ID: ${#ISSUER_ID} chars (UUID format)"
fi

# Check ASC_KEY_CONTENT (or APP_STORE_CONNECT_PRIVATE_KEY)
KEY_CONTENT="${ASC_KEY_CONTENT:-$APP_STORE_CONNECT_PRIVATE_KEY}"
if [ -z "$KEY_CONTENT" ]; then
    echo "[FAIL] ASC_KEY_CONTENT: Not set"
    ERRORS=$((ERRORS + 1))
elif [ ${#KEY_CONTENT} -lt 200 ]; then
    echo "[FAIL] ASC_KEY_CONTENT: Too short (${#KEY_CONTENT} chars, need 200+)"
    ERRORS=$((ERRORS + 1))
elif ! echo "$KEY_CONTENT" | grep -q "BEGIN.*PRIVATE KEY"; then
    echo "[WARN] ASC_KEY_CONTENT: Missing PEM header"
    echo "       Expected: -----BEGIN PRIVATE KEY-----"
else
    echo "[OK] ASC_KEY_CONTENT: ${#KEY_CONTENT} chars (PEM format OK)"
fi

# Check APPLE_TEAM_ID
TEAM_ID="$APPLE_TEAM_ID"
if [ -z "$TEAM_ID" ]; then
    echo "[FAIL] APPLE_TEAM_ID: Not set"
    ERRORS=$((ERRORS + 1))
elif [ ${#TEAM_ID} -ne 10 ]; then
    echo "[WARN] APPLE_TEAM_ID: Unexpected length (${#TEAM_ID} chars, expected 10)"
else
    echo "[OK] APPLE_TEAM_ID: ${#TEAM_ID} chars"
fi

echo ""
echo "============================================"
if [ $ERRORS -gt 0 ]; then
    echo "RESULT: $ERRORS error(s) found"
    echo ""
    echo "Set secrets at:"
    echo "https://github.com/OWNER/Echoelmusic/settings/secrets/actions"
    exit 1
else
    echo "RESULT: All secrets configured correctly!"
fi
echo "============================================"

# Optional: Test API communication
echo ""
echo "To test API communication, run:"
echo "  cd fastlane && bundle exec fastlane ios build_only"
echo ""
