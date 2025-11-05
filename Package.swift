// swift-tools-version: 5.5
// Minimum Swift 5.5 for maximum Xcode compatibility (13.4+)
// Compatible with Xcode 13.4 - 16.2+ for smooth upgrades

import PackageDescription

let package = Package(
    name: "Echoelmusic",
    platforms: [
        .iOS(.v14)  // iOS 14.0+ for maximum device compatibility
                    // iOS 15+ recommended for enhanced features (HealthKit, ARKit)
                    // iOS 16+ for advanced MIDI 2.0
                    // iOS 19+ for Apple Spatial Audio Features (AVAudioEnvironmentNode)
    ],
    products: [
        // The main app product
        .library(
            name: "Echoelmusic",
            targets: ["Echoelmusic"]),
    ],
    dependencies: [
        // Add future dependencies here (e.g., for audio processing, ML, etc.)
    ],
    targets: [
        // The main app target
        .target(
            name: "Echoelmusic",
            dependencies: [],
            resources: [
                // Include Info.plist and other resources
                .process("Resources")
            ]),

        // Test target for unit tests
        .testTarget(
            name: "EchoelmusicTests",
            dependencies: ["Echoelmusic"]),
    ]
)
