// swift-tools-version: 5.9

import PackageDescription

// MARK: - MetinSDK dependency
//
// Hozir: local xcframework (Frameworks/MetinSDK.xcframework)
//
// Kelajakda remote repodan olish uchun quyidagicha o'zgartiring:
//
//   .binaryTarget(
//       name: "MetinSDK",
//       url: "https://your-cdn.com/MetinSDK-1.1.5.xcframework.zip",
//       checksum: "<sha256 checksum>"
//   )
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
        // MARK: - MetinSDK (local binary, iOS only, kelajakda remote)
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
