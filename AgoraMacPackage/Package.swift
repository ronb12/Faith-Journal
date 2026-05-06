// swift-tools-version: 5.9
import PackageDescription

// macOS-only wrapper so the main app can depend on this for Mac and avoid
// pulling both Agora iOS and Agora macOS into the same graph from the app.
// Use this package only for the Mac target; keep Agora iOS direct for the iOS target.
let package = Package(
    name: "AgoraMacPackage",
    platforms: [.macOS(.v10_15)],
    products: [
        .library(name: "RtcBasic1", targets: ["AgoraMacWrapper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/AgoraIO/AgoraRtcEngine_macOS.git", from: "4.6.2"),
    ],
    targets: [
        .target(
            name: "AgoraMacWrapper",
            dependencies: [
                .product(
                    name: "RtcBasic",
                    package: "AgoraRtcEngine_macOS",
                    moduleAliases: [
                        "aosl": "aosl1",
                        "AgoraRtcKit": "AgoraRtcKit1",
                        "Agorafdkaac": "Agorafdkaac1",
                        "Agoraffmpeg": "Agoraffmpeg1",
                        "AgoraSoundTouch": "AgoraSoundTouch1",
                        "video_dec": "video_dec1",
                    ]
                ),
            ],
            path: "Sources/AgoraMacWrapper"
        ),
    ]
)
