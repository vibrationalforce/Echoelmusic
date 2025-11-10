// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Echoelmusic",
    platforms: [
        .iOS(.v15),        // iPhone & iPad - Wide compatibility
        .macOS(.v12),      // macOS Monterey - Professional desktop DAW
        .watchOS(.v8),     // Apple Watch - Companion app, biofeedback
        .tvOS(.v15),       // Apple TV - Home entertainment, visualizations
        .visionOS(.v1)     // Apple Vision Pro - Spatial computing, 3D visuals
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
