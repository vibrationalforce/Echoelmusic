#!/bin/bash
# =============================================================================
# ECHOELMUSIC — Install Git Hooks
# =============================================================================
# Installs the build-guard pre-push hook.
# Run once after cloning: ./scripts/install-hooks.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

echo "Installing Echoelmusic git hooks..."

# Create pre-push hook
cat > "$HOOKS_DIR/pre-push" << 'HOOK'
#!/bin/bash
# =============================================================================
# Echoelmusic Pre-Push Hook
# Runs build-guard --quick to catch known error patterns before push.
# Full compile check can be triggered with: ./scripts/build-guard.sh
# =============================================================================

# Only check Swift source changes
CHANGED_SWIFT=$(git diff --name-only HEAD @{upstream} 2>/dev/null | grep '\.swift$' || true)
if [[ -z "$CHANGED_SWIFT" ]]; then
    # If we can't compare to upstream (new branch), check staged vs HEAD
    CHANGED_SWIFT=$(git diff --name-only HEAD~1 HEAD 2>/dev/null | grep '\.swift$' || true)
fi

if [[ -z "$CHANGED_SWIFT" ]]; then
    echo "[build-guard] No Swift changes detected, skipping."
    exit 0
fi

GUARD_SCRIPT="$(git rev-parse --show-toplevel)/scripts/build-guard.sh"

if [[ -x "$GUARD_SCRIPT" ]]; then
    echo ""
    echo "[build-guard] Checking for known error patterns..."
    echo ""
    # Run quick pattern check (no compile, instant)
    if ! "$GUARD_SCRIPT" --quick; then
        echo ""
        echo "Push blocked by build-guard. Fix errors and try again."
        echo "To skip (not recommended): git push --no-verify"
        exit 1
    fi
else
    echo "[build-guard] Warning: scripts/build-guard.sh not found, skipping checks."
fi
HOOK

chmod +x "$HOOKS_DIR/pre-push"

echo "  Installed: .git/hooks/pre-push"
echo ""
echo "Done. The pre-push hook will run pattern checks before each push."
echo "To run a full build check manually: ./scripts/build-guard.sh"
