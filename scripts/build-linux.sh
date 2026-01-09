#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
# Echoelmusic - Linux Build Script
# Builds VST3, LV2, CLAP, and Standalone for Linux
# ═══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build/linux"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Echoelmusic Linux Build System${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check dependencies
check_dependencies() {
    echo -e "${BLUE}[INFO] Checking dependencies...${NC}"

    MISSING=""

    # Check for required tools
    for cmd in cmake gcc g++ pkg-config; do
        if ! command -v $cmd &> /dev/null; then
            MISSING="$MISSING $cmd"
        fi
    done

    # Check for ALSA
    if ! pkg-config --exists alsa 2>/dev/null; then
        MISSING="$MISSING libasound2-dev"
    fi

    # Check for X11
    if ! pkg-config --exists x11 2>/dev/null; then
        MISSING="$MISSING libx11-dev"
    fi

    # Check for FreeType
    if ! pkg-config --exists freetype2 2>/dev/null; then
        MISSING="$MISSING libfreetype6-dev"
    fi

    if [ -n "$MISSING" ]; then
        echo -e "${YELLOW}[WARNING] Missing dependencies:$MISSING${NC}"
        echo ""
        echo "Install with:"
        echo "  Ubuntu/Debian: sudo apt install build-essential cmake libasound2-dev libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libfreetype6-dev libcurl4-openssl-dev"
        echo "  Fedora: sudo dnf install gcc-c++ cmake alsa-lib-devel libX11-devel libXrandr-devel libXinerama-devel libXcursor-devel freetype-devel libcurl-devel"
        echo "  Arch: sudo pacman -S base-devel cmake alsa-lib libx11 libxrandr libxinerama libxcursor freetype2 curl"
        echo ""
        read -p "Continue anyway? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo -e "${GREEN}[SUCCESS] All dependencies found${NC}"
    fi
}

# Build
build() {
    echo -e "${BLUE}[INFO] Creating build directory...${NC}"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    echo -e "${BLUE}[INFO] Running CMake configuration...${NC}"
    cmake "$PROJECT_ROOT" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_VST3=ON \
        -DBUILD_LV2=ON \
        -DBUILD_CLAP=ON \
        -DBUILD_STANDALONE=ON \
        -DENABLE_ALSA=ON \
        -DENABLE_JACK=OFF \
        -DENABLE_PULSEAUDIO=OFF

    echo -e "${BLUE}[INFO] Building...${NC}"
    cmake --build . --parallel "$(nproc)"

    echo -e "${GREEN}[SUCCESS] Build complete!${NC}"
}

# Install
install_plugins() {
    echo ""
    echo -e "${BLUE}[INFO] Installing plugins...${NC}"

    # VST3
    VST3_DIR="$HOME/.vst3"
    mkdir -p "$VST3_DIR"
    cp -r "$BUILD_DIR"/*_artefacts/Release/VST3/*.vst3 "$VST3_DIR/" 2>/dev/null || true
    echo -e "${GREEN}  VST3 installed to: $VST3_DIR${NC}"

    # LV2
    LV2_DIR="$HOME/.lv2"
    mkdir -p "$LV2_DIR"
    cp -r "$BUILD_DIR"/*_artefacts/Release/LV2/*.lv2 "$LV2_DIR/" 2>/dev/null || true
    echo -e "${GREEN}  LV2 installed to: $LV2_DIR${NC}"

    # CLAP
    CLAP_DIR="$HOME/.clap"
    mkdir -p "$CLAP_DIR"
    cp -r "$BUILD_DIR"/*_artefacts/Release/CLAP/*.clap "$CLAP_DIR/" 2>/dev/null || true
    echo -e "${GREEN}  CLAP installed to: $CLAP_DIR${NC}"

    # Standalone
    LOCAL_BIN="$HOME/.local/bin"
    mkdir -p "$LOCAL_BIN"
    cp "$BUILD_DIR"/*_artefacts/Release/Standalone/* "$LOCAL_BIN/" 2>/dev/null || true
    echo -e "${GREEN}  Standalone installed to: $LOCAL_BIN${NC}"

    echo ""
    echo -e "${GREEN}[SUCCESS] Plugins installed!${NC}"
}

# Main
main() {
    check_dependencies
    build

    echo ""
    read -p "Install plugins to user directories? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_plugins
    fi

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Build Complete!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Build outputs are in: $BUILD_DIR"
    echo ""
}

main "$@"
