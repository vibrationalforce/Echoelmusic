// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EOEL",
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
            name: "EOEL",
            targets: ["EOEL"]),
    ],
    dependencies: [
        // Firebase - Backend infrastructure
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.20.0"),

        // Networking
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0"),

        // Secure Storage
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),

        // Analytics (Privacy-Friendly)
        .package(url: "https://github.com/TelemetryDeck/SwiftClient", from: "1.4.0"),
    ],
    targets: [
        // Core EOEL target - cross-platform code
        .target(
            name: "EOEL",
            dependencies: [
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
                .product(name: "FirebasePerformance", package: "firebase-ios-sdk"),
                "Alamofire",
                "KeychainAccess",
                "TelemetryDeck",
            ],
            resources: [
                .process("Resources")
            ]),

        // Test target for unit tests
        .testTarget(
            name: "EOELTests",
            dependencies: ["EOEL"]),
    ]
)
