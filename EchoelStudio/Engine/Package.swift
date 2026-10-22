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
//
// On Linux the Host library and its tests are not declared at all, so the module does not exist
// there: an `import EchoelHost` (or AVFoundation) that slips into the kernels or the engine fails the
// Linux build instead of compiling against an empty module (S-26 D4.1).

import PackageDescription

var products: [Product] = [
    .library(name: "EchoelEngine", targets: ["EchoelEngine"]),
    .library(name: "EchoelKernels", targets: ["EchoelKernels"]),
]

var targets: [Target] = [
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

#if !os(Linux)
products.append(.library(name: "EchoelHost", targets: ["EchoelHost"]))
targets += [
    .target(name: "EchoelHost", dependencies: [
        "EchoelKernels",
        .product(name: "EchoelCore", package: "Core"),
    ]),
    .testTarget(name: "EchoelHostTests", dependencies: [
        "EchoelHost",
        "EchoelEngine",
        "EchoelKernels",
        .product(name: "EchoelCore", package: "Core"),
        .product(name: "EchoelDSP", package: "DSP"),
    ]),
]
#endif

let package = Package(
    name: "EchoelEngine",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: products,
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../DSP"),
    ],
    targets: targets
)
