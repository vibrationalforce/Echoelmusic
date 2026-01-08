#!/bin/bash
# ci_post_xcodebuild.sh
# Xcode Cloud - Runs after successful xcodebuild
# Use this for post-build tasks like uploading to TestFlight

set -e

echo "=== Echoelmusic Xcode Cloud Post-Build Script ==="

cd "$CI_WORKSPACE"

# Check if build was successful
if [ "$CI_XCODEBUILD_EXIT_CODE" != "0" ]; then
    echo "Build failed with exit code: $CI_XCODEBUILD_EXIT_CODE"
    exit 1
fi

echo "Build successful!"

# Archive information
if [ -d "$CI_ARCHIVE_PATH" ]; then
    echo "Archive path: $CI_ARCHIVE_PATH"
    echo "Archive size: $(du -sh "$CI_ARCHIVE_PATH" | cut -f1)"
fi

# App information
if [ -n "$CI_APP_STORE_SIGNED_APP_PATH" ]; then
    echo "Signed app path: $CI_APP_STORE_SIGNED_APP_PATH"
fi

# TestFlight upload is handled automatically by Xcode Cloud
# when configured in App Store Connect

# Generate build report
cat > "$CI_WORKSPACE/build_report.txt" << EOF
Echoelmusic Build Report
========================
Build Number: $CI_BUILD_NUMBER
Branch: $CI_BRANCH
Commit: $CI_COMMIT
Scheme: $CI_XCODE_SCHEME
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Status: SUCCESS
EOF

echo "Build report generated"
echo "=== Post-Build Complete ==="
