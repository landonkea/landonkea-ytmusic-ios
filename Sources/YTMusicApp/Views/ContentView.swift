import SwiftUI

// MARK: - Main Content View

/// The root view of the app — contains the tab bar and the mini player.
///
/// HOW IT WORKS:
/// - TabView at the bottom provides 4 tabs: Home, Search, Library, Settings
/// - MiniPlayer overlays at the very bottom when a song is playing
/// - Tapping the mini player opens the full-screen PlayerView
/// - ZStack layers the mini player ON TOP of the TabView
struct ContentView: View {
    
    /// The audio player — shared across all views via the environment.
    /// @EnvironmentObject means this was created by the App and injected.
    /// Any view in the hierarchy can access it without explicit passing.
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    /// The API client — also shared across all views.
    @EnvironmentObject var apiClient: APIClient
    
    /// Controls whether the full-screen player is shown.
    /// @State = owned by this view. When it changes, the view re-renders.
    @State private var showFullPlayer = false
    
    /// Controls whether the queue sheet is shown (swipe up on mini player).
    @State private var showQueue = false
    
    var body: some View {
        // ZStack = layers views on top of each other (like Photoshop layers).
        // `.alignment: .bottom` = when child views are different sizes,
        // align them to the bottom edge. This ensures the mini player
        // stays at the bottom of the screen.
        ZStack(alignment: .bottom) {
            
            // ── TAB BAR ────────────────────────────────────────────
            // TabView creates the standard iOS bottom tab bar.
            // Each child with .tabItem becomes a tab.
            TabView {
                // Home tab — shows recommended music
                HomeView()
                    .tabItem {
                        // Label combines an icon + text (standard iOS pattern)
                        Label("Home", systemImage: "house.fill")
                    }
                
                // Search tab — search for songs, artists, albums
                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                
                // Library tab — playlists and downloads
                PlaylistsView()
                    .tabItem {
                        Label("Library", systemImage: "square.stack.fill")
                    }
                
                // Settings tab — app preferences
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }
            
            // ── MINI PLAYER ────────────────────────────────────────
            // The mini player shows at the bottom when a song is playing.
            // It's in a ZStack (not inside the TabView) so it floats
            // on top of all tabs, not just one.
            //
            // `if let` checks if a song is playing. If currentSong is nil,
            // the mini player is hidden (not just empty — completely removed).
            if audioPlayer.currentSong != nil {
                MiniPlayer()
                    // .transition defines how this view appears/disappears.
                    // .move(edge: .bottom) = slides up from the bottom when appearing,
                    // slides down when disappearing.
                    .transition(.move(edge: .bottom))
                    // Tap gesture on the mini player opens the full-screen player
                    .onTapGesture {
                        showFullPlayer = true
                    }
                    // Swipe up on mini player to show queue
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                // If the user swiped UP (negative vertical translation),
                                // show the queue sheet
                                if value.translation.height < -40 {
                                    showQueue = true
                                }
                            }
                    )
            }
        }
        // .fullScreenCover = presents a view that covers the ENTIRE screen
        // (including the status bar). Unlike .sheet, it can't be swiped down
        // to dismiss — the user must tap a button.
        // We pass $showFullPlayer as a binding so PlayerView can dismiss itself.
        .fullScreenCover(isPresented: $showFullPlayer) {
            PlayerView(isShowing: $showFullPlayer)
        }
        // Queue sheet — slides up when user swipes up on mini player
        .sheet(isPresented: $showQueue) {
            QueueView()
        }
        // Apply the user's font size preference from Settings.
        // Reads @AppStorage("fontSizeScale") and adjusts DynamicTypeSize.
        .withFontScale()
    }
}

// MARK: - Mini Player

/// The small player bar that shows at the bottom when music is playing.
///
/// Shows: progress bar, thumbnail, song title, artist, and play/pause button.
/// Tapping it opens the full PlayerView (handled by the parent ContentView).
/// Swipe left to skip to next song, swipe right to go to previous song.
struct MiniPlayer: View {
    
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    /// Tracks the horizontal drag offset for swipe gestures.
    /// When the user drags, this value changes and we use it to
    /// show a visual hint (the song slides slightly with the finger).
    @State private var dragOffset: CGFloat = 0
    
    /// Threshold for triggering a skip (in points).
    /// If the user swipes more than 80 points horizontally, we skip.
    private let swipeThreshold: CGFloat = 80
    
    var body: some View {
        // Safely unwrap — if nothing is playing, show nothing
        if let song = audioPlayer.currentSong {
            VStack(spacing: 0) {
                // ── PROGRESS BAR ──────────────────────────────────
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * audioPlayer.progress, height: 3)
                }
                .frame(height: 3)
                
                // ── SONG INFO AND CONTROLS ────────────────────────
                HStack {
                    // Album art thumbnail (48x48 points)
                    AsyncImage(url: URL(string: song.thumbnailUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 48, height: 48)
                    .cornerRadius(8)
                    
                    // Song title and artist, stacked vertically
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(song.artist)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer() // Pushes play button to the right
                    
                    // Play/pause button
                    Button(action: {
                        Haptics.tap()
                        audioPlayer.togglePlayPause()
                    }) {
                        Image(systemName: audioPlayer.state == .playing ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            // Apply the drag gesture for swiping between songs
            .offset(x: dragOffset) // Visual feedback — slides with the finger
            .gesture(
                DragGesture(minimumDistance: 20) // 20pt minimum to avoid accidental swipes
                    .onChanged { value in
                        // Only allow horizontal dragging (ignore vertical movement)
                        // The translation.width shows how far the finger has moved horizontally
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        // Check if the swipe was far enough to trigger a skip
                        if value.translation.width < -swipeThreshold {
                            // Swiped LEFT → next song
                            audioPlayer.playNext()
                        } else if value.translation.width > swipeThreshold {
                            // Swiped RIGHT → previous song
                            audioPlayer.playPrevious()
                        }
                        // Reset the drag offset (snap back to center)
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = 0
                        }
                    }
            )
            // White/light background for the mini player bar
            .background(Color(.systemBackground))
            // Subtle shadow below the mini player for depth
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: -2)
        }
    }
}

// MARK: - Library Placeholder

/// Placeholder view for the Library tab.
///
/// Currently shows a "coming soon" message. Will be replaced with
/// playlists, saved songs, and albums when login is implemented.
struct LibraryView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "square.stack.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                Text("Library")
                    .font(.title)
                
                Text("Playlists, albums, and saved songs will appear here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center) // Center multi-line text
            }
            .navigationTitle("Library")
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AudioPlayer())
        .environmentObject(APIClient())
}
