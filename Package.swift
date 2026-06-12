// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexBarLite",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CodexBarLite",
            targets: ["CodexBarLite"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CodexBarLite",
            path: "Sources/CodexBarLite"
        )
    ]
)