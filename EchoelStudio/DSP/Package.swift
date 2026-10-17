// swift-tools-version: 6.0
//
// EchoelDSP — the instruments' and effects' signal processing, as pure value types.
// Foundation only: no audio framework, no project types. Linked by the app AND by the
// AUv3 extensions, so a processor must never reach for anything above this layer.

import PackageDescription

let package = Package(
    name: "EchoelDSP",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "EchoelDSP", targets: ["EchoelDSP"]),
    ],
    targets: [
        .target(name: "EchoelDSP"),
        .testTarget(name: "EchoelDSPTests", dependencies: ["EchoelDSP"]),
    ]
)
