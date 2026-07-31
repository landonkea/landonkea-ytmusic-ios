import SwiftUI

// MARK: - Explore View

/// Browse new releases, moods, and genres from YouTube Music.
///
/// This view has three tabs:
/// 1. New Releases — recently released albums and singles
/// 2. Moods & Genres — curated playlists by mood or genre
/// 3. Explore — combined feed from YouTube Music's explore page
struct ExploreView: View {
    
    // MARK: - Properties
    
    /// The API client for fetching explore data
    @EnvironmentObject var apiClient: APIClient
    
    /// The audio player for playing songs
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    /// Selected tab: 0 = New Releases, 1 = Moods & Genres, 2 = Explore
    @State private var selectedTab = 0
    
    /// New releases categories
    @State private var newReleases: [ExploreCategory] = []
    
    /// Mood and genre categories
    @State private var moodCategories: [ExploreCategory] = []
    
    /// Explore page categories
    @State private var exploreSections: [ExploreCategory] = []
    
    /// Whether any data is currently loading
    @State private var isLoading = true
    
    /// Error message if loading fails
    @State private var errorMessage: String?
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Section", selection: $selectedTab) {
                Text("New Releases").tag(0)
                Text("Moods").tag(1)
                Text("Explore").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadAll() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        switch selectedTab {
                        case 0:
                            newReleasesContent
                        case 1:
                            moodsContent
                        case 2:
                            exploreContent
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAll()
        }
    }
    
    // MARK: - Load Data
    
    /// Load all explore data in parallel.
    private func loadAll() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch all in parallel
            async let releases = apiClient.getNewReleases()
            async let moods = apiClient.getMoodCategories()
            async let explore = apiClient.getExplore()
            
            (newReleases, moodCategories, exploreSections) = try await (releases, moods, explore)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - New Releases Content
    
    /// Grid of new album and single releases.
    private var newReleasesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if newReleases.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No new releases found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                ForEach(newReleases) { category in
                    // Category section
                    Text(category.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    // Horizontal carousel
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(category.items) { item in
                                NavigationLink(destination: destinationFor(item)) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        // Thumbnail
                                        AsyncImage(url: URL(string: item.thumbnailUrl)) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image.resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 140, height: 140)
                                                    .cornerRadius(8)
                                            case .failure:
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(.secondary.opacity(0.3))
                                                    .frame(width: 140, height: 140)
                                                    .overlay(
                                                        Image(systemName: "music.note")
                                                            .foregroundColor(.secondary)
                                                    )
                                            case .empty:
                                                ProgressView()
                                                    .frame(width: 140, height: 140)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        
                                        // Title
                                        Text(item.title)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .lineLimit(2)
                                            .foregroundColor(.primary)
                                            .frame(width: 140, alignment: .leading)
                                        
                                        // Subtitle
                                        Text(item.subtitle)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .frame(width: 140, alignment: .leading)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    // MARK: - Moods Content
    
    /// Grid of mood and genre categories.
    private var moodsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if moodCategories.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No moods available")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                ForEach(moodCategories) { category in
                    // Category section
                    Text(category.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    // Horizontal carousel
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(category.items) { item in
                                NavigationLink(destination: destinationFor(item)) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        // Thumbnail
                                        AsyncImage(url: URL(string: item.thumbnailUrl)) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image.resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 140, height: 140)
                                                    .cornerRadius(8)
                                            case .failure:
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(.secondary.opacity(0.3))
                                                    .frame(width: 140, height: 140)
                                                    .overlay(
                                                        Image(systemName: "music.note")
                                                            .foregroundColor(.secondary)
                                                    )
                                            case .empty:
                                                ProgressView()
                                                    .frame(width: 140, height: 140)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        
                                        // Title
                                        Text(item.title)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .lineLimit(2)
                                            .foregroundColor(.primary)
                                            .frame(width: 140, alignment: .leading)
                                        
                                        // Subtitle
                                        Text(item.subtitle)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .frame(width: 140, alignment: .leading)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    // MARK: - Explore Content
    
    /// Combined explore feed from YouTube Music.
    private var exploreContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if exploreSections.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Nothing to explore right now")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                ForEach(exploreSections) { section in
                    // Section header
                    Text(section.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    // Horizontal carousel
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(section.items) { item in
                                NavigationLink(destination: destinationFor(item)) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        // Thumbnail
                                        AsyncImage(url: URL(string: item.thumbnailUrl)) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image.resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 140, height: 140)
                                                    .cornerRadius(8)
                                            case .failure:
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(.secondary.opacity(0.3))
                                                    .frame(width: 140, height: 140)
                                                    .overlay(
                                                        Image(systemName: "music.note")
                                                            .foregroundColor(.secondary)
                                                    )
                                            case .empty:
                                                ProgressView()
                                                    .frame(width: 140, height: 140)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        
                                        // Title
                                        Text(item.title)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .lineLimit(2)
                                            .foregroundColor(.primary)
                                            .frame(width: 140, alignment: .leading)
                                        
                                        // Subtitle
                                        Text(item.subtitle)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .frame(width: 140, alignment: .leading)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    // MARK: - Navigation Destination
    
    /// Determine the appropriate destination view based on item type.
    @ViewBuilder
    private func destinationFor(_ item: BrowseItem) -> some View {
        switch item.type {
        case .album:
            AlbumView(browseId: item.id)
        case .artist:
            ArtistView(channelId: item.id)
        case .playlist:
            // Playlists open inline — show a simple text view
            // Full playlist browsing requires API support for fetching
            // playlist contents by browseId (future enhancement).
            PlaylistBrowseView(browseId: item.id, title: item.title)
        case .song:
            // Songs play inline — no navigation
            // Show a song detail view instead.
            // SongDetailView takes the song info as individual parameters.
            SongDetailView(
                videoId: item.id,
                title: item.title,
                artist: item.subtitle,
                thumbnailUrl: item.thumbnailUrl,
                duration: ""
            )
        }
    }
}

// MARK: - Playlist Browse View

/// A simple view for browsing external playlists from YouTube Music.
///
/// This is a placeholder until full API-based playlist browsing is implemented.
/// It shows the playlist title and explains that full browsing is coming soon.
struct PlaylistBrowseView: View {
    let browseId: String
    let title: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Playlist browsing coming soon")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("This playlist can be played from the YouTube Music app or website.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
