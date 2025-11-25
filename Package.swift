// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EOEL",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),        // iPhone & iPad - iOS 18+ for latest features
        .macOS(.v15),      // macOS Sequoia+ for latest SwiftUI
        .watchOS(.v11),    // Apple Watch - Latest bio-data capabilities
        .tvOS(.v18),       // Apple TV - Latest tvOS features
        .visionOS(.v2)     // Apple Vision Pro - Spatial Audio & Immersive v2
    ],
    products: [
        .library(name: "EOEL", targets: ["EOEL"]),
        .library(name: "EOELCore", targets: ["EOELCore"]),
    ],
    dependencies: [
        // Firebase - Backend infrastructure
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk",
            from: "10.20.0"
        ),
        // Networking
        .package(
            url: "https://github.com/Alamofire/Alamofire",
            from: "5.8.0"
        ),
        // Security
        .package(
            url: "https://github.com/kishikawakatsumi/KeychainAccess",
            from: "4.2.2"
        ),
        // Analytics
        .package(
            url: "https://github.com/TelemetryDeck/SwiftClient",
            from: "1.4.0"
        ),
        // Payments
        .package(
            url: "https://github.com/stripe/stripe-ios",
            from: "23.0.0"
        ),
    ],
    targets: [
        .target(
            name: "EOEL",
            dependencies: [
                "EOELCore",
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
                .product(name: "FirebasePerformance", package: "firebase-ios-sdk"),
                "Alamofire",
                "KeychainAccess",
                .product(name: "TelemetryClient", package: "SwiftClient"),
                .product(name: "StripePaymentSheet", package: "stripe-ios"),
            ],
            path: "EOEL",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "EOELCore",
            dependencies: [],
            path: "Sources/EOEL"
        ),
        .testTarget(
            name: "EOELTests",
            dependencies: ["EOEL"],
            path: "Tests/EOELTests"
        ),
    ]
)
