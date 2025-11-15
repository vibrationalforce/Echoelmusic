#!/bin/bash
# 🚀 Build ALL Platforms Simultaneously
# Echoelmusic Universal Build System

set -e

echo "╔════════════════════════════════════════════════════════╗"
echo "║  🎵 Echoelmusic Universal Build System 🎵            ║"
echo "║  Building for ALL platforms simultaneously...         ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Default platforms
PLATFORMS="ios,android,windows,linux,web"
CONFIGURATION="Release"
PARALLEL=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --platforms)
            PLATFORMS="$2"
            shift 2
            ;;
        --config)
            CONFIGURATION="$2"
            shift 2
            ;;
        --sequential)
            PARALLEL=false
            shift
            ;;
        --help)
            echo "Usage: ./build-all.sh [options]"
            echo ""
            echo "Options:"
            echo "  --platforms PLATFORMS   Comma-separated list (default: all)"
            echo "                         Options: ios,android,windows,linux,web"
            echo "  --config CONFIG        Build configuration (default: Release)"
            echo "  --sequential           Build sequentially instead of parallel"
            echo "  --help                 Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run --help for usage"
            exit 1
            ;;
    esac
done

# Split platforms
IFS=',' read -ra PLATFORM_ARRAY <<< "$PLATFORMS"

# Build function for each platform
build_ios() {
    echo "📱 Building iOS/macOS/visionOS/watchOS..."
    cd ios-app

    # Build iOS
    xcodebuild -scheme Echoelmusic -configuration $CONFIGURATION \
        -destination 'generic/platform=iOS' \
        -archivePath build/iOS/Echoelmusic.xcarchive \
        archive

    # Build macOS
    xcodebuild -scheme Echoelmusic -configuration $CONFIGURATION \
        -destination 'generic/platform=macOS' \
        -archivePath build/macOS/Echoelmusic.xcarchive \
        archive

    # Build visionOS
    xcodebuild -scheme Echoelmusic-visionOS -configuration $CONFIGURATION \
        -destination 'generic/platform=visionOS' \
        -archivePath build/visionOS/Echoelmusic.xcarchive \
        archive

    # Build watchOS
    xcodebuild -scheme Echoelmusic-watchOS -configuration $CONFIGURATION \
        -destination 'generic/platform=watchOS' \
        -archivePath build/watchOS/Echoelmusic.xcarchive \
        archive

    cd ..
    echo "✅ iOS/macOS/visionOS/watchOS build complete"
}

build_android() {
    echo "🤖 Building Android/Wear OS/Android TV..."
    cd android-app

    # Build all Android variants
    ./gradlew assembleRelease bundleRelease

    # Build Wear OS
    ./gradlew :wear:assembleRelease

    # Build Android TV
    ./gradlew :tv:assembleRelease

    cd ..
    echo "✅ Android/Wear OS/TV build complete"
}

build_windows() {
    echo "🪟 Building Windows..."
    cd desktop-engine

    # Configure with CMake
    cmake -B build-windows \
        -DCMAKE_BUILD_TYPE=$CONFIGURATION \
        -DCMAKE_SYSTEM_NAME=Windows \
        -G "Visual Studio 17 2022"

    # Build
    cmake --build build-windows --config $CONFIGURATION --parallel

    # Package
    cpack -C $CONFIGURATION -G WIX

    cd ..
    echo "✅ Windows build complete"
}

build_linux() {
    echo "🐧 Building Linux..."
    cd desktop-engine

    # Configure with CMake
    cmake -B build-linux \
        -DCMAKE_BUILD_TYPE=$CONFIGURATION \
        -DCMAKE_INSTALL_PREFIX=/usr

    # Build
    cmake --build build-linux --config $CONFIGURATION --parallel

    # Package (deb, rpm, AppImage, Flatpak)
    cd build-linux
    cpack -G "DEB;RPM"

    # Build AppImage
    linuxdeploy --appdir AppDir --output appimage

    # Build Flatpak
    flatpak-builder --force-clean build-dir com.echoelmusic.Echoelmusic.yaml

    cd ../..
    echo "✅ Linux build complete"
}

build_web() {
    echo "🌐 Building Web App..."
    cd web-app

    # Install dependencies
    npm ci

    # Build
    npm run build

    # Build WebAssembly
    npm run build:wasm

    cd ..
    echo "✅ Web build complete"
}

# Build each platform
if [ "$PARALLEL" = true ]; then
    # Parallel build
    for PLATFORM in "${PLATFORM_ARRAY[@]}"; do
        (
            case $PLATFORM in
                ios)
                    build_ios
                    ;;
                android)
                    build_android
                    ;;
                windows)
                    build_windows
                    ;;
                linux)
                    build_linux
                    ;;
                web)
                    build_web
                    ;;
                *)
                    echo "❌ Unknown platform: $PLATFORM"
                    ;;
            esac
        ) &
    done

    # Wait for all builds
    wait
else
    # Sequential build
    for PLATFORM in "${PLATFORM_ARRAY[@]}"; do
        case $PLATFORM in
            ios)
                build_ios
                ;;
            android)
                build_android
                ;;
            windows)
                build_windows
                ;;
            linux)
                build_linux
                ;;
            web)
                build_web
                ;;
            *)
                echo "❌ Unknown platform: $PLATFORM"
                ;;
        esac
    done
fi

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  ✅ ALL BUILDS COMPLETED SUCCESSFULLY! ✅            ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "📦 Build artifacts:"
for PLATFORM in "${PLATFORM_ARRAY[@]}"; do
    case $PLATFORM in
        ios)
            echo "  📱 iOS: ios-app/build/iOS/Echoelmusic.xcarchive"
            echo "  🖥️  macOS: ios-app/build/macOS/Echoelmusic.xcarchive"
            echo "  🥽 visionOS: ios-app/build/visionOS/Echoelmusic.xcarchive"
            echo "  ⌚ watchOS: ios-app/build/watchOS/Echoelmusic.xcarchive"
            ;;
        android)
            echo "  🤖 Android: android-app/app/build/outputs/"
            echo "  ⌚ Wear OS: android-app/wear/build/outputs/"
            echo "  📺 Android TV: android-app/tv/build/outputs/"
            ;;
        windows)
            echo "  🪟 Windows: desktop-engine/build-windows/"
            ;;
        linux)
            echo "  🐧 Linux: desktop-engine/build-linux/"
            ;;
        web)
            echo "  🌐 Web: web-app/dist/"
            ;;
    esac
done
echo ""
echo "Next steps:"
echo "  🧪 Test: ./scripts/test-all.sh"
echo "  🚀 Deploy: ./scripts/deploy-all.sh --version X.Y.Z"
