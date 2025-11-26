#!/bin/bash
#
# pre_submission_validation.sh
# Comprehensive Pre-Submission Validation Script
#
# This script checks that everything is ready for App Store submission
# Run this before building and uploading to catch issues early
#

set -e

echo "✅ Echoelmusic - Pre-Submission Validation"
echo "==========================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

check_pass() {
    echo -e "   ${GREEN}✅ PASS${NC} - $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

check_fail() {
    echo -e "   ${RED}❌ FAIL${NC} - $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

check_warn() {
    echo -e "   ${YELLOW}⚠️  WARN${NC} - $1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

echo -e "${BLUE}📁 1. File Structure Validation${NC}"
echo ""

# Check project file
if [ -f "Echoelmusic.xcodeproj/project.pbxproj" ]; then
    check_pass "Xcode project file exists"
else
    check_fail "Xcode project file not found"
fi

# Check Info.plist
if [ -f "Echoelmusic/Info.plist" ] || [ -f "Info.plist" ]; then
    check_pass "Info.plist exists"
else
    check_fail "Info.plist not found"
fi

# Check source files
SOURCE_FILES=(
    "Sources/Echoelmusic/Instruments/EchoelInstrumentLibrary.swift"
    "Sources/Echoelmusic/Audio/EchoelAudioEngine.swift"
    "Sources/Echoelmusic/Audio/DSP/EchoelDSPEffects.swift"
    "Sources/Echoelmusic/Views/MasterStudioHub.swift"
    "Sources/Echoelmusic/MIDI/MIDIManager.swift"
    "Sources/Echoelmusic/Services/BioDataProcessor.swift"
)

for file in "${SOURCE_FILES[@]}"; do
    if [ -f "$file" ]; then
        check_pass "$(basename $file) exists"
    else
        check_fail "$(basename $file) not found"
    fi
done

echo ""
echo -e "${BLUE}🎨 2. App Icons Validation${NC}"
echo ""

# Check icon files
ICON_FILES=(
    "Assets.xcassets/AppIcon.appiconset/icon-20@2x.png"
    "Assets.xcassets/AppIcon.appiconset/icon-60@3x.png"
    "Assets.xcassets/AppIcon.appiconset/icon-1024.png"
)

ICON_COUNT=0
for file in "${ICON_FILES[@]}"; do
    if [ -f "$file" ]; then
        ICON_COUNT=$((ICON_COUNT + 1))
    fi
done

if [ $ICON_COUNT -eq 3 ]; then
    check_pass "App icons present (checking 3 key sizes)"
else
    check_fail "App icons missing"
fi

# Check Contents.json
if [ -f "Assets.xcassets/AppIcon.appiconset/Contents.json" ]; then
    check_pass "App icon catalog configuration exists"
else
    check_fail "App icon catalog configuration missing"
fi

echo ""
echo -e "${BLUE}📄 3. Documentation Validation${NC}"
echo ""

DOCS=(
    "privacy-policy.html"
    "APPSTORE_METADATA.md"
    "FINAL_DEPLOYMENT_GUIDE.md"
    "SOFTWARE_FEATURES_DOCUMENTATION.md"
    "COMPLETE_DEPLOYMENT_PACKAGE.md"
)

for doc in "${DOCS[@]}"; do
    if [ -f "$doc" ]; then
        check_pass "$(basename $doc) exists"
    else
        check_fail "$(basename $doc) not found"
    fi
done

echo ""
echo -e "${BLUE}⚙️  4. Configuration Files Validation${NC}"
echo ""

# Check ExportOptions.plist
if [ -f "ExportOptions.plist" ]; then
    check_pass "ExportOptions.plist exists"

    # Check if Team ID is set
    if [ -f "ExportOptions.plist" ]; then
        TEAM_ID=$(/usr/libexec/PlistBuddy -c "Print :teamID" ExportOptions.plist 2>/dev/null || echo "YOUR_TEAM_ID_HERE")
        if [ "$TEAM_ID" == "YOUR_TEAM_ID_HERE" ]; then
            check_warn "Team ID not configured in ExportOptions.plist"
        else
            check_pass "Team ID configured: ${TEAM_ID}"
        fi
    fi
else
    check_fail "ExportOptions.plist not found"
fi

echo ""
echo -e "${BLUE}📱 5. Info.plist Validation${NC}"
echo ""

INFO_PLIST="Echoelmusic/Info.plist"
if [ ! -f "$INFO_PLIST" ]; then
    INFO_PLIST="Info.plist"
fi

if [ -f "$INFO_PLIST" ]; then
    # Check bundle identifier
    BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST" 2>/dev/null || echo "")
    if [ -n "$BUNDLE_ID" ]; then
        check_pass "Bundle identifier: ${BUNDLE_ID}"
    else
        check_fail "Bundle identifier not found"
    fi

    # Check version
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "")
    if [ -n "$VERSION" ]; then
        check_pass "Version: ${VERSION}"
    else
        check_fail "Version string not found"
    fi

    # Check required permissions
    PERMISSIONS=(
        "NSHealthShareUsageDescription"
        "NSMicrophoneUsageDescription"
        "NSPhotoLibraryUsageDescription"
    )

    for perm in "${PERMISSIONS[@]}"; do
        DESC=$(/usr/libexec/PlistBuddy -c "Print :${perm}" "$INFO_PLIST" 2>/dev/null || echo "")
        if [ -n "$DESC" ]; then
            check_pass "${perm} configured"
        else
            check_warn "${perm} not found"
        fi
    done
else
    check_fail "Info.plist not accessible"
fi

echo ""
echo -e "${BLUE}🔐 6. Privacy Policy Validation${NC}"
echo ""

if [ -f "privacy-policy.html" ]; then
    # Check file size (should be substantial)
    SIZE=$(wc -c < privacy-policy.html)
    if [ $SIZE -gt 1000 ]; then
        check_pass "Privacy policy size: ${SIZE} bytes"
    else
        check_warn "Privacy policy seems too small: ${SIZE} bytes"
    fi

    # Check for key compliance terms
    if grep -q "GDPR" privacy-policy.html; then
        check_pass "GDPR compliance mentioned"
    else
        check_warn "GDPR not mentioned"
    fi

    if grep -q "CCPA" privacy-policy.html; then
        check_pass "CCPA compliance mentioned"
    else
        check_warn "CCPA not mentioned"
    fi
else
    check_fail "privacy-policy.html not found"
fi

echo ""
echo -e "${BLUE}📝 7. App Store Metadata Validation${NC}"
echo ""

if [ -f "APPSTORE_METADATA.md" ]; then
    # Check app name
    if grep -q "## App Name" APPSTORE_METADATA.md; then
        APP_NAME=$(grep -A 1 "## App Name" APPSTORE_METADATA.md | tail -n 1)
        check_pass "App name: ${APP_NAME}"
    fi

    # Check description length
    DESC_LENGTH=$(grep -A 100 "## Description" APPSTORE_METADATA.md | wc -c)
    if [ $DESC_LENGTH -gt 500 ]; then
        check_pass "Description length: ${DESC_LENGTH} characters"
    else
        check_warn "Description might be too short"
    fi

    # Check keywords
    if grep -q "## Keywords" APPSTORE_METADATA.md; then
        KEYWORDS=$(grep -A 1 "## Keywords" APPSTORE_METADATA.md | tail -n 1)
        KEYWORD_LENGTH=${#KEYWORDS}
        if [ $KEYWORD_LENGTH -le 100 ]; then
            check_pass "Keywords length: ${KEYWORD_LENGTH}/100 characters"
        else
            check_fail "Keywords too long: ${KEYWORD_LENGTH}/100 characters"
        fi
    fi

    # Check screenshot captions
    if grep -q "## Screenshots Captions" APPSTORE_METADATA.md; then
        check_pass "Screenshot captions prepared"
    else
        check_warn "Screenshot captions not found"
    fi
else
    check_fail "APPSTORE_METADATA.md not found"
fi

echo ""
echo -e "${BLUE}🔨 8. Build Configuration Validation${NC}"
echo ""

# Check if code signing is configured
if command -v security &> /dev/null; then
    CERTS=$(security find-identity -v -p codesigning 2>/dev/null | grep -c "Apple Distribution" || echo "0")
    if [ $CERTS -gt 0 ]; then
        check_pass "Apple Distribution certificate found (${CERTS} certificates)"
    else
        check_warn "Apple Distribution certificate not found (may need to install)"
    fi
else
    check_warn "Cannot check certificates (not on macOS)"
fi

# Check if Xcode is installed (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v xcodebuild &> /dev/null; then
        XCODE_VERSION=$(xcodebuild -version | head -n 1 | awk '{print $2}')
        check_pass "Xcode installed: ${XCODE_VERSION}"
    else
        check_fail "Xcode not installed"
    fi
else
    check_warn "Not on macOS - build validation skipped"
fi

echo ""
echo -e "${BLUE}📸 9. Screenshot Requirements Check${NC}"
echo ""

echo -e "   ${YELLOW}⚠️  Manual Check Required${NC}"
echo "   Required screenshot sizes:"
echo "     - iPhone 6.7\" (1290 x 2796 px) - 5 screenshots"
echo "     - iPad Pro 12.9\" (2048 x 2732 px) - 5 screenshots"
echo ""
read -p "   Have you captured all required screenshots? (y/n): " screenshots_ready
if [ "$screenshots_ready" == "y" ]; then
    check_pass "Screenshots confirmed ready"
else
    check_warn "Screenshots not ready"
fi

echo ""
echo -e "${BLUE}🌐 10. Privacy Policy Hosting Check${NC}"
echo ""

echo -e "   ${YELLOW}⚠️  Manual Check Required${NC}"
read -p "   Is your privacy policy hosted and accessible? (y/n): " hosted
if [ "$hosted" == "y" ]; then
    read -p "   Enter your privacy policy URL: " privacy_url
    if [ -n "$privacy_url" ]; then
        check_pass "Privacy policy URL: ${privacy_url}"

        # Try to validate URL (if curl is available)
        if command -v curl &> /dev/null; then
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$privacy_url" 2>/dev/null || echo "000")
            if [ "$HTTP_CODE" == "200" ]; then
                check_pass "Privacy policy URL is accessible (HTTP 200)"
            else
                check_warn "Privacy policy URL returned HTTP ${HTTP_CODE}"
            fi
        fi
    else
        check_warn "Privacy policy URL not provided"
    fi
else
    check_warn "Privacy policy not yet hosted"
fi

echo ""
echo -e "${BLUE}🧪 11. Device Testing Check${NC}"
echo ""

echo -e "   ${YELLOW}⚠️  Manual Check Required${NC}"
read -p "   Have you tested on a real iPhone/iPad? (y/n): " device_tested
if [ "$device_tested" == "y" ]; then
    check_pass "Device testing completed"

    echo ""
    echo "   Quick testing checklist:"
    read -p "   - All 17 instruments play sound? (y/n): " instruments_work
    read -p "   - Recording works? (y/n): " recording_works
    read -p "   - Export works (WAV/AAC)? (y/n): " export_works
    read -p "   - HealthKit permission flow works? (y/n): " healthkit_works
    read -p "   - No crashes during 10-minute session? (y/n): " no_crashes

    if [ "$instruments_work" == "y" ] && [ "$recording_works" == "y" ] && [ "$export_works" == "y" ] && [ "$healthkit_works" == "y" ] && [ "$no_crashes" == "y" ]; then
        check_pass "All critical tests passed"
    else
        check_warn "Some tests not confirmed - review before submission"
    fi
else
    check_fail "Device testing not completed - CRITICAL before submission"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}Validation Complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

# Summary
echo "📊 Validation Summary:"
echo ""
echo -e "   ${GREEN}✅ Passed: ${PASS_COUNT}${NC}"
echo -e "   ${YELLOW}⚠️  Warnings: ${WARN_COUNT}${NC}"
echo -e "   ${RED}❌ Failed: ${FAIL_COUNT}${NC}"
echo ""

# Overall status
if [ $FAIL_COUNT -eq 0 ]; then
    if [ $WARN_COUNT -eq 0 ]; then
        echo -e "${GREEN}🎉 READY FOR SUBMISSION!${NC}"
        echo ""
        echo "All checks passed. You can proceed with:"
        echo "   1. Build and archive (./scripts/build_and_upload.sh)"
        echo "   2. Upload to App Store Connect"
        echo "   3. Submit for review"
    else
        echo -e "${YELLOW}⚠️  MOSTLY READY - Review warnings${NC}"
        echo ""
        echo "Most checks passed, but review warnings above."
        echo "These are typically not blockers but should be addressed."
    fi
else
    echo -e "${RED}❌ NOT READY - Fix issues before submission${NC}"
    echo ""
    echo "Please address the failed checks above before proceeding."
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

exit $FAIL_COUNT
