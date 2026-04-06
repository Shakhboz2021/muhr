// swift-tools-version: 5.9

import PackageDescription

// MARK: - MetinSDK dependency
//
// Remote: https://github.com/AzizParpiyev/MetinSDK (branch: mkbank, MetinSDK-iOS/)
// Version: v1.1.7
//

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
        ),
    ],

    targets: [
        // MARK: - MetinSDK (remote binary, iOS only)
        .binaryTarget(
            name: "MetinSDK",
            url: "https://github.com/AzizParpiyev/MetinSDK/raw/mkbank/MetinSDK-iOS/MetinSDK.xcframework_v1.1.7.zip",
            checksum: "04d2e74f5b98a282ad4ea2a442edbf9d6e4e28f3dc431f5880b6050d03594ea6"
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
