#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
# Echoelmusic - Universal Build Script
# Builds for all supported platforms and plugin formats
# ═══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Detect Platform
# ═══════════════════════════════════════════════════════════════════════════════

detect_platform() {
    case "$(uname -s)" in
        Darwin)
            PLATFORM="macos"
            ;;
        Linux)
            PLATFORM="linux"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            PLATFORM="windows"
            ;;
        *)
            print_error "Unknown platform: $(uname -s)"
            exit 1
            ;;
    esac
    print_info "Detected platform: $PLATFORM"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Build Swift (iOS/macOS/watchOS/tvOS/visionOS)
# ═══════════════════════════════════════════════════════════════════════════════

build_swift() {
    print_header "Building Swift Package"

    cd "$PROJECT_ROOT"

    if command -v swift &> /dev/null; then
        print_info "Building Swift package..."
        swift build -c release
        print_success "Swift build complete"
    else
        print_warning "Swift not found - skipping Swift build"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Build Desktop Plugins (VST3/AU/AAX/LV2/CLAP)
# ═══════════════════════════════════════════════════════════════════════════════

build_desktop_plugins() {
    print_header "Building Desktop Plugins (VST3/AU/AAX/LV2/CLAP)"

    mkdir -p "$BUILD_DIR/desktop"
    cd "$BUILD_DIR/desktop"

    CMAKE_ARGS=(
        -DCMAKE_BUILD_TYPE=Release
        -DBUILD_VST3=ON
        -DBUILD_STANDALONE=ON
    )

    # Platform-specific options
    case "$PLATFORM" in
        macos)
            CMAKE_ARGS+=(-DBUILD_AU=ON -DBUILD_AAX=ON -DBUILD_CLAP=ON)
            ;;
        linux)
            CMAKE_ARGS+=(-DBUILD_LV2=ON -DBUILD_CLAP=ON -DENABLE_ALSA=ON)
            ;;
        windows)
            CMAKE_ARGS+=(-DBUILD_AAX=ON -DBUILD_CLAP=ON -DENABLE_ASIO=ON -DENABLE_WASAPI=ON)
            ;;
    esac

    # Check for JUCE
    if [ -d "$PROJECT_ROOT/ThirdParty/JUCE" ]; then
        CMAKE_ARGS+=(-DUSE_JUCE=ON)
        print_info "JUCE found - building with JUCE"
    else
        print_warning "JUCE not found - using iPlug2 or native build"
        CMAKE_ARGS+=(-DUSE_IPLUG2=ON)
    fi

    print_info "Running CMake with: ${CMAKE_ARGS[*]}"
    cmake "$PROJECT_ROOT" "${CMAKE_ARGS[@]}"
    cmake --build . --parallel "$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"

    print_success "Desktop plugins build complete"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Build Android
# ═══════════════════════════════════════════════════════════════════════════════

build_android() {
    print_header "Building Android App"

    if [ -d "$PROJECT_ROOT/android" ]; then
        cd "$PROJECT_ROOT/android"

        if [ -f "gradlew" ]; then
            chmod +x gradlew

            print_info "Building Android debug APK..."
            ./gradlew assembleDebug
            print_success "Android debug build complete"

            print_info "Building Android release APK..."
            ./gradlew assembleRelease
            print_success "Android release build complete"

            # Copy APKs to build directory
            mkdir -p "$BUILD_DIR/android"
            cp app/build/outputs/apk/debug/*.apk "$BUILD_DIR/android/" 2>/dev/null || true
            cp app/build/outputs/apk/release/*.apk "$BUILD_DIR/android/" 2>/dev/null || true
        else
            print_warning "Gradle wrapper not found - skipping Android build"
        fi
    else
        print_warning "Android directory not found - skipping Android build"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Build for Windows (Cross-compile on Linux/macOS)
# ═══════════════════════════════════════════════════════════════════════════════

build_windows_crosscompile() {
    print_header "Cross-compiling for Windows"

    if command -v x86_64-w64-mingw32-gcc &> /dev/null; then
        mkdir -p "$BUILD_DIR/windows"
        cd "$BUILD_DIR/windows"

        cmake "$PROJECT_ROOT" \
            -DCMAKE_TOOLCHAIN_FILE="$PROJECT_ROOT/cmake/mingw-toolchain.cmake" \
            -DCMAKE_BUILD_TYPE=Release \
            -DBUILD_VST3=ON \
            -DBUILD_STANDALONE=ON

        cmake --build . --parallel
        print_success "Windows cross-compile complete"
    else
        print_warning "MinGW not found - skipping Windows cross-compile"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Run Tests
# ═══════════════════════════════════════════════════════════════════════════════

run_tests() {
    print_header "Running Tests"

    cd "$PROJECT_ROOT"

    # Swift tests
    if command -v swift &> /dev/null; then
        print_info "Running Swift tests..."
        swift test
        print_success "Swift tests passed"
    fi

    # Android tests
    if [ -d "$PROJECT_ROOT/android" ] && [ -f "$PROJECT_ROOT/android/gradlew" ]; then
        print_info "Running Android tests..."
        cd "$PROJECT_ROOT/android"
        ./gradlew test
        print_success "Android tests passed"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Create Distribution Package
# ═══════════════════════════════════════════════════════════════════════════════

create_distribution() {
    print_header "Creating Distribution Package"

    DIST_DIR="$BUILD_DIR/dist"
    mkdir -p "$DIST_DIR"

    VERSION=$(grep 'version' "$PROJECT_ROOT/Package.swift" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "1.0.0")

    print_info "Creating Echoelmusic v$VERSION distribution..."

    # Copy build artifacts
    cp -r "$BUILD_DIR/desktop"/*.vst3 "$DIST_DIR/" 2>/dev/null || true
    cp -r "$BUILD_DIR/desktop"/*.component "$DIST_DIR/" 2>/dev/null || true
    cp -r "$BUILD_DIR/android"/*.apk "$DIST_DIR/" 2>/dev/null || true

    # Create archive
    cd "$BUILD_DIR"
    tar -czvf "echoelmusic-$VERSION-$PLATFORM.tar.gz" dist/

    print_success "Distribution package created: echoelmusic-$VERSION-$PLATFORM.tar.gz"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    print_header "Echoelmusic Universal Build System"

    detect_platform

    # Parse arguments
    BUILD_SWIFT=true
    BUILD_DESKTOP=true
    BUILD_ANDROID=true
    RUN_TESTS=false
    CREATE_DIST=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --swift-only)
                BUILD_DESKTOP=false
                BUILD_ANDROID=false
                ;;
            --desktop-only)
                BUILD_SWIFT=false
                BUILD_ANDROID=false
                ;;
            --android-only)
                BUILD_SWIFT=false
                BUILD_DESKTOP=false
                ;;
            --test)
                RUN_TESTS=true
                ;;
            --dist)
                CREATE_DIST=true
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --swift-only     Build only Swift targets"
                echo "  --desktop-only   Build only desktop plugins"
                echo "  --android-only   Build only Android"
                echo "  --test           Run tests after build"
                echo "  --dist           Create distribution package"
                echo "  --help           Show this help"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
        shift
    done

    # Execute builds
    if [ "$BUILD_SWIFT" = true ]; then
        build_swift
    fi

    if [ "$BUILD_DESKTOP" = true ]; then
        build_desktop_plugins
    fi

    if [ "$BUILD_ANDROID" = true ]; then
        build_android
    fi

    if [ "$RUN_TESTS" = true ]; then
        run_tests
    fi

    if [ "$CREATE_DIST" = true ]; then
        create_distribution
    fi

    print_header "Build Complete!"
    echo ""
    print_info "Build outputs are in: $BUILD_DIR"
    echo ""
}

main "$@"
