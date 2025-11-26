#!/bin/bash
#
# build_and_upload.sh
# Automated Xcode Build, Archive, and App Store Upload Script
#
# This script automates the entire build and upload process for Echoelmusic
# Requirements: Xcode 15.0+, macOS 13.0+, valid Apple Developer account
#

set -e  # Exit on error

echo "🚀 Echoelmusic - Automated Build & Upload Script"
echo "================================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
PROJECT_NAME="Echoelmusic"
SCHEME="Echoelmusic"
CONFIGURATION="Release"
ARCHIVE_PATH="./build/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="./build/export"
IPA_PATH="${EXPORT_PATH}/${PROJECT_NAME}.ipa"

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ Error: This script must be run on macOS${NC}"
    echo "Current OS: $OSTYPE"
    exit 1
fi

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Error: Xcode is not installed${NC}"
    echo "Please install Xcode from the App Store"
    exit 1
fi

# Check Xcode version
XCODE_VERSION=$(xcodebuild -version | head -n 1 | awk '{print $2}')
echo -e "${BLUE}📱 Xcode Version: ${XCODE_VERSION}${NC}"

# Check if project file exists
if [ ! -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
    echo -e "${RED}❌ Error: ${PROJECT_NAME}.xcodeproj not found${NC}"
    echo "Please ensure you're in the project directory"
    exit 1
fi

echo ""
echo -e "${BLUE}📋 Build Configuration:${NC}"
echo "   Project: ${PROJECT_NAME}"
echo "   Scheme: ${SCHEME}"
echo "   Configuration: ${CONFIGURATION}"
echo "   Archive Path: ${ARCHIVE_PATH}"
echo "   Export Path: ${EXPORT_PATH}"
echo ""

read -p "Continue with build? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "Build cancelled"
    exit 0
fi

# Step 1: Clean build folder
echo ""
echo -e "${BLUE}🧹 Step 1/7: Cleaning build folder...${NC}"
rm -rf build
mkdir -p build

xcodebuild clean \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    | grep -E '^(Clean|.*error|.*warning)' || true

echo -e "${GREEN}✅ Clean complete${NC}"

# Step 2: Update build number
echo ""
echo -e "${BLUE}📝 Step 2/7: Updating build number...${NC}"

# Get current build number
CURRENT_BUILD=$(xcodebuild -project "${PROJECT_NAME}.xcodeproj" -showBuildSettings | grep CURRENT_PROJECT_VERSION | awk '{print $3}')
NEW_BUILD=$((CURRENT_BUILD + 1))

echo "   Current build: ${CURRENT_BUILD}"
echo "   New build: ${NEW_BUILD}"

# Update build number using PlistBuddy
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${NEW_BUILD}" "${PROJECT_NAME}/Info.plist" 2>/dev/null || true

echo -e "${GREEN}✅ Build number updated${NC}"

# Step 3: Check Team ID
echo ""
echo -e "${BLUE}🔐 Step 3/7: Checking Apple Developer Team ID...${NC}"

if [ -f "ExportOptions.plist" ]; then
    TEAM_ID=$(/usr/libexec/PlistBuddy -c "Print :teamID" ExportOptions.plist 2>/dev/null || echo "YOUR_TEAM_ID_HERE")

    if [ "$TEAM_ID" == "YOUR_TEAM_ID_HERE" ]; then
        echo -e "${YELLOW}⚠️  Team ID not configured in ExportOptions.plist${NC}"
        echo ""
        echo "To find your Team ID:"
        echo "   1. Visit: https://developer.apple.com/account"
        echo "   2. Go to: Membership"
        echo "   3. Copy your Team ID"
        echo ""
        read -p "Enter your Team ID: " TEAM_ID

        # Update ExportOptions.plist
        /usr/libexec/PlistBuddy -c "Set :teamID ${TEAM_ID}" ExportOptions.plist
        echo -e "${GREEN}✅ Team ID updated in ExportOptions.plist${NC}"
    else
        echo "   Team ID: ${TEAM_ID}"
        echo -e "${GREEN}✅ Team ID configured${NC}"
    fi
else
    echo -e "${RED}❌ Error: ExportOptions.plist not found${NC}"
    exit 1
fi

# Step 4: Build and Archive
echo ""
echo -e "${BLUE}🔨 Step 4/7: Building and archiving...${NC}"
echo "   This may take 5-10 minutes..."
echo ""

xcodebuild archive \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -archivePath "${ARCHIVE_PATH}" \
    -destination "generic/platform=iOS" \
    CODE_SIGNING_ALLOWED=YES \
    CODE_SIGNING_REQUIRED=YES \
    | grep -E '^(Build|Archive|.*error|.*warning|===)' || true

if [ ! -d "${ARCHIVE_PATH}" ]; then
    echo -e "${RED}❌ Error: Archive failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Archive complete${NC}"

# Step 5: Export IPA
echo ""
echo -e "${BLUE}📦 Step 5/7: Exporting IPA...${NC}"

xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist ExportOptions.plist \
    | grep -E '^(Export|.*error|.*warning)' || true

if [ ! -f "${IPA_PATH}" ]; then
    echo -e "${RED}❌ Error: IPA export failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ IPA exported successfully${NC}"

# Get IPA size
IPA_SIZE=$(du -h "${IPA_PATH}" | awk '{print $1}')
echo "   IPA Size: ${IPA_SIZE}"

# Step 6: Validate IPA
echo ""
echo -e "${BLUE}✅ Step 6/7: Validating IPA...${NC}"

echo ""
echo "Validation options:"
echo "   1. Upload to App Store"
echo "   2. Validate only (no upload)"
echo "   3. Skip validation"
echo ""
read -p "Select option (1-3): " validation_option

if [ "$validation_option" == "1" ] || [ "$validation_option" == "2" ]; then
    echo ""
    echo "Apple ID credentials required"
    read -p "Apple ID email: " APPLE_ID
    read -s -p "App-specific password: " APP_PASSWORD
    echo ""

    if [ "$validation_option" == "2" ]; then
        # Validate only
        echo ""
        echo -e "${BLUE}Validating IPA...${NC}"

        xcrun altool --validate-app \
            --type ios \
            --file "${IPA_PATH}" \
            --username "${APPLE_ID}" \
            --password "${APP_PASSWORD}" \
            2>&1 | grep -v "password"

        echo -e "${GREEN}✅ Validation complete${NC}"
    else
        # Upload
        echo ""
        echo -e "${BLUE}Uploading to App Store...${NC}"
        echo "   This may take 10-20 minutes..."
        echo ""

        xcrun altool --upload-app \
            --type ios \
            --file "${IPA_PATH}" \
            --username "${APPLE_ID}" \
            --password "${APP_PASSWORD}" \
            2>&1 | grep -v "password"

        echo ""
        echo -e "${GREEN}✅ Upload complete!${NC}"
    fi
fi

# Step 7: Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 Build Process Complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""
echo "📊 Build Summary:"
echo "   Version: 1.0"
echo "   Build: ${NEW_BUILD}"
echo "   IPA Size: ${IPA_SIZE}"
echo "   Archive: ${ARCHIVE_PATH}"
echo "   IPA: ${IPA_PATH}"
echo ""

if [ "$validation_option" == "1" ]; then
    echo "📋 Next Steps:"
    echo "   1. Wait 10-30 minutes for App Store processing"
    echo "   2. Go to: https://appstoreconnect.apple.com"
    echo "   3. Navigate to: My Apps → ${PROJECT_NAME} → TestFlight"
    echo "   4. Wait for build to appear"
    echo "   5. Move build to App Store section"
    echo "   6. Submit for review"
    echo ""
else
    echo "📋 Next Steps:"
    echo "   1. Open Xcode"
    echo "   2. Window → Organizer → Archives"
    echo "   3. Select the archive"
    echo "   4. Click 'Distribute App'"
    echo "   5. Select 'App Store Connect'"
    echo "   6. Follow the prompts to upload"
    echo ""
fi

echo -e "${GREEN}Build script complete! 🚀${NC}"
