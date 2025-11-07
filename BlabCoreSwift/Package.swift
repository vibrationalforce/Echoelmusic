// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BlabCoreSwift",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "BlabCoreSwift",
            targets: ["BlabCoreSwift"]
        ),
    ],
    targets: [
        // Rust binary (built separately)
        .binaryTarget(
            name: "BlabCore",
            path: "../blab-core/target/universal/release/libblab_ffi.xcframework"
        ),

        // Swift wrapper
        .target(
            name: "BlabCoreSwift",
            dependencies: ["BlabCore"],
            path: "Sources"
        ),

        // Tests
        .testTarget(
            name: "BlabCoreSwiftTests",
            dependencies: ["BlabCoreSwift"]
        ),
    ]
)
