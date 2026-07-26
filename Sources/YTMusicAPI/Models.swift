import Foundation

/// Simple, clean data models for the UI layer
/// These are what our SwiftUI views will use

/// A search result (song, video, etc.)
struct SearchResult: Identifiable, Hashable {
    let id: String          // YouTube video ID
    let title: String       // Song/video title
    let artist: String      // Artist or channel name
    let thumbnailUrl: String // URL to the thumbnail image
    let duration: String?   // Duration string like "3:45"
    
    /// Get the best thumbnail URL (highest resolution)
    var bestThumbnailUrl: String {
        // YouTube thumbnails follow a pattern
        // We can request any size by changing the URL
        return "https://i.ytimg.com/vi/\(id)/mqdefault.jpg"
    }
}

/// Info needed to play a song
struct PlayerInfo {
    let videoId: String
    let title: String
    let artist: String
    let thumbnailUrl: String
    let duration: Int           // Duration in seconds
    let audioUrl: String        // Direct URL to the audio stream
    let audioQuality: String    // "High", "Medium", "Low"
    let viewCount: String
}

/// A section on the home/browse screen
struct BrowseSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [BrowseItem]
}

/// A single item on the home/browse screen
struct BrowseItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let thumbnailUrl: String
    let type: ItemType
    
    /// What type of content this is
    enum ItemType {
        case song
        case album
        case playlist
        case artist
    }
}

/// Player state for the audio player
enum PlayerState {
    case stopped
    case playing
    case paused
    case loading
}

/// What's currently playing
struct NowPlaying: Equatable {
    let id: String
    let title: String
    let artist: String
    let thumbnailUrl: String
    let duration: Int
    let audioUrl: String
    
    static func == (lhs: NowPlaying, rhs: NowPlaying) -> Bool {
        return lhs.id == rhs.id
    }
}
