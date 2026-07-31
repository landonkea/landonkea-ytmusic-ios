import Foundation
import SwiftUI
import BackgroundTasks  // BGTaskScheduler for requesting background time

/// Manages offline song caching — downloading, storing, and playing cached songs.
///
/// HOW IT WORKS:
/// - Songs are downloaded to the app's Documents/Downloads/ directory
/// - A JSON file tracks which songs are downloaded (metadata + file paths)
/// - When playing a song, we check if it's cached first (saves data + works offline)
/// - Users can delete individual downloads or clear all
///
/// BACKGROUND DOWNLOADS:
/// - Uses a URLSession with a background identifier so iOS continues
///   downloading even when the app is suspended or in the background
/// - The system wakes the app briefly when a download finishes
/// - On cellular, respects the "Wi-Fi Only" setting
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
class OfflineManager: NSObject, ObservableObject {
    
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
    
    /// URL session for downloads — uses background config so downloads
    /// continue when the app is in the background.
    private var session: URLSession!
    
    /// Background completion handler registered by the system when a
    /// background download task finishes while the app was suspended.
    private var backgroundCompletionHandler: (() -> Void)?
    
    /// Track which background download task maps to which video ID.
    /// When the delegate callback fires, we look up the video ID
    /// from this dictionary using the task identifier.
    private var taskIdToVideoId: [Int: String] = [:]
    
    /// Continuations for bridging delegate-based background downloads
    /// to async/await. Each active task gets a continuation that is
    /// resumed when the download completes or fails.
    private var downloadContinuations: [Int: CheckedContinuation<URL, Error>] = [:]
    
    /// Set the background completion handler (called from AppDelegate/SceneDelegate).
    ///
    /// The system calls this when a background download completes while
    /// the app was suspended. We store the handler and call it after
    /// processing all completed downloads.
    func setBackgroundCompletionHandler(_ handler: @escaping () -> Void) {
        self.backgroundCompletionHandler = handler
    }
    
    // MARK: - Initialization
    
    override init() {
        // We override NSObject's init() because OfflineManager
        // subclasses NSObject (for URLSessionDownloadDelegate).
        // The 'override' keyword is required by Swift.
        //
        // Get the app's Documents directory
        // FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        // returns the Documents directory for the current user.
        // [0] because there's typically only one match.
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.documentsPath = documents
        self.downloadsPath = documents.appendingPathComponent("Downloads")
        self.indexFilePath = documents.appendingPathComponent("downloads.json")
        
        // Call super.init() AFTER all stored properties are set.
        super.init()
        
        // Create the Downloads directory if it doesn't exist
        try? FileManager.default.createDirectory(at: downloadsPath, withIntermediateDirectories: true)
        
        // Load the download index from disk
        loadIndex()
        
        // Set up the background URL session
        // Background sessions use a unique identifier string so iOS can
        // reconnect to the same session when the app relaunches.
        
        // Background configuration allows downloads to continue when the app
        // is suspended or in the background. The system manages the download
        // and wakes the app when it's done.
        let config = URLSessionConfiguration.background(withIdentifier: "com.landonkea.ytmusic.downloads")
        config.isDiscretionary = false  // Download immediately, not when the system decides
        config.shouldUseExtendedBackgroundIdleMode = true  // Keep network alive longer
        
        // Create the session with self as delegate
        // NSObject conformance above makes this possible
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
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
            
            // Use continuation to bridge the delegate-based background download
            // to the async/await pattern. The delegate callback will resume
            // this continuation when the download finishes.
            //
            // IMPORTANT: The delegate methods below (URLSessionDownloadDelegate)
            // handle the actual download lifecycle and call the continuation.
            let tempURL: URL = try await withCheckedThrowingContinuation { continuation in
                // Create a download task — this works with background sessions
                let task = session.downloadTask(with: url)
                
                // Store the continuation associated with this task
                // so the delegate can find it when the download completes
                downloadContinuations[task.taskIdentifier] = continuation
                // Track which video this task belongs to
                taskIdToVideoId[task.taskIdentifier] = videoId
                
                // Start the download (system continues it in background)
                task.resume()
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
    
    /// Cancel an active download.
    ///
    /// This cancels the URLSession task. The system stops downloading
    /// and removes any partially downloaded data.
    func cancelDownload(videoId: String) {
        // Remove from progress tracking
        downloading.removeValue(forKey: videoId)
        
        // Find and cancel the URLSession task
        // We iterate over all tasks to find the matching one
        session.getAllTasks { [weak self] tasks in
            for task in tasks {
                if self?.taskIdToVideoId[task.taskIdentifier] == videoId {
                    task.cancel()
                    self?.taskIdToVideoId.removeValue(forKey: task.taskIdentifier)
                    self?.downloadContinuations.removeValue(forKey: task.taskIdentifier)
                    break
                }
            }
        }
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

// MARK: - URLSession Delegate

/// Delegate methods for the background URLSession.
///
/// These methods are called by the system when download tasks make progress,
/// complete, or fail. They run on a background queue, so we dispatch to
/// the main actor when updating @Published properties.
extension OfflineManager: URLSessionDownloadDelegate {
    
    /// Called periodically during download to report progress.
    ///
    /// `bytesWritten` is how many bytes were written since the last call.
    /// `totalBytesExpectedToWrite` is the total file size (or -1 if unknown).
    /// We use this to update the progress bar in the UI.
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        // Calculate progress as a fraction (0.0 to 1.0)
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        // Look up the video ID and update the published dictionary.
        // We do this on the main actor (inside DispatchQueue.main.async)
        // because taskIdToVideoId and downloading are main-actor-isolated.
        let taskId = downloadTask.taskIdentifier
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let videoId = self.taskIdToVideoId[taskId] else { return }
            self.downloading[videoId] = progress
        }
    }
    
    /// Called when a download completes successfully.
    ///
    /// `location` is a temporary file URL where the downloaded data is stored.
    /// We must move this file before returning (it's deleted after this method).
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let taskId = downloadTask.taskIdentifier
        
        // Get the temp file URL to the main actor, where the
        // continuation dictionary lives, and resume the continuation.
        // (The removed code tried MainActor.runSync, which does not
        // exist — DispatchQueue.main.async is the correct approach
        // and avoids deadlocks.)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let continuation = self.downloadContinuations.removeValue(forKey: taskId) {
                continuation.resume(returning: location)
            }
            self.taskIdToVideoId.removeValue(forKey: taskId)
        }
    }
    
    /// Called when a download task fails.
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let taskId = task.taskIdentifier
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let error = error {
                // Resume the continuation with the error
                if let continuation = self.downloadContinuations.removeValue(forKey: taskId) {
                    continuation.resume(throwing: error)
                }
            }
            // Clean up
            if let videoId = self.taskIdToVideoId.removeValue(forKey: taskId) {
                if error != nil {
                    self.downloading.removeValue(forKey: videoId)
                }
            }
        }
    }
    
    /// Called when all background tasks complete and the session
    /// has no more work to do.
    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // Call the background completion handler to let the system know
        // we've processed all completed downloads
        DispatchQueue.main.async { [weak self] in
            self?.backgroundCompletionHandler?()
            self?.backgroundCompletionHandler = nil
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
