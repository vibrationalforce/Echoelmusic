#!/bin/bash
# ci_pre_xcodebuild.sh
# Xcode Cloud - Runs before xcodebuild
# Use this to configure build settings, run code generation, etc.

set -e

echo "=== Echoelmusic Xcode Cloud Pre-Build Script ==="

cd "$CI_WORKSPACE"

# Verify Swift version
echo "Swift version:"
swift --version

# List available schemes (for debugging)
echo "Available build configurations..."

# Environment-specific configuration
case "$CI_XCODE_SCHEME" in
    *Release*)
        echo "Building RELEASE configuration"
        export SWIFT_ACTIVE_COMPILATION_CONDITIONS="RELEASE"
        ;;
    *Debug*)
        echo "Building DEBUG configuration"
        export SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG"
        ;;
    *)
        echo "Building with default configuration"
        ;;
esac

# Verify code signing (Xcode Cloud handles this automatically)
echo "Code signing will be handled by Xcode Cloud"

echo "=== Pre-Build Complete ==="
