#!/bin/bash
# =============================================================================
# ECHOELMUSIC - XCODE PROJECT GENERATOR
# Generates Xcode project from Swift Package for screenshot automation
# Version: 1.0.0 - Phase 10000 ULTIMATE MODE
# =============================================================================

set -e

echo "=============================================="
echo "Echoelmusic Xcode Project Generator"
echo "=============================================="

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "Working directory: $PROJECT_DIR"

# Check for xcodegen
if command -v xcodegen &> /dev/null; then
    echo "Using xcodegen..."
    xcodegen generate
    echo "Xcode project generated with xcodegen"
else
    echo "xcodegen not found, using swift package generate-xcodeproj..."

    # Generate Xcode project from SPM
    swift package generate-xcodeproj \
        --enable-code-coverage \
        --output Echoelmusic.xcodeproj

    echo "Xcode project generated"
fi

# Add UI test target if needed
if [ -d "Tests/EchoelmusicUITests" ]; then
    echo "UI test files found in Tests/EchoelmusicUITests/"
    echo ""
    echo "To add UI test target in Xcode:"
    echo "1. Open Echoelmusic.xcodeproj"
    echo "2. File > New > Target > iOS UI Testing Bundle"
    echo "3. Name: EchoelmusicUITests"
    echo "4. Drag files from Tests/EchoelmusicUITests/ into the target"
    echo ""
fi

# Create screenshot scheme if xcodegen is available
if [ -f "project.yml" ]; then
    echo "project.yml found, screenshots scheme should be included"
fi

echo ""
echo "=============================================="
echo "Done! Open Echoelmusic.xcodeproj in Xcode"
echo "=============================================="
echo ""
echo "To capture screenshots:"
echo "  fastlane screenshots"
echo ""
echo "To capture iPhone only:"
echo "  fastlane screenshots_iphone"
echo ""
