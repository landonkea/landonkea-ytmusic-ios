import Foundation
import SwiftUI

// MARK: - Stats Manager

/// Tracks listening statistics — total time, top songs, daily streaks, etc.
///
/// HOW IT WORKS:
/// - Records a "listen session" every time a song is played
/// - Each session stores: videoId, title, artist, duration played, timestamp
/// - Aggregates are computed from the raw session data
///
/// DATA STORED:
/// - Total time listened (in seconds)
/// - Total songs played
/// - Most-played songs (by play count)
/// - Listening history (last 500 sessions)
///
/// PERSISTENCE:
/// - Stored as JSON in the Documents directory
/// - Sessions older than 1 year are pruned to save space
@MainActor
class StatsManager: ObservableObject {
    
    // MARK: - Types
    
    /// A single listen session — recorded when a song is played for >10 seconds.
    struct ListenSession: Codable, Identifiable {
        let id: UUID
        let videoId: String
        let title: String
        let artist: String
        let durationPlayed: Double  // seconds actually listened
        let timestamp: Date
    }
    
    // MARK: - Published Properties
    
    /// All recorded listen sessions (limited to last 500).
    @Published private(set) var sessions: [ListenSession] = []
    
    // MARK: - Computed Properties
    
    /// Total time listened in seconds.
    var totalTimeListened: TimeInterval {
        sessions.reduce(0) { $0 + $1.durationPlayed }
    }
    
    /// Total number of songs played.
    var totalSongsPlayed: Int {
        sessions.count
    }
    
    /// Average time listened per song in seconds.
    var averageListenTime: TimeInterval {
        guard !sessions.isEmpty else { return 0 }
        return totalTimeListened / Double(sessions.count)
    }
    
    /// Get the top N most played songs.
    func mostPlayedSongs(limit: Int = 20) -> [(videoId: String, title: String, artist: String, count: Int)] {
        var counts: [String: (title: String, artist: String, count: Int)] = [:]
        
        for session in sessions {
            if var entry = counts[session.videoId] {
                entry.count += 1
                counts[session.videoId] = entry
            } else {
                counts[session.videoId] = (session.title, session.artist, 1)
            }
        }
        
        return counts
            .sorted { $0.value.count > $1.value.count }
            .prefix(limit)
            .map { (videoId: $0.key, title: $0.value.title, artist: $0.value.artist, count: $0.value.count) }
    }
    
    /// Top artists by listen count.
    func topArtists(limit: Int = 10) -> [(artist: String, count: Int)] {
        var counts: [String: Int] = [:]
        
        for session in sessions {
            counts[session.artist, default: 0] += 1
        }
        
        return counts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (artist: $0.key, count: $0.value) }
    }
    
    /// Human-readable total listening time (e.g. "12h 34m").
    var formattedTotalTime: String {
        let totalSeconds = Int(totalTimeListened)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    // MARK: - Private Properties
    
    /// File URL for the sessions JSON.
    private let fileURL: URL
    
    // MARK: - Initialization
    
    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documents.appendingPathComponent("listen_sessions.json")
        load()
        
        // Observe song finish notifications to record listening stats
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(songDidFinish(_:)),
            name: .songDidFinishPlaying,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Notification Handler
    
    /// Called when a song finishes playing naturally.
    @objc private func songDidFinish(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let videoId = userInfo["videoId"] as? String,
              let title = userInfo["title"] as? String,
              let artist = userInfo["artist"] as? String,
              let durationPlayed = userInfo["durationPlayed"] as? Double else {
            return
        }
        
        recordPlay(videoId: videoId, title: title, artist: artist, durationPlayed: durationPlayed)
    }
    
    // MARK: - Recording
    
    /// Record a listen session.
    ///
    /// Only records if the song was played for at least 10 seconds (filters out accidental taps).
    func recordPlay(videoId: String, title: String, artist: String, durationPlayed: Double) {
        guard durationPlayed >= 10 else { return }
        
        let session = ListenSession(
            id: UUID(),
            videoId: videoId,
            title: title,
            artist: artist,
            durationPlayed: durationPlayed,
            timestamp: Date()
        )
        
        sessions.append(session)
        
        // Keep only last 500 sessions
        if sessions.count > 500 {
            sessions = Array(sessions.suffix(500))
        }
        
        save()
    }
    
    // MARK: - Persistence
    
    /// Save sessions to disk.
    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(sessions)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save listen sessions: \(error)")
        }
    }
    
    /// Load sessions from disk.
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            sessions = try decoder.decode([ListenSession].self, from: data)
        } catch {
            print("Failed to load listen sessions: \(error)")
        }
    }
}
