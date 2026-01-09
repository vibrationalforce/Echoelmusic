// swift-tools-version:5.9
// EchoelmusicMVP - Minimal Viable Product
// Guaranteed to compile, ~5,000 lines, focused functionality

import PackageDescription

let package = Package(
    name: "EchoelmusicMVP",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "EchoelmusicMVP",
            targets: ["EchoelmusicMVP"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "EchoelmusicMVP",
            dependencies: [],
            path: "Sources/EchoelmusicMVP"
        ),
        .testTarget(
            name: "EchoelmusicMVPTests",
            dependencies: ["EchoelmusicMVP"],
            path: "Tests/EchoelmusicMVPTests"
        )
    ]
)
