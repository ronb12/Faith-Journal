// swift-tools-version: 5.5
// Local fork: target names suffixed with "1" to avoid SPM duplicate targets with AgoraInfra_iOS.
import PackageDescription

let package = Package(
    name: "AgoraInfra_macOS_1",
    defaultLocalization: "en",
    platforms: [.macOS(.v10_10)],
    products: [
        .library(name: "AgoraInfra_macOS1", targets: ["aosl1"]),
    ],
    targets: [
        .binaryTarget(
            name: "aosl1",
            url: "https://download.agora.io/swiftpm/AgoraInfra_macOS/1.3.5/aosl.xcframework.zip",
            checksum: "e79e07fc834be13596a5bca79a96b81f29ee6c8c44c7c4be66473e0aa4e260bb"
        ),
    ]
)
