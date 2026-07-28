import Foundation
import SwiftUI

// MARK: - Playlist Manager

/// Manages local playlists — create, rename, delete, add/remove songs.
///
/// WHAT THIS DOES:
/// Users can create playlists to organize their favorite songs. Playlists
/// are stored locally on the device (no login required). Each playlist has
/// a name, creation date, and list of songs.
///
/// STORAGE:
/// Playlists are saved as a JSON file in the Documents directory.
/// Each playlist is a simple struct with a name and array of NowPlaying songs.
///
/// HOW IT WORKS:
/// 1. User taps "New Playlist" in the Library tab
/// 2. They enter a name and tap Create
/// 3. From any song's context menu, they tap "Add to Playlist"
/// 4. They select which playlist to add to
/// 5. The song is appended to that playlist and saved to disk
/// 6. Tapping a playlist shows its songs
/// 7. Tapping a song in the playlist starts playing from that playlist
class PlaylistManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All user-created playlists, sorted by creation date (newest first).
    @Published var playlists: [Playlist] = []
    
    // MARK: - Private Properties
    
    /// File path for persisting playlists as JSON.
    private let playlistsPath: URL
    
    // MARK: - Initialization
    
    /// Create the playlist manager and load existing playlists from disk.
    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.playlistsPath = documents.appendingPathComponent("playlists.json")
        loadPlaylists()
    }
    
    // MARK: - Playlist CRUD
    
    /// Create a new empty playlist.
    ///
    /// - Parameter name: The playlist name (e.g. "Workout Mix")
    /// - Returns: The newly created playlist
    @discardableResult
    func createPlaylist(name: String) -> Playlist {
        let playlist = Playlist(
            id: UUID().uuidString,
            name: name,
            songs: [],
            createdAt: Date()
        )
        playlists.insert(playlist, at: 0) // Newest first
        savePlaylists()
        return playlist
    }
    
    /// Rename an existing playlist.
    ///
    /// - Parameters:
    ///   - playlist: The playlist to rename
    ///   - newName: The new name
    func renamePlaylist(_ playlist: Playlist, newName: String) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].name = newName
        savePlaylists()
    }
    
    /// Delete a playlist.
    ///
    /// - Parameter playlist: The playlist to delete
    func deletePlaylist(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        savePlaylists()
    }
    
    /// Toggle whether a playlist is pinned (appears at top of the list).
    func togglePin(_ playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].isPinned.toggle()
        savePlaylists()
        
        // Re-sort: pinned first, then by creation date (newest first)
        playlists.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.createdAt > rhs.createdAt
        }
    }
    
    // MARK: - Song Management
    
    /// Add a song to a playlist.
    ///
    /// Prevents duplicates — if the song is already in the playlist, it won't be added again.
    ///
    /// - Parameters:
    ///   - song: The NowPlaying song to add
    ///   - playlist: The playlist to add it to
    func addSong(_ song: NowPlaying, to playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        
        // Don't add duplicates
        guard !playlists[index].songs.contains(where: { $0.id == song.id }) else { return }
        
        playlists[index].songs.append(song)
        savePlaylists()
    }
    
    /// Remove a song from a playlist.
    ///
    /// - Parameters:
    ///   - song: The song to remove
    ///   - playlist: The playlist to remove it from
    func removeSong(_ song: NowPlaying, from playlist: Playlist) {
        guard let playlistIndex = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        
        playlists[playlistIndex].songs.removeAll { $0.id == song.id }
        savePlaylists()
    }
    
    /// Check if a song is in a playlist.
    ///
    /// - Parameters:
    ///   - song: The song to check
    ///   - playlist: The playlist to check in
    /// - Returns: true if the song is already in the playlist
    func containsSong(_ song: NowPlaying, in playlist: Playlist) -> Bool {
        guard let playlistIndex = playlists.firstIndex(where: { $0.id == playlist.id }) else { return false }
        return playlists[playlistIndex].songs.contains(where: { $0.id == song.id })
    }
    
    /// Get all playlists that contain a specific song.
    ///
    /// Used by the "Add to Playlist" menu to show checkmarks next to playlists
    /// that already contain the song.
    func playlistsContaining(_ song: NowPlaying) -> [Playlist] {
        return playlists.filter { playlist in
            playlist.songs.contains(where: { $0.id == song.id })
        }
    }
    
    // MARK: - Persistence
    
    /// Save all playlists to disk as JSON.
    /// Marked as internal (not private) so PlaylistDetailView can call it after reordering.
    func savePlaylists() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(playlists)
            try data.write(to: playlistsPath)
        } catch {
            print("Failed to save playlists: \(error)")
        }
    }
    
    /// Load playlists from disk.
    private func loadPlaylists() {
        guard FileManager.default.fileExists(atPath: playlistsPath.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: playlistsPath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            playlists = try decoder.decode([Playlist].self, from: data)
            
            // Sort: pinned first, then by creation date (newest first)
            playlists.sort { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                return lhs.createdAt > rhs.createdAt
            }
        } catch {
            print("Failed to load playlists: \(error)")
            playlists = []
        }
    }
}

// MARK: - Playlist Model

/// A local playlist containing a list of songs.
struct Playlist: Identifiable, Codable {
    /// Unique identifier for this playlist
    let id: String
    
    /// User-given name (e.g. "Workout Mix", "Chill Vibes")
    var name: String
    
    /// The songs in this playlist, in order
    var songs: [NowPlaying]
    
    /// When this playlist was created
    let createdAt: Date
    
    /// Whether this playlist is pinned to the top of the list.
    /// Default false for backward compatibility with existing playlists.
    var isPinned: Bool = false
    
    /// Number of songs in the playlist (computed convenience property)
    var songCount: Int {
        songs.count
    }
    
    /// Total duration of all songs in the playlist (computed).
    /// Returns a human-readable string like "45 min" or "1 hr 23 min".
    var totalDuration: String {
        let totalSeconds = songs.reduce(0) { $0 + $1.duration }
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        } else {
            return "\(minutes) min"
        }
    }
}
