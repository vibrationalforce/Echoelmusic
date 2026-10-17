// swift-tools-version: 6.0
//
// EchoelCore — the project document, the command catalog and undo.
// Foundation and Observation only: no UI, no audio, no platform guards needed.
// It builds and tests on macOS, iOS and Linux alike (`swift test` in this directory).

import PackageDescription

let package = Package(
    name: "EchoelCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "EchoelCore", targets: ["EchoelCore"]),
    ],
    targets: [
        .target(name: "EchoelCore"),
        .testTarget(name: "EchoelCoreTests", dependencies: ["EchoelCore"]),
    ]
)
