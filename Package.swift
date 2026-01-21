// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "loom-core",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .macCatalyst(.v14),
        .tvOS(.v14),
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
