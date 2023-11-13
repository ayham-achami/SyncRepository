// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CRepository",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .macCatalyst(.v14)
    ],
    products: [
        .library(
            name: "CRepository",
            targets: [
                "CRepository"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/realm/SwiftLint", from: "0.53.0"),
        .package(url: "https://github.com/realm/realm-cocoa.git", .upToNextMajor(from: "10.38.0"))
    ],
    targets: [
        .target(
            name: "CRepository",
            dependencies: [
                .product(name: "RealmSwift", package: "realm-cocoa")
            ],
            plugins: [
                .plugin(name: "SwiftLintPlugin", package: "SwiftLint")
            ]
        ),
        .testTarget(
            name: "CRepositoryTests",
            dependencies: [
                "CRepository"
            ],
            path: "CRepositoryTests",
            exclude: [
                "Info.plist"
            ],
            plugins: [
                .plugin(name: "SwiftLintPlugin", package: "SwiftLint")
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
