// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// NEXT-GEN TRANSFORMATION (Jan 2026)
// - Swift 6.0 with strict concurrency checking
// - iOS 17+ / macOS 14+ / visionOS 2+ for latest APIs
// - Prepared for Apple Intelligence & Foundation Models integration

import PackageDescription

let package = Package(
    name: "Echoelmusic",
    platforms: [
        .iOS(.v17),        // iPhone & iPad - iOS 17+ for latest SwiftUI & ML
        .macOS(.v14),      // macOS Sonoma+ for Apple Silicon optimization
        .watchOS(.v10),    // Apple Watch - Enhanced bio-data collection
        .tvOS(.v17),       // Apple TV - Large display visualizations
        .visionOS(.v2)     // Apple Vision Pro 2 - Enhanced Spatial Computing
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
