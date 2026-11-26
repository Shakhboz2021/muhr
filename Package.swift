// swift-tools-version: 5.9

import PackageDescription

// MARK: - MetinSDK dependency
//
// Remote: https://github.com/AzizParpiyev/MetinSDK (branch: mkbank)
// Version: v3.6.5
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
        .package(url: "https://github.com/peachdev-uz/eimzo-ios-sdk", .upToNextMajor(from: "2.6.1")),
    ],

    targets: [
        // MARK: - MetinSDK (remote binary, iOS only)
        .binaryTarget(
            name: "MetinSDK",
            url:
                "https://github.com/AzizParpiyev/MetinSDK/raw/mkbank/MetinSDK-iOS/MetinSDK.xcframework_v3.6.5.zip",
            checksum: "225dca52368c709ad4c711b08afcbd54933afc3b3f212668b14c3b97cc0d642f"
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
