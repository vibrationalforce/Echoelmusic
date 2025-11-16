#!/bin/bash
# claude-workflow.sh - Optimized Claude Code Workflow for Echoelmusic

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Function: Create new feature branch
new_feature() {
    if [ -z "$1" ]; then
        echo -e "${RED}Error: Feature name required${NC}"
        echo "Usage: ./claude-workflow.sh feature <feature-name>"
        exit 1
    fi

    echo -e "${BLUE}Creating new feature branch...${NC}"

    # Generate session ID (simple timestamp)
    SESSION_ID=$(date +%s | tail -c 8)

    # Branch name format: claude/<feature-name>-<sessionId>
    BRANCH_NAME="claude/$1-${SESSION_ID}"

    # Checkout and create branch
    git checkout main && git pull origin main
    git checkout -b "$BRANCH_NAME"

    echo -e "${GREEN}✓ Branch '$BRANCH_NAME' created${NC}"
    echo -e "${YELLOW}Remember to push with: git push -u origin $BRANCH_NAME${NC}"
}

# Function: Run pre-commit checks
pre_commit_check() {
    echo -e "${YELLOW}Running pre-commit checks...${NC}"
    local FAILED=0

    # Check 1: Swift format (if available)
    echo -e "${BLUE}[1/6] Checking Swift format...${NC}"
    if command -v swift-format &> /dev/null; then
        swift-format lint --recursive Sources/ Tests/ || FAILED=1
    else
        echo -e "${YELLOW}  ⚠ swift-format not installed, skipping${NC}"
    fi

    # Check 2: SwiftLint (if available)
    echo -e "${BLUE}[2/6] Running SwiftLint...${NC}"
    if command -v swiftlint &> /dev/null; then
        swiftlint lint --quiet || FAILED=1
    else
        echo -e "${YELLOW}  ⚠ SwiftLint not installed, skipping${NC}"
    fi

    # Check 3: Swift build
    echo -e "${BLUE}[3/6] Building Swift code...${NC}"
    swift build -c release || { echo -e "${RED}✗ Swift build failed${NC}"; FAILED=1; }

    # Check 4: Run tests
    echo -e "${BLUE}[4/6] Running tests...${NC}"
    swift test || { echo -e "${RED}✗ Tests failed${NC}"; FAILED=1; }

    # Check 5: Security scan for secrets
    echo -e "${BLUE}[5/6] Scanning for hardcoded secrets...${NC}"
    if grep -r "sk_live_\|pk_live_\|AKIA\|ghp_" Sources/ 2>/dev/null; then
        echo -e "${RED}✗ Found potential API keys in source code!${NC}"
        FAILED=1
    else
        echo -e "${GREEN}  ✓ No secrets found${NC}"
    fi

    # Check 6: Check for force unwraps (Swift anti-pattern)
    echo -e "${BLUE}[6/6] Checking for force unwraps...${NC}"
    FORCE_UNWRAPS=$(grep -r "!" Sources/Echoelmusic/**/*.swift | grep -v "!=" | grep -v "// " | wc -l | tr -d ' ')
    if [ "$FORCE_UNWRAPS" -gt 0 ]; then
        echo -e "${YELLOW}  ⚠ Found $FORCE_UNWRAPS potential force unwraps${NC}"
    else
        echo -e "${GREEN}  ✓ No force unwraps found${NC}"
    fi

    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All checks passed${NC}"
        return 0
    else
        echo -e "${RED}✗ Some checks failed${NC}"
        return 1
    fi
}

# Function: Generate PR description
generate_pr() {
    local PR_FILE=".github/PULL_REQUEST_TEMPLATE.md"

    echo -e "${BLUE}Generating PR template...${NC}"

    mkdir -p .github

    cat > "$PR_FILE" << 'EOF'
## 🎯 Description
Brief description of changes

## 🔧 Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Performance improvement
- [ ] Refactoring (no functional changes)
- [ ] Documentation update
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)

## 🧪 Testing
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Audio latency <3ms verified (if audio changes)
- [ ] UI renders at 60 FPS (if UI changes)
- [ ] Test coverage maintained/improved

## 📊 Performance Impact
| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Audio latency | ? ms | ? ms | ? % |
| Memory usage | ? MB | ? MB | ? % |
| FPS (UI) | ? fps | ? fps | ? % |
| Build time | ? s | ? s | ? % |

## 🔒 Security Checklist
- [ ] No hardcoded secrets or API keys
- [ ] Biometric data encrypted (if applicable)
- [ ] No sensitive data in logs
- [ ] Keychain used for secrets (NOT UserDefaults)
- [ ] Input validation added
- [ ] HTTPS/TLS for network requests

## 📝 Documentation
- [ ] CLAUDE.md updated (if workflow changes)
- [ ] Code comments added for complex logic
- [ ] README.md updated (if user-facing changes)
- [ ] COMPLETE_FEATURE_LIST.md updated (if new features)

## 🚀 Deployment Notes
Any special deployment instructions or migration steps needed?

## 🔗 Related Issues
Closes #...

## 📸 Screenshots (if applicable)
Before | After
-------|-------
(screenshot) | (screenshot)
EOF

    echo -e "${GREEN}✓ PR template generated at $PR_FILE${NC}"
}

# Function: Security scan
security_scan() {
    echo -e "${BLUE}Running security scan...${NC}"
    local ISSUES=0

    echo -e "${YELLOW}[1/4] Scanning for hardcoded secrets...${NC}"
    if grep -r "sk_live_\|pk_live_\|AKIA\|ghp_\|xox[baprs]-" Sources/ 2>/dev/null; then
        echo -e "${RED}✗ Found potential API keys${NC}"
        ISSUES=$((ISSUES + 1))
    fi

    echo -e "${YELLOW}[2/4] Checking encryption key storage...${NC}"
    if grep -r "UserDefaults.*encryptionKey\|UserDefaults.*privateKey" Sources/ 2>/dev/null; then
        echo -e "${RED}✗ Encryption keys may be in UserDefaults (should use Keychain)${NC}"
        ISSUES=$((ISSUES + 1))
    fi

    echo -e "${YELLOW}[3/4] Checking for plaintext sensitive data...${NC}"
    if grep -r "streamKey.*:.*String\|password.*:.*String" Sources/Echoelmusic/Stream/ Sources/Echoelmusic/Cloud/ 2>/dev/null; then
        echo -e "${RED}✗ Sensitive data stored as plaintext String${NC}"
        ISSUES=$((ISSUES + 1))
    fi

    echo -e "${YELLOW}[4/4] Checking HealthKit compliance...${NC}"
    if grep -r "healthData.*sync\|HealthKit.*cloud" Sources/ 2>/dev/null | grep -v "// "; then
        echo -e "${RED}✗ HealthKit data may be synced to cloud (HIPAA violation)${NC}"
        ISSUES=$((ISSUES + 1))
    fi

    if [ $ISSUES -eq 0 ]; then
        echo -e "${GREEN}✓ No security issues found${NC}"
    else
        echo -e "${RED}✗ Found $ISSUES security issue(s)${NC}"
    fi

    return $ISSUES
}

# Function: Run performance benchmarks
benchmark() {
    echo -e "${BLUE}Running performance benchmarks...${NC}"

    # Build in release mode
    echo -e "${YELLOW}Building in Release mode...${NC}"
    swift build -c release || { echo -e "${RED}✗ Build failed${NC}"; return 1; }

    # Run performance tests
    echo -e "${YELLOW}Running performance tests...${NC}"
    swift test --filter PerformanceTests || { echo -e "${RED}✗ Performance tests failed${NC}"; return 1; }

    echo -e "${GREEN}✓ Benchmarks complete${NC}"
}

# Function: Clean build artifacts
clean() {
    echo -e "${BLUE}Cleaning build artifacts...${NC}"

    rm -rf .build
    rm -rf build
    rm -rf DerivedData
    rm -rf .swiftpm

    echo -e "${GREEN}✓ Clean complete${NC}"
}

# Function: Setup development environment
setup() {
    echo -e "${BLUE}Setting up development environment...${NC}"

    # Install git hooks
    echo -e "${YELLOW}Installing git hooks...${NC}"
    mkdir -p .git/hooks

    cat > .git/hooks/pre-commit << 'HOOK'
#!/bin/bash
# Pre-commit hook for Echoelmusic

echo "Running pre-commit checks..."
./scripts/claude-workflow.sh check

if [ $? -ne 0 ]; then
    echo "Pre-commit checks failed. Commit aborted."
    exit 1
fi
HOOK

    chmod +x .git/hooks/pre-commit
    echo -e "${GREEN}✓ Git hooks installed${NC}"

    # Check for required tools
    echo -e "${YELLOW}Checking required tools...${NC}"

    command -v swift >/dev/null 2>&1 || { echo -e "${RED}✗ Swift not found${NC}"; }
    command -v cmake >/dev/null 2>&1 || { echo -e "${YELLOW}⚠ CMake not found (needed for JUCE)${NC}"; }
    command -v swiftlint >/dev/null 2>&1 || { echo -e "${YELLOW}⚠ SwiftLint not found (optional)${NC}"; }

    echo -e "${GREEN}✓ Setup complete${NC}"
}

# Main command dispatcher
case "$1" in
    feature)
        new_feature "$2"
        ;;
    check)
        pre_commit_check
        ;;
    pr)
        generate_pr
        ;;
    security)
        security_scan
        ;;
    benchmark)
        benchmark
        ;;
    clean)
        clean
        ;;
    setup)
        setup
        ;;
    *)
        echo "Echoelmusic Claude Code Workflow"
        echo ""
        echo "Usage: ./claude-workflow.sh [command] [args]"
        echo ""
        echo "Commands:"
        echo "  feature <name>   - Create new claude/* feature branch"
        echo "  check            - Run pre-commit checks (format, lint, test, security)"
        echo "  pr               - Generate Pull Request template"
        echo "  security         - Run security scan"
        echo "  benchmark        - Run performance benchmarks"
        echo "  clean            - Clean build artifacts"
        echo "  setup            - Setup development environment"
        echo ""
        echo "Examples:"
        echo "  ./claude-workflow.sh feature audio-latency-fix"
        echo "  ./claude-workflow.sh check"
        echo "  ./claude-workflow.sh security"
        ;;
esac
