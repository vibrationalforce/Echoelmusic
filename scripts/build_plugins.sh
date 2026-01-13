#!/bin/bash
# ============================================================================
# EchoelDSP Plugin Build Script
# ============================================================================
# Builds VST3, Audio Unit, and CLAP plugins for all platforms
# ============================================================================

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
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}              EchoelDSP Plugin Build System                   ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  JUCE-FREE | iPlug2-FREE | Pure C++17 | SIMD-Optimized      ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

detect_platform() {
    case "$(uname -s)" in
        Darwin*)
            PLATFORM="macos"
            if [[ "$(uname -m)" == "arm64" ]]; then
                ARCH="arm64"
            else
                ARCH="x86_64"
            fi
            ;;
        Linux*)
            PLATFORM="linux"
            ARCH="$(uname -m)"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            PLATFORM="windows"
            ARCH="x64"
            ;;
        *)
            echo -e "${RED}Unknown platform: $(uname -s)${NC}"
            exit 1
            ;;
    esac

    echo -e "${GREEN}Platform:${NC} $PLATFORM ($ARCH)"
}

build_cmake() {
    echo ""
    echo -e "${YELLOW}[1/4] Configuring CMake...${NC}"

    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    CMAKE_ARGS=(
        -DCMAKE_BUILD_TYPE=Release
        -DECHOEL_DSP_BUILD_TESTS=ON
        -DECHOEL_DSP_BUILD_EXAMPLES=ON
        -DECHOEL_DSP_ENABLE_SIMD=ON
    )

    # Platform-specific options
    case "$PLATFORM" in
        macos)
            CMAKE_ARGS+=(-DECHOEL_DSP_BUILD_AU=ON)
            CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES="arm64;x86_64")
            ;;
        linux)
            CMAKE_ARGS+=(-DECHOEL_DSP_BUILD_VST3=ON)
            CMAKE_ARGS+=(-DECHOEL_DSP_BUILD_CLAP=ON)
            ;;
        windows)
            CMAKE_ARGS+=(-DECHOEL_DSP_BUILD_VST3=ON)
            CMAKE_ARGS+=(-DECHOEL_DSP_BUILD_CLAP=ON)
            CMAKE_ARGS+=(-G "Visual Studio 17 2022" -A x64)
            ;;
    esac

    cmake "$PROJECT_ROOT/Sources/EchoelDSP" "${CMAKE_ARGS[@]}"
}

build_plugins() {
    echo ""
    echo -e "${YELLOW}[2/4] Building plugins...${NC}"

    cd "$BUILD_DIR"

    if [ "$PLATFORM" == "windows" ]; then
        cmake --build . --config Release --parallel
    else
        cmake --build . --parallel $(nproc 2>/dev/null || sysctl -n hw.ncpu)
    fi
}

run_tests() {
    echo ""
    echo -e "${YELLOW}[3/4] Running tests...${NC}"

    cd "$BUILD_DIR"

    if [ -f "./EchoelDSPTests" ]; then
        ./EchoelDSPTests
    elif [ -f "./Release/EchoelDSPTests.exe" ]; then
        ./Release/EchoelDSPTests.exe
    else
        echo -e "${YELLOW}  Tests not found, skipping...${NC}"
    fi
}

package_plugins() {
    echo ""
    echo -e "${YELLOW}[4/4] Packaging plugins...${NC}"

    mkdir -p "$DIST_DIR/$PLATFORM"

    case "$PLATFORM" in
        macos)
            # Copy Audio Unit
            if [ -d "$BUILD_DIR/Echoelmusic.component" ]; then
                cp -r "$BUILD_DIR/Echoelmusic.component" "$DIST_DIR/$PLATFORM/"
                echo -e "${GREEN}  ✓ Audio Unit${NC}"
            fi

            # Copy VST3
            if [ -d "$BUILD_DIR/Echoelmusic.vst3" ]; then
                cp -r "$BUILD_DIR/Echoelmusic.vst3" "$DIST_DIR/$PLATFORM/"
                echo -e "${GREEN}  ✓ VST3${NC}"
            fi

            # Copy CLAP
            if [ -f "$BUILD_DIR/Echoelmusic.clap" ]; then
                cp "$BUILD_DIR/Echoelmusic.clap" "$DIST_DIR/$PLATFORM/"
                echo -e "${GREEN}  ✓ CLAP${NC}"
            fi
            ;;

        linux)
            # Copy VST3
            if [ -d "$BUILD_DIR/Echoelmusic.vst3" ]; then
                cp -r "$BUILD_DIR/Echoelmusic.vst3" "$DIST_DIR/$PLATFORM/"
                echo -e "${GREEN}  ✓ VST3${NC}"
            fi

            # Copy CLAP
            if [ -f "$BUILD_DIR/Echoelmusic.clap" ]; then
                cp "$BUILD_DIR/Echoelmusic.clap" "$DIST_DIR/$PLATFORM/"
                echo -e "${GREEN}  ✓ CLAP${NC}"
            fi
            ;;

        windows)
            # Copy VST3
            if [ -d "$BUILD_DIR/Release/Echoelmusic.vst3" ]; then
                cp -r "$BUILD_DIR/Release/Echoelmusic.vst3" "$DIST_DIR/$PLATFORM/"
                echo -e "${GREEN}  ✓ VST3${NC}"
            fi

            # Copy CLAP
            if [ -f "$BUILD_DIR/Release/Echoelmusic.clap" ]; then
                cp "$BUILD_DIR/Release/Echoelmusic.clap" "$DIST_DIR/$PLATFORM/"
                echo -e "${GREEN}  ✓ CLAP${NC}"
            fi
            ;;
    esac

    echo ""
    echo -e "${GREEN}Plugins packaged to: $DIST_DIR/$PLATFORM${NC}"
}

# ============================================================================
# Main
# ============================================================================

print_header
detect_platform
build_cmake
build_plugins
run_tests
package_plugins

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              BUILD COMPLETE                                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
