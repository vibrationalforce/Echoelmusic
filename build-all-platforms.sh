#!/bin/bash

###############################################################################
# Echoelmusic Multi-Platform Build & Archive Script
#
# This script builds and archives Echoelmusic for all supported platforms:
# - iOS/iPadOS
# - macOS
# - watchOS
# - tvOS
# - visionOS
#
# Usage:
#   ./build-all-platforms.sh [clean|archive|export|all]
#
# Requirements:
#   - Xcode 15.0+
#   - Valid code signing certificates
#   - Provisioning profiles installed
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="Echoelmusic"
BUILD_DIR="./build"
ARCHIVE_DIR="$BUILD_DIR/archives"
EXPORT_DIR="$BUILD_DIR/exports"

# Schemes
IOS_SCHEME="Echoelmusic-iOS"
MACOS_SCHEME="Echoelmusic-macOS"
WATCHOS_SCHEME="Echoelmusic-watchOS"
TVOS_SCHEME="Echoelmusic-tvOS"
VISIONOS_SCHEME="Echoelmusic-visionOS"

# Archive paths
IOS_ARCHIVE="$ARCHIVE_DIR/Echoelmusic-iOS.xcarchive"
MACOS_ARCHIVE="$ARCHIVE_DIR/Echoelmusic-macOS.xcarchive"
WATCHOS_ARCHIVE="$ARCHIVE_DIR/Echoelmusic-watchOS.xcarchive"
TVOS_ARCHIVE="$ARCHIVE_DIR/Echoelmusic-tvOS.xcarchive"
VISIONOS_ARCHIVE="$ARCHIVE_DIR/Echoelmusic-visionOS.xcarchive"

###############################################################################
# Helper Functions
###############################################################################

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

###############################################################################
# Clean Function
###############################################################################

clean_build() {
    print_header "Cleaning Build Directory"

    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        print_success "Removed $BUILD_DIR"
    fi

    mkdir -p "$ARCHIVE_DIR"
    mkdir -p "$EXPORT_DIR"
    print_success "Created clean build directories"

    # Clean Xcode derived data
    xcodebuild clean -quiet
    print_success "Cleaned Xcode derived data"
}

###############################################################################
# Build & Archive Functions
###############################################################################

archive_ios() {
    print_header "Building & Archiving iOS/iPadOS"

    xcodebuild archive \
        -scheme "$IOS_SCHEME" \
        -destination 'generic/platform=iOS' \
        -archivePath "$IOS_ARCHIVE" \
        -configuration Release \
        CODE_SIGN_STYLE=Automatic \
        | xcpretty || return 1

    print_success "iOS archive completed: $IOS_ARCHIVE"
}

archive_macos() {
    print_header "Building & Archiving macOS"

    xcodebuild archive \
        -scheme "$MACOS_SCHEME" \
        -destination 'generic/platform=macOS' \
        -archivePath "$MACOS_ARCHIVE" \
        -configuration Release \
        CODE_SIGN_STYLE=Automatic \
        | xcpretty || return 1

    print_success "macOS archive completed: $MACOS_ARCHIVE"
}

archive_watchos() {
    print_header "Building & Archiving watchOS"

    xcodebuild archive \
        -scheme "$WATCHOS_SCHEME" \
        -destination 'generic/platform=watchOS' \
        -archivePath "$WATCHOS_ARCHIVE" \
        -configuration Release \
        CODE_SIGN_STYLE=Automatic \
        | xcpretty || return 1

    print_success "watchOS archive completed: $WATCHOS_ARCHIVE"
}

archive_tvos() {
    print_header "Building & Archiving tvOS"

    xcodebuild archive \
        -scheme "$TVOS_SCHEME" \
        -destination 'generic/platform=tvOS' \
        -archivePath "$TVOS_ARCHIVE" \
        -configuration Release \
        CODE_SIGN_STYLE=Automatic \
        | xcpretty || return 1

    print_success "tvOS archive completed: $TVOS_ARCHIVE"
}

archive_visionos() {
    print_header "Building & Archiving visionOS"

    xcodebuild archive \
        -scheme "$VISIONOS_SCHEME" \
        -destination 'generic/platform=visionOS' \
        -archivePath "$VISIONOS_ARCHIVE" \
        -configuration Release \
        CODE_SIGN_STYLE=Automatic \
        | xcpretty || return 1

    print_success "visionOS archive completed: $VISIONOS_ARCHIVE"
}

###############################################################################
# Export Functions
###############################################################################

export_ios() {
    print_header "Exporting iOS Archive"

    xcodebuild -exportArchive \
        -archivePath "$IOS_ARCHIVE" \
        -exportPath "$EXPORT_DIR/iOS" \
        -exportOptionsPlist ExportOptions-iOS.plist \
        | xcpretty || return 1

    print_success "iOS exported to: $EXPORT_DIR/iOS"
}

export_macos() {
    print_header "Exporting macOS Archive"

    xcodebuild -exportArchive \
        -archivePath "$MACOS_ARCHIVE" \
        -exportPath "$EXPORT_DIR/macOS" \
        -exportOptionsPlist ExportOptions-macOS.plist \
        | xcpretty || return 1

    print_success "macOS exported to: $EXPORT_DIR/macOS"
}

export_watchos() {
    print_header "Exporting watchOS Archive"

    xcodebuild -exportArchive \
        -archivePath "$WATCHOS_ARCHIVE" \
        -exportPath "$EXPORT_DIR/watchOS" \
        -exportOptionsPlist ExportOptions-iOS.plist \
        | xcpretty || return 1

    print_success "watchOS exported to: $EXPORT_DIR/watchOS"
}

export_tvos() {
    print_header "Exporting tvOS Archive"

    xcodebuild -exportArchive \
        -archivePath "$TVOS_ARCHIVE" \
        -exportPath "$EXPORT_DIR/tvOS" \
        -exportOptionsPlist ExportOptions-iOS.plist \
        | xcpretty || return 1

    print_success "tvOS exported to: $EXPORT_DIR/tvOS"
}

export_visionos() {
    print_header "Exporting visionOS Archive"

    xcodebuild -exportArchive \
        -archivePath "$VISIONOS_ARCHIVE" \
        -exportPath "$EXPORT_DIR/visionOS" \
        -exportOptionsPlist ExportOptions-iOS.plist \
        | xcpretty || return 1

    print_success "visionOS exported to: $EXPORT_DIR/visionOS"
}

###############################################################################
# Main Build Pipeline
###############################################################################

build_all_archives() {
    print_header "🏗️  Building All Platforms"

    START_TIME=$(date +%s)

    # Build each platform
    archive_ios || print_error "iOS build failed"
    archive_macos || print_error "macOS build failed"
    archive_watchos || print_error "watchOS build failed"
    archive_tvos || print_error "tvOS build failed"
    archive_visionos || print_error "visionOS build failed"

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    print_success "All archives completed in ${DURATION}s"
}

export_all_archives() {
    print_header "📦 Exporting All Platforms"

    START_TIME=$(date +%s)

    # Export each platform
    export_ios || print_error "iOS export failed"
    export_macos || print_error "macOS export failed"
    export_watchos || print_error "watchOS export failed"
    export_tvos || print_error "tvOS export failed"
    export_visionos || print_error "visionOS export failed"

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    print_success "All exports completed in ${DURATION}s"
}

show_summary() {
    print_header "📊 Build Summary"

    echo ""
    echo "Archives:"
    ls -lh "$ARCHIVE_DIR" | tail -n +2 | awk '{print "  " $9 " - " $5}'

    echo ""
    echo "Exports:"
    find "$EXPORT_DIR" -name "*.ipa" -o -name "*.app" | while read file; do
        SIZE=$(du -h "$file" | cut -f1)
        echo "  $(basename "$file") - $SIZE"
    done

    print_success "Build complete!"
}

###############################################################################
# Script Entry Point
###############################################################################

main() {
    print_header "🎵 Echoelmusic Multi-Platform Build"

    # Check if xcpretty is installed
    if ! command -v xcpretty &> /dev/null; then
        print_warning "xcpretty not found. Installing..."
        gem install xcpretty
    fi

    # Parse command line arguments
    COMMAND="${1:-all}"

    case "$COMMAND" in
        clean)
            clean_build
            ;;
        archive)
            clean_build
            build_all_archives
            ;;
        export)
            export_all_archives
            ;;
        all)
            clean_build
            build_all_archives
            export_all_archives
            show_summary
            ;;
        *)
            print_error "Unknown command: $COMMAND"
            echo ""
            echo "Usage: $0 [clean|archive|export|all]"
            echo ""
            echo "Commands:"
            echo "  clean   - Clean build directory"
            echo "  archive - Build and archive all platforms"
            echo "  export  - Export all archives"
            echo "  all     - Clean, archive, and export (default)"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
