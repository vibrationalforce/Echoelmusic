// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Echoelmusic",
    platforms: [
        .iOS(.v15)  // Minimum iOS 15 for maximum compatibility
                    // Supports iPhone 7, 6s (2015-2016 models!)
                    // iOS 16+ recommended for head tracking
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
