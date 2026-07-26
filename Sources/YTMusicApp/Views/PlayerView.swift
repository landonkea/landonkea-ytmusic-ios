import SwiftUI

/// The full-screen music player that shows when you tap the mini player
struct PlayerView: View {
    
    @EnvironmentObject var audioPlayer: AudioPlayer
    @Environment(\.dismiss) var dismiss
    
    /// Whether to show this view
    @Binding var isShowing: Bool
    
    var body: some View {
        if let song = audioPlayer.currentSong {
            ZStack {
                // Background gradient based on album art
                LinearGradient(
                    colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header with close button
                    HStack {
                        Button(action: {
                            isShowing = false
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Text("Now Playing")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        // Placeholder for menu
                        Button(action: {}) {
                            Image(systemName: "ellipsis")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Album art
                    AsyncImage(url: URL(string: song.thumbnailUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    }
                    .frame(width: 300, height: 300)
                    .cornerRadius(16)
                    .shadow(radius: 10)
                    
                    // Song info
                    VStack(spacing: 8) {
                        Text(song.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(song.artist)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    
                    // Progress bar
                    VStack(spacing: 4) {
                        Slider(
                            value: Binding(
                                get: { audioPlayer.progress },
                                set: { newValue in
                                    audioPlayer.seek(to: newValue)
                                }
                            )
                        ) { editing in
                            // Slider is being dragged
                        }
                        .tint(.white)
                        
                        HStack {
                            Text(formatTime(audioPlayer.currentTime))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text(formatTime(audioPlayer.duration))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal)
                    
                    // Playback controls
                    HStack(spacing: 40) {
                        // Shuffle button
                        Button(action: {
                            audioPlayer.isShuffled.toggle()
                        }) {
                            Image(systemName: "shuffle")
                                .font(.title3)
                                .foregroundColor(audioPlayer.isShuffled ? .white : .white.opacity(0.5))
                        }
                        
                        // Previous button
                        Button(action: {
                            audioPlayer.playPrevious()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        
                        // Play/pause button
                        Button(action: {
                            audioPlayer.togglePlayPause()
                        }) {
                            Image(systemName: audioPlayer.state == .playing ? "pause.fill" : "play.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        }
                        
                        // Next button
                        Button(action: {
                            audioPlayer.playNext()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        
                        // Repeat button
                        Button(action: {
                            // Cycle through repeat modes
                            switch audioPlayer.repeatMode {
                            case .none:
                                audioPlayer.repeatMode = .all
                            case .all:
                                audioPlayer.repeatMode = .one
                            case .one:
                                audioPlayer.repeatMode = .none
                            }
                        }) {
                            Image(systemName: audioPlayer.repeatMode == .one ? "repeat.1" : "repeat")
                                .font(.title3)
                                .foregroundColor(audioPlayer.repeatMode != .none ? .white : .white.opacity(0.5))
                        }
                    }
                    
                    Spacer()
                    
                    // AirPlay and other controls
                    HStack(spacing: 60) {
                        Button(action: {}) {
                            Image(systemName: "airplayaudio")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "list.bullet")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .padding()
            }
            .transition(.move(edge: .bottom))
        }
    }
    
    /// Format seconds into MM:SS string
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else {
            return "0:00"
        }
        
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    PlayerView(isShowing: .constant(true))
        .environmentObject(AudioPlayer())
}
