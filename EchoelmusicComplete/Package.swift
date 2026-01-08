// swift-tools-version:5.9
// EchoelmusicComplete - Full Featured Bio-Reactive Audio-Visual Platform

import PackageDescription

let package = Package(
    name: "EchoelmusicComplete",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "EchoelmusicComplete",
            targets: ["EchoelmusicComplete"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "EchoelmusicComplete",
            dependencies: [],
            path: "Sources/EchoelmusicComplete"
        ),
        .testTarget(
            name: "EchoelmusicCompleteTests",
            dependencies: ["EchoelmusicComplete"],
            path: "Tests/EchoelmusicCompleteTests"
        )
    ]
)
