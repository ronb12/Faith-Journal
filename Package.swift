// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Faith Journal",
    platforms: [
        .iOS(.v17)
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
<<<<<<< HEAD
            path: "Faith Journal/Faith Journal"),
=======
            path: "Sources"),
>>>>>>> 5032e386757d61b607f69b96e9ac6ae9aac5e187
        .testTarget(
            name: "Faith JournalTests",
            dependencies: ["Faith Journal"],
            path: "Tests"),
    ]
) 