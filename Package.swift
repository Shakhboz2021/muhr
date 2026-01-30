// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Muhr",
    defaultLocalization: "uz",
    platforms: [
        .iOS(.v14),
        .macOS(.v12),
    ],

    products: [
        .library(
            name: "Muhr",
            targets: ["Muhr"]
        )
    ],

    targets: [
        .target(
            name: "Muhr",
            dependencies: [],
            path: "Sources/Muhr",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MuhrTests",
            dependencies: ["Muhr"],
            path: "Tests/MuhrTests"
        ),
    ]
)
