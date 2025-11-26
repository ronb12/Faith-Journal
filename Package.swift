// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Faith Journal",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Faith Journal",
            targets: ["Faith Journal"]),
    ],
    dependencies: [
        // Dependencies go here
    ],
    targets: [
        .target(
            name: "Faith Journal",
            dependencies: [],
            path: "Sources",
            exclude: ["Info.plist"]),
        .testTarget(
            name: "Faith JournalTests",
            dependencies: ["Faith Journal"],
            path: "Tests",
            swiftSettings: [
                .define("TESTING")
            ]),
    ]
) 