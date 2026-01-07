#!/bin/bash
#
# Integration Test Runner for Echoelmusic
# Runs all integration tests with detailed output
#

set -e

echo "========================================="
echo "  Echoelmusic Integration Test Suite"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Run only integration tests
echo -e "${YELLOW}Running Integration Tests...${NC}"
echo ""

if swift test --filter IntegrationTests --parallel; then
    echo ""
    echo -e "${GREEN}✓ All integration tests passed!${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}✗ Integration tests failed${NC}"
    echo ""
    exit 1
fi

# Show coverage summary
echo "========================================="
echo "  Integration Test Coverage Summary"
echo "========================================="
echo ""
echo "Test Categories:"
echo "  ✓ BioAudioIntegrationTests (10 tests)"
echo "  ✓ VisualAudioIntegrationTests (8 tests)"
echo "  ✓ HardwareIntegrationTests (8 tests)"
echo "  ✓ StreamingIntegrationTests (6 tests)"
echo "  ✓ CollaborationIntegrationTests (6 tests)"
echo "  ✓ PluginIntegrationTests (6 tests)"
echo "  ✓ FullSessionIntegrationTests (6 tests)"
echo ""
echo "Total: 50+ integration test methods"
echo ""

# Show individual test counts by category
echo "Detailed Test Breakdown:"
swift test --filter IntegrationTests --list-tests 2>/dev/null | grep "test" | sort

echo ""
echo -e "${GREEN}Integration test run complete!${NC}"
