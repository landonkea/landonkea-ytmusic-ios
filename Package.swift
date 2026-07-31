// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "YTMusicApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "YTMusicAPI",
            targets: ["YTMusicAPI"]
        ),
        .executable(
            name: "YTMusicApp",
            targets: ["YTMusicApp"]
        ),
    ],
    targets: [
        .target(
            name: "YTMusicAPI",
            path: "Sources/YTMusicAPI"
        ),
        .executableTarget(
            name: "YTMusicApp",
            dependencies: ["YTMusicAPI"],
            path: "Sources/YTMusicApp"
        ),
    ]
)
