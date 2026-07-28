import Foundation
import SwiftUI

/// Manages offline song caching — downloading, storing, and playing cached songs.
///
/// HOW IT WORKS:
/// - Songs are downloaded to the app's Documents/Downloads/ directory
/// - A JSON file tracks which songs are downloaded (metadata + file paths)
/// - When playing a song, we check if it's cached first (saves data + works offline)
/// - Users can delete individual downloads or clear all
///
/// STORAGE LOCATION:
/// iOS apps have a "Documents" directory that persists between launches.
/// We store downloads in Documents/Downloads/ and the index in Documents/downloads.json.
///
/// LIMITATIONS:
/// - Cached songs are deleted if the user uninstalls the app
/// - Stream URLs expire after a few hours, so cached audio files are the only
///   thing that persists — we can't re-download with the same URL
/// - Storage is limited by the device's available space
@MainActor
class OfflineManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// List of all downloaded songs. Updated when downloads complete or are deleted.
    @Published var downloads: [DownloadedSong] = []
    
    /// Currently downloading songs (video ID → progress 0.0-1.0)
    @Published var downloading: [String: Double] = [:]
    
    // MARK: - Private Properties
    
    /// The app's Documents directory (persists between launches)
    private let documentsPath: URL
    
    /// The Downloads subdirectory where audio files are stored
    private let downloadsPath: URL
    
    /// The JSON file that stores the download index
    private let indexFilePath: URL
    
    /// URL session for downloads
    private let session: URLSession
    
    // MARK: - Initialization
    
    init() {
        // Get the app's Documents directory
        // FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        // returns the Documents directory for the current user.
        // [0] because there's typically only one match.
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.documentsPath = documents
        self.downloadsPath = documents.appendingPathComponent("Downloads")
        self.indexFilePath = documents.appendingPathComponent("downloads.json")
        self.session = URLSession.shared
        
        // Create the Downloads directory if it doesn't exist
        try? FileManager.default.createDirectory(at: downloadsPath, withIntermediateDirectories: true)
        
        // Load the download index from disk
        loadIndex()
    }
    
    // MARK: - Public Methods
    
    /// Check if a song is already downloaded.
    ///
    /// - Parameter videoId: YouTube video ID
    /// - Returns: true if the audio file exists locally
    func isDownloaded(_ videoId: String) -> Bool {
        return downloads.contains { $0.videoId == videoId }
    }
    
    /// Check if a song is currently being downloaded.
    func isDownloading(_ videoId: String) -> Bool {
        return downloading[videoId] != nil
    }
    
    /// Get the local file URL for a downloaded song.
    ///
    /// - Parameter videoId: YouTube video ID
    /// - Returns: File URL if downloaded, nil otherwise
    func localURL(for videoId: String) -> URL? {
        guard let song = downloads.first(where: { $0.videoId == videoId }) else {
            return nil
        }
        let fileURL = downloadsPath.appendingPathComponent(song.fileName)
        // Verify the file actually exists (it might have been deleted externally)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return fileURL
    }
    
    /// Download a song's audio file for offline playback.
    ///
    /// FLOW:
    /// 1. Check if already downloaded (skip if so)
    /// 2. Create a temporary file path
    /// 3. Start the download task
    /// 4. On completion, move the file to the Downloads directory
    /// 5. Add the song to the download index
    ///
    /// - Parameters:
    ///   - videoId: YouTube video ID (used as unique identifier)
    ///   - title: Song title (for display)
    ///   - artist: Artist name (for display)
    ///   - audioUrl: Direct URL to the audio stream
    ///   - thumbnailUrl: URL to album art (for display in downloads list)
    func download(
        videoId: String,
        title: String,
        artist: String,
        audioUrl: String,
        thumbnailUrl: String
    ) async {
        // Don't download if already downloaded or currently downloading
        guard !isDownloaded(videoId), !isDownloading(videoId) else { return }
        
        // Create a unique filename using the video ID
        // We add .m4a extension because YouTube streams are typically AAC audio in MP4 container
        let fileName = "\(videoId).m4a"
        let fileURL = downloadsPath.appendingPathComponent(fileName)
        
        // Start with 0% progress
        downloading[videoId] = 0.0
        
        do {
            // Create the download task
            guard let url = URL(string: audioUrl) else {
                downloading.removeValue(forKey: videoId)
                return
            }
            
            let (tempURL, response) = try await session.download(from: url)
            
            // Check for HTTP errors
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                downloading.removeValue(forKey: videoId)
                return
            }
            
            // Move the downloaded file to our Downloads directory
            // FileManager.default.moveItem replaces the destination if it exists
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: fileURL)
            
            // Create the download record
            let song = DownloadedSong(
                videoId: videoId,
                title: title,
                artist: artist,
                thumbnailUrl: thumbnailUrl,
                fileName: fileName,
                downloadDate: Date()
            )
            
            // Add to our list and save the index
            downloads.append(song)
            saveIndex()
            
            // Remove from downloading list
            downloading.removeValue(forKey: videoId)
            
        } catch {
            print("Download failed: \(error)")
            downloading.removeValue(forKey: videoId)
        }
    }
    
    /// Delete a downloaded song.
    ///
    /// Removes the audio file from disk and the entry from the index.
    func delete(videoId: String) {
        guard let index = downloads.firstIndex(where: { $0.videoId == videoId }) else { return }
        
        let song = downloads[index]
        let fileURL = downloadsPath.appendingPathComponent(song.fileName)
        
        // Delete the file from disk
        try? FileManager.default.removeItem(at: fileURL)
        
        // Remove from our list and save
        downloads.remove(at: index)
        saveIndex()
    }
    
    /// Delete all downloaded songs.
    func deleteAll() {
        // Delete all files in the Downloads directory
        try? FileManager.default.removeItem(at: downloadsPath)
        try? FileManager.default.createDirectory(at: downloadsPath, withIntermediateDirectories: true)
        
        // Clear the list and save
        downloads = []
        saveIndex()
    }
    
    /// Get total storage used by downloads (in bytes).
    func totalStorageUsed() -> Int64 {
        var total: Int64 = 0
        for song in downloads {
            let fileURL = downloadsPath.appendingPathComponent(song.fileName)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }
    
    // MARK: - Private Methods
    
    /// Save the download index to disk.
    ///
    /// We store a JSON array of DownloadedSong objects in Documents/downloads.json.
    /// This lets us quickly load the list of downloads on app launch
    /// without scanning the entire file system.
    private func saveIndex() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(downloads)
            try data.write(to: indexFilePath)
        } catch {
            print("Failed to save download index: \(error)")
        }
    }
    
    /// Load the download index from disk.
    ///
    /// Called on init to populate the downloads array.
    /// Also verifies that each file actually exists (in case files were deleted externally).
    private func loadIndex() {
        guard FileManager.default.fileExists(atPath: indexFilePath.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: indexFilePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            downloads = try decoder.decode([DownloadedSong].self, from: data)
            
            // Verify files exist — remove any entries whose files are missing
            downloads = downloads.filter { song in
                let fileURL = downloadsPath.appendingPathComponent(song.fileName)
                return FileManager.default.fileExists(atPath: fileURL.path)
            }
        } catch {
            print("Failed to load download index: \(error)")
            downloads = []
        }
    }
}

// MARK: - Downloaded Song Model

/// A song that has been downloaded for offline playback.
///
/// Stored in the download index JSON file. Contains metadata for display
/// in the downloads list, plus the filename for locating the audio file.
struct DownloadedSong: Codable, Identifiable {
    /// YouTube video ID (unique identifier)
    let videoId: String
    
    /// Song title (for display in the downloads list)
    let title: String
    
    /// Artist name (for display)
    let artist: String
    
    /// URL to the album art thumbnail (for display)
    let thumbnailUrl: String
    
    /// Filename in the Downloads directory (e.g. "dQw4w9WgXcQ.m4a")
    let fileName: String
    
    /// When the song was downloaded
    let downloadDate: Date
    
    /// Identifiable conformance — use videoId as the unique ID
    var id: String { videoId }
}
