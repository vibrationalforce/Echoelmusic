#!/bin/bash
# Local Evolution Script - ZERO COST
# Run this instead of Claude for routine checks

set -e

echo "🔄 Echoelmusic Local Evolution - Zero Cost Mode"
echo "================================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 1. Swift Lint
echo -e "\n${YELLOW}[1/5] Running SwiftLint...${NC}"
if command -v swiftlint &> /dev/null; then
    swiftlint lint --quiet || true
    echo -e "${GREEN}✓ SwiftLint complete${NC}"
else
    echo "Install: brew install swiftlint"
fi

# 2. Count Metrics
echo -e "\n${YELLOW}[2/5] Counting metrics...${NC}"
SWIFT_FILES=$(find Sources -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
SWIFT_LINES=$(find Sources -name "*.swift" -exec cat {} \; 2>/dev/null | wc -l | tr -d ' ')
TEST_FILES=$(find Tests -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
TODO_COUNT=$(grep -r "TODO\|FIXME" --include="*.swift" Sources 2>/dev/null | wc -l | tr -d ' ')
PRINT_COUNT=$(grep -r "print(" --include="*.swift" Sources 2>/dev/null | wc -l | tr -d ' ')

echo "  Swift Files: $SWIFT_FILES"
echo "  Lines: $SWIFT_LINES"
echo "  Test Files: $TEST_FILES"
echo "  TODO/FIXME: $TODO_COUNT"
echo "  print(): $PRINT_COUNT"

# 3. Check for Issues
echo -e "\n${YELLOW}[3/5] Checking for issues...${NC}"
FATAL_COUNT=$(grep -r "fatalError" --include="*.swift" Sources 2>/dev/null | wc -l | tr -d ' ')
FORCE_CAST=$(grep -r "as!" --include="*.swift" Sources 2>/dev/null | wc -l | tr -d ' ')
HTTP_COUNT=$(grep -r "http://" --include="*.swift" Sources 2>/dev/null | grep -v https:// | wc -l | tr -d ' ')

if [ "$FATAL_COUNT" -gt 0 ]; then
    echo -e "${RED}  ⚠ fatalError(): $FATAL_COUNT${NC}"
else
    echo -e "${GREEN}  ✓ No fatalError()${NC}"
fi

if [ "$FORCE_CAST" -gt 0 ]; then
    echo -e "${RED}  ⚠ Force casts (as!): $FORCE_CAST${NC}"
else
    echo -e "${GREEN}  ✓ No force casts${NC}"
fi

if [ "$HTTP_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}  ⚠ HTTP URLs: $HTTP_COUNT${NC}"
else
    echo -e "${GREEN}  ✓ All HTTPS${NC}"
fi

# 4. Build Check (if xcodebuild available)
echo -e "\n${YELLOW}[4/5] Build check...${NC}"
if command -v xcodebuild &> /dev/null; then
    xcodebuild -scheme Echoelmusic -destination 'platform=iOS Simulator,name=iPhone 15' build 2>/dev/null && \
        echo -e "${GREEN}✓ Build successful${NC}" || \
        echo -e "${YELLOW}⚠ Build issues detected${NC}"
else
    echo "  Skipped (no xcodebuild)"
fi

# 5. Generate Report
echo -e "\n${YELLOW}[5/5] Generating report...${NC}"
DATE=$(date +%Y-%m-%d)
REPORT_FILE=".claude/health-reports/${DATE}-local.md"

mkdir -p .claude/health-reports

cat > "$REPORT_FILE" << EOF
# Local Health Report - $DATE

## Metrics
| Metric | Value |
|--------|-------|
| Swift Files | $SWIFT_FILES |
| Lines of Code | $SWIFT_LINES |
| Test Files | $TEST_FILES |
| TODO/FIXME | $TODO_COUNT |
| print() | $PRINT_COUNT |

## Issues
| Issue | Count | Status |
|-------|-------|--------|
| fatalError() | $FATAL_COUNT | $([ "$FATAL_COUNT" -eq 0 ] && echo "✅" || echo "⚠️") |
| Force casts | $FORCE_CAST | $([ "$FORCE_CAST" -eq 0 ] && echo "✅" || echo "⚠️") |
| HTTP URLs | $HTTP_COUNT | $([ "$HTTP_COUNT" -eq 0 ] && echo "✅" || echo "⚠️") |

---
*Generated locally - zero AI cost*
EOF

echo -e "${GREEN}✓ Report saved: $REPORT_FILE${NC}"

# Summary
echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}Local Evolution Complete - \$0 Cost${NC}"
echo -e "${GREEN}================================================${NC}"
EOF
