// swift-tools-version: 6.0
//
// Three libraries:
// - EchoelKernels — what a plugin and the engine both play: the instrument and effect kernels,
//   the synth patch mapping, the demo gate, and the protocols a hosted unit plays through. Pure
//   Swift on EchoelCore and EchoelDSP.
// - EchoelEngine — what the render thread runs: the sequencer that plays a compiled snapshot
//   sample-accurately into the instruments, the mix, and the metronome. Pure Swift on
//   EchoelKernels, EchoelCore and EchoelDSP; tested on the macOS host by rendering offline.
// - EchoelHost — the Audio Unit side: HostedUnit and HostedEffect wrap a loaded unit for the
//   engine, StandardEffectUnit is our own effect as an Audio Unit, SampleFile reads a sample.
//   AVFoundation and AudioToolbox live here only. It depends on EchoelKernels and EchoelCore and
//   never on EchoelEngine, so the plugin extension can link it without the engine.

import PackageDescription

let package = Package(
    name: "EchoelEngine",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "EchoelEngine", targets: ["EchoelEngine"]),
        .library(name: "EchoelKernels", targets: ["EchoelKernels"]),
        .library(name: "EchoelHost", targets: ["EchoelHost"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../DSP"),
    ],
    targets: [
        .target(name: "EchoelKernels", dependencies: [
            .product(name: "EchoelCore", package: "Core"),
            .product(name: "EchoelDSP", package: "DSP"),
        ]),
        .target(name: "EchoelEngine", dependencies: [
            "EchoelKernels",
            .product(name: "EchoelCore", package: "Core"),
            .product(name: "EchoelDSP", package: "DSP"),
        ]),
        .target(name: "EchoelHost", dependencies: [
            "EchoelKernels",
            .product(name: "EchoelCore", package: "Core"),
        ]),
        .testTarget(name: "EchoelKernelsTests", dependencies: [
            "EchoelKernels",
            .product(name: "EchoelCore", package: "Core"),
            .product(name: "EchoelDSP", package: "DSP"),
        ]),
        .testTarget(name: "EchoelEngineTests", dependencies: [
            "EchoelEngine",
            "EchoelKernels",
            .product(name: "EchoelCore", package: "Core"),
            .product(name: "EchoelDSP", package: "DSP"),
        ]),
        .testTarget(name: "EchoelHostTests", dependencies: [
            "EchoelHost",
            "EchoelEngine",
            "EchoelKernels",
            .product(name: "EchoelCore", package: "Core"),
            .product(name: "EchoelDSP", package: "DSP"),
        ]),
    ]
)
