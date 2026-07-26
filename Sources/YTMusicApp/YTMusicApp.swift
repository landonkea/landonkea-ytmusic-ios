import SwiftUI

/// The main entry point for the YouTube Music iOS app
/// This creates the app and sets up the main window
@main
struct YTMusicApp: App {
    
    /// The shared audio player that all views will use
    @StateObject private var audioPlayer = AudioPlayer()
    
    /// The API client for talking to YouTube
    @StateObject private var apiClient = APIClient()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioPlayer)
                .environmentObject(apiClient)
        }
    }
}

/// A simple wrapper around InnerTubeClient that works with SwiftUI
@MainActor
class APIClient: ObservableObject {
    
    /// The underlying InnerTube client
    let client = InnerTubeClient()
    
    /// Cached search results
    @Published var searchResults: [SearchResult] = []
    
    /// Cached home feed
    @Published var homeSections: [BrowseSection] = []
    
    /// Whether we're currently loading
    @Published var isLoading: Bool = false
    
    /// Error message to display
    @Published var errorMessage: String?
    
    /// Search for songs
    func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let results = try await client.search(query: query)
            searchResults = results
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            print("Search error: \(error)")
        }
        
        isLoading = false
    }
    
    /// Load the home feed
    func loadHome() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let sections = try await client.getHome()
            homeSections = sections
        } catch {
            errorMessage = "Failed to load home: \(error.localizedDescription)"
            print("Home load error: \(error)")
        }
        
        isLoading = false
    }
    
    /// Get player info for a song
    func getPlayerInfo(videoId: String) async throws -> PlayerInfo {
        return try await client.getPlayer(videoId: videoId)
    }
}
