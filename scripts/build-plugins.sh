#!/bin/bash
# =============================================================================
# EchoelCore Plugin Build Script
# =============================================================================
# Builds VST3, AU, CLAP, AUv3 plugins for all platforms
# NO JUCE. NO iPlug2. Pure native build.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
DIST_DIR="$PROJECT_ROOT/dist"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "=============================================="
echo "  EchoelCore Plugin Builder"
echo "  NO JUCE. NO iPlug2. Pure Native."
echo "=============================================="
echo -e "${NC}"

# =============================================================================
# Detect Platform
# =============================================================================

detect_platform() {
    case "$(uname -s)" in
        Darwin*)
            PLATFORM="macos"
            ;;
        Linux*)
            PLATFORM="linux"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            PLATFORM="windows"
            ;;
        *)
            echo -e "${RED}Unsupported platform: $(uname -s)${NC}"
            exit 1
            ;;
    esac
    echo -e "${GREEN}Platform: $PLATFORM${NC}"
}

# =============================================================================
# Build Configuration
# =============================================================================

configure_build() {
    local build_type="${1:-Release}"

    echo -e "${YELLOW}Configuring build ($build_type)...${NC}"

    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    cmake "$PROJECT_ROOT/Sources/EchoelCore" \
        -DCMAKE_BUILD_TYPE="$build_type" \
        -DECHOELCORE_BUILD_TESTS=ON \
        -DECHOELCORE_BUILD_VST3=ON \
        -DECHOELCORE_BUILD_CLAP=ON \
        -DECHOELCORE_USE_SIMD=ON

    if [[ "$PLATFORM" == "macos" ]]; then
        cmake "$PROJECT_ROOT/Sources/EchoelCore" \
            -DECHOELCORE_BUILD_AU=ON
    fi
}

# =============================================================================
# Build
# =============================================================================

build_project() {
    echo -e "${YELLOW}Building...${NC}"

    cd "$BUILD_DIR"
    cmake --build . --parallel $(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

    echo -e "${GREEN}Build complete!${NC}"
}

# =============================================================================
# Run Tests
# =============================================================================

run_tests() {
    echo -e "${YELLOW}Running tests...${NC}"

    cd "$BUILD_DIR"

    if [[ -f "EchoelCoreTests" ]]; then
        ./EchoelCoreTests
    else
        echo -e "${YELLOW}Test executable not found, skipping...${NC}"
    fi
}

# =============================================================================
# Package Plugins
# =============================================================================

package_vst3() {
    echo -e "${YELLOW}Packaging VST3...${NC}"

    local vst3_dir="$DIST_DIR/VST3"
    mkdir -p "$vst3_dir"

    # VST3 bundle structure
    local bundle="$vst3_dir/Echoelmusic.vst3"
    mkdir -p "$bundle/Contents/MacOS"
    mkdir -p "$bundle/Contents/Resources"

    # Copy binary (if exists)
    if [[ -f "$BUILD_DIR/libEchoelmusic.dylib" ]]; then
        cp "$BUILD_DIR/libEchoelmusic.dylib" "$bundle/Contents/MacOS/Echoelmusic"
    fi

    # Create Info.plist
    cat > "$bundle/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>English</string>
    <key>CFBundleExecutable</key>
    <string>Echoelmusic</string>
    <key>CFBundleIdentifier</key>
    <string>com.echoelmusic.vst3</string>
    <key>CFBundleName</key>
    <string>Echoelmusic</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
</dict>
</plist>
EOF

    echo -e "${GREEN}VST3 packaged: $bundle${NC}"
}

package_au() {
    if [[ "$PLATFORM" != "macos" ]]; then
        return
    fi

    echo -e "${YELLOW}Packaging Audio Unit...${NC}"

    local au_dir="$DIST_DIR/AU"
    mkdir -p "$au_dir"

    local bundle="$au_dir/Echoelmusic.component"
    mkdir -p "$bundle/Contents/MacOS"
    mkdir -p "$bundle/Contents/Resources"

    # Copy binary (if exists)
    if [[ -f "$BUILD_DIR/libEchoelmusic.dylib" ]]; then
        cp "$BUILD_DIR/libEchoelmusic.dylib" "$bundle/Contents/MacOS/Echoelmusic"
    fi

    # Create Info.plist for AU
    cat > "$bundle/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>English</string>
    <key>CFBundleExecutable</key>
    <string>Echoelmusic</string>
    <key>CFBundleIdentifier</key>
    <string>com.echoelmusic.audiounit</string>
    <key>CFBundleName</key>
    <string>Echoelmusic</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>AudioComponents</key>
    <array>
        <dict>
            <key>name</key>
            <string>Echoelmusic: Bio-Reactive</string>
            <key>description</key>
            <string>Bio-Reactive Audio Processor</string>
            <key>manufacturer</key>
            <string>Echo</string>
            <key>type</key>
            <string>aufx</string>
            <key>subtype</key>
            <string>Echl</string>
            <key>version</key>
            <integer>65536</integer>
        </dict>
    </array>
</dict>
</plist>
EOF

    echo -e "${GREEN}AU packaged: $bundle${NC}"
}

package_clap() {
    echo -e "${YELLOW}Packaging CLAP...${NC}"

    local clap_dir="$DIST_DIR/CLAP"
    mkdir -p "$clap_dir"

    # CLAP is a single file on most platforms
    local clap_file="$clap_dir/Echoelmusic.clap"

    if [[ "$PLATFORM" == "macos" ]]; then
        # macOS CLAP bundle
        mkdir -p "$clap_file/Contents/MacOS"

        if [[ -f "$BUILD_DIR/libEchoelmusic.dylib" ]]; then
            cp "$BUILD_DIR/libEchoelmusic.dylib" "$clap_file/Contents/MacOS/Echoelmusic"
        fi

        cat > "$clap_file/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Echoelmusic</string>
    <key>CFBundleIdentifier</key>
    <string>com.echoelmusic.clap</string>
    <key>CFBundleName</key>
    <string>Echoelmusic</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
</dict>
</plist>
EOF
    fi

    echo -e "${GREEN}CLAP packaged: $clap_file${NC}"
}

# =============================================================================
# WebAssembly Build
# =============================================================================

build_wasm() {
    echo -e "${YELLOW}Building WebAssembly module...${NC}"

    if ! command -v emcc &> /dev/null; then
        echo -e "${RED}Emscripten not found. Install with: brew install emscripten${NC}"
        return
    fi

    local wasm_dir="$DIST_DIR/WASM"
    mkdir -p "$wasm_dir"

    emcc "$PROJECT_ROOT/Sources/EchoelCore/Backends/WebAudioBackend.h" \
        -I"$PROJECT_ROOT/Sources" \
        -O3 \
        -s WASM=1 \
        -s MODULARIZE=1 \
        -s EXPORT_NAME='EchoelCore' \
        -s EXPORTED_FUNCTIONS='["_initializeAudio","_startAudio","_stopAudio","_processAudio","_getInputBufferPtr","_getOutputBufferPtr"]' \
        -s EXPORTED_RUNTIME_METHODS='["ccall","cwrap"]' \
        -msimd128 \
        -o "$wasm_dir/echoelcore.js"

    echo -e "${GREEN}WASM built: $wasm_dir/echoelcore.js${NC}"
}

# =============================================================================
# Clean
# =============================================================================

clean() {
    echo -e "${YELLOW}Cleaning build directories...${NC}"
    rm -rf "$BUILD_DIR"
    rm -rf "$DIST_DIR"
    echo -e "${GREEN}Clean complete!${NC}"
}

# =============================================================================
# Main
# =============================================================================

usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  all       Build all plugins (default)"
    echo "  vst3      Build VST3 only"
    echo "  au        Build Audio Unit only (macOS)"
    echo "  clap      Build CLAP only"
    echo "  wasm      Build WebAssembly module"
    echo "  test      Run unit tests"
    echo "  clean     Clean build directories"
    echo ""
}

main() {
    detect_platform

    case "${1:-all}" in
        all)
            configure_build Release
            build_project
            run_tests
            package_vst3
            package_au
            package_clap
            ;;
        vst3)
            configure_build Release
            build_project
            package_vst3
            ;;
        au)
            configure_build Release
            build_project
            package_au
            ;;
        clap)
            configure_build Release
            build_project
            package_clap
            ;;
        wasm)
            build_wasm
            ;;
        test)
            configure_build Debug
            build_project
            run_tests
            ;;
        clean)
            clean
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            usage
            exit 1
            ;;
    esac

    echo ""
    echo -e "${GREEN}=============================================="
    echo "  Build Complete!"
    echo "  Output: $DIST_DIR"
    echo "==============================================${NC}"
}

main "$@"
