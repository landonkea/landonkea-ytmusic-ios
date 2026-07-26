import Foundation

/// The main client for talking to YouTube's InnerTube API
/// All methods are async and return parsed Swift objects
class InnerTubeClient {
    
    // MARK: - Properties
    
    /// Base URL for all InnerTube API requests
    private let baseURL = "https://music.youtube.com/youtubei/v1"
    
    /// API key (obtained from YouTube's web app)
    /// This is a public key embedded in the YouTube client - not a secret
    private let apiKey = "AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30"
    
    /// The context we send with every request (pretends to be iOS YouTube Music)
    private let context: InnerTubeContext
    
    /// URL session for making HTTP requests
    private let session: URLSession
    
    // MARK: - Initialization
    
    /// Create a new InnerTube client
    /// - Parameter session: URL session to use (for testing, you can pass a mock)
    init(session: URLSession = .shared) {
        self.session = session
        
        // Set up the client info to pretend we're the iOS YouTube Music app
        self.context = InnerTubeContext(
            client: InnerTubeClientInfo(
                clientName: "IOS_MUSIC",
                clientVersion: "7.27.0",
                deviceMake: "Apple",
                deviceModel: "iPhone16,2",
                hl: "en",
                gl: "US",
                osName: "iPhone",
                osVersion: "18.5.0",
                userAgent: "com.google.ios.youtubemusic/7.27.0 (iPhone16,2; U; CPU iOS 18_5_0 like Mac OS X;)"
            )
        )
    }
    
    // MARK: - Search
    
    /// Search for songs, albums, artists, or playlists
    /// - Parameter query: The search term (e.g. "Bohemian Rhapsody")
    /// - Returns: Array of search result items
    func search(query: String) async throws -> [SearchResult] {
        // Build the request body
        let body = InnerTubeRequest(
            context: context,
            query: query,
            browseId: nil,
            videoId: nil,
            playlistId: nil,
            params: nil
        )
        
        // Make the request to YouTube
        let response: InnerTubeResponse = try await POST(
            endpoint: "/search",
            body: body
        )
        
        // Parse the response into our simple SearchResult model
        return parseSearchResults(from: response)
    }
    
    // MARK: - Player
    
    /// Get streaming URLs for a video/song
    /// - Parameter videoId: The YouTube video ID (e.g. "dQw4w9WgXcQ")
    /// - Returns: Player info including stream URLs and video details
    func getPlayer(videoId: String) async throws -> PlayerInfo {
        // Build the request body
        let body = InnerTubeRequest(
            context: context,
            query: nil,
            browseId: nil,
            videoId: videoId,
            playlistId: nil,
            params: nil
        )
        
        // Make the request
        let response: InnerTubeResponse = try await POST(
            endpoint: "/player",
            body: body
        )
        
        // Parse into our simple model
        return try parsePlayerInfo(from: response)
    }
    
    // MARK: - Browse (Home, Trending, etc.)
    
    /// Browse a YouTube Music page (home, trending, charts, etc.)
    /// - Parameter browseId: The browse ID (e.g. "FEmusic_home" for home)
    /// - Returns: Array of content sections
    func browse(browseId: String, params: String? = nil) async throws -> [BrowseSection] {
        // Build the request body
        let body = InnerTubeRequest(
            context: context,
            query: nil,
            browseId: browseId,
            videoId: nil,
            playlistId: nil,
            params: params
        )
        
        // Make the request
        let response: InnerTubeResponse = try await POST(
            endpoint: "/browse",
            body: body
        )
        
        // Parse into sections
        return parseBrowseSections(from: response)
    }
    
    // MARK: - Get Home Feed
    
    /// Get the YouTube Music home page
    /// - Returns: Array of content sections (quick picks, trending, etc.)
    func getHome() async throws -> [BrowseSection] {
        return try await browse(browseId: "FEmusic_home")
    }
    
    // MARK: - Get Search Suggestions
    
    /// Get autocomplete suggestions as user types
    /// - Parameter query: The partial search query
    /// - Returns: Array of suggestion strings
    func getSearchSuggestions(query: String) async throws -> [String] {
        // This uses a different endpoint format
        let url = URL(string: "\(baseURL)/music/get_search_suggestions?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(context.client.userAgent, forHTTPHeaderField: "User-Agent")
        
        // Build the body
        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "IOS_MUSIC",
                    "clientVersion": "7.27.0"
                ]
            ],
            "input": query
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Make the request
        let (data, _) = try await session.data(for: request)
        
        // Parse the response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let suggestions = json?["contents"] as? [[String: Any]]
        
        return suggestions?.compactMap { item in
            let renderer = item["searchSuggestionRenderer"] as? [String: Any]
            let text = renderer?["suggestion"] as? [String: Any]
            return text?["simpleText"] as? String
        } ?? []
    }
    
    // MARK: - Private Helpers
    
    /// Make a POST request to an InnerTube endpoint
    /// - Parameters:
    ///   - endpoint: The API endpoint (e.g. "/search")
    ///   - body: The request body
    /// - Returns: The decoded response
    private func POST<T: Decodable>(endpoint: String, body: InnerTubeRequest) async throws -> T {
        // Build the URL with API key
        let urlString = "\(baseURL)\(endpoint)?key=\(apiKey)"
        let url = URL(string: urlString)!
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(context.client.userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("music.youtube.com", forHTTPHeaderField: "Host")
        
        // Encode the body to JSON
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        // Make the request
        let (data, response) = try await session.data(for: request)
        
        // Check for HTTP errors
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InnerTubeError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw InnerTubeError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Decode the JSON response
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // If decoding fails, print the raw JSON for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON response: \(jsonString.prefix(500))")
            }
            throw InnerTubeError.decodingFailed(error)
        }
    }
    
    // MARK: - Response Parsers
    
    /// Parse search results from the raw response
    private func parseSearchResults(from response: InnerTubeResponse) -> [SearchResult] {
        var results: [SearchResult] = []
        
        // Navigate the nested response structure
        guard let contents = response.contents else { return results }
        
        // Try different response structures
        if let tabbedResults = contents.singleColumnSearchResultsRenderer?.contents {
            for content in tabbedResults {
                if let shelf = content.musicShelfRenderer,
                   let items = shelf.contents {
                    for item in items {
                        if let renderer = item.musicResponsiveListItemRenderer {
                            if let result = parseSearchItem(renderer) {
                                results.append(result)
                            }
                        }
                    }
                }
            }
        }
        
        return results
    }
    
    /// Parse a single search item
    private func parseSearchItem(_ renderer: MusicResponsiveListItemRenderer) -> SearchResult? {
        // Get the video ID from navigation endpoint
        guard let videoId = renderer.navigationEndpoint?.watchEndpoint?.videoId else {
            return nil
        }
        
        // Get title from first flex column
        let title = renderer.flexColumns?.first?.musicResponsiveListItemFlexColumnRenderer?.text?.text ?? "Unknown"
        
        // Get artist/subtitle from second flex column
        let artist = renderer.flexColumns?.dropFirst().first?.musicResponsiveListItemFlexColumnRenderer?.text?.text ?? "Unknown Artist"
        
        // Get thumbnail URL
        let thumbnailUrl = renderer.thumbnail?.musicThumbnailRenderer?.thumbnails?.last?.url ?? ""
        
        // Get duration from overlay
        let duration = renderer.overlay?.musicItemThumbnailOverlayRenderer?.content?.musicResponsiveListItemOverlayRenderer?.musicDurationText?.text
        
        return SearchResult(
            id: videoId,
            title: title,
            artist: artist,
            thumbnailUrl: thumbnailUrl,
            duration: duration
        )
    }
    
    /// Parse player info from the response
    private func parsePlayerInfo(from response: InnerTubeResponse) throws -> PlayerInfo {
        // Check if the video is playable
        if let status = response.playabilityStatus, status.status != "OK" {
            throw InnerTubeError.videoUnplayable(reason: status.reason ?? "Unknown reason")
        }
        
        // Get video details
        guard let details = response.videoDetails else {
            throw InnerTubeError.noVideoDetails
        }
        
        // Get streaming data
        guard let streaming = response.streamingData else {
            throw InnerTubeError.noStreamingData
        }
        
        // Find the best audio stream
        let audioStreams = (streaming.adaptiveFormats ?? []).filter { $0.isAudio }
        guard let bestAudio = audioStreams.max(by: { $0.bitrate < $1.bitrate }) else {
            throw InnerTubeError.noAudioStream
        }
        
        // Get thumbnail
        let thumbnailUrl = details.thumbnail?.thumbnails?.last?.url ?? ""
        
        return PlayerInfo(
            videoId: details.videoId,
            title: details.title,
            artist: details.author,
            thumbnailUrl: thumbnailUrl,
            duration: Int(details.lengthSeconds) ?? 0,
            audioUrl: bestAudio.url ?? "",
            audioQuality: bestAudio.audioQuality,
            viewCount: details.viewCount
        )
    }
    
    /// Parse browse sections from the response
    private func parseBrowseSections(from response: InnerTubeResponse) -> [BrowseSection] {
        var sections: [BrowseSection] = []
        
        guard let contents = response.contents else { return sections }
        
        // Navigate to the section list
        let sectionList = contents.singleColumnBrowseResultsRenderer?.tabs?.first?.tabRenderer?.content?.sectionListRenderer
            ?? contents.sectionListRenderer
        
        guard let sectionContents = sectionList?.contents else { return sections }
        
        for sectionContent in sectionContents {
            // Handle carousel shelves (horizontal scrolling rows)
            if let carousel = sectionContent.musicCarouselShelfRenderer {
                let title = carousel.header?.musicCarouselShelfBasicHeaderRenderer?.title?.text ?? "Untitled"
                var items: [BrowseItem] = []
                
                for item in carousel.contents ?? [] {
                    if let twoRow = item.musicTwoRowItemRenderer {
                        let itemTitle = twoRow.title?.text ?? ""
                        let subtitle = twoRow.subtitle?.text ?? ""
                        let thumbUrl = twoRow.thumbnailRenderer?.musicThumbnailRenderer?.thumbnails?.last?.url ?? ""
                        let browseId = twoRow.navigationEndpoint?.browseEndpoint?.browseId
                        let videoId = twoRow.navigationEndpoint?.watchEndpoint?.videoId
                        
                        items.append(BrowseItem(
                            id: browseId ?? videoId ?? "",
                            title: itemTitle,
                            subtitle: subtitle,
                            thumbnailUrl: thumbUrl,
                            type: browseId != nil ? .playlist : .song
                        ))
                    }
                    
                    if let listItem = item.musicResponsiveListItemRenderer {
                        if let result = parseSearchItem(listItem) {
                            items.append(BrowseItem(
                                id: result.id,
                                title: result.title,
                                subtitle: result.artist,
                                thumbnailUrl: result.thumbnailUrl,
                                type: .song
                            ))
                        }
                    }
                }
                
                sections.append(BrowseSection(title: title, items: items))
            }
            
            // Handle music shelves (vertical lists)
            if let shelf = sectionContent.musicShelfRenderer {
                let title = shelf.title?.text ?? "Untitled"
                var items: [BrowseItem] = []
                
                for item in shelf.contents ?? [] {
                    if let renderer = item.musicResponsiveListItemRenderer {
                        if let result = parseSearchItem(renderer) {
                            items.append(BrowseItem(
                                id: result.id,
                                title: result.title,
                                subtitle: result.artist,
                                thumbnailUrl: result.thumbnailUrl,
                                type: .song
                            ))
                        }
                    }
                }
                
                sections.append(BrowseSection(title: title, items: items))
            }
        }
        
        return sections
    }
}

// MARK: - Custom Errors

/// Errors that can occur when using the InnerTube API
enum InnerTubeError: Error, LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingFailed(Error)
    case videoUnplayable(reason: String)
    case noVideoDetails
    case noStreamingData
    case noAudioStream
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error \(statusCode)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .videoUnplayable(let reason):
            return "Video is unplayable: \(reason)"
        case .noVideoDetails:
            return "No video details in response"
        case .noStreamingData:
            return "No streaming data in response"
        case .noAudioStream:
            return "No audio stream found"
        }
    }
}
