// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Echoelmusic",
    platforms: [
        .iOS(.v16)  // Minimum iOS 16 for core features
                    // iOS 17+ recommended for enhanced performance
                    // iOS 19+ for Apple Spatial Audio Features (ASAF)
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
