// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Notes",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/kliliom/LoomCore.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Notes",
            dependencies: [.product(name: "LoomCore", package: "LoomCore")]
        )
    ]
)
