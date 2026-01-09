#!/bin/bash
# Echoelmusic macOS DMG Creator

set -e

APP_NAME="Echoelmusic"
VERSION="1.0.0"
DMG_NAME="${APP_NAME}-macOS-${VERSION}"
BUILD_DIR="../../Sources/Desktop/build"
DMG_DIR="dmg_contents"
OUTPUT_DIR="."

echo "==================================="
echo "  Echoelmusic macOS DMG Creator"
echo "==================================="

# Clean up
rm -rf "${DMG_DIR}"
rm -f "${OUTPUT_DIR}/${DMG_NAME}.dmg"

# Create directory structure
mkdir -p "${DMG_DIR}/Standalone"
mkdir -p "${DMG_DIR}/Plugins/VST3"
mkdir -p "${DMG_DIR}/Plugins/AU"
mkdir -p "${DMG_DIR}/Plugins/CLAP"

echo "Copying files..."

# Copy Standalone
if [ -f "${BUILD_DIR}/Echoelmusic_Standalone" ]; then
    cp "${BUILD_DIR}/Echoelmusic_Standalone" "${DMG_DIR}/Standalone/"
fi

# Copy VST3
if [ -d "${BUILD_DIR}/Echoelmusic.vst3" ]; then
    cp -R "${BUILD_DIR}/Echoelmusic.vst3" "${DMG_DIR}/Plugins/VST3/"
fi

# Copy AU
if [ -d "${BUILD_DIR}/Echoelmusic.component" ]; then
    cp -R "${BUILD_DIR}/Echoelmusic.component" "${DMG_DIR}/Plugins/AU/"
fi

# Copy CLAP
if [ -f "${BUILD_DIR}/Echoelmusic.clap" ]; then
    cp "${BUILD_DIR}/Echoelmusic.clap" "${DMG_DIR}/Plugins/CLAP/"
fi

# Create README
cat > "${DMG_DIR}/README.txt" << 'EOF'
ECHOELMUSIC INSTALLATION
========================

STANDALONE APP:
  Copy "Echoelmusic_Standalone" to /Applications

VST3 PLUGIN:
  Copy "Echoelmusic.vst3" to:
  /Library/Audio/Plug-Ins/VST3/

AUDIO UNIT (AU) PLUGIN:
  Copy "Echoelmusic.component" to:
  /Library/Audio/Plug-Ins/Components/

CLAP PLUGIN:
  Copy "Echoelmusic.clap" to:
  /Library/Audio/Plug-Ins/CLAP/

After installation, restart your DAW to detect new plugins.

Website: https://echoelmusic.com
Support: michaelterbuyken@gmail.com
EOF

# Create symbolic links for Applications and Plugin folders
ln -s /Applications "${DMG_DIR}/Applications"
ln -s "/Library/Audio/Plug-Ins" "${DMG_DIR}/Plugin Folder"

echo "Creating DMG..."

# Create DMG
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_DIR}" \
    -ov -format UDZO \
    "${OUTPUT_DIR}/${DMG_NAME}.dmg"

# Clean up
rm -rf "${DMG_DIR}"

echo "==================================="
echo "  DMG created: ${DMG_NAME}.dmg"
echo "==================================="
