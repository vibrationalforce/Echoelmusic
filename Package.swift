// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// TESTFLIGHT READY - 27.01.2026
// - Swift 6.0 with strict concurrency checking
// - Deployment targets synchronized with project.yml for TestFlight
// - Wider audience support: iOS 16+, macOS 13+
// - Prepared for Apple Intelligence & Foundation Models integration

import PackageDescription

let package = Package(
    name: "Echoelmusic",
    platforms: [
        .iOS(.v16),        // iPhone & iPad - iOS 16+ for wider TestFlight compatibility
        .macOS(.v13),      // macOS Ventura+ for Apple Silicon + Intel support
        .watchOS(.v9),     // Apple Watch - HRV & bio-data collection
        .tvOS(.v16),       // Apple TV - Big screen visualizations
        .visionOS(.v1)     // Apple Vision Pro - Spatial Audio Immersive
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
                // Files requiring platform-specific frameworks
                "VisionOS",
                "WatchOS",
                "tvOS",
                "Widgets"
                // NOTE: Sources/_Deferred/ is automatically excluded (sibling folder)
                // See DEFERRED_FEATURES.md for deferred features roadmap
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                // Swift 6 Strict Concurrency - Full Data Race Safety
                .enableExperimentalFeature("StrictConcurrency"),
                // Upcoming Swift features
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("ImplicitOpenExistentials"),
                .enableUpcomingFeature("DisableOutwardActorInference")
            ]),

        // Test target for unit tests
        .testTarget(
            name: "EchoelmusicTests",
            dependencies: ["Echoelmusic"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]),
    ],
    swiftLanguageVersions: [.v6]
)
