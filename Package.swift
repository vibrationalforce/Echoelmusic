// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Blab",
    platforms: [
        .iOS(.v15)  // Minimum iOS 15 for wide device compatibility
                    // iOS 16+ recommended for enhanced features
                    // iOS 19+ for Apple Spatial Audio Features (ASAF)
    ],
    products: [
        // The main app product
        .library(
            name: "Blab",
            targets: ["Blab"]),
    ],
    dependencies: [
        // HaishinKit for RTMP streaming
        .package(url: "https://github.com/shogo4405/HaishinKit.swift.git", from: "1.6.0"),
    ],
    targets: [
        // The main app target
        .target(
            name: "Blab",
            dependencies: [
                .product(name: "HaishinKit", package: "HaishinKit.swift"),
            ],
            resources: [
                // Include Info.plist and other resources
                .process("Resources")
            ]),

        // Test target for unit tests
        .testTarget(
            name: "BlabTests",
            dependencies: ["Blab"]),
    ]
)
