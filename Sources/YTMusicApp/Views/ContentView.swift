import SwiftUI

/// The main view that contains the tab bar and navigation
struct ContentView: View {
    
    /// Access the audio player from the environment
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    /// Access the API client from the environment
    @EnvironmentObject var apiClient: APIClient
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main tab view
            TabView {
                // Home tab
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                
                // Search tab
                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                
                // Library tab (placeholder for now)
                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "square.stack.fill")
                    }
            }
            
            // Mini player at the bottom (when something is playing)
            if audioPlayer.currentSong != nil {
                MiniPlayer()
                    .transition(.move(edge: .bottom))
            }
        }
    }
}

/// The mini player that shows at the bottom when music is playing
struct MiniPlayer: View {
    
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    var body: some View {
        if let song = audioPlayer.currentSong {
            VStack(spacing: 0) {
                // Progress bar
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * audioPlayer.progress, height: 3)
                }
                .frame(height: 3)
                
                // Song info and controls
                HStack {
                    // Thumbnail
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
                    
                    // Title and artist
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
                    
                    Spacer()
                    
                    // Play/pause button
                    Button(action: {
                        audioPlayer.togglePlayPause()
                    }) {
                        Image(systemName: audioPlayer.state == .playing ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: -2)
            .onTapGesture {
                // Open full player (we'll implement this later)
            }
        }
    }
}

/// Placeholder for the Library tab
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
                    .multilineTextAlignment(.center)
            }
            .navigationTitle("Library")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioPlayer())
        .environmentObject(APIClient())
}
