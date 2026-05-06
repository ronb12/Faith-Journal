// swift-tools-version: 5.5
// Local fork: all target names suffixed with "1" to avoid SPM duplicate targets with AgoraRtcEngine_iOS.
import PackageDescription

let package = Package(
    name: "AgoraRtcEngine_macOS_1",
    defaultLocalization: "en",
    platforms: [.macOS(.v10_10)],
    products: [
        .library(name: "RtcBasic1", targets: ["AgoraRtcKit1", "Agorafdkaac1", "Agoraffmpeg1", "AgoraSoundTouch1", "video_dec1", "AgoraInfra_macOS1"]),
    ],
    dependencies: [
        .package(path: "../AgoraInfra_macOS_1"),
    ],
    targets: [
        .binaryTarget(
            name: "AgoraRtcKit1",
            path: "AgoraRtcKit1.xcframework"
        ),
        .binaryTarget(
            name: "Agorafdkaac1",
            url: "https://download.agora.io/swiftpm/AgoraRtcEngine_macOS/4.6.2/Agorafdkaac.xcframework.zip",
            checksum: "eb1235366e9b952a71163afeada2fe350f60dca050e866f0b5c1bb0411640ca8"
        ),
        .binaryTarget(
            name: "Agoraffmpeg1",
            url: "https://download.agora.io/swiftpm/AgoraRtcEngine_macOS/4.6.2/Agoraffmpeg.xcframework.zip",
            checksum: "ca8fd0f7d008d2398c3616e28dce66b78ab23beb2d1cfcf7d29a5a0d3b7105e3"
        ),
        .binaryTarget(
            name: "AgoraSoundTouch1",
            url: "https://download.agora.io/swiftpm/AgoraRtcEngine_macOS/4.6.2/AgoraSoundTouch.xcframework.zip",
            checksum: "fa35927bef8acb16caa774e7c3a2fcc2b27292a03f99a6fa792f28bd90a297f4"
        ),
        .binaryTarget(
            name: "video_dec1",
            url: "https://download.agora.io/swiftpm/AgoraRtcEngine_macOS/4.6.2/video_dec.xcframework.zip",
            checksum: "2fabeed4a4dca155cce6ce796e9d561ec9b76c8e273b247260c40301402615b5"
        ),
        .target(
            name: "AgoraInfra_macOS1",
            dependencies: [
                .product(name: "AgoraInfra_macOS1", package: "AgoraInfra_macOS_1"),
            ],
            path: "Sources/AgoraInfra_macOS1"
        ),
    ]
)
