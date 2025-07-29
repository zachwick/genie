// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "genie",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.4"),
        .package(url: "https://github.com/dastrobu/argtree.git", from: "1.5.2"),
        .package(url: "https://github.com/realm/SwiftLint.git", from: "0.59.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .executableTarget(
            name: "genie",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
                "argtree"
            ]),
        .testTarget(
            name: "genieTests",
            dependencies: ["genie"]),
    ]
)
