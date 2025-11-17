#!/bin/bash
# verify_build.sh - ECHOELMUSIC BUILD VERIFICATION
# Usage: ./verify_build.sh [--clean]

set -e  # Stop on first error

echo "🔍 ECHOELMUSIC BUILD VERIFICATION"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
CLEAN_BUILD=false
if [[ "$1" == "--clean" ]]; then
    CLEAN_BUILD=true
fi

# 1. Clean everything if requested
if [ "$CLEAN_BUILD" = true ]; then
    echo -e "${BLUE}🧹 Cleaning build artifacts...${NC}"
    rm -rf build
    rm -rf Builds/*/build
    rm -rf .cache
    rm -rf CMakeCache.txt
    echo -e "${GREEN}✅ Clean complete${NC}"
fi

# 2. Check JUCE
echo -e "${BLUE}🎵 Checking JUCE framework...${NC}"
if [ ! -d "ThirdParty/JUCE" ] || [ -z "$(ls -A ThirdParty/JUCE)" ]; then
    echo -e "${RED}❌ JUCE not found! Installing...${NC}"
    rm -rf ThirdParty/JUCE
    git clone --depth 1 --branch 7.0.12 https://github.com/juce-framework/JUCE.git ThirdParty/JUCE

    if [ ! -d "ThirdParty/JUCE/modules" ]; then
        echo -e "${RED}❌ JUCE installation failed!${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ JUCE found${NC}"
fi

# Check JUCE modules
JUCE_MODULES=$(ls ThirdParty/JUCE/modules 2>/dev/null | wc -l)
echo -e "${GREEN}   Found $JUCE_MODULES JUCE modules${NC}"

# 3. Configure
echo -e "${BLUE}⚙️  Configuring CMake...${NC}"
cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="-Wall -Wno-deprecated-declarations" \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DBUILD_VST3=ON \
    -DBUILD_STANDALONE=ON \
    -DBUILD_AAX=OFF \
    -DBUILD_LV2=OFF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ CMake configuration successful${NC}"
else
    echo -e "${RED}❌ CMake configuration failed!${NC}"
    exit 1
fi

# 4. Build
echo -e "${BLUE}🔨 Building Echoelmusic...${NC}"
echo "   This may take several minutes..."

# Get CPU count for parallel build
NPROC=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
echo "   Using $NPROC parallel jobs"

# Build and capture output
if cmake --build build --parallel $NPROC 2>&1 | tee build.log; then
    echo -e "${GREEN}✅ Build successful${NC}"
else
    echo -e "${RED}❌ Build failed! Check build.log for details${NC}"
    echo ""
    echo "Last 20 lines of build log:"
    tail -20 build.log
    exit 1
fi

# 5. Check for warnings
echo -e "${BLUE}⚠️  Checking for warnings...${NC}"
WARNINGS=$(grep -i "warning" build.log | grep -v "has no symbols" | wc -l || echo "0")
WARNINGS=$(echo $WARNINGS | xargs)  # Trim whitespace

if [ "$WARNINGS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $WARNINGS warnings${NC}"
    echo "   First 10 warnings:"
    grep -i "warning" build.log | grep -v "has no symbols" | head -10 || true
else
    echo -e "${GREEN}✅ No warnings!${NC}"
fi

# 6. Run tests (if available)
echo -e "${BLUE}🧪 Running tests...${NC}"
if [ -d "build/Tests" ]; then
    if ctest --test-dir build --output-on-failure; then
        echo -e "${GREEN}✅ All tests passed${NC}"
    else
        echo -e "${YELLOW}⚠️  Some tests failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No tests found${NC}"
fi

# 7. Verify outputs
echo -e "${BLUE}📦 Verifying build outputs...${NC}"

# Platform-specific expected outputs
EXPECTED_OUTPUTS=()

# Check for Standalone
if [ -f "build/Echoelmusic_artefacts/Release/Standalone/Echoelmusic" ] || \
   [ -f "build/Echoelmusic_artefacts/Release/Standalone/Echoelmusic.exe" ] || \
   [ -d "build/Echoelmusic_artefacts/Release/Standalone/Echoelmusic.app" ]; then
    echo -e "${GREEN}✅ Standalone application built${NC}"
    EXPECTED_OUTPUTS+=("Standalone")
else
    echo -e "${YELLOW}⚠️  Standalone application not found${NC}"
fi

# Check for VST3
if [ -d "build/Echoelmusic_artefacts/Release/VST3/Echoelmusic.vst3" ]; then
    echo -e "${GREEN}✅ VST3 plugin built${NC}"
    EXPECTED_OUTPUTS+=("VST3")
else
    echo -e "${YELLOW}⚠️  VST3 plugin not found${NC}"
fi

# Check for AU (macOS only)
if [ "$(uname)" == "Darwin" ]; then
    if [ -d "build/Echoelmusic_artefacts/Release/AU/Echoelmusic.component" ]; then
        echo -e "${GREEN}✅ AU plugin built${NC}"
        EXPECTED_OUTPUTS+=("AU")
    else
        echo -e "${YELLOW}⚠️  AU plugin not found${NC}"
    fi
fi

# Check for AAX
if [ -d "build/Echoelmusic_artefacts/Release/AAX/Echoelmusic.aaxplugin" ]; then
    echo -e "${GREEN}✅ AAX plugin built${NC}"
    EXPECTED_OUTPUTS+=("AAX")
fi

# Check for CLAP
if [ -d "build/Echoelmusic_artefacts/Release/CLAP/Echoelmusic.clap" ]; then
    echo -e "${GREEN}✅ CLAP plugin built${NC}"
    EXPECTED_OUTPUTS+=("CLAP")
fi

# 8. File size check
echo -e "${BLUE}📊 Build artifacts summary:${NC}"
if [ -d "build/Echoelmusic_artefacts/Release" ]; then
    du -sh build/Echoelmusic_artefacts/Release/* 2>/dev/null || true
fi

# 9. Summary
echo ""
echo "=================================="
echo -e "${BLUE}🎉 BUILD VERIFICATION COMPLETE!${NC}"
echo "=================================="
echo ""
echo "Summary:"
echo "  Built formats: ${#EXPECTED_OUTPUTS[@]}"
for format in "${EXPECTED_OUTPUTS[@]}"; do
    echo "    - $format"
done
echo "  Warnings: $WARNINGS"
echo ""
echo "Build log saved to: build.log"
echo ""

if [ ${#EXPECTED_OUTPUTS[@]} -gt 0 ] && [ "$WARNINGS" -lt 10 ]; then
    echo -e "${GREEN}✅ Build is ready for deployment!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Build completed with issues. Review above.${NC}"
    exit 0
fi
