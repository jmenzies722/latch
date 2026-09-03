// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Latch",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "LatchCore", targets: ["LatchCore"]),
    ],
    targets: [
        .target(
            name: "LatchCore",
            path: "Sources/LatchCore"
        ),
        .testTarget(
            name: "LatchCoreTests",
            dependencies: ["LatchCore"],
            path: "Tests/LatchCoreTests"
        ),
    ]
)
