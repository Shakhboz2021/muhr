// swift-tools-version: 5.9

import PackageDescription

// MARK: - MetinSDK dependency
//
// Remote: https://github.com/AzizParpiyev/MetinSDK (branch: mkbank)
// Version: v3.6.4
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
                "https://github.com/AzizParpiyev/MetinSDK/raw/mkbank/MetinSDK-iOS/MetinSDK.xcframework_v3.6.4.zip",
            checksum: "ba8bb70bc6cf1d7ffa784a847935a8d8cafd5adb1d7fdcea7f69f034ece9234d"
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
