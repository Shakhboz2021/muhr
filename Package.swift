// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Muhr",

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
            path: "Sources/Muhr"
        ),
        .testTarget(
            name: "MuhrTests",
            dependencies: ["Muhr"],
            path: "Tests/MuhrTests"
        ),
    ]
)
