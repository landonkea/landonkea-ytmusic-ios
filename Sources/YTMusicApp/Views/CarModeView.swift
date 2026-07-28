// CarModeView.swift — A simplified, full-screen player interface optimized for use while driving.

import SwiftUI

/// A simplified player view with large buttons for safe driving.
///
/// HOW IT WORKS:
/// - Full-screen dark interface with minimal distractions
/// - Giant buttons that are easy to tap without looking
/// - Only essential controls: previous, play/pause, next
/// - Shows song title and artist (no album art to reduce distraction)
/// - Swipe down or tap X to exit car mode
///
/// WHY THIS EXISTS:
/// Using a phone while driving is dangerous. Car mode makes the controls
/// large enough to use with a quick glance, reducing distraction.
/// This is similar to what Apple Music and Spotify offer.
struct CarModeView: View {
    
    /// The audio player — provides playback controls and song info
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    /// Dismiss this view when the user taps the close button
    @Environment(\.dismiss) var dismiss
    
    /// The main view content — describes what appears on screen and how it's laid out
    var body: some View {
        // Full-screen black background for maximum contrast
        ZStack {
            // Set the entire background to black
            Color.black
                .ignoresSafeArea() // Extend black beyond safe areas (notch, home indicator)
            
            // Vertical stack holds all UI elements in a column
            VStack(spacing: 40) {
                // ── HEADER ─────────────────────────────────────────
                // Top row: close button, title, empty spacer (for symmetry)
                HStack {
                    // Exit car mode button
                    Button(action: {
                        dismiss() // Call the system dismiss to go back
                    }) {
                        // X mark icon
                        Image(systemName: "xmark")
                            .font(.title) // Large title font size
                            .foregroundColor(.white) // White icon on black
                            .frame(width: 50, height: 50) // Fixed size for easy tapping
                    }
                    
                    Spacer() // Push content apart
                    
                    // "Car Mode" label
                    Text("Car Mode")
                        .font(.headline) // Bold, medium-sized font
                        .foregroundColor(.white.opacity(0.6)) // Slightly transparent white
                    
                    Spacer() // Push content apart
                    
                    // Placeholder for future settings
                    Color.clear // Invisible spacer, same size as the close button
                        .frame(width: 50, height: 50) // Keeps layout balanced
                }
                .padding(.horizontal) // Add padding on left and right edges
                
                Spacer() // Push everything toward the vertical center
                
                // ── SONG INFO ──────────────────────────────────────
                // Large text, easy to read at a glance
                if let song = audioPlayer.currentSong { // Only show if a song is loaded
                    VStack(spacing: 12) {
                        // Song title — large and bold
                        Text(song.title)
                            .font(.title) // Large font
                            .fontWeight(.bold) // Bold weight
                            .foregroundColor(.white) // White text
                            .lineLimit(2) // Wrap at most 2 lines
                            .multilineTextAlignment(.center) // Center-align text
                        
                        // Artist name — slightly smaller, less prominent
                        Text(song.artist)
                            .font(.title3) // Medium-large font
                            .foregroundColor(.white.opacity(0.7)) // Slightly transparent
                            .lineLimit(1) // Single line only (truncate with ...)
                    }
                    .padding(.horizontal, 32) // Side padding so text doesn't touch edges
                }
                
                Spacer() // Push everything toward the vertical center
                
                // ── PROGRESS BAR ───────────────────────────────────
                // Simple progress indicator (no time labels — keeps it minimal)
                VStack(spacing: 8) {
                    GeometryReader { geometry in // Reads available width for drawing
                        ZStack(alignment: .leading) { // Align fill bar to the left
                            // Background track (gray)
                            RoundedRectangle(cornerRadius: 4) // Rounded rectangle shape
                                .fill(Color.white.opacity(0.2)) // Faded white fill
                                .frame(height: 8) // 8 points tall
                            
                            // Filled portion (white)
                            RoundedRectangle(cornerRadius: 4) // Rounded rectangle shape
                                .fill(Color.white) // Solid white fill
                                .frame(
                                    // Width = total width × progress (0.0 to 1.0)
                                    width: geometry.size.width * audioPlayer.progress,
                                    height: 8 // Match background height
                                )
                        }
                    }
                    .frame(height: 8) // Constrain GeometryReader to match bar height
                    
                    // Time labels — larger font for readability
                    HStack {
                        // Current playback time (elapsed)
                        Text(formatTime(audioPlayer.currentTime))
                            .font(.body) // Standard body font
                            .foregroundColor(.white.opacity(0.6)) // Semi-transparent white
                        
                        Spacer() // Push times to opposite sides
                        
                        // Total song duration
                        Text(formatTime(audioPlayer.duration))
                            .font(.body) // Standard body font
                            .foregroundColor(.white.opacity(0.6)) // Semi-transparent white
                    }
                }
                .padding(.horizontal, 40) // Side padding for progress bar
                
                // ── PLAYBACK CONTROLS ──────────────────────────────
                // Giant buttons — 80pt minimum tap target for safe driving
                HStack(spacing: 60) {
                    // Previous button (large)
                    Button(action: {
                        audioPlayer.playPrevious() // Skip to previous track
                    }) {
                        Image(systemName: "backward.fill") // Skip back icon
                            .font(.system(size: 50)) // Very large icon
                            .foregroundColor(.white) // White icon
                    }
                    .frame(width: 80, height: 80) // Large tap target
                    
                    // Play/pause button (extra large — the most important button)
                    Button(action: {
                        audioPlayer.togglePlayPause() // Play if paused, pause if playing
                    }) {
                        // Dynamic icon: show pause when playing, play when not
                        Image(systemName: audioPlayer.state == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 70)) // Extra-large icon
                            .foregroundColor(.white) // White icon
                    }
                    .frame(width: 100, height: 100) // Largest tap target in the UI
                    
                    // Next button (large)
                    Button(action: {
                        audioPlayer.playNext() // Skip to next track
                    }) {
                        Image(systemName: "forward.fill") // Skip forward icon
                            .font(.system(size: 50)) // Very large icon
                            .foregroundColor(.white) // White icon
                    }
                    .frame(width: 80, height: 80) // Large tap target
                }
                
                Spacer() // Push everything toward the vertical center
                
                // ── SHUFFLE + REPEAT (smaller, less important) ──────
                HStack(spacing: 60) {
                    // Shuffle toggle button
                    Button(action: {
                        audioPlayer.toggleShuffle() // Toggle shuffle mode on/off
                    }) {
                        Image(systemName: "shuffle") // Shuffle icon
                            .font(.title2) // Medium size — less prominent than transport
                            // Bright when on, faded when off
                            .foregroundColor(audioPlayer.isShuffled ? .white : .white.opacity(0.4))
                    }
                    
                    // Repeat mode toggle button
                    Button(action: {
                        audioPlayer.toggleRepeat() // Cycle repeat modes: off → all → one
                    }) {
                        // Show "repeat.1" when repeating a single track
                        Image(systemName: audioPlayer.repeatMode == .one ? "repeat.1" : "repeat")
                            .font(.title2) // Medium size
                            // Bright when active, faded when off
                            .foregroundColor(audioPlayer.repeatMode != .none ? .white : .white.opacity(0.4))
                    }
                }
                .padding(.bottom, 40) // Space between controls and bottom edge
            }
        }
        // Hide the status bar for a cleaner, more immersive look
        .statusBarHidden(true)
    }
    
    // MARK: - Helpers
    
    /// Format seconds into MM:SS string.
    /// Same logic as PlayerView's formatTime — could be extracted to a shared utility.
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else {
            return "0:00" // Safe fallback for invalid time values
        }
        let mins = Int(seconds) / 60 // Calculate whole minutes
        let secs = Int(seconds) % 60 // Calculate remaining seconds
        return String(format: "%d:%02d", mins, secs) // Format as "M:SS" with leading zero on seconds
    }
}

#Preview {
    CarModeView()
        .environmentObject(AudioPlayer()) // Provide a mock AudioPlayer for preview rendering
}
