// swift-tools-version: 5.9

import PackageDescription

// MARK: - MetinSDK dependency
//
// Remote: https://github.com/AzizParpiyev/MetinSDK (branch: mkbank, MetinSDK-iOS/)
// Version: v1.1.8
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
            url: "https://github.com/AzizParpiyev/MetinSDK/releases/download/v1.1.8/MetinSDK.xcframework_v1.1.8.zip",
            checksum: "c5771847a96db008c9c80efc6b6c1c83169d8c65930f21460bf37c738245bf7e"
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
