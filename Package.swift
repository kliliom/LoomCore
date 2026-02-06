// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "loom-core",
    platforms: [
        .iOS(.v16),
        .macCatalyst(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .visionOS(.v1),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "LoomCore",
            targets: ["LoomCore"]
        ),
    ],
    targets: [
        .target(
            name: "LoomCore",
            path: "Sources"
        ),
        .testTarget(
            name: "LoomCoreTests",
            dependencies: ["LoomCore"],
            path: "Tests"
        ),
    ]
)
