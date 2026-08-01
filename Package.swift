// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package

import PackageDescription

let package = Package(
    name: "YTMusicApp",
    platforms: [
        .iOS(.v17),   // iOS 17 or later
        .macOS(.v14)  // macOS 14 or later
    ],
    products: [
        // The app executable.
        // NOTE: This package builds BOTH source folders as ONE module,
        // exactly like the Xcode project (project.yml + xcodegen).
        // The code has no `public` access modifiers, so a separate
        // YTMusicAPI module would not be able to see its types.
        .executable(
            name: "YTMusicApp",
            targets: ["YTMusicApp"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "YTMusicApp",
            // The executable is rooted at Sources/...
            path: "Sources",
            // ...and includes BOTH the app code and the API layer
            // as a single module (mirrors the xcodegen single-target setup).
            sources: ["YTMusicApp", "YTMusicAPI"]
        ),
    ]
)
