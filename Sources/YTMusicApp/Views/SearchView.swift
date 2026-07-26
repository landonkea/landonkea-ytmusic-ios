import SwiftUI

/// The search screen where users can find songs, artists, albums
struct SearchView: View {
    
    @EnvironmentObject var apiClient: APIClient
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    /// The current search text
    @State private var searchText = ""
    
    /// Whether we're currently searching
    @State private var isSearching = false
    
    /// Search suggestions for autocomplete
    @State private var suggestions: [String] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(
                    text: $searchText,
                    isSearching: $isSearching,
                    onSearchButtonClicked: {
                        performSearch()
                    },
                    onTextChanged: { newValue in
                        // Get suggestions as user types
                        Task {
                            await loadSuggestions(for: newValue)
                        }
                    }
                )
                
                // Show suggestions while typing
                if !searchText.isEmpty && !suggestions.isEmpty && !isSearching {
                    SuggestionsList(suggestions: suggestions) { suggestion in
                        searchText = suggestion
                        performSearch()
                    }
                }
                
                // Search results
                if isSearching {
                    if apiClient.isLoading {
                        ProgressView("Searching...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if apiClient.searchResults.isEmpty && !searchText.isEmpty {
                        // No results
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No results found")
                                .font(.headline)
                            Text("Try a different search term")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        // Show results
                        SearchResultsList(results: apiClient.searchResults)
                    }
                } else {
                    // Show recent searches or suggestions when not searching
                    RecentSearchesView()
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    /// Perform the search
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isSearching = true
        suggestions = []
        
        Task {
            await apiClient.search(query: searchText)
        }
    }
    
    /// Load search suggestions
    private func loadSuggestions(for query: String) async {
        guard query.count >= 2 else {
            suggestions = []
            return
        }
        
        do {
            let newSuggestions = try await apiClient.client.getSearchSuggestions(query: query)
            suggestions = Array(newSuggestions.prefix(8))
        } catch {
            // Silently fail for suggestions
            print("Failed to load suggestions: \(error)")
        }
    }
}

/// The search bar component
struct SearchBar: View {
    
    @Binding var text: String
    @Binding var isSearching: Bool
    var onSearchButtonClicked: () -> Void
    var onTextChanged: (String) -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search songs, artists, albums...", text: $text)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit {
                        onSearchButtonClicked()
                    }
                    .onChange(of: text) { newValue in
                        onTextChanged(newValue)
                    }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                        isSearching = false
                        suggestions = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Cancel button
            if isFocused || isSearching {
                Button("Cancel") {
                    text = ""
                    isSearching = false
                    isFocused = false
                    suggestions = []
                }
                .transition(.move(edge: .trailing))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .animation(.easeInOut, value: isFocused)
        .animation(.easeInOut, value: isSearching)
    }
    
    @State private var suggestions: [String] = []
}

/// List of search suggestions while typing
struct SuggestionsList: View {
    
    let suggestions: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: {
                        onSelect(suggestion)
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            
                            Text(suggestion)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                    
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .frame(maxHeight: 300)
        .background(Color(.systemBackground))
    }
}

/// List of search results
struct SearchResultsList: View {
    
    let results: [SearchResult]
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var apiClient: APIClient
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(results) { result in
                    SearchResultRow(result: result)
                        .onTapGesture {
                            playResult(result)
                        }
                    
                    Divider()
                        .padding(.leading, 76)
                }
            }
        }
    }
    
    /// Play a search result
    private func playResult(_ result: SearchResult) {
        Task {
            do {
                // Get streaming URL
                let playerInfo = try await apiClient.getPlayerInfo(videoId: result.id)
                
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
                print("Failed to play: \(error)")
            }
        }
    }
}

/// A single row in the search results
struct SearchResultRow: View {
    
    let result: SearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AsyncImage(url: URL(string: result.bestThumbnailUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 56, height: 56)
            .cornerRadius(4)
            
            // Title and artist
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.body)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(result.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let duration = result.duration {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(duration)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .lineLimit(1)
            }
            
            Spacer()
            
            // More button
            Button(action: {
                // Show options menu
            }) {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

/// Recent searches placeholder
struct RecentSearchesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No recent searches")
                .font(.headline)
            
            Text("Search for your favorite songs")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

#Preview {
    SearchView()
        .environmentObject(AudioPlayer())
        .environmentObject(APIClient())
}
