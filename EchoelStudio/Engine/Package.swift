// swift-tools-version: 6.0
//
// Two libraries:
// - EchoelKernels — what a plugin and the engine both play: the instrument and effect kernels,
//   the synth patch mapping, the demo gate, and the protocols a hosted unit plays through. Pure
//   Swift on EchoelCore and EchoelDSP.
// - EchoelEngine — what the render thread runs: the sequencer that plays a compiled snapshot
//   sample-accurately into the instruments, the mix, and the metronome. Tested on the macOS host
//   by rendering offline. ⚠️ It still holds the Audio Unit wrappers (HostedUnit, HostedEffect,
//   StandardEffectUnit) and SampleFile, which import AVFoundation and AudioToolbox; they leave
//   for their own target next (S-26, D1.3).

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
    ]
)
