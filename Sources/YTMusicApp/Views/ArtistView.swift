import SwiftUI

// MARK: - Artist View

/// Full artist page showing top songs, albums, singles, and related artists.
///
/// HOW IT WORKS:
/// - Uses the `browse` API with the artist's channel ID (e.g. "UC...")
/// - Parses the response into an ArtistInfo model with all sections
/// - Top songs are playable directly
/// - Albums navigate to AlbumView for full track list
/// - Related artists navigate to another ArtistView (recursive)
struct ArtistView: View {
    
    // MARK: - Properties
    
    /// YouTube channel ID for this artist
    let channelId: String
    
    /// The API client for fetching artist data
    @EnvironmentObject var apiClient: APIClient
    
    /// The audio player for playing songs
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    /// The artist data (loaded from API)
    @State private var artist: ArtistInfo?
    
    /// Whether the artist data is currently loading
    @State private var isLoading = true
    
    /// Error message if loading fails
    @State private var errorMessage: String?
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if isLoading {
                // Loading state with skeleton placeholders
                ScrollView {
                    VStack(spacing: 16) {
                        // Artist avatar skeleton
                        SkeletonView(width: 120, height: 120, cornerRadius: 60)
                        
                        // Name skeleton
                        SkeletonView(width: 200, height: 24, cornerRadius: 4)
                        
                        // Subscriber count skeleton
                        SkeletonView(width: 150, height: 16, cornerRadius: 4)
                        
                        // Top songs skeleton
                        SkeletonSection()
                        
                        // Albums skeleton
                        SkeletonSection()
                    }
                    .padding()
                }
            } else if let error = errorMessage {
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Failed to load artist")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        Task { await loadArtist() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else if let artist = artist {
                // Artist content
                ScrollView {
                    VStack(spacing: 24) {
                        // Artist header
                        artistHeader(artist)
                        
                        // Top songs section
                        if !artist.topSongs.isEmpty {
                            topSongsSection(artist.topSongs)
                        }
                        
                        // Albums section
                        if !artist.albums.isEmpty {
                            albumsSection(artist.albums)
                        }
                        
                        // Related artists section
                        if !artist.relatedArtists.isEmpty {
                            relatedArtistsSection(artist.relatedArtists)
                        }
                    }
                    .padding(.bottom, 100) // Space for mini player
                }
                .navigationTitle(artist.name)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task {
            await loadArtist()
        }
    }
    
    // MARK: - Load Artist
    
    /// Fetch artist data from the API.
    private func loadArtist() async {
        isLoading = true
        errorMessage = nil
        
        do {
            artist = try await apiClient.getArtist(channelId: channelId)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Artist Header
    
    /// The artist header with avatar, name, and subscriber count.
    private func artistHeader(_ artist: ArtistInfo) -> some View {
        VStack(spacing: 12) {
            // Avatar
            AsyncImage(url: URL(string: artist.thumbnailUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                case .failure:
                    // Fallback icon
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 120))
                        .foregroundColor(.secondary)
                case .empty:
                    ProgressView()
                        .frame(width: 120, height: 120)
                @unknown default:
                    EmptyView()
                }
            }
            
            // Name
            Text(artist.name)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Subscriber count
            if let subscribers = artist.subscriberCount {
                Text(subscribers)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Description (collapsed)
            if let description = artist.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - Top Songs Section
    
    /// A list of the artist's most popular songs.
    private func topSongsSection(_ songs: [SearchResult]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Image(systemName: "music.note.list")
                    .foregroundColor(.purple)
                Text("Top Songs")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .padding(.horizontal)
            
            // Song list
            ForEach(Array(songs.prefix(10).enumerated()), id: \.element.id) { index, song in
                Button {
                    Task {
                        await playSong(song)
                    }
                } label: {
                    HStack(spacing: 12) {
                        // Position number
                        Text("\(index + 1)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        
                        // Thumbnail
                        AsyncImage(url: URL(string: song.thumbnailUrl)) { phase in
                            if let image = phase.image {
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 44, height: 44)
                                    .cornerRadius(4)
                            } else {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.secondary.opacity(0.3))
                                    .frame(width: 44, height: 44)
                            }
                        }
                        
                        // Title and artist
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.body)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .foregroundColor(.primary)
                            Text(song.artist)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Duration
                        if let duration = song.duration {
                            Text(duration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Play icon
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - Albums Section
    
    /// Horizontal carousel of the artist's albums and singles.
    private func albumsSection(_ albums: [AlbumInfo]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Image(systemName: "square.stack")
                    .foregroundColor(.purple)
                Text("Albums & Singles")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .padding(.horizontal)
            
            // Horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(albums) { album in
                        NavigationLink(destination: AlbumView(browseId: album.id)) {
                            VStack(alignment: .leading, spacing: 6) {
                                // Album art
                                AsyncImage(url: URL(string: album.thumbnailUrl)) { phase in
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
                                
                                // Album title
                                Text(album.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(2)
                                    .foregroundColor(.primary)
                                    .frame(width: 140, alignment: .leading)
                                
                                // Album type
                                Text(album.artist)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .frame(width: 140, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Related Artists Section
    
    /// Horizontal carousel of related/similar artists.
    private func relatedArtistsSection(_ artists: [ArtistInfo]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.purple)
                Text("Related Artists")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .padding(.horizontal)
            
            // Horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(artists) { relatedArtist in
                        NavigationLink(destination: ArtistView(channelId: relatedArtist.id)) {
                            VStack(spacing: 8) {
                                // Artist avatar
                                AsyncImage(url: URL(string: relatedArtist.thumbnailUrl)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 80, height: 80)
                                            .clipShape(Circle())
                                    case .failure:
                                        Circle()
                                            .fill(.secondary.opacity(0.3))
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Image(systemName: "person.fill")
                                                    .foregroundColor(.secondary)
                                            )
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 80, height: 80)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                
                                // Artist name
                                Text(relatedArtist.name)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                    .frame(width: 80)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Play Song
    
    /// Fetch streaming URL and play the selected song.
    private func playSong(_ song: SearchResult) async {
        do {
            let info = try await apiClient.getPlayerInfo(videoId: song.id)
            audioPlayer.play(info: info)
        } catch {
            print("Failed to play song: \(error)")
        }
    }
}
