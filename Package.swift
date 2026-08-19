// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let package = Package(
    name: "LoomCore",
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
            name: "LoomCore"
        ),
        .testTarget(
            name: "LoomCoreTests",
            dependencies: ["LoomCore"]
        ),
    ]
)

// The DocC plugin is only needed when generating documentation (the docs
// workflow sets BUILDING_DOCC); keep library consumers dependency-free.
if ProcessInfo.processInfo.environment["BUILDING_DOCC"] != nil {
    package.dependencies.append(
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.3")
    )
}
