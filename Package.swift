// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Echoelmusic",
    platforms: [
        .iOS(.v17),        // iPhone & iPad - iOS 17+ for TimelineView, @Observable
        .macOS(.v14),      // macOS Sonoma+ for @Observable
        .watchOS(.v10),    // Apple Watch - watchOS 10+ for HKWorkoutSession Streaming
        .tvOS(.v17),       // Apple TV - Large display visualizations
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
            resources: [
                .process("Resources")
            ]),

        // Test target for unit tests
        .testTarget(
            name: "EchoelmusicTests",
            dependencies: ["Echoelmusic"]),
    ]
)
