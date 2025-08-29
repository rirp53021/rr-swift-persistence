// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RRPersistence",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "RRPersistence",
            targets: ["RRPersistence"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/rirp53021/rr-swift-foundation.git", from: "1.7.1"),
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.5.0")
    ],
    targets: [
        .target(
            name: "RRPersistence",
            dependencies: [
                .product(name: "RRFoundation", package: "rr-swift-foundation")
            ],
            path: "Sources/RRPersistence"
        ),
        .testTarget(
            name: "RRPersistenceTests",
            dependencies: ["RRPersistence", .product(name: "Testing", package: "swift-testing")],
            path: "Tests/RRPersistenceTests"
        )
    ]
)
