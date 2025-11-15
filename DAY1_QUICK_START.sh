#!/bin/bash

# 🚀 ULTRATHINK DAY 1 - Quick Start Script
# Automated setup for desktop build environment

set -e  # Exit on error

echo "╔═══════════════════════════════════════╗"
echo "║  🎵 ECHOELMUSIC - DAY 1 QUICK START  ║"
echo "╚═══════════════════════════════════════╝"
echo ""

# ====================================
# 1. Environment Check
# ====================================
echo "📋 Step 1: Checking environment..."

# Check for required tools
command -v cmake >/dev/null 2>&1 || { echo "❌ CMake not found. Install: sudo apt install cmake"; exit 1; }
command -v g++ >/dev/null 2>&1 || { echo "❌ G++ not found. Install: sudo apt install build-essential"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "❌ Git not found. Install: sudo apt install git"; exit 1; }

echo "✅ CMake: $(cmake --version | head -1)"
echo "✅ G++: $(g++ --version | head -1)"
echo "✅ Git: $(git --version)"
echo ""

# ====================================
# 2. JUCE Framework Check
# ====================================
echo "📋 Step 2: Checking JUCE framework..."

if [ ! -f "ThirdParty/JUCE/CMakeLists.txt" ]; then
    echo "⚠️  JUCE not found. Cloning JUCE 7.0.12..."
    mkdir -p ThirdParty/JUCE
    git clone --depth=1 --branch=7.0.12 https://github.com/juce-framework/JUCE.git ThirdParty/JUCE
    echo "✅ JUCE installed!"
else
    echo "✅ JUCE already installed"
fi
echo ""

# ====================================
# 3. Clean Build Directory
# ====================================
echo "📋 Step 3: Preparing build directory..."

if [ -d "build" ]; then
    echo "🗑️  Removing old build directory..."
    rm -rf build
fi

mkdir -p build
echo "✅ Clean build directory created"
echo ""

# ====================================
# 4. CMake Configuration
# ====================================
echo "📋 Step 4: Configuring CMake (Release mode)..."

cd build
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_VST3=ON \
    -DBUILD_STANDALONE=ON \
    -DBUILD_AU=OFF \
    -DBUILD_AAX=OFF \
    -DENABLE_ALSA=ON \
    -DENABLE_JACK=OFF \
    -DENABLE_PULSEAUDIO=OFF \
    2>&1 | tee cmake_config.log

if [ $? -eq 0 ]; then
    echo "✅ CMake configuration successful!"
else
    echo "❌ CMake configuration failed. Check cmake_config.log"
    exit 1
fi
echo ""

# ====================================
# 5. Compile (First Attempt)
# ====================================
echo "📋 Step 5: Compiling project..."
echo "⏱️  This may take 5-15 minutes..."
echo ""

# Build with all cores
CORES=$(nproc)
echo "🔧 Building with $CORES cores..."

make -j$CORES 2>&1 | tee compile.log

BUILD_STATUS=$?

echo ""
if [ $BUILD_STATUS -eq 0 ]; then
    echo "✅ ✅ ✅ BUILD SUCCESSFUL! ✅ ✅ ✅"
    echo ""
    echo "📊 Build Summary:"
    echo "  - Standalone: $(find . -name 'Echoelmusic' -type f | head -1)"
    echo "  - VST3: $(find . -name 'Echoelmusic.vst3' -type d | head -1)"
    echo ""
    echo "🚀 To run standalone:"
    echo "   ./$(find . -name 'Echoelmusic' -type f | head -1 | sed 's|^./||')"
    echo ""
else
    echo "⚠️  BUILD FAILED (expected on first try)"
    echo ""
    echo "📊 Error Analysis:"

    # Count errors and warnings
    ERRORS=$(grep -c "error:" compile.log || true)
    WARNINGS=$(grep -c "warning:" compile.log || true)

    echo "  - Errors: $ERRORS"
    echo "  - Warnings: $WARNINGS"
    echo ""
    echo "🔍 Top 10 errors:"
    grep "error:" compile.log | head -10 || echo "  (no error details found)"
    echo ""
    echo "📝 Full log saved to: build/compile.log"
fi

cd ..

# ====================================
# 6. Status Summary
# ====================================
echo ""
echo "╔═══════════════════════════════════════╗"
echo "║        DAY 1 QUICK START DONE        ║"
echo "╚═══════════════════════════════════════╝"
echo ""

if [ $BUILD_STATUS -eq 0 ]; then
    echo "✅ SUCCESS: Desktop build is working!"
    echo ""
    echo "📋 Next Steps:"
    echo "  1. Run the standalone: cd build && make run"
    echo "  2. Test basic features (audio, MIDI, save/load)"
    echo "  3. Start fixing warnings (see Day 2 tasks)"
    echo ""
else
    echo "⚠️  BUILD NEEDS FIXES"
    echo ""
    echo "📋 Next Steps:"
    echo "  1. Review build/compile.log for errors"
    echo "  2. Fix top 5 critical errors first"
    echo "  3. Re-run this script: ./DAY1_QUICK_START.sh"
    echo ""
fi

echo "📖 See ULTRATHINK_7DAY_SPRINT.md for full plan"
echo ""
echo "🚀 Let's build something amazing!"
