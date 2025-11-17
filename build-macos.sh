#!/bin/bash
# build-macos.sh - macOS Build Script for Echoelmusic
# Usage: ./build-macos.sh [Release|Debug]

set -e

echo "========================================"
echo "ECHOELMUSIC MACOS BUILD"
echo "========================================"

# Parse arguments
BUILD_TYPE="${1:-Release}"
echo "Build Type: $BUILD_TYPE"
echo ""

# Check for CMake
if ! command -v cmake &> /dev/null; then
    echo "Error: CMake not found!"
    echo "Install with: brew install cmake"
    exit 1
fi

# Check for Ninja (optional, but faster)
if command -v ninja &> /dev/null; then
    GENERATOR="Ninja"
    echo "Using Ninja build system (fast)"
else
    GENERATOR="Unix Makefiles"
    echo "Using Make build system"
    echo "Tip: Install Ninja for faster builds: brew install ninja"
fi

# Check/Install JUCE
if [ ! -d "ThirdParty/JUCE/modules" ]; then
    echo "Installing JUCE framework..."
    rm -rf ThirdParty/JUCE
    git clone --depth 1 --branch 7.0.12 https://github.com/juce-framework/JUCE.git ThirdParty/JUCE

    if [ ! -d "ThirdParty/JUCE/modules" ]; then
        echo "Error: Failed to clone JUCE"
        exit 1
    fi
fi

echo "JUCE: OK"
echo ""

# Create build directory
rm -rf build
mkdir build
cd build

# Detect CPU cores
NPROC=$(sysctl -n hw.ncpu)
echo "CPU Cores: $NPROC"

# Configure with CMake (Universal Binary)
echo "Configuring CMake (Universal Binary: arm64 + x86_64)..."
cmake .. -G "$GENERATOR" \
    -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=10.13 \
    -DBUILD_VST3=ON \
    -DBUILD_AU=ON \
    -DBUILD_STANDALONE=ON \
    -DBUILD_AAX=OFF \
    -DBUILD_LV2=OFF

echo ""
echo "Building..."
cmake --build . --config $BUILD_TYPE --parallel $NPROC

cd ..

echo ""
echo "========================================"
echo "BUILD SUCCESS!"
echo "========================================"
echo ""
echo "Output location:"
ls -lh build/Echoelmusic_artefacts/$BUILD_TYPE/

# Verify Universal Binary
echo ""
echo "Verifying Universal Binary:"
if [ -f "build/Echoelmusic_artefacts/$BUILD_TYPE/Standalone/Echoelmusic.app/Contents/MacOS/Echoelmusic" ]; then
    lipo -info "build/Echoelmusic_artefacts/$BUILD_TYPE/Standalone/Echoelmusic.app/Contents/MacOS/Echoelmusic"
fi

echo ""
echo "To install:"
echo "  VST3: cp -r build/Echoelmusic_artefacts/$BUILD_TYPE/VST3/Echoelmusic.vst3 ~/Library/Audio/Plug-Ins/VST3/"
echo "  AU:   cp -r build/Echoelmusic_artefacts/$BUILD_TYPE/AU/Echoelmusic.component ~/Library/Audio/Plug-Ins/Components/"
echo "  App:  cp -r build/Echoelmusic_artefacts/$BUILD_TYPE/Standalone/Echoelmusic.app /Applications/"
echo ""
echo "IMPORTANT: For distribution, you must code sign and notarize:"
echo "  codesign --deep --force --verify --verbose --sign 'Developer ID' Echoelmusic.app"
echo "  xcrun notarytool submit Echoelmusic.dmg --keychain-profile 'AC_PASSWORD'"
echo ""
