import SwiftUI

// MARK: - Home Screen

/// The home screen showing recommended music, trending songs, and playlists.
///
/// HOW IT WORKS:
/// - Loads YouTube Music's home feed when the view first appears
/// - Displays content in horizontal carousels (like the YouTube Music app)
/// - User can pull down to refresh the feed
/// - Tapping a song starts playing it immediately
struct HomeView: View {
    
    /// The API client handles loading home feed data from YouTube.
    /// @EnvironmentObject = injected by the parent (ContentView/App),
    /// shared across all views in the app.
    @EnvironmentObject var apiClient: APIClient
    
    /// The audio player handles playing songs.
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    /// The play count manager — provides most played song data.
    @EnvironmentObject var playCountManager: PlayCountManager
    
    var body: some View {
        // NavigationView adds a navigation bar with the title
        NavigationView {
            // ScrollView makes the content scrollable vertically
            ScrollView {
                // ── STATE MACHINE: Loading → Empty → Content ────────
                if apiClient.isLoading && apiClient.homeSections.isEmpty {
                    // STATE 1: Initial load — show skeleton placeholders.
                    // These look like the actual content cards but are gray
                    // rectangles with a shimmer animation.
                    LazyVStack(spacing: 24) {
                        SkeletonSection()
                        SkeletonSection()
                        SkeletonSection()
                    }
                    .padding(.vertical)
                } else if apiClient.homeSections.isEmpty {
                    // STATE 2: Loaded but nothing to show (empty home feed)
                    VStack(spacing: 20) {
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Welcome to YouTube Music")
                            .font(.title2)
                        
                        Text("Your music, ad-free")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    // STATE 3: Content loaded — show the sections
                    // LazyVStack = vertical stack that creates views lazily
                    // (only when they scroll into view, not all at once).
                    // This is important for performance with many sections.
                    LazyVStack(spacing: 24) {
                        // ── RECENTLY PLAYED SECTION ───────────────────
                        // Shows songs the user recently listened to.
                        // Only shown if there are songs in the history.
                        if !audioPlayer.recentlyPlayed.isEmpty {
                            RecentlyPlayedSection(songs: audioPlayer.recentlyPlayed)
                        }
                        
                        // ── MOST PLAYED SECTION ──────────────────────
                        // Shows the user's most frequently played songs.
                        // Cross-references play counts with the recently played
                        // list to get full song metadata (title, artist, etc.)
                        let mostPlayed = getMostPlayedSongs()
                        if !mostPlayed.isEmpty {
                            MostPlayedSection(songs: mostPlayed)
                        }
                        
                        // ── TRENDING CHARTS SECTION ───────────────────
                        // Shows top songs and trending content from YouTube Music.
                        // Loaded separately from the home feed.
                        if !apiClient.chartsSections.isEmpty {
                            ForEach(apiClient.chartsSections) { section in
                                SectionView(section: section)
                            }
                        }
                        
                        // ── YOUTUBE MUSIC HOME FEED SECTIONS ──────────
                        ForEach(apiClient.homeSections) { section in
                            SectionView(section: section)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Home")
            // Show error banner if an API error occurred
            .overlay(alignment: .top) {
                if let error = apiClient.errorMessage {
                    ErrorBanner(message: error) {
                        Task { await apiClient.loadHome() }
                    }
                }
            }
            // .task runs async code when the view first appears.
            // It's like .onAppear but supports async/await.
            // We only load if homeSections is empty (avoids reloading on tab switch).
            .task {
                if apiClient.homeSections.isEmpty {
                    // Load home feed and charts in parallel for faster loading
                    async let homeLoad: () = apiClient.loadHome()
                    async let chartsLoad: () = apiClient.loadCharts()
                    await homeLoad
                    await chartsLoad
                }
            }
            // .refreshable enables pull-to-refresh (pull down from top).
            // This calls our closure when the user releases the pull.
            // Always reloads (doesn't check if empty) since user explicitly asked.
            .refreshable {
                // Reload both home and charts on pull-to-refresh
                async let homeLoad: () = apiClient.loadHome()
                async let chartsLoad: () = apiClient.loadCharts()
                await homeLoad
                await chartsLoad
            }
        }
    }
    
    // MARK: - Most Played Helper
    
    /// Get the user's most played songs with full metadata.
    ///
    /// Cross-references play counts from PlayCountManager with the
    /// recently played list to get complete song info (title, artist, etc.).
    /// Returns up to 10 songs sorted by play count.
    private func getMostPlayedSongs() -> [(song: NowPlaying, playCount: Int)] {
        let topPlayed = playCountManager.getMostPlayed(limit: 10)
        
        // Map play counts to full song objects using recently played as a lookup
        var result: [(song: NowPlaying, playCount: Int)] = []
        
        for item in topPlayed {
            // Find the song in recently played to get full metadata
            if let song = audioPlayer.recentlyPlayed.first(where: { $0.id == item.videoId }) {
                result.append((song: song, playCount: item.count))
            }
        }
        
        return result
    }
}

// MARK: - Section View

/// A single horizontal carousel section (like "Quick Picks" or "Trending").
///
/// Each section has a title and a horizontally scrolling list of items.
struct SectionView: View {
    
    /// The section data (title + list of items)
    let section: BrowseSection
    
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var apiClient: APIClient
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section title (e.g. "Quick Picks", "Trending")
            Text(section.title)
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            // ScrollView(.horizontal) = horizontal scrolling container
            // showsIndicators: false = hide the scroll bar dots
            ScrollView(.horizontal, showsIndicators: false) {
                // LazyHStack = horizontal stack with lazy view creation
                // (better performance for long lists)
                LazyHStack(spacing: 12) {
                    ForEach(section.items) { item in
                        ItemCard(item: item)
                            .onTapGesture {
                                // When user taps a card, play that song
                                playItem(item)
                            }
                    }
                }
                .padding(.horizontal) // Indent cards from screen edges
            }
        }
    }
    
    // MARK: - Playback
    
    /// Play an item when the user taps it.
    ///
    /// FLOW:
    /// 1. We have a BrowseItem with just the video ID and metadata
    /// 2. We need to call getPlayerInfo() to get the actual audio streaming URL
    /// 3. Once we have the streaming URL, we pass it to AudioPlayer to play
    ///
    /// This 2-step process (metadata → stream URL) is because YouTube doesn't
    /// include streaming URLs in browse/search responses — they're only
    /// available from the player endpoint, and they expire after a few hours.
    private func playItem(_ item: BrowseItem) {
        // Task = start an async operation without blocking the UI
        Task {
            do {
                // Step 1: Get the streaming URL from YouTube's player endpoint
                let playerInfo = try await apiClient.getPlayerInfo(videoId: item.id)
                
                // Step 2: Tell the audio player to play this song
                // `await` because AudioPlayer's play() method is also async
                await audioPlayer.play(
                    videoId: playerInfo.videoId,
                    title: playerInfo.title,
                    artist: playerInfo.artist,
                    thumbnailUrl: playerInfo.thumbnailUrl,
                    audioUrl: playerInfo.audioUrl,
                    duration: playerInfo.duration
                )
            } catch {
                // If anything fails (network error, invalid URL, etc.),
                // log it for debugging. In production, we'd show an alert.
                print("Failed to play item: \(error)")
            }
        }
    }
}

// MARK: - Item Card

/// A single card in the horizontal carousel.
///
/// Shows: thumbnail image, title, and subtitle (artist/playlist name).
/// The card is a fixed width (160pt) so carousels scroll smoothly.
struct ItemCard: View {
    
    /// The item data to display
    let item: BrowseItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Album art thumbnail
            // AsyncImage loads the URL asynchronously and shows a placeholder while loading
            AsyncImage(url: URL(string: item.thumbnailUrl)) { image in
                image
                    .resizable() // Allow resizing to fit frame
                    .aspectRatio(contentMode: .fill) // Fill the frame (may crop)
            } placeholder: {
                // Gray box with music note while image loads
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 160, height: 160)
            .cornerRadius(8)
            
            // Title (e.g. "Bohemian Rhapsody")
            Text(item.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2) // Allow 2 lines, truncate with "..." if longer
                .frame(width: 160, alignment: .leading)
            
            // Subtitle (e.g. "Queen" or "Playlist • 50 songs")
            Text(item.subtitle)
                .font(.caption) // Smaller font
                .foregroundColor(.secondary) // Gray
                .lineLimit(1)
                .frame(width: 160, alignment: .leading)
        }
    }
}

// MARK: - Recently Played Section

/// A horizontal carousel showing recently played songs.
///
/// Similar to YouTube Music's "Recently Played" section on the home screen.
/// Shows the last 20 songs played, most recent on the left.
struct RecentlyPlayedSection: View {
    
    /// The audio player for starting playback
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    /// The list of recently played songs (most recent first)
    let songs: [NowPlaying]
    
    /// The song being viewed in SongDetailView
    @State private var selectedSong: NowPlaying?
    
    /// Whether to show the SongDetailView sheet
    @State private var showSongInfo = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text("Recently Played")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            // Horizontal scroll of song cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Show up to 20 recent songs
                    ForEach(Array(songs.prefix(20))) { song in
                        // Each song is a tappable card
                        Button(action: {
                            audioPlayer.addToQueueAndPlay(song)
                        }) {
                            VStack(alignment: .leading, spacing: 6) {
                                // Album art thumbnail
                                AsyncImage(url: URL(string: song.thumbnailUrl)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    // Placeholder while loading
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay(
                                            Image(systemName: "music.note")
                                                .foregroundColor(.secondary)
                                        )
                                }
                                .frame(width: 120, height: 120)
                                .cornerRadius(8)
                                
                                // Song title
                                Text(song.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(2)
                                    .frame(width: 120, alignment: .leading)
                                
                                // Artist name
                                Text(song.artist)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)
                            }
                        }
                        // Long-press menu with Song Info option
                        .contextMenu {
                            Button(action: {
                                selectedSong = song
                                showSongInfo = true
                            }) {
                                Label("Song Info", systemImage: "info.circle")
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Most Played Section

/// A horizontal carousel showing the user's most frequently played songs.
///
/// Shows up to 10 songs with their play count displayed as a badge.
/// Tapping a song starts playing it immediately. Long-press shows Song Info.
struct MostPlayedSection: View {
    
    /// The audio player for starting playback
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    /// The list of most played songs with their play counts
    let songs: [(song: NowPlaying, playCount: Int)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("Most Played")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding(.horizontal)
            
            // Horizontal scroll of song cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(songs.prefix(10).enumerated()), id: \.element.song.id) { index, item in
                        NavigationLink(destination: SongDetailView(
                            videoId: item.song.id,
                            title: item.song.title,
                            artist: item.song.artist,
                            thumbnailUrl: item.song.thumbnailUrl,
                            duration: "\(item.song.duration)"
                        )) {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .topTrailing) {
                                    // Album art thumbnail
                                    AsyncImage(url: URL(string: item.song.thumbnailUrl)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .overlay(
                                                Image(systemName: "music.note")
                                                    .foregroundColor(.secondary)
                                            )
                                    }
                                    .frame(width: 120, height: 120)
                                    .cornerRadius(8)
                                    
                                    // Play count badge
                                    Text("\(item.playCount)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.orange)
                                        .cornerRadius(8)
                                        .padding(4)
                                }
                                
                                // Song title
                                Text(item.song.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(2)
                                    .frame(width: 120, alignment: .leading)
                                
                                // Artist name
                                Text(item.song.artist)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environmentObject(AudioPlayer())
        .environmentObject(APIClient())
        .environmentObject(PlayCountManager())
}
