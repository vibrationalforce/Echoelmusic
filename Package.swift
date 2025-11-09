// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Echoelmusic",
    platforms: [
        .iOS(.v15)  // Minimum iOS 15 for wide device compatibility
                    // iOS 16+ recommended for enhanced features
                    // iOS 19+ for Apple Spatial Audio Features (ASAF)
    ],
    products: [
        // The main app product
        .library(
            name: "Echoel",
            targets: ["Echoel"]),
    ],
    dependencies: [
        // Add future dependencies here (e.g., for audio processing, ML, etc.)
    ],
    targets: [
        // The main app target
        .target(
            name: "Echoel",
            dependencies: [],
            resources: [
                // Include Info.plist and other resources
                .process("Resources")
            ]),

        // Test target for unit tests
        .testTarget(
            name: "EchoelTests",
            dependencies: ["Echoel"]),
    ]
)
