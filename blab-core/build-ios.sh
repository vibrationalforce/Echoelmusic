#!/bin/bash
# Build Rust BLAB Core for iOS (Universal Binary + XCFramework)
#
# Requirements:
# - Rust toolchain with iOS targets
# - Xcode command line tools
# - cbindgen
#
# Output: libblab_ffi.xcframework

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔨 Building BLAB Rust Core for iOS${NC}"
echo ""

# Configuration
CRATE_NAME="blab-ffi"
LIB_NAME="libblab_ffi"
TARGETS=(
    "aarch64-apple-ios"           # iOS devices (ARM64)
    "x86_64-apple-ios"            # iOS Simulator (Intel)
    "aarch64-apple-ios-sim"       # iOS Simulator (Apple Silicon)
)

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/target"
UNIVERSAL_DIR="${BUILD_DIR}/universal"
XCFRAMEWORK_DIR="${BUILD_DIR}/xcframework"

echo -e "${YELLOW}📋 Build Configuration${NC}"
echo "  Crate: ${CRATE_NAME}"
echo "  Lib: ${LIB_NAME}"
echo "  Targets: ${TARGETS[@]}"
echo "  Output: ${XCFRAMEWORK_DIR}/${LIB_NAME}.xcframework"
echo ""

# Step 1: Check Rust installation
echo -e "${YELLOW}🦀 Checking Rust installation${NC}"
if ! command -v rustc &> /dev/null; then
    echo -e "${RED}❌ Rust not found. Install from https://rustup.rs${NC}"
    exit 1
fi
echo "  ✓ Rust $(rustc --version)"

# Step 2: Check cbindgen
echo -e "${YELLOW}🔧 Checking cbindgen${NC}"
if ! command -v cbindgen &> /dev/null; then
    echo "  Installing cbindgen..."
    cargo install cbindgen
fi
echo "  ✓ cbindgen installed"

# Step 3: Add iOS targets
echo -e "${YELLOW}📱 Adding iOS targets${NC}"
for target in "${TARGETS[@]}"; do
    echo "  Adding ${target}..."
    rustup target add "${target}" 2>/dev/null || echo "  Already installed"
done
echo "  ✓ All targets ready"

# Step 4: Generate C header
echo -e "${YELLOW}📄 Generating C header (cbindgen)${NC}"
cd "${SCRIPT_DIR}/crates/ffi"
cbindgen --config cbindgen.toml --crate ${CRATE_NAME} --output "${SCRIPT_DIR}/BlabCore.h"
echo "  ✓ Header generated: BlabCore.h"

# Step 5: Build for each target (Release)
echo -e "${YELLOW}🔨 Building for iOS targets${NC}"
cd "${SCRIPT_DIR}"

for target in "${TARGETS[@]}"; do
    echo "  Building ${target}..."
    cargo build --package ${CRATE_NAME} --release --target "${target}"
    echo "  ✓ Built ${target}"
done

# Step 6: Create universal binaries
echo -e "${YELLOW}🔗 Creating universal binaries${NC}"
mkdir -p "${UNIVERSAL_DIR}/release"

# iOS Device (ARM64 only - universal is deprecated for devices)
echo "  Creating iOS device library (aarch64)..."
cp "${BUILD_DIR}/aarch64-apple-ios/release/${LIB_NAME}.a" \
   "${UNIVERSAL_DIR}/release/${LIB_NAME}-ios.a"

# iOS Simulator (x86_64 + aarch64 fat binary)
echo "  Creating iOS Simulator universal library (x86_64 + aarch64)..."
lipo -create \
    "${BUILD_DIR}/x86_64-apple-ios/release/${LIB_NAME}.a" \
    "${BUILD_DIR}/aarch64-apple-ios-sim/release/${LIB_NAME}.a" \
    -output "${UNIVERSAL_DIR}/release/${LIB_NAME}-sim.a"

echo "  ✓ Universal binaries created"

# Step 7: Create XCFramework
echo -e "${YELLOW}📦 Creating XCFramework${NC}"
rm -rf "${XCFRAMEWORK_DIR}/${LIB_NAME}.xcframework"
mkdir -p "${XCFRAMEWORK_DIR}"

xcodebuild -create-xcframework \
    -library "${UNIVERSAL_DIR}/release/${LIB_NAME}-ios.a" \
    -headers "${SCRIPT_DIR}/BlabCore.h" \
    -library "${UNIVERSAL_DIR}/release/${LIB_NAME}-sim.a" \
    -headers "${SCRIPT_DIR}/BlabCore.h" \
    -output "${XCFRAMEWORK_DIR}/${LIB_NAME}.xcframework"

echo "  ✓ XCFramework created"

# Step 8: Copy to Swift Package
echo -e "${YELLOW}📋 Copying to Swift Package${NC}"
SWIFT_PKG_DIR="${SCRIPT_DIR}/../BlabCoreSwift"
if [ -d "${SWIFT_PKG_DIR}" ]; then
    rm -rf "${SWIFT_PKG_DIR}/${LIB_NAME}.xcframework"
    cp -R "${XCFRAMEWORK_DIR}/${LIB_NAME}.xcframework" "${SWIFT_PKG_DIR}/"
    echo "  ✓ Copied to BlabCoreSwift/"
else
    echo "  ⚠️  Swift package not found at ${SWIFT_PKG_DIR}"
fi

# Step 9: Print size info
echo -e "${YELLOW}📊 Build Statistics${NC}"
du -sh "${XCFRAMEWORK_DIR}/${LIB_NAME}.xcframework"

echo ""
echo -e "${GREEN}✅ Build Complete!${NC}"
echo ""
echo "📦 Output:"
echo "  XCFramework: ${XCFRAMEWORK_DIR}/${LIB_NAME}.xcframework"
echo "  C Header: ${SCRIPT_DIR}/BlabCore.h"
echo ""
echo "🚀 Next Steps:"
echo "  1. Open Xcode project"
echo "  2. Add BlabCoreSwift package dependency"
echo "  3. Import BlabCoreSwift in Swift code"
echo ""
