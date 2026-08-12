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
        // MARK: - MetinSDK (LOCAL test binary, iOS only)
        // TEMP: v2.1.0 ni local test qilish uchun. Commit qilmang —
        // asl remote binaryTarget ga qaytaring.
        .binaryTarget(
            name: "MetinSDK",
            path: "Frameworks/MetinSDK.xcframework"
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
