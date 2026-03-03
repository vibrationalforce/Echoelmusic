#!/bin/bash
#
# test.sh - VS Code friendly test script for Echoelmusic
# Runs Swift unit tests with nice output
#
# Usage:
#   ./test.sh              # Run all tests
#   ./test.sh --verbose    # Verbose output
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Echoelmusic - Running Tests        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    echo -e "${RED}❌ Error: Package.swift not found${NC}"
    echo "Please run this script from the project root directory"
    exit 1
fi

# Check for verbose flag
VERBOSE=""
if [ "$1" = "--verbose" ] || [ "$1" = "-v" ]; then
    VERBOSE="--verbose"
    echo -e "${YELLOW}🔍 Running in VERBOSE mode...${NC}"
    echo ""
fi

echo -e "${BLUE}🧪 Running unit tests...${NC}"
echo ""

# Run tests
swift test $VERBOSE

# Check if tests succeeded
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ All Tests Passed!                ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}╔═══════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ❌ Tests Failed!                    ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}💡 Tips:${NC}"
    echo "  1. Check the error messages above"
    echo "  2. Run with verbose: ${GREEN}./test.sh --verbose${NC}"
    echo "  3. Check individual test files in Tests/"
    echo ""
    exit 1
fi
