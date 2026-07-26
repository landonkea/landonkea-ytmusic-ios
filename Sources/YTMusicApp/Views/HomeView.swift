import SwiftUI

/// The home screen showing recommended music, trending, etc.
struct HomeView: View {
    
    @EnvironmentObject var apiClient: APIClient
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    var body: some View {
        NavigationView {
            ScrollView {
                if apiClient.isLoading && apiClient.homeSections.isEmpty {
                    // Show loading spinner
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if apiClient.homeSections.isEmpty {
                    // Show empty state
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
                    // Show sections
                    LazyVStack(spacing: 24) {
                        ForEach(apiClient.homeSections) { section in
                            SectionView(section: section)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Home")
            .task {
                // Load home feed when view appears
                if apiClient.homeSections.isEmpty {
                    await apiClient.loadHome()
                }
            }
            .refreshable {
                // Pull to refresh
                await apiClient.loadHome()
            }
        }
    }
}

/// A single section on the home screen (like "Quick Picks" or "Trending")
struct SectionView: View {
    
    let section: BrowseSection
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var apiClient: APIClient
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section title
            Text(section.title)
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            // Horizontal scrolling list of items
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(section.items) { item in
                        ItemCard(item: item)
                            .onTapGesture {
                                playItem(item)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    /// Play an item when tapped
    private func playItem(_ item: BrowseItem) {
        Task {
            do {
                // Get the streaming URL
                let playerInfo = try await apiClient.getPlayerInfo(videoId: item.id)
                
                // Play it
                await audioPlayer.play(
                    videoId: playerInfo.videoId,
                    title: playerInfo.title,
                    artist: playerInfo.artist,
                    thumbnailUrl: playerInfo.thumbnailUrl,
                    audioUrl: playerInfo.audioUrl,
                    duration: playerInfo.duration
                )
            } catch {
                print("Failed to play item: \(error)")
            }
        }
    }
}

/// A card for a single item in the horizontal scroll
struct ItemCard: View {
    
    let item: BrowseItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Thumbnail
            AsyncImage(url: URL(string: item.thumbnailUrl)) { image in
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
            .frame(width: 160, height: 160)
            .cornerRadius(8)
            
            // Title
            Text(item.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .frame(width: 160, alignment: .leading)
            
            // Subtitle
            Text(item.subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 160, alignment: .leading)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AudioPlayer())
        .environmentObject(APIClient())
}
