import Foundation

// MARK: - Overview

/// Simple, clean data models for the UI layer.
///
/// HOW THIS DIFFERS FROM InnerTubeModels.swift:
/// - InnerTubeModels.swift = complex models that mirror YouTube's nested JSON
/// - Models.swift = simple models that our SwiftUI views actually use
///
/// We convert from InnerTube models to these simple models before passing
/// data to views. This keeps the UI code clean and decoupled from YouTube's
/// internal API format.

// MARK: - Search Result

/// A single search result (song, video, etc.).
///
/// Created from YouTube's search response. Used by SearchView to display results.
struct SearchResult: Identifiable, Hashable {
    /// YouTube video ID (e.g. "dQw4w9WgXcQ") — used as unique identifier
    let id: String
    /// Song/video title (e.g. "Bohemian Rhapsody")
    let title: String
    /// Artist or channel name (e.g. "Queen")
    let artist: String
    /// URL to the thumbnail image (e.g. "https://i.ytimg.com/vi/.../mqdefault.jpg")
    let thumbnailUrl: String
    /// Duration string (e.g. "3:45") — optional because some results (like artists) don't have one
    let duration: String?
    
    /// Get the best thumbnail URL (medium quality, 320x180).
    ///
    /// YouTube thumbnails follow a predictable URL pattern:
    ///   https://i.ytimg.com/vi/{videoId}/{size}.jpg
    ///
    /// Available sizes:
    /// - `default.jpg` = 120x90
    /// - `mqdefault.jpg` = 320x180 (medium quality — we use this)
    /// - `hqdefault.jpg` = 480x360 (high quality)
    /// - `sddefault.jpg` = 640x480 (standard definition)
    /// - `maxresdefault.jpg` = 1920x1080 (max resolution, not always available)
    var bestThumbnailUrl: String {
        return "https://i.ytimg.com/vi/\(id)/mqdefault.jpg"
    }
}

// MARK: - Player Info

/// Info needed to play a song (including the streaming URL).
///
/// This is returned by the player endpoint. It contains the actual audio
/// stream URL, which is NOT available in search/browse responses.
///
/// STREAM URLs ARE TEMPORARY:
/// The audioUrl expires after a few hours. If the user tries to play a song
/// after the URL expires, we'd need to fetch a fresh one.
struct PlayerInfo {
    let videoId: String
    let title: String
    let artist: String
    let thumbnailUrl: String
    let duration: Int           // Duration in seconds (e.g. 225 = 3:45)
    let audioUrl: String        // Direct URL to the audio stream (temporary!)
    let audioQuality: String    // "High", "Medium", or "Low"
    let viewCount: String       // View count as a string (e.g. "1,234,567")
}

// MARK: - Browse Section

/// A section on the home/browse screen (e.g. "Quick Picks", "Trending").
///
/// Each section has a title and a list of items displayed in a horizontal carousel.
struct BrowseSection: Identifiable {
    /// UUID = universally unique identifier. Generated automatically for each instance.
    /// This is needed because SwiftUI's ForEach requires each item to have a unique ID.
    /// We use UUID() instead of a YouTube ID because browse sections don't always
    /// have a stable identifier from the API.
    let id = UUID()
    let title: String
    let items: [BrowseItem]
}

// MARK: - Browse Item

/// A single item on the home/browse screen (a song, album, playlist, or artist).
struct BrowseItem: Identifiable, Hashable {
    /// YouTube video/playlist/album ID
    let id: String
    let title: String
    let subtitle: String       // e.g. artist name or "Playlist • 50 songs"
    let thumbnailUrl: String
    let type: ItemType
    
    /// What type of content this is.
    /// Used by views to decide how to display and handle the item.
    enum ItemType {
        case song        // Playable song — tap to play
        case album       // Album — tap to show track list
        case playlist    // Playlist — tap to show songs
        case artist      // Artist — tap to show artist page
    }
}

// MARK: - Player State

/// The current state of the audio player.
///
/// STATE TRANSITIONS:
/// ```
/// .stopped → .loading → .playing ↔ .paused
///                ↓           ↓
///            .stopped    .stopped
/// ```
///
/// - .stopped: Nothing is playing (initial state and after stop())
/// - .loading: A song is being loaded/buffered (brief state before playback starts)
/// - .playing: Audio is actively playing
/// - .paused: Audio is paused (can be resumed)
enum PlayerState {
    case stopped    // No playback
    case playing    // Audio is playing
    case paused     // Audio is paused
    case loading    // Buffering/loading a new song
}

// MARK: - Now Playing

/// What's currently playing — the audio player's core data model.
///
/// This is a NORMALIZED representation of a song. We create this from
/// PlayerInfo (which has extra fields like audioUrl and viewCount)
/// because the audio player only needs the essential display info.
///
/// EQUATABLE CONFORMANCE:
/// We implement == to compare only the `id` field. This means two NowPlaying
/// objects with the same video ID are considered equal, even if other fields
/// differ. This is useful for finding songs in the queue by ID.
struct NowPlaying: Equatable {
    /// YouTube video ID — unique identifier for this song
    let id: String
    /// Song title (e.g. "Bohemian Rhapsody")
    let title: String
    /// Artist name (e.g. "Queen")
    let artist: String
    /// URL to album art thumbnail
    let thumbnailUrl: String
    /// Duration in seconds (e.g. 225 = 3:45)
    let duration: Int
    /// Direct URL to the audio stream (obtained from player endpoint)
    let audioUrl: String
    
    /// Custom equality: two NowPlaying objects are equal if they have the same ID.
    /// This ignores title, artist, thumbnail, etc. — only the ID matters.
    /// This is important for queue management (finding songs by ID).
    static func == (lhs: NowPlaying, rhs: NowPlaying) -> Bool {
        return lhs.id == rhs.id
    }
}
