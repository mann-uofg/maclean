// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "maclean",
    platforms: [
        .macOS("26.3") // macOS Tahoe (26.3) minimum
    ],
    products: [
        .executable(name: "maclean", targets: ["MacleanCLI"]),
        .executable(name: "MacleanApp", targets: ["MacleanApp"]),
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
        .executableTarget(
            name: "MacleanApp",
            dependencies: ["MacleanCore"]
        ),
        .testTarget(
            name: "MacleanCoreTests",
            dependencies: ["MacleanCore"]
        )
    ]
)
