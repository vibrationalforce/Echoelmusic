#!/bin/bash

#######################################################
# Eoel JUCE + VST3 + CLAP Setup Script
#######################################################

set -e

echo "🎸 ================================================"
echo "🎸 Eoel JUCE Plugin Setup"
echo "🎸 ================================================"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directories
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THIRD_PARTY_DIR="$PROJECT_ROOT/ThirdParty"

echo -e "${BLUE}📂 Project Root: $PROJECT_ROOT${NC}"
echo ""

#######################################################
# Step 1: Check Dependencies
#######################################################

echo -e "${BLUE}Step 1: Checking dependencies...${NC}"

# Check CMake
if ! command -v cmake &> /dev/null; then
    echo -e "${YELLOW}⚠️  CMake not found${NC}"
    echo "Install via: brew install cmake"
    exit 1
fi

echo -e "${GREEN}✓ CMake found:$(cmake --version | head -1)${NC}"

# Check Git
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}⚠️  Git not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Git found${NC}"
echo ""

#######################################################
# Step 2: Download JUCE
#######################################################

echo -e "${BLUE}Step 2: Setting up JUCE framework...${NC}"

mkdir -p "$THIRD_PARTY_DIR"
cd "$THIRD_PARTY_DIR"

if [ ! -d "JUCE" ]; then
    echo "Cloning JUCE from GitHub..."
    git clone --depth 1 --branch 7.0.12 https://github.com/juce-framework/JUCE.git
    echo -e "${GREEN}✓ JUCE downloaded${NC}"
else
    echo -e "${GREEN}✓ JUCE already exists${NC}"
fi
echo ""

#######################################################
# Step 3: Download VST3 SDK (Steinberg, Open Source!)
#######################################################

echo -e "${BLUE}Step 3: Setting up VST3 SDK...${NC}"

if [ ! -d "vst3sdk" ]; then
    echo "Cloning VST3 SDK from GitHub..."
    git clone --depth 1 --branch v3.7.7_build_19 https://github.com/steinbergmedia/vst3sdk.git
    echo -e "${GREEN}✓ VST3 SDK downloaded${NC}"
else
    echo -e "${GREEN}✓ VST3 SDK already exists${NC}"
fi
echo ""

#######################################################
# Step 4: Download CLAP (MIT License!)
#######################################################

echo -e "${BLUE}Step 4: Setting up CLAP...${NC}"

if [ ! -d "clap" ]; then
    echo "Cloning CLAP from GitHub..."
    git clone --depth 1 https://github.com/free-audio/clap.git
    echo -e "${GREEN}✓ CLAP downloaded${NC}"
else
    echo -e "${GREEN}✓ CLAP already exists${NC}"
fi
echo ""

#######################################################
# Step 5: Create Build Directory
#######################################################

echo -e "${BLUE}Step 5: Creating build directory...${NC}"

cd "$PROJECT_ROOT"
mkdir -p build
echo -e "${GREEN}✓ Build directory created${NC}"
echo ""

#######################################################
# Step 6: CMake Configuration
#######################################################

echo -e "${BLUE}Step 6: Configuring CMake...${NC}"

cd build

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0

echo -e "${GREEN}✓ CMake configured${NC}"
echo ""

#######################################################
# Step 7: Build Instructions
#######################################################

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Build the plugin:"
echo "   cd build"
echo "   cmake --build . --config Release"
echo ""
echo "2. Install plugins:"
echo "   cmake --build . --target install"
echo ""
echo "Plugin locations:"
echo "   • VST3:  ~/Library/Audio/Plug-Ins/VST3/Eoel.vst3"
echo "   • AU:    ~/Library/Audio/Plug-Ins/Components/Eoel.component"
echo "   • CLAP:  ~/Library/Audio/Plug-Ins/CLAP/Eoel.clap"
echo ""
echo "3. Test in your DAW:"
echo "   • Ableton Live"
echo "   • Logic Pro"
echo "   • Bitwig Studio"
echo "   • Reaper"
echo ""
echo -e "${YELLOW}Note: First build will take 5-10 minutes (JUCE compilation)${NC}"
echo ""
