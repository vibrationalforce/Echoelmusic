// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Echoelmusic",
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
            name: "Echoelmusic",
            targets: ["Echoelmusic"]),
    ],
    dependencies: [
        // Supabase Swift SDK - Cloud backend (Auth, Database, Storage, Realtime)
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
    ],
    targets: [
        // Core Echoelmusic target - cross-platform code
        .target(
            name: "Echoelmusic",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
            ],
            resources: [
                .process("Resources")
            ]),

        // Test target for unit tests
        .testTarget(
            name: "EchoelmusicTests",
            dependencies: ["Echoelmusic"]),
    ]
)
