// swift-tools-version: 5.9

import PackageDescription

// MARK: - MetinSDK dependency
//
// Remote: https://github.com/AzizParpiyev/MetinSDK (releases)
// Version: v2.5.0
//

let package = Package(
    name: "Muhr",
    defaultLocalization: "uz",
    platforms: [
        .iOS(.v16),
    ],

    products: [
        .library(
            name: "Muhr",
            targets: ["Muhr"]
        ),
    ],

    dependencies: [
        .package(url: "https://github.com/peachdev-uz/eimzo-ios-sdk", .upToNextMajor(from: "1.0.0")),
    ],

    targets: [
        // MARK: - MetinSDK (remote binary, iOS only)
        .binaryTarget(
            name: "MetinSDK",
            url:
                "https://github.com/AzizParpiyev/MetinSDK/releases/download/v2.5.0/MetinSDK.xcframework_v2.5.0.zip",
            checksum: "d597c6096d9458fded8ec89aef99c55fedc9b40bb070bb1211012150a319e6b4"
        ),

        // MARK: - Muhr (iOS + macOS)
        // MetinSDK faqat iOS da mavjud — Sources/Muhr/Data/Providers/MetinProvider.swift
        // ichida `#if canImport(MetinSDK)` guard ishlatiladi, macOS da ignore qilinadi.
        .target(
            name: "Muhr",
            dependencies: [
                .target(
                    name: "MetinSDK",
                    condition: .when(platforms: [.iOS])
                ),
                .product(
                    name: "EimzoSDK",
                    package: "eimzo-ios-sdk",
                    condition: .when(platforms: [.iOS])
                ),
            ],
            path: "Sources/Muhr",
            resources: [
                .process("Resources")
            ]
        ),

        // MARK: - Tests
        .testTarget(
            name: "MuhrTests",
            dependencies: ["Muhr"],
            path: "Tests/MuhrTests"
        ),
    ]
)
