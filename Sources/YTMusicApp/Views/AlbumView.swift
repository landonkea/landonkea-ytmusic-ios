import SwiftUI

// MARK: - Album View

/// Full album page showing track list, album art, and metadata.
///
/// HOW IT WORKS:
/// - Uses the `browse` API with the album's browse ID (e.g. "MPREb_...")
/// - Parses the response into an AlbumInfo model
/// - Displays album art, title, artist, year, and full track list
/// - Each track is playable with a tap
struct AlbumView: View {
    
    // MARK: - Properties
    
    /// YouTube browse ID for this album
    let browseId: String
    
    /// The API client for fetching album data
    @EnvironmentObject var apiClient: APIClient
    
    /// The audio player for playing tracks
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    /// The album data (loaded from API)
    @State private var album: AlbumInfo?
    
    /// Whether the album data is currently loading
    @State private var isLoading = true
    
    /// Error message if loading fails
    @State private var errorMessage: String?
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if isLoading {
                // Loading state
                ScrollView {
                    VStack(spacing: 16) {
                        // Album art skeleton
                        SkeletonView(width: 200, height: 200, cornerRadius: 12)
                        
                        // Title skeleton
                        SkeletonView(width: 180, height: 24, cornerRadius: 4)
                        
                        // Artist skeleton
                        SkeletonView(width: 140, height: 16, cornerRadius: 4)
                        
                        // Track list skeletons
                        ForEach(0..<8) { _ in
                            HStack {
                                SkeletonView(width: 40, height: 40, cornerRadius: 4)
                                VStack(alignment: .leading, spacing: 4) {
                                    SkeletonView(width: 160, height: 14, cornerRadius: 2)
                                    SkeletonView(width: 100, height: 12, cornerRadius: 2)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
            } else if let error = errorMessage {
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Failed to load album")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        Task { await loadAlbum() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else if let album = album {
                // Album content
                ScrollView {
                    VStack(spacing: 16) {
                        // Album header
                        albumHeader(album)
                        
                        // Play All button
                        playAllButton(album)
                        
                        // Track list divider
                        Divider()
                            .padding(.horizontal)
                        
                        // Track list
                        trackList(album)
                    }
                    .padding(.bottom, 100)
                }
                .navigationTitle(album.title)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task {
            await loadAlbum()
        }
    }
    
    // MARK: - Load Album
    
    /// Fetch album data from the API.
    private func loadAlbum() async {
        isLoading = true
        errorMessage = nil
        
        do {
            album = try await apiClient.getAlbum(browseId: browseId)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Album Header
    
    /// Album art, title, artist, and metadata.
    private func albumHeader(_ album: AlbumInfo) -> some View {
        VStack(spacing: 12) {
            // Album art
            AsyncImage(url: URL(string: album.thumbnailUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 200)
                        .cornerRadius(12)
                        .shadow(radius: 8)
                case .failure:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.secondary.opacity(0.3))
                        .frame(width: 200, height: 200)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                        )
                case .empty:
                    ProgressView()
                        .frame(width: 200, height: 200)
                @unknown default:
                    EmptyView()
                }
            }
            
            // Title
            Text(album.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Artist
            Text(album.artist)
                .font(.body)
                .foregroundColor(.secondary)
            
            // Year and track count
            if let year = album.year {
                HStack(spacing: 8) {
                    Text("\(year)")
                    
                    if let count = album.trackCount {
                        Text("•")
                        Text("\(count) songs")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            } else if let count = album.trackCount {
                Text("\(count) songs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top)
    }
    
    // MARK: - Play All Button
    
    /// Button to play the entire album starting from the first track.
    private func playAllButton(_ album: AlbumInfo) -> some View {
        Button {
            Task {
                await playAll(album)
            }
        } label: {
            HStack {
                Image(systemName: "play.fill")
                Text("Play All")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
        }
        .disabled(album.tracks?.isEmpty ?? true)
        .opacity(album.tracks?.isEmpty ?? true ? 0.5 : 1)
    }
    
    // MARK: - Track List
    
    /// Complete list of tracks in the album.
    private func trackList(_ album: AlbumInfo) -> some View {
        VStack(spacing: 0) {
            if let tracks = album.tracks {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    Button {
                        Task {
                            await playTrack(track, tracks: tracks, startIndex: index)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            // Track number
                            Text("\(index + 1)")
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .frame(width: 28)
                            
                            // Thumbnail
                            AsyncImage(url: URL(string: track.thumbnailUrl)) { phase in
                                if let image = phase.image {
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 40)
                                        .cornerRadius(4)
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.secondary.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                }
                            }
                            
                            // Title and artist
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                Text(track.artist)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // Duration
                            if let duration = track.duration {
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
                        .padding(.vertical, 6)
                    }
                    
                    Divider()
                        .padding(.leading, 80)
                }
            } else {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No tracks available")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 40)
            }
        }
    }
    
    // MARK: - Play Actions
    
    /// Play the entire album starting from the beginning.
    private func playAll(_ album: AlbumInfo) async {
        guard let tracks = album.tracks, !tracks.isEmpty else { return }
        await playTrack(tracks[0], tracks: tracks, startIndex: 0)
    }
    
    /// Play a specific track and queue the rest of the album.
    private func playTrack(_ track: SearchResult, tracks: [SearchResult], startIndex: Int) async {
        do {
            let info = try await apiClient.getPlayerInfo(videoId: track.id)
            audioPlayer.play(info: info)
            
            // Queue remaining tracks after the current one
            for i in (startIndex + 1)..<tracks.count {
                let nextTrack = tracks[i]
                if let nextInfo = try? await apiClient.getPlayerInfo(videoId: nextTrack.id) {
                    audioPlayer.addToQueue(nextInfo)
                }
            }
        } catch {
            print("Failed to play track: \(error)")
        }
    }
}
