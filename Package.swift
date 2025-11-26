// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Eoel",
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
            name: "Eoel",
            targets: ["Eoel"]),
    ],
    dependencies: [
        // Add future dependencies here (e.g., for audio processing, ML, etc.)
    ],
    targets: [
        // Core Eoel target - cross-platform code
        .target(
            name: "Eoel",
            dependencies: [],
            resources: [
                .process("Resources")
            ]),

        // Test target for unit tests
        .testTarget(
            name: "EoelTests",
            dependencies: ["Eoel"]),
    ]
)
