import SwiftUI

/// The full-screen music player that shows when you tap the mini player.
///
/// HOW IT WORKS:
/// - Presented as a full-screen cover (slides up from bottom, covers entire screen)
/// - Shows album art, song info, progress bar, and playback controls
/// - Uses bindings and environment objects to stay in sync with AudioPlayer
/// - Control Center / lock screen controls are handled by AudioPlayer, not here
struct PlayerView: View {
    
    /// Grab the audio player from the environment. This is the source of truth
    /// for what's playing, playback state, progress, queue, shuffle, and repeat.
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    /// `dismiss` lets us close this full-screen cover programmatically.
    /// We get this from the SwiftUI environment — it's provided by `.fullScreenCover`.
    @Environment(\.dismiss) var dismiss
    
    /// Two-way binding to the parent's `showFullPlayer` state.
    /// When we set `isShowing = false`, the parent hides this view.
    /// The parent controls whether this view is shown; we just ask to be dismissed.
    @Binding var isShowing: Bool
    
    /// Whether to show the lyrics overlay on top of the album art.
    /// Toggled by the lyrics button in the bottom controls.
    @State private var showLyrics = false
    
    /// Whether car mode is active (big buttons, simplified UI for driving)
    @State private var showCarMode = false
    
    /// Whether the sleep timer modal is showing
    @State private var showSleepTimer = false
    
    /// Whether the equalizer modal is showing
    @State private var showEqualizer = false
    
    /// Whether the player is in light mode (overrides global setting)
    @State private var isLightMode = false
    
    /// Whether the queue sheet is showing
    @State private var showQueue = false
    
    /// Whether the related songs section is showing
    @State private var showRelated = false
    
    /// Whether the playback speed picker is showing
    @State private var showSpeedPicker = false
    
    /// Whether we are in a regular (iPad landscape) or compact (iPhone) horizontal size class
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    /// The offline manager for downloading songs
    @EnvironmentObject var offlineManager: OfflineManager
    
    /// The equalizer manager for audio effects
    @EnvironmentObject var equalizer: EqualizerManager
    
    /// The API client — needed to re-fetch player info for download quality
    @EnvironmentObject var apiClient: APIClient
    
    var body: some View {
        // Safely unwrap the current song. If nothing is playing,
        // show nothing (the full screen cover will be empty).
        if let song = audioPlayer.currentSong {
            ZStack {
                // ── BACKGROUND: FULL-SCREEN ALBUM ART ─────────────────
                // Use the album art as a blurred background, creating a
                // dynamic, contextual color scheme. Falls back to gradient
                // while the image loads.
                AsyncImage(url: URL(string: song.thumbnailUrl)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 60, opaque: true)
                            .overlay(Color.black.opacity(0.4)) // Dark overlay for readability
                            .ignoresSafeArea()
                    } else {
                        // Fallback gradient while album art loads
                        LinearGradient(
                            colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()
                    }
                }
                
                // Main content stacked vertically with 24pt spacing between items
                VStack(spacing: 24) {
                    
                    // ── HEADER BAR ──────────────────────────────────
                    HStack {
                        // Close button — chevron down icon
                        Button(action: {
                            // Setting isShowing to false tells the parent
                            // (ContentView) to hide this full-screen cover
                            isShowing = false
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        
                        Spacer() // Pushes center text to the middle
                        
                        Text("Now Playing")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer() // Pushes right button to the edge
                        
                        // Share button — shares the song link via iOS share sheet
                        // ShareLink is SwiftUI's built-in way to share content.
                        // It presents the standard iOS share sheet (AirDrop, Messages, etc.)
                        ShareLink(
                            item: URL(string: "https://music.youtube.com/watch?v=\(song.id)")!,
                            preview: SharePreview(
                                song.title,
                                image: AsyncImage(url: URL(string: song.thumbnailUrl)) { image in
                                    image.resizable()
                                } placeholder: {
                                    Color.gray
                                }
                            )
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        
                        // Dark/light mode toggle — switches the player's color scheme
                        Button(action: {
                            withAnimation {
                                isLightMode.toggle()
                            }
                        }) {
                            Image(systemName: isLightMode ? "moon.fill" : "sun.max.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        .accessibilityLabel(isLightMode ? "Switch to dark mode" : "Switch to light mode")
                    }
                    .padding(.horizontal)
                    
                    Spacer() // Pushes album art to center vertically
                    
                    // ── ALBUM ART ───────────────────────────────────
                    // AsyncImage loads the thumbnail URL asynchronously.
                    // While loading, it shows a gray rectangle with a music note icon.
                    // .aspectRatio(contentMode: .fit) = scale to fit within frame
                    // (vs .fill which would crop to fill the frame)
                    ZStack {
                        AsyncImage(url: URL(string: song.thumbnailUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            // Placeholder shown while the image loads
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
                        .shadow(radius: 10) // Drop shadow for depth
                        
                        // Lyrics overlay — shown on top of album art when toggled
                        if showLyrics {
                            LyricsView()
                                .frame(width: 300, height: 300)
                                .cornerRadius(16)
                                .transition(.opacity) // Fade in/out
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: showLyrics)
                    
                    // ── SONG INFO ───────────────────────────────────
                    VStack(spacing: 8) {
                        Text(song.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1) // One line, truncate with "..." if too long
                        
                        Text(song.artist)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    
                    // ── PROGRESS BAR (SLIDER) ───────────────────────
                    VStack(spacing: 4) {
                        // The Slider's value must be a Binding — a two-way connection
                        // between the UI and our data. We create a custom Binding:
                        //
                        //   get: read audioPlayer.progress (0.0 to 1.0)
                        //   set: when user drags, call audioPlayer.seek(to: newValue)
                        //
                        // The `{ editing in }` trailing closure is called when the
                        // user starts (editing=true) or stops (editing=false) dragging.
                        // We don't use it here, but it could be used to pause updates
                        // while the user is scrubbing (to prevent the slider from jumping).
                        Slider(
                            value: Binding(
                                get: { audioPlayer.progress },
                                set: { newValue in
                                    audioPlayer.seek(to: newValue)
                                }
                            )
                        ) { editing in
                            // Called when user starts/stops dragging the slider
                            // Currently unused — could pause periodic updates here
                        }
                        .tint(.white) // Color of the filled portion
                        .accessibilityLabel("Song progress")
                        
                        // Time labels: current position on left, total duration on right
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
                    
                    // ── VOLUME CONTROL ──────────────────────────────
                    // Volume slider between the progress bar and playback controls.
                    // Shows a speaker icon on each end and a draggable slider.
                    HStack(spacing: 12) {
                        // Speaker icon (muted/low volume)
                        Image(systemName: "speaker.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        
                        // Volume slider — same pattern as the progress slider
                        Slider(
                            value: Binding(
                                get: { audioPlayer.volume },
                                set: { newValue in
                                    audioPlayer.setVolume(newValue)
                                }
                            )
                        ) { editing in
                            // Could pause volume updates while dragging if needed
                        }
                        .tint(.white)
                        
                        // Speaker icon (high volume)
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal)
                    
                    // ── PLAYBACK CONTROLS ───────────────────────────
                    HStack(spacing: 40) {
                        // Shuffle button
                        // IMPORTANT: We call toggleShuffle() which handles saving
                        // the queue order, shuffling, and moving current song to front.
                        Button(action: {
                            Haptics.tap() // Vibrate on shuffle toggle
                            audioPlayer.toggleShuffle()
                        }) {
                            Image(systemName: "shuffle")
                                .font(.title3)
                                // Bright white when shuffle is on, dim when off
                                .foregroundColor(audioPlayer.isShuffled ? .white : .white.opacity(0.5))
                        }
                        .accessibilityLabel(audioPlayer.isShuffled ? "Turn off shuffle" : "Turn on shuffle")
                        
                        // Previous track button
                        Button(action: {
                            Haptics.tap()
                            audioPlayer.playPrevious()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        .accessibilityLabel("Previous track")
                        
                        // Play/pause button (the big center button)
                        // Shows pause icon when playing, play icon when paused/stopped
                        Button(action: {
                            Haptics.tap()
                            audioPlayer.togglePlayPause()
                        }) {
                            Image(systemName: audioPlayer.state == .playing ? "pause.fill" : "play.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        }
                        .accessibilityLabel(audioPlayer.state == .playing ? "Pause" : "Play")
                        
                        // Next track button
                        Button(action: {
                            Haptics.tap()
                            audioPlayer.playNext()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        .accessibilityLabel("Next track")
                        
                        // Repeat button
                        // IMPORTANT: We call toggleRepeat() which cycles through
                        // none → all → one → none. Previously this duplicated the
                        // cycling logic here, which is a maintenance risk if the
                        // AudioPlayer's logic ever changes.
                        Button(action: {
                            Haptics.tap()
                            audioPlayer.toggleRepeat()
                        }) {
                            // Show "repeat.1" icon when repeating one song,
                            // regular "repeat" icon otherwise
                            Image(systemName: audioPlayer.repeatMode == .one ? "repeat.1" : "repeat")
                                .font(.title3)
                                // Bright when repeat is on (all or one), dim when off
                                .foregroundColor(audioPlayer.repeatMode != .none ? .white : .white.opacity(0.5))
                        }
                        .accessibilityLabel({
                            switch audioPlayer.repeatMode {
                            case .none: return "Turn on repeat"
                            case .all: return "Turn on repeat one"
                            case .one: return "Turn off repeat"
                            }
                        }())
                    }
                    
                    Spacer() // Pushes bottom controls down
                    
                    // ── BOTTOM CONTROLS (AirPlay + Lyrics + Download + Car + Queue) ──
                    HStack(spacing: 28) {
                        // AirPlay button — currently a placeholder
                        Button(action: {}) {
                            Image(systemName: "airplayaudio")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        .accessibilityLabel("AirPlay")
                        
                        // Lyrics button — toggles lyrics overlay
                        Button(action: {
                            showLyrics.toggle()
                        }) {
                            Image(systemName: "text.alignleft")
                                .font(.title3)
                                .foregroundColor(showLyrics ? .white : .white.opacity(0.5))
                        }
                        .accessibilityLabel(showLyrics ? "Hide lyrics" : "Show lyrics")
                        
                        // Download button — saves song for offline playback
                        Button(action: {
                            downloadCurrentSong()
                        }) {
                            if offlineManager.isDownloading(song.id) {
                                ProgressView()
                        .tint(.white)
                        .accessibilityLabel("Volume")
                            } else if offlineManager.isDownloaded(song.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "arrow.down.circle")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .disabled(offlineManager.isDownloaded(song.id) || offlineManager.isDownloading(song.id))
                        .accessibilityLabel({
                            if offlineManager.isDownloading(song.id) { return "Downloading" }
                            if offlineManager.isDownloaded(song.id) { return "Downloaded" }
                            return "Download song"
                        }())
                        
                        // Car mode button — switches to large-button UI for safe driving
                        Button(action: {
                            showCarMode = true
                        }) {
                            Image(systemName: "car.fill")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .accessibilityLabel("Car mode")
                        
                        // Sleep timer button — shows timer modal for bedtime listening
                        Button(action: {
                            showSleepTimer = true
                        }) {
                            Image(systemName: audioPlayer.isSleepTimerActive ? "moon.fill" : "moon")
                                .font(.title3)
                                // Purple when timer is active, dim when off
                                .foregroundColor(audioPlayer.isSleepTimerActive ? .purple : .white.opacity(0.5))
                        }
                        .accessibilityLabel(audioPlayer.isSleepTimerActive ? "Sleep timer active" : "Sleep timer")
                        
                        // Equalizer button — opens equalizer for audio adjustments
                        Button(action: {
                            showEqualizer = true
                        }) {
                            Image(systemName: equalizer.isEnabled ? "slider.horizontal.3" : "slider.horizontal.3")
                                .font(.title3)
                                // Orange when equalizer is active, dim when off
                                .foregroundColor(equalizer.isEnabled ? .orange : .white.opacity(0.5))
                        }
                        .accessibilityLabel("Equalizer")
                        
                        // Related songs button — toggles related songs section
                        Button(action: {
                            showRelated.toggle()
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.title3)
                                .foregroundColor(showRelated ? .purple : .white.opacity(0.5))
                        }
                        .accessibilityLabel("Related songs")
                        
                        // Queue button — shows the queue sheet
                        Button(action: {
                            showQueue = true
                        }) {
                            Image(systemName: "list.bullet")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        .accessibilityLabel("Queue")
                        
                        // Playback speed button — opens speed picker
                        Button(action: {
                            showSpeedPicker = true
                        }) {
                            let isCustom = abs(audioPlayer.playbackRate - 1.0) > 0.01
                            Text("\(audioPlayer.playbackRate, specifier: "%.1f")×")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(isCustom ? .yellow : .white.opacity(0.5))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().stroke(isCustom ? Color.yellow : Color.white.opacity(0.3), lineWidth: 1))
                        }
                        .accessibilityLabel("Playback speed: \(audioPlayer.playbackRate, specifier: "%.1f")×")
                    }
                    .padding(.bottom, 20)
                }
                .padding()
            }
            // Transition animation when this view appears/disappears
            // .move(edge: .bottom) = slides up from the bottom edge
            .transition(.move(edge: .bottom))
            // Related songs sheet — shows recommended songs
            .sheet(isPresented: $showRelated) {
                NavigationView {
                    ScrollView {
                        RelatedSongsView(videoId: song.id)
                            .padding()
                    }
                    .navigationTitle("Related Songs")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showRelated = false
                            }
                        }
                    }
                }
                .environmentObject(apiClient)
                .environmentObject(audioPlayer)
            }
            // Car mode sheet — large buttons for safe driving
            .sheet(isPresented: $showCarMode) {
                CarModeView()
                    .environmentObject(audioPlayer)
            }
            // Sleep timer sheet — set a countdown to stop playback
            .sheet(isPresented: $showSleepTimer) {
                SleepTimerView()
                    .environmentObject(audioPlayer)
            }
            // Equalizer sheet — adjust audio frequencies
            .sheet(isPresented: $showEqualizer) {
                EqualizerView()
                    .environmentObject(equalizer)
            }
            // Queue sheet — view and manage the playback queue
            .sheet(isPresented: $showQueue) {
                QueueView()
            }
            // Playback speed picker — choose from 0.25× to 2.0×
            .sheet(isPresented: $showSpeedPicker) {
                speedPickerSheet
            }
            // Swipe down gesture to dismiss player
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.height > 80 {
                            isShowing = false
                        }
                    }
            )
            // Override the color scheme for this view only
            // isLightMode toggles between light and dark regardless of global setting
            .preferredColorScheme(isLightMode ? .light : .dark)
        }
    }
    
    // MARK: - Speed Picker Sheet
    
    /// Sheet that lets the user choose a playback speed.
    private var speedPickerSheet: some View {
        NavigationView {
            List {
                Section("Playback Speed") {
                    ForEach(PlaybackRate.allCases, id: \.rawValue) { rate in
                        Button {
                            audioPlayer.setPlaybackRate(rate.rawValue)
                            showSpeedPicker = false
                        } label: {
                            HStack {
                                Text(rate.label)
                                    .foregroundColor(.primary)
                                Spacer()
                                if abs(audioPlayer.playbackRate - rate.rawValue) < 0.01 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Speed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showSpeedPicker = false }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Download the current song for offline playback.
    ///
    /// Re-fetches the player info with the download quality setting to get
    /// the appropriate audio stream URL for the chosen quality level.
    private func downloadCurrentSong() {
        guard let song = audioPlayer.currentSong else { return }
        
        // Don't download if already downloaded or in progress
        guard !offlineManager.isDownloaded(song.id),
              !offlineManager.isDownloading(song.id) else { return }
        
        Task {
            // Re-fetch player info with download quality setting
            // This gets a different audio URL if the user chose lower quality
            do {
                let playerInfo = try await apiClient.getPlayerInfoForDownload(videoId: song.id)
                await offlineManager.download(
                    videoId: song.id,
                    title: song.title,
                    artist: song.artist,
                    audioUrl: playerInfo.audioUrl,
                    thumbnailUrl: song.thumbnailUrl
                )
            } catch {
                print("Failed to get download URL: \(error)")
            }
        }
    }
    
    /// Convert seconds into a human-readable time string like "3:45".
    ///
    /// HOW IT WORKS:
    /// - Divide total seconds by 60 to get minutes
    /// - Use modulo (%) to get remaining seconds
    /// - `%02d` means "2-digit number with leading zero" (e.g. "05" not "5")
    ///
    /// - Parameter seconds: Time in seconds (e.g. 225.0)
    /// - Returns: Formatted string (e.g. "3:45")
    private func formatTime(_ seconds: Double) -> String {
        // Guard against NaN (Not a Number) and Infinite values.
        // These can occur if the audio player hasn't loaded yet or
        // if there's a parsing error with the duration. Return "0:00" as fallback.
        guard !seconds.isNaN && !seconds.isInfinite else {
            return "0:00"
        }
        
        let mins = Int(seconds) / 60    // Integer division gives minutes
        let secs = Int(seconds) % 60    // Modulo gives remaining seconds
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    PlayerView(isShowing: .constant(true))
        .environmentObject(AudioPlayer())
}
