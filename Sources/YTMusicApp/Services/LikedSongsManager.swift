import Foundation
import SwiftUI

// MARK: - Liked Songs Manager

/// Manages the user's liked songs locally.
///
/// HOW IT WORKS:
/// - Stores liked song video IDs in UserDefaults as a Set<String>
/// - Persists on device (no account needed)
/// - Views check `isLiked(videoId:)` to show heart/filled heart icons
///
/// LIMITATIONS:
/// - Liked songs are LOCAL only — they don't sync with YouTube Music
/// - If the user logs into YouTube Music in the future, we'd need to
///   change this to use the API's `like/like` and `like/removelike` endpoints
@MainActor
class LikedSongsManager: ObservableObject {
    
    // MARK: - Properties
    
    /// Set of liked song video IDs.
    /// Published so views update when likes change.
    @Published private(set) var likedIds: Set<String> = []
    
    /// UserDefaults key for persistence.
    private let defaultsKey = "likedSongIds"
    
    // MARK: - Initialization
    
    init() {
        load()
    }
    
    // MARK: - Public Methods
    
    /// Toggle like status for a song.
    /// Returns the new state (true = liked, false = unliked).
    @discardableResult
    func toggle(_ videoId: String) -> Bool {
        if likedIds.contains(videoId) {
            likedIds.remove(videoId)
            save()
            return false
        } else {
            likedIds.insert(videoId)
            save()
            return true
        }
    }
    
    /// Like a specific song.
    func like(_ videoId: String) {
        likedIds.insert(videoId)
        save()
    }
    
    /// Unlike a specific song.
    func unlike(_ videoId: String) {
        likedIds.remove(videoId)
        save()
    }
    
    /// Check if a song is liked.
    func isLiked(_ videoId: String) -> Bool {
        likedIds.contains(videoId)
    }
    
    /// Get all liked song IDs.
    func allLikedIds() -> [String] {
        Array(likedIds)
    }
    
    /// Get the total number of liked songs.
    var count: Int {
        likedIds.count
    }
    
    // MARK: - Persistence
    
    /// Save liked IDs to UserDefaults.
    private func save() {
        UserDefaults.standard.set(Array(likedIds), forKey: defaultsKey)
    }
    
    /// Load liked IDs from UserDefaults.
    private func load() {
        if let ids = UserDefaults.standard.stringArray(forKey: defaultsKey) {
            likedIds = Set(ids)
        }
    }
}
