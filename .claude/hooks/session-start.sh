#!/bin/bash
set -euo pipefail

# SessionStart hook for Echoelmusic - Swift Package project
# Only runs in Claude Code remote (web) environment

# Skip if not running in remote environment
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
    exit 0
fi

echo "Setting up Echoelmusic development environment..."

# Navigate to project directory
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Check if Swift is available
if command -v swift &> /dev/null; then
    echo "Swift found: $(swift --version 2>&1 | head -n1)"

    # Build the Swift package to resolve any dependencies
    # Using 'swift build' which is idempotent and benefits from caching
    echo "Building Swift package to resolve dependencies..."
    swift build --quiet 2>/dev/null || swift build

    echo "Echoelmusic environment setup complete!"
else
    echo "Note: Swift is not installed in this environment."
    echo "This is a Swift/iOS project that requires Xcode or Swift toolchain."
    echo "Code review and documentation tasks can still be performed."
    echo "For building/testing, use a macOS environment with Xcode installed."
fi

exit 0
