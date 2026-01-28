// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Echoelmusic",
    platforms: [
        .iOS(.v15),        // iPhone & iPad - iOS 15+ for wide compatibility
        .macOS(.v12),      // macOS Monterey+ for Apple Silicon & Intel
        .watchOS(.v8),     // Apple Watch - Critical for bio-data collection
        .tvOS(.v15),       // Apple TV - Large display visualizations
        .visionOS(.v1)     // Apple Vision Pro - Spatial Audio & Immersive
    ],
    products: [
        // Core library - shared across all platforms
        .library(
            name: "Echoelmusic",
            targets: ["Echoelmusic"]),
    ],
    dependencies: [
        // Add future dependencies here (e.g., for audio processing, ML, etc.)
    ],
    targets: [
        // Core Echoelmusic target - cross-platform code
        .target(
            name: "Echoelmusic",
            dependencies: [],
            exclude: [
                // Platform-specific directories (handled separately)
                "Platforms/visionOS",
                "Platforms/watchOS",
                "Platforms/tvOS",
                "Platforms/iOS",
                "Platforms/macOS",
                // Files requiring platform-specific frameworks
                "VisionOS",
                "WatchOS",
                "tvOS",
                "Widgets",
                "LiveActivity"
                // NOTE: Sources/_Deferred/ is automatically excluded (sibling folder)
                // See DEFERRED_FEATURES.md for deferred features roadmap
            ],
            resources: [
                .process("Resources")
            ]),

        // Test target for unit tests
        .testTarget(
            name: "EchoelmusicTests",
            dependencies: ["Echoelmusic"]),
    ]
)
