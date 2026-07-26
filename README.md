# landonkea-ytmusic-ios

A free, open-source YouTube Music client for iPhone, iPad, and Mac.

## Features

- Search for songs, artists, and albums
- Play music from YouTube's vast library
- Background audio playback
- Mini player with playback controls
- Full-screen player with progress bar
- AirPlay support
- No ads, no subscription required

## Requirements

- iOS 17.0+ / macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

## Setup

1. Open Xcode
2. File → New → Project
3. Choose "iOS" → "App"
4. Product Name: `YTMusic`
5. Organization Identifier: `com.landonkea`
6. Interface: SwiftUI
7. Language: Swift
8. Save the project in this folder
9. In Xcode, go to File → Add Package Dependencies
10. Add this local package (the folder you're in)

## How It Works

This app uses YouTube's InnerTube API - the same internal API that the official YouTube Music app uses. By pretending to be the official iOS YouTube Music client, we can:

- Search for any song
- Get streaming URLs
- Play audio without ads

## Technical Details

- **API Client**: Talks directly to YouTube's InnerTube servers
- **Audio Playback**: Uses AVFoundation for native audio playback
- **UI**: Built with SwiftUI for a native Apple feel
- **Architecture**: MVVM (Model-View-ViewModel)

## Project Structure

```
Sources/
├── YTMusicAPI/           # The API client library
│   ├── InnerTubeClient.swift    # Main API client
│   ├── InnerTubeModels.swift    # Data models for API
│   └── Models.swift            # Simple models for UI
│
└── YTMusicApp/           # The iOS/macOS app
    ├── YTMusicApp.swift         # App entry point
    ├── Services/
    │   └── AudioPlayer.swift    # Audio playback manager
    └── Views/
        ├── ContentView.swift    # Main tab view
        ├── HomeView.swift       # Home screen
        ├── SearchView.swift     # Search screen
        └── PlayerView.swift     # Full-screen player
```

## What's Next

- [ ] Playlist support
- [ ] Lyrics display
- [ ] Offline caching
- [ ] Queue management
- [ ] Dark mode support
- [ ] Widget for home screen

## Disclaimer

This project is not affiliated with YouTube or Google. It uses an unofficial API that may stop working at any time.

## License

MIT License
