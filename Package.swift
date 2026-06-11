// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LoopForge",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LoopForge", targets: ["LoopForge"])
    ],
    targets: [
        .executableTarget(
            name: "LoopForge",
            path: "Sources/LoopForge"
        ),
        .testTarget(
            name: "LoopForgeTests",
            dependencies: ["LoopForge"],
            path: "Tests/LoopForgeTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
