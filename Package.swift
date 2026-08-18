// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DeskBat",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "DeskBatCore",
            path: "Sources/DeskBatCore"
        ),
        .executableTarget(
            name: "DeskBat",
            dependencies: ["DeskBatCore"],
            path: "Sources/DeskBat"
        ),
        .testTarget(
            name: "DeskBatCoreTests",
            dependencies: ["DeskBatCore"],
            path: "Tests/DeskBatCoreTests"
        )
    ]
)
