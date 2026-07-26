import AVFoundation
import Combine
import SwiftUI

/// Manages audio playback using AVFoundation
/// Handles playing songs, background audio, and playback controls
@MainActor
class AudioPlayer: ObservableObject {
    
    // MARK: - Published Properties
    
    /// What's currently playing (nil if nothing)
    @Published var currentSong: NowPlaying?
    
    /// Current playback state
    @Published var state: PlayerState = .stopped
    
    /// Current playback position in seconds
    @Published var currentTime: Double = 0
    
    /// Total duration of current song in seconds
    @Published var duration: Double = 0
    
    /// Current playback progress as a fraction (0.0 to 1.0)
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    /// Whether shuffle is enabled
    @Published var isShuffled: Bool = false
    
    /// Current repeat mode
    @Published var repeatMode: RepeatMode = .none
    
    // MARK: - Private Properties
    
    /// The AVAudioPlayer that does the actual playback
    private var player: AVPlayer?
    
    /// Time observer token for tracking playback position
    private var timeObserverToken: Any?
    
    /// Queue of songs to play
    private var queue: [NowPlaying] = []
    
    /// Current index in the queue
    private var currentIndex: Int = -1
    
    // MARK: - Types
    
    enum RepeatMode {
        case none       // Stop after current song
        case all        // Repeat the entire queue
        case one        // Repeat current song
    }
    
    // MARK: - Initialization
    
    init() {
        setupAudioSession()
    }
    
    // MARK: - Public Methods
    
    /// Play a song by its video ID
    /// - Parameters:
    ///   - videoId: The YouTube video ID
    ///   - title: The song title
    ///   - artist: The artist name
    ///   - thumbnailUrl: URL to the album art
    ///   - audioUrl: The direct URL to the audio stream
    ///   - duration: Total duration in seconds
    func play(
        videoId: String,
        title: String,
        artist: String,
        thumbnailUrl: String,
        audioUrl: String,
        duration: Int
    ) async {
        // Create the now playing info
        let song = NowPlaying(
            id: videoId,
            title: title,
            artist: artist,
            thumbnailUrl: thumbnailUrl,
            duration: duration,
            audioUrl: audioUrl
        )
        
        // Stop any current playback
        stop()
        
        // Set up the new player
        guard let url = URL(string: audioUrl) else {
            print("Invalid audio URL")
            return
        }
        
        // Create player item
        let playerItem = AVPlayerItem(url: url)
        
        // Create the player
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.allowsExternalPlayback = true  // Allow AirPlay
        
        // Add time observer to track playback position
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = newPlayer.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
            }
        }
        
        // Update state
        self.player = newPlayer
        self.currentSong = song
        self.state = .loading
        self.duration = Double(duration)
        self.currentTime = 0
        
        // Start playback
        newPlayer.play()
        self.state = .playing
        
        // Update Now Playing info for Control Center
        updateNowPlayingInfo()
    }
    
    /// Toggle between play and pause
    func togglePlayPause() {
        guard let player = player else { return }
        
        if state == .playing {
            player.pause()
            state = .paused
        } else if state == .paused {
            player.play()
            state = .playing
        }
    }
    
    /// Stop playback completely
    func stop() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        player?.pause()
        player = nil
        state = .stopped
        currentSong = nil
        currentTime = 0
        duration = 0
    }
    
    /// Seek to a specific position
    /// - Parameter progress: Position as a fraction (0.0 to 1.0)
    func seek(to progress: Double) {
        guard let player = player else { return }
        
        let targetTime = CMTime(seconds: duration * progress, preferredTimescale: 600)
        player.seek(to: targetTime)
        currentTime = duration * progress
    }
    
    /// Skip forward 15 seconds
    func skipForward() {
        guard let player = player else { return }
        
        let newTime = min(currentTime + 15, duration)
        let targetTime = CMTime(seconds: newTime, preferredTimescale: 600)
        player.seek(to: targetTime)
        currentTime = newTime
    }
    
    /// Skip backward 15 seconds
    func skipBackward() {
        guard let player = player else { return }
        
        let newTime = max(currentTime - 15, 0)
        let targetTime = CMTime(seconds: newTime, preferredTimescale: 600)
        player.seek(to: targetTime)
        currentTime = newTime
    }
    
    /// Play the next song in the queue
    func playNext() {
        guard currentIndex < queue.count - 1 else {
            // No more songs
            if repeatMode == .all {
                // Loop back to start
                currentIndex = 0
                let song = queue[currentIndex]
                Task {
                    await play(
                        videoId: song.id,
                        title: song.title,
                        artist: song.artist,
                        thumbnailUrl: song.thumbnailUrl,
                        audioUrl: song.audioUrl,
                        duration: song.duration
                    )
                }
            } else {
                stop()
            }
            return
        }
        
        currentIndex += 1
        let song = queue[currentIndex]
        Task {
            await play(
                videoId: song.id,
                title: song.title,
                artist: song.artist,
                thumbnailUrl: song.thumbnailUrl,
                audioUrl: song.audioUrl,
                duration: song.duration
            )
        }
    }
    
    /// Play the previous song in the queue
    func playPrevious() {
        // If more than 3 seconds into song, restart it
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        
        guard currentIndex > 0 else {
            // At the beginning, restart current song
            seek(to: 0)
            return
        }
        
        currentIndex -= 1
        let song = queue[currentIndex]
        Task {
            await play(
                videoId: song.id,
                title: song.title,
                artist: song.artist,
                thumbnailUrl: song.thumbnailUrl,
                audioUrl: song.audioUrl,
                duration: song.duration
            )
        }
    }
    
    /// Add a song to the queue and play it
    func addToQueueAndPlay(_ song: NowPlaying) {
        queue.append(song)
        currentIndex = queue.count - 1
        Task {
            await play(
                videoId: song.id,
                title: song.title,
                artist: song.artist,
                thumbnailUrl: song.thumbnailUrl,
                audioUrl: song.audioUrl,
                duration: song.duration
            )
        }
    }
    
    /// Add a song to the end of the queue
    func addToQueue(_ song: NowPlaying) {
        queue.append(song)
    }
    
    /// Clear the queue
    func clearQueue() {
        queue.removeAll()
        currentIndex = -1
    }
    
    // MARK: - Private Methods
    
    /// Set up the audio session for background playback
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,                    // Play audio even in silent mode
                mode: .default,
                options: [.mixWithOthers]     // Allow mixing with other audio
            )
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    /// Update the Now Playing info shown in Control Center
    private func updateNowPlayingInfo() {
        guard let song = currentSong else { return }
        
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = song.title
        info[MPMediaItemPropertyArtist] = song.artist
        info[MPMediaItemPropertyPlaybackDuration] = song.duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = state == .playing ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

import MediaPlayer
