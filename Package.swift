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
// yoki SPM git dependency bo'lsa:
//   .package(url: "https://github.com/your-org/MetinSDK.git", from: "1.1.5")

let package = Package(
    name: "Muhr",
    defaultLocalization: "uz",
    platforms: [
        .iOS(.v14),
        .macOS(.v12),
    ],

    products: [
        // Muhr core — Styx (lokal sertifikat), asosiy kriptografiya (iOS + macOS)
        .library(
            name: "Muhr",
            targets: ["Muhr"]
        ),
        // MuhrMetin — Metin ERI/ЭЦП integratsiyasi (iOS only)
        .library(
            name: "MuhrMetin",
            targets: ["MuhrMetin"]
        ),
    ],

    targets: [
        // MARK: - MetinSDK (local binary, iOS only, kelajakda remote)
        .binaryTarget(
            name: "MetinSDK",
            path: "Frameworks/MetinSDK.xcframework"
        ),

        // MARK: - Muhr core (iOS + macOS)
        .target(
            name: "Muhr",
            dependencies: [],
            path: "Sources/Muhr",
            resources: [
                .process("Resources")
            ]
        ),

        // MARK: - MuhrMetin (iOS only)
        // MetinSDK faqat iOS da mavjud.
        // MetinProvider.swift ichida `#if canImport(MetinSDK)` guard ishlatiladi.
        .target(
            name: "MuhrMetin",
            dependencies: [
                "Muhr",
                .target(
                    name: "MetinSDK",
                    condition: .when(platforms: [.iOS])
                ),
            ],
            path: "Sources/MuhrMetin"
        ),

        // MARK: - Tests
        .testTarget(
            name: "MuhrTests",
            dependencies: ["Muhr"],
            path: "Tests/MuhrTests"
        ),
    ]
)
