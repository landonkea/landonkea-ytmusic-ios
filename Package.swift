// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package

import PackageDescription

let package = Package(
    name: "YTMusicAPI",
    platforms: [
        .iOS(.v17),      // iOS 17 or later
        .macOS(.v14)     // macOS 14 or later
    ],
    products: [
        // The API client library
        .library(
            name: "YTMusicAPI",
            targets: ["YTMusicAPI"]
        ),
    ],
    targets: [
        .target(
            name: "YTMusicAPI",
            path: "Sources/YTMusicAPI"
        ),
    ]
)
