// swift-tools-version: 6.0
//
// EchoelEngine — what the render thread runs: the sequencer that plays a compiled
// snapshot sample-accurately into the synth voices, the mix, and the metronome.
// Pure Swift on EchoelCore and EchoelDSP; the AVAudioEngine glue lives in the app, so
// everything here is tested on the macOS host by rendering offline.

import PackageDescription

let package = Package(
    name: "EchoelEngine",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "EchoelEngine", targets: ["EchoelEngine"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../DSP"),
    ],
    targets: [
        .target(name: "EchoelEngine", dependencies: [
            .product(name: "EchoelCore", package: "Core"),
            .product(name: "EchoelDSP", package: "DSP"),
        ]),
        .testTarget(name: "EchoelEngineTests", dependencies: ["EchoelEngine"]),
    ]
)
