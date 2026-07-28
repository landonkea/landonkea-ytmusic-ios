import Foundation
import SwiftUI

// MARK: - Play Count Manager

/// Tracks how many times each song has been played and when it was last played.
///
/// WHAT THIS DOES:
/// Every time a song starts playing, we increment its play count and record
/// the timestamp. This data can be used to:
/// - Show "Most Played" section on the home screen
/// - Sort playlists by play count
/// - Show listening stats to the user
///
/// STORAGE:
/// Play counts are stored as a dictionary mapping video IDs to play counts.
/// Last played timestamps are stored separately. Both are persisted to JSON
/// files in the Documents directory.
///
/// HOW IT WORKS:
/// AudioPlayer calls recordPlay() whenever a new song starts playing.
/// The manager increments the count and saves to disk. Views can call
/// getPlayCount() or getMostPlayed() to display this data.
class PlayCountManager: ObservableObject {
    
    // MARK: - Static Reference
    
    /// Shared instance that AudioPlayer can access via PlayCountManager.shared.
    /// Set in YTMusicApp.init() after the PlayCountManager is created.
    static var shared: PlayCountManager?
    
    // MARK: - Published Properties
    
    /// Dictionary mapping video IDs to their play counts.
    /// Updated whenever a song is played.
    @Published var playCounts: [String: Int] = [:]
    
    /// Dictionary mapping video IDs to their last played date.
    /// Used for "Recently Played" sorting and "Last Played" display.
    @Published var lastPlayedDates: [String: Date] = [:]
    
    // MARK: - Private Properties
    
    /// File paths for persisting play count data.
    private let playCountsPath: URL
    private let lastPlayedPath: URL
    
    // MARK: - Initialization
    
    /// Create the play count manager and load saved data from disk.
    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.playCountsPath = documents.appendingPathComponent("play_counts.json")
        self.lastPlayedPath = documents.appendingPathComponent("last_played.json")
        
        loadPlayCounts()
        loadLastPlayedDates()
    }
    
    // MARK: - Public Methods
    
    /// Record that a song was played.
    ///
    /// Called by AudioPlayer when a new song starts playing.
    /// Increments the play count and updates the last played timestamp.
    ///
    /// - Parameter videoId: The YouTube video ID of the played song
    func recordPlay(videoId: String) {
        // Increment play count
        playCounts[videoId, default: 0] += 1
        
        // Update last played timestamp
        lastPlayedDates[videoId] = Date()
        
        // Save to disk
        savePlayCounts()
        saveLastPlayedDates()
    }
    
    /// Get the play count for a specific song.
    ///
    /// - Parameter videoId: The YouTube video ID
    /// - Returns: Number of times the song was played (0 if never played)
    func getPlayCount(videoId: String) -> Int {
        return playCounts[videoId] ?? 0
    }
    
    /// Get the last played date for a specific song.
    ///
    /// - Parameter videoId: The YouTube video ID
    /// - Returns: The date the song was last played, or nil if never played
    func getLastPlayedDate(videoId: String) -> Date? {
        return lastPlayedDates[videoId]
    }
    
    /// Get the top N most played songs.
    ///
    /// - Parameter limit: Maximum number of songs to return (default: 10)
    /// - Returns: Array of (videoId, playCount) tuples sorted by play count
    func getMostPlayed(limit: Int = 10) -> [(videoId: String, count: Int)] {
        return playCounts
            .sorted { $0.value > $1.value } // Sort by count descending
            .prefix(limit) // Take top N
            .map { (videoId: $0.key, count: $0.value) }
    }
    
    /// Get the total number of songs that have been played.
    var totalSongsPlayed: Int {
        playCounts.count
    }
    
    /// Get the total number of plays across all songs.
    var totalPlays: Int {
        playCounts.values.reduce(0, +)
    }
    
    // MARK: - Persistence
    
    /// Save play counts to disk.
    private func savePlayCounts() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(playCounts)
            try data.write(to: playCountsPath)
        } catch {
            print("Failed to save play counts: \(error)")
        }
    }
    
    /// Load play counts from disk.
    private func loadPlayCounts() {
        guard FileManager.default.fileExists(atPath: playCountsPath.path) else { return }
        
        do {
            let data = try Data(contentsOf: playCountsPath)
            playCounts = try JSONDecoder().decode([String: Int].self, from: data)
        } catch {
            print("Failed to load play counts: \(error)")
            playCounts = [:]
        }
    }
    
    /// Save last played dates to disk.
    private func saveLastPlayedDates() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(lastPlayedDates)
            try data.write(to: lastPlayedPath)
        } catch {
            print("Failed to save last played dates: \(error)")
        }
    }
    
    /// Load last played dates from disk.
    private func loadLastPlayedDates() {
        guard FileManager.default.fileExists(atPath: lastPlayedPath.path) else { return }
        
        do {
            let data = try Data(contentsOf: lastPlayedPath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            lastPlayedDates = try decoder.decode([String: Date].self, from: data)
        } catch {
            print("Failed to load last played dates: \(error)")
            lastPlayedDates = [:]
        }
    }
}
