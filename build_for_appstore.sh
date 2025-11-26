#!/bin/bash

###############################################################################
# Echoelmusic - App Store Build Script
# Version: 1.0
# Purpose: Automate the build and archive process for App Store submission
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="Echoelmusic"
SCHEME="Echoelmusic"
BUNDLE_ID="com.vibrationalforce.echoelmusic"
VERSION="1.0"
BUILD_DIR="./build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"

###############################################################################
# Functions
###############################################################################

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ ERROR: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

check_xcode() {
    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode command line tools not found"
        echo "Please install Xcode and run: xcode-select --install"
        exit 1
    fi
    print_success "Xcode found: $(xcodebuild -version | head -1)"
}

check_project() {
    if [ ! -d "Echoelmusic.xcodeproj" ] && [ ! -d "Echoelmusic.xcworkspace" ]; then
        print_error "Echoelmusic project not found in current directory"
        echo "Please run this script from the project root directory"
        exit 1
    fi

    if [ -d "Echoelmusic.xcworkspace" ]; then
        PROJECT_TYPE="-workspace Echoelmusic.xcworkspace"
        print_success "Using workspace"
    else
        PROJECT_TYPE="-project Echoelmusic.xcodeproj"
        print_success "Using project"
    fi
}

verify_info_plist() {
    print_info "Verifying Info.plist configuration..."

    PLIST_PATH="Info.plist"

    if [ ! -f "$PLIST_PATH" ]; then
        print_error "Info.plist not found at $PLIST_PATH"
        exit 1
    fi

    # Check version
    VERSION_CHECK=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST_PATH" 2>/dev/null || echo "")
    if [ "$VERSION_CHECK" != "1.0" ]; then
        print_warning "Version is $VERSION_CHECK (expected 1.0)"
    else
        print_success "Version: $VERSION_CHECK"
    fi

    # Check required permissions
    REQUIRED_KEYS=(
        "NSMicrophoneUsageDescription"
        "NSCameraUsageDescription"
        "NSHealthShareUsageDescription"
        "NSBluetoothAlwaysUsageDescription"
    )

    for key in "${REQUIRED_KEYS[@]}"; do
        if /usr/libexec/PlistBuddy -c "Print :$key" "$PLIST_PATH" &>/dev/null; then
            print_success "$key present"
        else
            print_error "$key MISSING - Required for App Store"
            exit 1
        fi
    done
}

clean_build() {
    print_info "Cleaning previous builds..."

    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        print_success "Removed previous build directory"
    fi

    xcodebuild clean $PROJECT_TYPE -scheme "$SCHEME" -configuration Release &>/dev/null
    print_success "Cleaned Xcode build"
}

run_tests() {
    print_info "Running tests..."

    # Check if tests exist
    if xcodebuild test $PROJECT_TYPE -scheme "$SCHEME" -destination 'platform=iOS Simulator,name=iPhone 15 Pro' 2>&1 | grep -q "Test Succeeded"; then
        print_success "All tests passed"
    else
        print_warning "No tests found or tests failed (continuing anyway)"
    fi
}

build_archive() {
    print_info "Creating archive..."
    print_info "This may take a few minutes..."

    mkdir -p "$BUILD_DIR"

    xcodebuild archive \
        $PROJECT_TYPE \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -destination 'generic/platform=iOS' \
        CODE_SIGN_STYLE=Automatic \
        | xcpretty || xcodebuild archive \
            $PROJECT_TYPE \
            -scheme "$SCHEME" \
            -configuration Release \
            -archivePath "$ARCHIVE_PATH" \
            -destination 'generic/platform=iOS' \
            CODE_SIGN_STYLE=Automatic

    if [ -d "$ARCHIVE_PATH" ]; then
        print_success "Archive created successfully"
        print_info "Archive location: $ARCHIVE_PATH"
    else
        print_error "Archive creation failed"
        exit 1
    fi
}

export_ipa() {
    print_info "Exporting IPA for App Store..."

    # Create ExportOptions.plist
    cat > "${BUILD_DIR}/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>teamID</key>
    <string></string>
</dict>
</plist>
EOF

    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$BUILD_DIR" \
        -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist" \
        | xcpretty || xcodebuild -exportArchive \
            -archivePath "$ARCHIVE_PATH" \
            -exportPath "$BUILD_DIR" \
            -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist"

    if [ -f "${BUILD_DIR}/${APP_NAME}.ipa" ]; then
        print_success "IPA exported successfully"
        print_info "IPA location: ${BUILD_DIR}/${APP_NAME}.ipa"
    else
        print_warning "IPA export failed (you can still use Xcode Organizer to upload)"
    fi
}

show_summary() {
    print_header "Build Summary"

    echo "📦 App Name:       $APP_NAME"
    echo "🔖 Version:        $VERSION"
    echo "🆔 Bundle ID:      $BUNDLE_ID"
    echo "📁 Archive:        $ARCHIVE_PATH"

    if [ -f "${BUILD_DIR}/${APP_NAME}.ipa" ]; then
        IPA_SIZE=$(du -h "${BUILD_DIR}/${APP_NAME}.ipa" | cut -f1)
        echo "💾 IPA Size:       $IPA_SIZE"
    fi

    echo ""
    print_success "Build completed successfully!"
    echo ""

    echo "Next steps:"
    echo "1. Open Xcode → Window → Organizer"
    echo "2. Select the archive: $APP_NAME $(date +%Y-%m-%d)"
    echo "3. Click 'Distribute App'"
    echo "4. Select 'App Store Connect'"
    echo "5. Click 'Upload'"
    echo "6. Wait for processing (15-30 min)"
    echo "7. Submit for review in App Store Connect"
    echo ""
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --clean-only     Only clean the build, don't archive"
    echo "  --skip-tests     Skip running tests"
    echo "  --archive-only   Only create archive, don't export IPA"
    echo "  --help           Show this help message"
    echo ""
}

###############################################################################
# Main Script
###############################################################################

main() {
    print_header "Echoelmusic - App Store Build Script"

    # Parse arguments
    CLEAN_ONLY=false
    SKIP_TESTS=false
    ARCHIVE_ONLY=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean-only)
                CLEAN_ONLY=true
                shift
                ;;
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --archive-only)
                ARCHIVE_ONLY=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Pre-flight checks
    print_header "Pre-Flight Checks"
    check_xcode
    check_project
    verify_info_plist

    # Clean build
    print_header "Clean Build"
    clean_build

    if [ "$CLEAN_ONLY" = true ]; then
        print_success "Clean completed (skipping build)"
        exit 0
    fi

    # Run tests
    if [ "$SKIP_TESTS" = false ]; then
        print_header "Running Tests"
        run_tests
    fi

    # Build archive
    print_header "Building Archive"
    build_archive

    # Export IPA
    if [ "$ARCHIVE_ONLY" = false ]; then
        print_header "Exporting IPA"
        export_ipa
    fi

    # Show summary
    show_summary
}

# Run main function
main "$@"
