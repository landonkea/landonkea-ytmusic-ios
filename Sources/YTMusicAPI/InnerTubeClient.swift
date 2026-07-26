import Foundation

/// The main client for talking to YouTube's InnerTube API
/// Based on Metrolist's approach - uses WEB_REMIX for most operations
/// All methods are async and return parsed Swift objects
class InnerTubeClient {
    
    // MARK: - Properties
    
    /// Base URL for all InnerTube API requests (YouTube Music)
    private let baseURL = "https://music.youtube.com/youtubei/v1"
    
    /// API key (obtained from YouTube's web app - this is public, not a secret)
    private let apiKey = "AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30"
    
    /// URL session for making HTTP requests
    private let session: URLSession
    
    /// Visitor data (obtained from YouTube, used for tracking)
    private var visitorData: String?
    
    /// Cookie for authentication (optional - only needed for logged-in features)
    private var cookie: String?
    
    // MARK: - Client Configurations
    
    /// WEB_REMIX - The main YouTube Music web client
    /// Used for: search, browse, get suggestions
    /// This is what the YouTube Music website uses
    private let webRemixClient = YouTubeClient(
        clientName: "WEB_REMIX",
        clientVersion: "1.20260114.03.00",
        clientId: "67",
        userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0",
        loginSupported: true
    )
    
    /// IOS - The iOS YouTube client
    /// Used for: player (getting streaming URLs)
    /// This pretends to be the official iOS YouTube app
    private let iosClient = YouTubeClient(
        clientName: "IOS",
        clientVersion: "21.03.1",
        clientId: "5",
        userAgent: "com.google.ios.youtube/21.03.1 (iPhone16,2; U; CPU iOS 18_2 like Mac OS X;)",
        osVersion: "18.2.22C152",
        loginSupported: false
    )
    
    /// TVHTML5 - TV client (fallback for player)
    /// Used when IOS client fails
    private let tvClient = YouTubeClient(
        clientName: "TVHTML5",
        clientVersion: "7.20260114.12.00",
        clientId: "7",
        userAgent: "Mozilla/5.0 (ChromiumStylePlatform) Cobalt/25.lts.30.1034943-gold (unlike Gecko), Unknown_TV_Unknown_0/Unknown (Unknown, Unknown)",
        loginSupported: true
    )
    
    // MARK: - Initialization
    
    /// Create a new InnerTube client
    /// - Parameter session: URL session to use (for testing, you can pass a mock)
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - Search
    
    /// Search for songs, albums, artists, or playlists
    /// - Parameter query: The search term (e.g. "Bohemian Rhapsody")
    /// - Returns: Array of search result items
    func search(query: String) async throws -> [SearchResult] {
        // Build the request body with WEB_REMIX client
        let body = SearchBody(
            context: webRemixClient.toContext(visitorData: visitorData),
            query: query
        )
        
        // Make the request to YouTube
        let response: SearchResponse = try await POST(
            endpoint: "/search",
            client: webRemixClient,
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
        // Try IOS client first (best for audio)
        do {
            return try await getPlayerWithClient(videoId: videoId, client: iosClient)
        } catch {
            // If IOS fails, try TV client as fallback
            print("IOS client failed, trying TV client: \(error)")
            return try await getPlayerWithClient(videoId: videoId, client: tvClient)
        }
    }
    
    /// Get player info with a specific client
    private func getPlayerWithClient(videoId: String, client: YouTubeClient) async throws -> PlayerInfo {
        let body = PlayerBody(
            context: client.toContext(visitorData: visitorData),
            videoId: videoId
        )
        
        let response: PlayerResponse = try await POST(
            endpoint: "/player",
            client: client,
            body: body
        )
        
        return try parsePlayerInfo(from: response)
    }
    
    // MARK: - Browse (Home, Trending, etc.)
    
    /// Browse a YouTube Music page (home, trending, charts, etc.)
    /// - Parameter browseId: The browse ID (e.g. "FEmusic_home" for home)
    /// - Returns: Array of content sections
    func browse(browseId: String, params: String? = nil) async throws -> [BrowseSection] {
        let body = BrowseBody(
            context: webRemixClient.toContext(visitorData: visitorData),
            browseId: browseId,
            params: params
        )
        
        let response: BrowseResponse = try await POST(
            endpoint: "/browse",
            client: webRemixClient,
            body: body
        )
        
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
        let body = GetSearchSuggestionsBody(
            context: webRemixClient.toContext(visitorData: visitorData),
            input: query
        )
        
        let response: GetSearchSuggestionsResponse = try await POST(
            endpoint: "/music/get_search_suggestions",
            client: webRemixClient,
            body: body
        )
        
        // Parse suggestions from response
        return response.contents?
            .first?
            .searchSuggestionsSectionRenderer?
            .contents?
            .compactMap { $0.searchSuggestionRenderer?.suggestion?.runs?.map(\.text).joined() }
            ?? []
    }
    
    // MARK: - Private Helpers
    
    /// Make a POST request to an InnerTube endpoint
    /// - Parameters:
    ///   - endpoint: The API endpoint (e.g. "/search")
    ///   - client: The YouTube client to use
    ///   - body: The request body
    /// - Returns: The decoded response
    private func POST<T: Decodable>(endpoint: String, client: YouTubeClient, body: some Encodable) async throws -> T {
        // Build the URL with API key
        let urlString = "\(baseURL)\(endpoint)?key=\(apiKey)&prettyPrint=false"
        let url = URL(string: urlString)!
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        
        // Add the special headers that YouTube expects
        request.addValue("1", forHTTPHeaderField: "X-Goog-Api-Format-Version")
        request.addValue(client.clientId, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.addValue(client.clientVersion, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.addValue("https://music.youtube.com", forHTTPHeaderField: "X-Origin")
        request.addValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        
        // Add visitor data if we have it
        if let visitorData = visitorData {
            request.addValue(visitorData, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }
        
        // Add cookie if we have it (for logged-in features)
        if let cookie = cookie {
            request.addValue(cookie, forHTTPHeaderField: "Cookie")
        }
        
        // Encode the body to JSON
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        request.httpBody = try encoder.encode(body)
        
        // Make the request with retry logic
        return try await withRetry(maxAttempts: 3) {
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
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.allowsLossyConversion = true
            
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                // If decoding fails, print the raw JSON for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Raw JSON response (first 1000 chars): \(jsonString.prefix(1000))")
                }
                throw InnerTubeError.decodingFailed(error)
            }
        }
    }
    
    /// Retry logic with exponential backoff
    private func withRetry<T>(maxAttempts: Int, initialDelay: TimeInterval = 0.5, block: () async throws -> T) async throws -> T {
        var currentDelay = initialDelay
        var lastError: Error?
        
        for attempt in 0..<maxAttempts {
            do {
                return try await block()
            } catch let error as InnerTubeError {
                // Don't retry client errors (bad request, etc.)
                if case .httpError(let statusCode) = error, (400...499).contains(statusCode) {
                    throw error
                }
                lastError = error
                
                if attempt < maxAttempts - 1 {
                    try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                    currentDelay *= 2 // Exponential backoff
                }
            } catch {
                lastError = error
                if attempt < maxAttempts - 1 {
                    try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                    currentDelay *= 2
                }
            }
        }
        
        throw lastError ?? InnerTubeError.invalidResponse
    }
    
    // MARK: - Response Parsers
    
    /// Parse search results from the raw response
    private func parseSearchResults(from response: SearchResponse) -> [SearchResult] {
        var results: [SearchResult] = []
        
        // Navigate the nested response structure
        guard let tabs = response.contents?.tabbedSearchResultsRenderer?.tabs else {
            return results
        }
        
        // Get the first tab (usually "All")
        guard let tabContent = tabs.first?.tabRenderer?.content?.sectionListRenderer?.contents else {
            return results
        }
        
        // Look for music shelves (lists of songs)
        for section in tabContent {
            if let shelf = section.musicShelfRenderer,
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
    private func parsePlayerInfo(from response: PlayerResponse) throws -> PlayerInfo {
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
    private func parseBrowseSections(from response: BrowseResponse) -> [BrowseSection] {
        var sections: [BrowseSection] = []
        
        guard let contents = response.contents else { return sections }
        
        // Navigate to the section list
        let sectionList = contents.singleColumnBrowseResultsRenderer?.tabs?.first?.tabRenderer?.content?.sectionListRenderer
        
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

// MARK: - Client Configuration

/// Configuration for a YouTube client type
struct YouTubeClient {
    let clientName: String
    let clientVersion: String
    let clientId: String
    let userAgent: String
    let osVersion: String?
    let loginSupported: Bool
    
    /// Convert this client to a context object for API requests
    func toContext(visitorData: String? = nil) -> InnerTubeContext {
        InnerTubeContext(
            client: InnerTubeClientInfo(
                clientName: clientName,
                clientVersion: clientVersion,
                deviceMake: "Apple",
                deviceModel: "iPhone16,2",
                hl: "en",
                gl: "US",
                osName: "iPhone",
                osVersion: osVersion ?? "18.2.0",
                userAgent: userAgent,
                visitorData: visitorData
            )
        )
    }
}

// MARK: - Request Body Models

/// Request body for search
struct SearchBody: Codable {
    let context: InnerTubeContext
    let query: String
}

/// Request body for player
struct PlayerBody: Codable {
    let context: InnerTubeContext
    let videoId: String
}

/// Request body for browse
struct BrowseBody: Codable {
    let context: InnerTubeContext
    let browseId: String
    let params: String?
}

/// Request body for search suggestions
struct GetSearchSuggestionsBody: Codable {
    let context: InnerTubeContext
    let input: String
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
