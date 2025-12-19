#!/usr/bin/env bash
#
# Setup Git Hooks for Echoelmusic
# Installs pre-commit hooks for automatic code quality enforcement
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

echo "🔧 Setting up Git hooks for Echoelmusic..."

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Create pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/usr/bin/env bash
#
# Pre-commit hook for Echoelmusic
# Runs code quality checks before allowing commit
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Running pre-commit checks..."

# Get list of staged Swift files
SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$' || true)

# Get list of staged C++ files
CPP_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(cpp|h)$' || true)

# Track if any check failed
FAILED=0

# ============================================================================
# SwiftLint
# ============================================================================

if [ -n "$SWIFT_FILES" ]; then
    echo "→ Checking Swift files with SwiftLint..."

    if command -v swiftlint &> /dev/null; then
        if swiftlint lint --quiet $SWIFT_FILES; then
            echo -e "${GREEN}✓${NC} SwiftLint passed"
        else
            echo -e "${RED}✗${NC} SwiftLint found issues"
            echo "  Fix issues or run: swiftlint autocorrect"
            FAILED=1
        fi
    else
        echo -e "${YELLOW}⚠${NC}  SwiftLint not installed, skipping"
        echo "  Install: brew install swiftlint"
    fi
fi

# ============================================================================
# swift-format
# ============================================================================

if [ -n "$SWIFT_FILES" ]; then
    echo "→ Checking Swift formatting..."

    if command -v swift-format &> /dev/null; then
        UNFORMATTED_FILES=""

        for file in $SWIFT_FILES; do
            if ! swift-format lint --strict "$file" &> /dev/null; then
                UNFORMATTED_FILES="$UNFORMATTED_FILES $file"
            fi
        done

        if [ -z "$UNFORMATTED_FILES" ]; then
            echo -e "${GREEN}✓${NC} Swift formatting OK"
        else
            echo -e "${RED}✗${NC} Swift files need formatting:"
            for file in $UNFORMATTED_FILES; do
                echo "    $file"
            done
            echo "  Fix: swift-format format --in-place $UNFORMATTED_FILES"
            FAILED=1
        fi
    else
        echo -e "${YELLOW}⚠${NC}  swift-format not installed, skipping"
        echo "  Install: brew install swift-format"
    fi
fi

# ============================================================================
# clang-format (C++)
# ============================================================================

if [ -n "$CPP_FILES" ]; then
    echo "→ Checking C++ formatting..."

    if command -v clang-format &> /dev/null; then
        UNFORMATTED_CPP=""

        for file in $CPP_FILES; do
            if ! clang-format --dry-run --Werror "$file" &> /dev/null; then
                UNFORMATTED_CPP="$UNFORMATTED_CPP $file"
            fi
        done

        if [ -z "$UNFORMATTED_CPP" ]; then
            echo -e "${GREEN}✓${NC} C++ formatting OK"
        else
            echo -e "${RED}✗${NC} C++ files need formatting:"
            for file in $UNFORMATTED_CPP; do
                echo "    $file"
            done
            echo "  Fix: clang-format -i $UNFORMATTED_CPP"
            FAILED=1
        fi
    else
        echo -e "${YELLOW}⚠${NC}  clang-format not installed, skipping"
        echo "  Install: brew install llvm"
    fi
fi

# ============================================================================
# Security Checks
# ============================================================================

echo "→ Checking for security issues..."

# Check for hardcoded credentials
if git diff --cached | grep -iE "(password|api[_-]?key|secret|token)\s*=\s*['\"]" &> /dev/null; then
    echo -e "${RED}✗${NC} Hardcoded credentials detected!"
    echo "  Remove hardcoded credentials before committing"
    FAILED=1
else
    echo -e "${GREEN}✓${NC} No hardcoded credentials"
fi

# Check for force unwrapping in Swift (warning only)
if [ -n "$SWIFT_FILES" ]; then
    FORCE_UNWRAP_COUNT=$(git diff --cached $SWIFT_FILES | grep -c "!" | grep -v "//" || true)

    if [ "$FORCE_UNWRAP_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}⚠${NC}  Found $FORCE_UNWRAP_COUNT force unwrapping operator(s)"
        echo "  Consider using optional binding instead"
    fi
fi

# ============================================================================
# TODO/FIXME Check
# ============================================================================

echo "→ Checking for TODO/FIXME..."

TODO_COUNT=$(git diff --cached | grep -c "TODO\|FIXME" || true)

if [ "$TODO_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠${NC}  Found $TODO_COUNT TODO/FIXME comment(s)"
    echo "  Remember to address before release"
fi

# ============================================================================
# Result
# ============================================================================

echo ""
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All pre-commit checks passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Pre-commit checks failed${NC}"
    echo ""
    echo "Fix the issues above or use:"
    echo "  git commit --no-verify  (skip hooks - use with caution)"
    exit 1
fi
EOF

# Make pre-commit hook executable
chmod +x "$HOOKS_DIR/pre-commit"

# Create commit-msg hook for commit message validation
cat > "$HOOKS_DIR/commit-msg" << 'EOF'
#!/usr/bin/env bash
#
# Commit message validation hook
# Ensures commit messages follow conventional commit format
#

COMMIT_MSG_FILE=$1
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Conventional commit pattern
# feat: description
# fix: description
# docs: description
# style: description
# refactor: description
# perf: description
# test: description
# chore: description

PATTERN="^(feat|fix|docs|style|refactor|perf|test|chore|ci|build)(\(.+\))?: .{1,72}"

if [[ ! "$COMMIT_MSG" =~ $PATTERN ]]; then
    echo -e "${YELLOW}⚠ Commit message does not follow conventional commits format${NC}"
    echo ""
    echo "Expected format:"
    echo "  <type>(<scope>): <description>"
    echo ""
    echo "Types: feat, fix, docs, style, refactor, perf, test, chore, ci, build"
    echo ""
    echo "Examples:"
    echo "  feat: Add preset management system"
    echo "  fix: Resolve audio latency issue"
    echo "  docs: Update README with installation steps"
    echo ""
    echo "Your message:"
    echo "  $COMMIT_MSG"
    echo ""
    echo "Skip this check with: git commit --no-verify"
    exit 1
fi

# Check minimum length
if [ ${#COMMIT_MSG} -lt 10 ]; then
    echo -e "${RED}✗${NC} Commit message too short (minimum 10 characters)"
    exit 1
fi

echo -e "${GREEN}✓${NC} Commit message format OK"
exit 0
EOF

chmod +x "$HOOKS_DIR/commit-msg"

# Success message
echo ""
echo -e "${GREEN}✅ Git hooks installed successfully!${NC}"
echo ""
echo "Hooks installed:"
echo "  • pre-commit   - Code quality checks (SwiftLint, swift-format, security)"
echo "  • commit-msg   - Commit message validation"
echo ""
echo "To bypass hooks (use with caution):"
echo "  git commit --no-verify"
echo ""
