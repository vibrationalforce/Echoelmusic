#!/bin/bash
# =============================================================================
# ECHOELMUSIC - LOCAL DEVELOPMENT SETUP SCRIPT
# =============================================================================
# Automated setup for local development environment
# Usage: ./scripts/setup.sh
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "=============================================="
echo "  ECHOELMUSIC - Development Setup"
echo "  Phase 10000 ULTIMATE MODE"
echo "=============================================="
echo -e "${NC}"

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${YELLOW}Warning: This script is optimized for macOS.${NC}"
    echo "Some features may not work on other platforms."
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Step 1: Check Xcode
echo -e "${BLUE}[1/7] Checking Xcode...${NC}"
if command_exists xcodebuild; then
    XCODE_VERSION=$(xcodebuild -version | head -1)
    echo -e "${GREEN}✓ $XCODE_VERSION${NC}"
else
    echo -e "${RED}✗ Xcode not found. Please install from App Store.${NC}"
    exit 1
fi

# Step 2: Install Homebrew (if not installed)
echo -e "${BLUE}[2/7] Checking Homebrew...${NC}"
if command_exists brew; then
    echo -e "${GREEN}✓ Homebrew installed${NC}"
else
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Step 3: Install XcodeGen
echo -e "${BLUE}[3/7] Installing XcodeGen...${NC}"
if command_exists xcodegen; then
    echo -e "${GREEN}✓ XcodeGen already installed${NC}"
else
    brew install xcodegen
    echo -e "${GREEN}✓ XcodeGen installed${NC}"
fi

# Step 4: Install Fastlane
echo -e "${BLUE}[4/7] Installing Fastlane...${NC}"
if command_exists fastlane; then
    FASTLANE_VERSION=$(fastlane --version | head -1)
    echo -e "${GREEN}✓ Fastlane installed ($FASTLANE_VERSION)${NC}"
else
    echo "Installing Fastlane..."
    gem install fastlane -N --no-document
    echo -e "${GREEN}✓ Fastlane installed${NC}"
fi

# Step 5: Install SwiftLint (optional but recommended)
echo -e "${BLUE}[5/7] Installing SwiftLint...${NC}"
if command_exists swiftlint; then
    echo -e "${GREEN}✓ SwiftLint already installed${NC}"
else
    brew install swiftlint || echo -e "${YELLOW}⚠ SwiftLint installation failed (optional)${NC}"
fi

# Step 6: Generate Xcode Project
echo -e "${BLUE}[6/7] Generating Xcode Project...${NC}"
cd "$(dirname "$0")/.."

if [ -f "project.yml" ]; then
    xcodegen generate --spec project.yml
    echo -e "${GREEN}✓ Xcode project generated (Echoelmusic.xcodeproj)${NC}"
else
    echo -e "${RED}✗ project.yml not found${NC}"
    exit 1
fi

# Step 7: Resolve Swift Packages
echo -e "${BLUE}[7/7] Resolving Swift Packages...${NC}"
swift package resolve 2>/dev/null || echo -e "${YELLOW}⚠ Swift package resolve skipped${NC}"

echo ""
echo -e "${GREEN}=============================================="
echo "  SETUP COMPLETE!"
echo "=============================================="
echo -e "${NC}"

echo "Next steps:"
echo ""
echo "  1. Open Xcode project:"
echo "     open Echoelmusic.xcodeproj"
echo ""
echo "  2. Configure signing (Xcode → Signing & Capabilities):"
echo "     - Select your Team ID"
echo "     - Enable 'Automatically manage signing' for development"
echo ""
echo "  3. Build and run:"
echo "     - Select target (Echoelmusic, Echoelmusic-macOS, etc.)"
echo "     - Cmd+R to run"
echo ""
echo "  4. For TestFlight deployment, configure GitHub Secrets:"
echo "     - APP_STORE_CONNECT_KEY_ID"
echo "     - APP_STORE_CONNECT_ISSUER_ID"
echo "     - APP_STORE_CONNECT_PRIVATE_KEY"
echo "     - APPLE_TEAM_ID"
echo ""
echo "  See TESTFLIGHT_SETUP.md for detailed instructions."
echo ""
