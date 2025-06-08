// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "FaithJournal",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "FaithJournal",
            targets: ["FaithJournal"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FaithJournal",
            dependencies: [],
            path: "Faith Journal"
        ),
        .testTarget(
            name: "FaithJournalTests",
            dependencies: ["FaithJournal"],
            path: "Faith JournalTests"
        )
    ]
)