// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "maclean",
    platforms: [
        .macOS(.v14) // macOS Sonoma (14.0) minimum
    ],
    products: [
        .executable(name: "maclean", targets: ["MacleanCLI"]),
        .library(name: "MacleanCore", targets: ["MacleanCore"])
    ],
    targets: [
        .target(
            name: "MacleanCore",
            dependencies: []
        ),
        .executableTarget(
            name: "MacleanCLI",
            dependencies: ["MacleanCore"]
        ),
        .testTarget(
            name: "MacleanCoreTests",
            dependencies: ["MacleanCore"]
        )
    ]
)
