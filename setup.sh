#!/bin/bash
# Echoelmusic Development Setup Script
# Run this once to set up all dependencies

set -e

echo "========================================"
echo "  ECHOELMUSIC DEVELOPMENT SETUP"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    OS="windows"
fi

echo -e "Detected OS: ${GREEN}$OS${NC}"
echo ""

# ============================================
# 1. Clone iPlug2 for Desktop Builds
# ============================================
echo -e "${YELLOW}[1/4] Setting up iPlug2 for Desktop...${NC}"

if [ -d "ThirdParty/iPlug2" ]; then
    echo "  iPlug2 already exists, updating..."
    cd ThirdParty/iPlug2
    git pull
    cd ../..
else
    echo "  Cloning iPlug2..."
    mkdir -p ThirdParty
    git clone https://github.com/iPlug2/iPlug2 ThirdParty/iPlug2
    cd ThirdParty/iPlug2
    git submodule update --init --recursive
    cd ../..
fi
echo -e "  ${GREEN}iPlug2 ready!${NC}"
echo ""

# ============================================
# 2. Install Desktop Dependencies
# ============================================
echo -e "${YELLOW}[2/4] Installing Desktop dependencies...${NC}"

if [[ "$OS" == "macos" ]]; then
    if command -v brew &> /dev/null; then
        brew install cmake pkg-config
    else
        echo "  Please install Homebrew first: https://brew.sh"
    fi
elif [[ "$OS" == "linux" ]]; then
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y build-essential cmake git \
            libasound2-dev libjack-jackd2-dev libfreetype6-dev \
            libx11-dev libxcomposite-dev libxcursor-dev \
            libxext-dev libxinerama-dev libxrandr-dev \
            libxrender-dev libglu1-mesa-dev libcurl4-openssl-dev
    else
        echo "  Please install: cmake, build-essential, audio/X11 dev libraries"
    fi
fi
echo -e "  ${GREEN}Desktop dependencies ready!${NC}"
echo ""

# ============================================
# 3. Setup Android
# ============================================
echo -e "${YELLOW}[3/4] Setting up Android...${NC}"

if [ -d "android" ]; then
    cd android
    chmod +x gradlew 2>/dev/null || true
    cd ..
    echo -e "  ${GREEN}Android project ready!${NC}"
else
    echo -e "  ${RED}Android directory not found${NC}"
fi
echo ""

# ============================================
# 4. Build Desktop
# ============================================
echo -e "${YELLOW}[4/4] Building Desktop plugins...${NC}"

cd Sources/Desktop
mkdir -p build
cd build

if [[ "$OS" == "windows" ]]; then
    cmake -G "Visual Studio 17 2022" -A x64 ..
    cmake --build . --config Release
else
    cmake -DCMAKE_BUILD_TYPE=Release ..
    cmake --build .
fi

cd ../../..
echo -e "  ${GREEN}Desktop build complete!${NC}"
echo ""

# ============================================
# Summary
# ============================================
echo "========================================"
echo -e "  ${GREEN}SETUP COMPLETE!${NC}"
echo "========================================"
echo ""
echo "Next steps:"
echo ""
echo "  Desktop (run standalone):"
echo "    ./Sources/Desktop/build/Echoelmusic_Standalone"
echo ""
echo "  Android (build APK):"
echo "    cd android && ./gradlew assembleDebug"
echo ""
echo "  iOS (requires Xcode):"
echo "    xcodegen generate && open Echoelmusic.xcodeproj"
echo ""
echo "========================================"
