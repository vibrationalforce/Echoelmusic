// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Echoelmusic",
    platforms: [
        .iOS(.v15),  // Minimum iOS 15 for wide compatibility
        .macOS(.v12) // macOS 12+ for potential desktop support
    ],
    products: [
        // Main app product (aggregates all modules)
        .library(
            name: "Echoelmusic",
            targets: ["Echoelmusic"]),

        // Individual module products
        .library(name: "EchoelmusicCore", targets: ["EchoelmusicCore"]),
        .library(name: "EchoelmusicAudio", targets: ["EchoelmusicAudio"]),
        .library(name: "EchoelmusicBio", targets: ["EchoelmusicBio"]),
        .library(name: "EchoelmusicVisual", targets: ["EchoelmusicVisual"]),
        .library(name: "EchoelmusicControl", targets: ["EchoelmusicControl"]),
        .library(name: "EchoelmusicMIDI", targets: ["EchoelmusicMIDI"]),
        .library(name: "EchoelmusicHardware", targets: ["EchoelmusicHardware"]),
        .library(name: "EchoelmusicUI", targets: ["EchoelmusicUI"]),
        .library(name: "EchoelmusicPlatform", targets: ["EchoelmusicPlatform"]),
    ],
    dependencies: [
        // External dependencies can be added here
        // Example: .package(url: "https://github.com/...", from: "1.0.0")
    ],
    targets: [
        // MARK: - Core Module (Foundation - No Dependencies)

        .target(
            name: "EchoelmusicCore",
            dependencies: [],
            path: "Sources/EchoelmusicCore"
        ),
        .testTarget(
            name: "EchoelmusicCoreTests",
            dependencies: ["EchoelmusicCore"],
            path: "Tests/EchoelmusicCoreTests"
        ),

        // MARK: - Audio Module (depends on Core)

        .target(
            name: "EchoelmusicAudio",
            dependencies: ["EchoelmusicCore"],
            path: "Sources/EchoelmusicAudio"
        ),
        .testTarget(
            name: "EchoelmusicAudioTests",
            dependencies: ["EchoelmusicAudio", "EchoelmusicCore"],
            path: "Tests/EchoelmusicAudioTests"
        ),

        // MARK: - Bio Module (depends on Core)

        .target(
            name: "EchoelmusicBio",
            dependencies: ["EchoelmusicCore"],
            path: "Sources/EchoelmusicBio"
        ),
        .testTarget(
            name: "EchoelmusicBioTests",
            dependencies: ["EchoelmusicBio", "EchoelmusicCore"],
            path: "Tests/EchoelmusicBioTests"
        ),

        // MARK: - MIDI Module (depends on Core)

        .target(
            name: "EchoelmusicMIDI",
            dependencies: ["EchoelmusicCore"],
            path: "Sources/EchoelmusicMIDI"
        ),
        .testTarget(
            name: "EchoelmusicMIDITests",
            dependencies: ["EchoelmusicMIDI", "EchoelmusicCore"],
            path: "Tests/EchoelmusicMIDITests"
        ),

        // MARK: - Visual Module (depends on Core)

        .target(
            name: "EchoelmusicVisual",
            dependencies: ["EchoelmusicCore"],
            path: "Sources/EchoelmusicVisual"
        ),
        .testTarget(
            name: "EchoelmusicVisualTests",
            dependencies: ["EchoelmusicVisual", "EchoelmusicCore"],
            path: "Tests/EchoelmusicVisualTests"
        ),

        // MARK: - Hardware Module (depends on Core, MIDI)

        .target(
            name: "EchoelmusicHardware",
            dependencies: [
                "EchoelmusicCore",
                "EchoelmusicMIDI"
            ],
            path: "Sources/EchoelmusicHardware"
        ),
        .testTarget(
            name: "EchoelmusicHardwareTests",
            dependencies: ["EchoelmusicHardware", "EchoelmusicCore"],
            path: "Tests/EchoelmusicHardwareTests"
        ),

        // MARK: - Control Module (depends on Core, Audio, Bio, Visual)

        .target(
            name: "EchoelmusicControl",
            dependencies: [
                "EchoelmusicCore",
                "EchoelmusicAudio",
                "EchoelmusicBio",
                "EchoelmusicVisual"
            ],
            path: "Sources/EchoelmusicControl"
        ),
        .testTarget(
            name: "EchoelmusicControlTests",
            dependencies: ["EchoelmusicControl", "EchoelmusicCore"],
            path: "Tests/EchoelmusicControlTests"
        ),

        // MARK: - Platform Module (depends on Core)

        .target(
            name: "EchoelmusicPlatform",
            dependencies: ["EchoelmusicCore"],
            path: "Sources/EchoelmusicPlatform"
        ),
        .testTarget(
            name: "EchoelmusicPlatformTests",
            dependencies: ["EchoelmusicPlatform", "EchoelmusicCore"],
            path: "Tests/EchoelmusicPlatformTests"
        ),

        // MARK: - UI Module (depends on Core, Control, Visual)

        .target(
            name: "EchoelmusicUI",
            dependencies: [
                "EchoelmusicCore",
                "EchoelmusicControl",
                "EchoelmusicVisual"
            ],
            path: "Sources/EchoelmusicUI"
        ),
        .testTarget(
            name: "EchoelmusicUITests",
            dependencies: ["EchoelmusicUI", "EchoelmusicCore"],
            path: "Tests/EchoelmusicUITests"
        ),

        // MARK: - Main App Target (aggregates everything)

        .target(
            name: "Echoelmusic",
            dependencies: [
                "EchoelmusicCore",
                "EchoelmusicAudio",
                "EchoelmusicBio",
                "EchoelmusicVisual",
                "EchoelmusicControl",
                "EchoelmusicMIDI",
                "EchoelmusicHardware",
                "EchoelmusicUI",
                "EchoelmusicPlatform"
            ],
            resources: [
                .process("Resources")
            ]
        ),

        // Main app tests
        .testTarget(
            name: "EchoelmusicTests",
            dependencies: [
                "Echoelmusic",
                "EchoelmusicCore",
                "EchoelmusicAudio",
                "EchoelmusicBio",
                "EchoelmusicVisual",
                "EchoelmusicControl"
            ]
        ),
    ]
)
