#!/bin/bash
# Echoelmusic Linux AppImage & Deb Creator

set -e

APP_NAME="Echoelmusic"
VERSION="1.0.0"
BUILD_DIR="../../Sources/Desktop/build"
APPDIR="Echoelmusic.AppDir"

echo "==================================="
echo "  Echoelmusic Linux Package Creator"
echo "==================================="

# ============================================
# AppImage Creation
# ============================================

echo "Creating AppImage..."

# Clean up
rm -rf "${APPDIR}"
rm -f "${APP_NAME}-${VERSION}-x86_64.AppImage"

# Create AppDir structure
mkdir -p "${APPDIR}/usr/bin"
mkdir -p "${APPDIR}/usr/lib/vst3"
mkdir -p "${APPDIR}/usr/lib/clap"
mkdir -p "${APPDIR}/usr/share/applications"
mkdir -p "${APPDIR}/usr/share/icons/hicolor/256x256/apps"

# Copy standalone
if [ -f "${BUILD_DIR}/Echoelmusic_Standalone" ]; then
    cp "${BUILD_DIR}/Echoelmusic_Standalone" "${APPDIR}/usr/bin/echoelmusic"
    chmod +x "${APPDIR}/usr/bin/echoelmusic"
fi

# Copy plugins
if [ -d "${BUILD_DIR}/Echoelmusic.vst3" ]; then
    cp -R "${BUILD_DIR}/Echoelmusic.vst3" "${APPDIR}/usr/lib/vst3/"
fi

if [ -f "${BUILD_DIR}/Echoelmusic.clap" ]; then
    cp "${BUILD_DIR}/Echoelmusic.clap" "${APPDIR}/usr/lib/clap/"
fi

# Create desktop file
cat > "${APPDIR}/usr/share/applications/echoelmusic.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Echoelmusic
Comment=Bio-Reactive Audio-Visual Platform
Exec=echoelmusic
Icon=echoelmusic
Categories=AudioVideo;Audio;Music;
Keywords=audio;music;synth;daw;production;
EOF

cp "${APPDIR}/usr/share/applications/echoelmusic.desktop" "${APPDIR}/"

# Create AppRun
cat > "${APPDIR}/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/usr/bin/echoelmusic" "$@"
EOF
chmod +x "${APPDIR}/AppRun"

# Create placeholder icon (should be replaced with real icon)
cat > "${APPDIR}/usr/share/icons/hicolor/256x256/apps/echoelmusic.png" << 'EOF'
# Placeholder - replace with actual PNG icon
EOF
cp "${APPDIR}/usr/share/icons/hicolor/256x256/apps/echoelmusic.png" "${APPDIR}/echoelmusic.png"

# Download appimagetool if not present
if [ ! -f "appimagetool-x86_64.AppImage" ]; then
    echo "Downloading appimagetool..."
    wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x appimagetool-x86_64.AppImage
fi

# Create AppImage
./appimagetool-x86_64.AppImage "${APPDIR}" "${APP_NAME}-${VERSION}-x86_64.AppImage"

# ============================================
# Deb Package Creation
# ============================================

echo "Creating Deb package..."

DEB_DIR="echoelmusic_${VERSION}_amd64"
rm -rf "${DEB_DIR}"

# Create directory structure
mkdir -p "${DEB_DIR}/DEBIAN"
mkdir -p "${DEB_DIR}/usr/bin"
mkdir -p "${DEB_DIR}/usr/lib/vst3"
mkdir -p "${DEB_DIR}/usr/lib/clap"
mkdir -p "${DEB_DIR}/usr/share/applications"
mkdir -p "${DEB_DIR}/usr/share/icons/hicolor/256x256/apps"

# Copy files
if [ -f "${BUILD_DIR}/Echoelmusic_Standalone" ]; then
    cp "${BUILD_DIR}/Echoelmusic_Standalone" "${DEB_DIR}/usr/bin/echoelmusic"
    chmod +x "${DEB_DIR}/usr/bin/echoelmusic"
fi

if [ -d "${BUILD_DIR}/Echoelmusic.vst3" ]; then
    cp -R "${BUILD_DIR}/Echoelmusic.vst3" "${DEB_DIR}/usr/lib/vst3/"
fi

if [ -f "${BUILD_DIR}/Echoelmusic.clap" ]; then
    cp "${BUILD_DIR}/Echoelmusic.clap" "${DEB_DIR}/usr/lib/clap/"
fi

# Desktop file
cp "${APPDIR}/usr/share/applications/echoelmusic.desktop" "${DEB_DIR}/usr/share/applications/"

# Control file
cat > "${DEB_DIR}/DEBIAN/control" << EOF
Package: echoelmusic
Version: ${VERSION}
Section: sound
Priority: optional
Architecture: amd64
Depends: libasound2, libjack-jackd2-0 | libjack0, libfreetype6, libx11-6
Maintainer: Echoelmusic <support@echoelmusic.com>
Description: Bio-Reactive Audio-Visual Platform
 Echoelmusic is a complete music production platform with
 quantum AI tools, bio-reactive features, and professional
 audio synthesis. Includes standalone app and plugins.
EOF

# Build deb
dpkg-deb --build "${DEB_DIR}"

# Clean up
rm -rf "${APPDIR}" "${DEB_DIR}"

echo "==================================="
echo "  Packages created:"
echo "  - ${APP_NAME}-${VERSION}-x86_64.AppImage"
echo "  - echoelmusic_${VERSION}_amd64.deb"
echo "==================================="
