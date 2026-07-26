import Foundation

/// All the data structures needed to talk to YouTube's InnerTube API
/// These match the JSON format that YouTube's servers expect and return

// MARK: - Request Models

/// The context object that every InnerTube request needs
/// It tells YouTube which "client" we're pretending to be
struct InnerTubeContext: Codable {
    let client: InnerTubeClient
}

/// Information about which YouTube client we're impersonating
struct InnerTubeClient: Codable {
    let clientName: String      // e.g. "IOS_MUSIC"
    let clientVersion: String   // e.g. "7.27.0"
    let deviceMake: String      // e.g. "Apple"
    let deviceModel: String     // e.g. "iPhone16,2"
    let hl: String              // language, e.g. "en"
    let gl: String              // country, e.g. "US"
    let osName: String          // e.g. "iPhone"
    let osVersion: String       // e.g. "18.2.0"
    let userAgent: String       // browser/device user agent string
}

/// The full request body we send to InnerTube
struct InnerTubeRequest: Codable {
    let context: InnerTubeContext
    let query: String?              // for search requests
    let browseId: String?           // for browse requests (home, trending, etc.)
    let videoId: String?            // for player requests
    let playlistId: String?         // for playlist requests
    let params: String?             // additional parameters (pagination, filters)
    
    // Custom encoding so we only include non-nil values
    enum CodingKeys: String, CodingKey {
        case context, query, browseId, videoId, playlistId, params
    }
}

// MARK: - Response Models

/// The full response from InnerTube
struct InnerTubeResponse: Codable {
    let contents: ResponseContents?
    let playabilityStatus: PlayabilityStatus?
    let streamingData: StreamingData?
    let videoDetails: VideoDetails?
    let contents2: ResponseContents?  // some responses use "contents" differently
    
    // Custom key mapping for responses that nest differently
    enum CodingKeys: String, CodingKey {
        case contents, playabilityStatus, streamingData, videoDetails
        case contents2 = "contents"
    }
}

/// Container for different types of content in a response
struct ResponseContents: Codable {
    let singleColumnSearchResultsRenderer: SingleColumnSearchResults?
    let sectionListRenderer: SectionListRenderer?
    let tabRenderer: TabRenderer?
}

/// Search results wrapper
struct SingleColumnSearchResults: Codable {
    let contents: [SearchContent]?
}

/// A single content item from search or browse
struct SearchContent: Codable {
    let musicShelfRenderer: MusicShelfRenderer?
    let musicResponsiveListItemRenderer: MusicResponsiveListItemRenderer?
    let sectionListRenderer: SectionListRenderer?
}

/// A shelf/section of music items
struct MusicShelfRenderer: Codable {
    let title: TextRun?
    let contents: [MusicItem]?
}

/// Individual music item (song, album, artist, etc.)
struct MusicItem: Codable {
    let musicResponsiveListItemRenderer: MusicResponsiveListItemRenderer?
}

/// A music list item with full details
struct MusicResponsiveListItemRenderer: Codable {
    let flexColumns: [FlexColumn]?
    let thumbnail: ThumbnailContainer?
    let overlay: ItemOverlay?
    let navigationEndpoint: NavigationEndpoint?
}

/// A flexible column in the list item layout
struct FlexColumn: Codable {
    let musicResponsiveListItemFlexColumnRenderer: FlexColumnRenderer?
}

/// The actual content of a flex column
struct FlexColumnRenderer: Codable {
    let text: TextRun?
}

/// Text that can be either a simple string or a run of text
struct TextRun: Codable {
    let runs: [Run]?       // array of text segments
    let simpleText: String? // or just a plain string
    
    /// Convenience to get the full text as a single string
    var text: String {
        if let simpleText = simpleText {
            return simpleText
        }
        return runs?.map(\.text).joined() ?? ""
    }
}

/// A single segment of text (can have different styles)
struct Run: Codable {
    let text: String
}

// MARK: - Navigation

/// Tells the app where to go when something is tapped
struct NavigationEndpoint: Codable {
    let watchEndpoint: WatchEndpoint?
    let browseEndpoint: BrowseEndpoint?
}

/// Endpoint for watching/playing a video
struct WatchEndpoint: Codable {
    let videoId: String?
    let playlistId: String?
    let index: Int?
}

/// Endpoint for browsing a page
struct BrowseEndpoint: Codable {
    let browseId: String?
    let params: String?
}

// MARK: - Thumbnails

/// Container for thumbnail images
struct ThumbnailContainer: Codable {
    let musicThumbnailRenderer: MusicThumbnailRenderer?
}

/// The actual thumbnail with its images
struct MusicThumbnailRenderer: Codable {
    let thumbnails: [Thumbnail]?
}

/// A single thumbnail image at a specific size
struct Thumbnail: Codable {
    let url: String
    let width: Int
    let height: Int
}

// MARK: - Overlay (for badges, duration, etc.)

/// Overlay info on top of an item (like duration badge)
struct ItemOverlay: Codable {
    let musicItemThumbnailOverlayRenderer: MusicItemThumbnailOverlayRenderer?
}

/// The overlay content
struct MusicItemThumbnailOverlayRenderer: Codable {
    let content: OverlayContent?
}

/// What's in the overlay (usually a duration or badge)
struct OverlayContent: Codable {
    let musicResponsiveListItemOverlayLayout: OverlayLayout?
}

/// Layout of the overlay
struct OverlayLayout: Codable {
    let musicDurationText: TextRun?
}

// MARK: - Section List (for browse/home)

/// A list of sections on a page
struct SectionListRenderer: Codable {
    let contents: [SectionContent]?
}

/// A single section
struct SectionContent: Codable {
    let musicShelfRenderer: MusicShelfRenderer?
    let musicCarouselShelfRenderer: MusicCarouselShelfRenderer?
}

/// A horizontal carousel of music items (like "Trending" row)
struct MusicCarouselShelfRenderer: Codable {
    let header: CarouselHeader?
    let contents: [CarouselItem]?
}

/// Header for a carousel section
struct CarouselHeader: Codable {
    let musicCarouselShelfBasicHeaderRenderer: CarouselHeaderRenderer?
}

/// The actual header content
struct CarouselHeaderRenderer: Codable {
    let title: TextRun?
}

/// A single item in a carousel
struct CarouselItem: Codable {
    let musicResponsiveListItemRenderer: MusicResponsiveListItemRenderer?
    let musicTwoRowItemRenderer: MusicTwoRowItemRenderer?
}

/// A two-row item (used for albums, playlists)
struct MusicTwoRowItemRenderer: Codable {
    let thumbnailRenderer: ThumbnailContainer?
    let title: TextRun?
    let navigationEndpoint: NavigationEndpoint?
    let subtitle: TextRun?
}

// MARK: - Tab Renderer (for home screen tabs)

/// A tab on the home screen
struct TabRenderer: Codable {
    let content: TabContent?
}

/// Content inside a tab
struct TabContent: Codable {
    let sectionListRenderer: SectionListRenderer?
}

// MARK: - Playability

/// Status of whether a video can be played
struct PlayabilityStatus: Codable {
    let status: String          // "OK", "UNPLAYABLE", etc.
    let reason: String?         // why it can't be played
}

// MARK: - Streaming Data

/// Contains the actual audio/video stream URLs
struct StreamingData: Codable {
    let formats: [StreamFormat]?          // combined audio+video
    let adaptiveFormats: [StreamFormat]?  // separate audio/video streams
    let expiresInSeconds: String?         // how long URLs are valid
}

/// A single stream format (audio or video)
struct StreamFormat: Codable {
    let itag: Int                    // format identifier
    let url: String?                 // direct URL to stream
    let mimeType: String             // e.g. "audio/mp4; codecs=\"mp4a.40.2\""
    let bitrate: Int                 // bits per second
    let width: Int?                  // video width (nil for audio)
    let height: Int?                 // video height (nil for audio)
    let contentLength: String?       // file size in bytes
    let approxDurationMs: String?    // duration in milliseconds
    
    /// Whether this is an audio-only stream
    var isAudio: Bool {
        return mimeType.contains("audio")
    }
    
    /// Whether this is a video stream
    var isVideo: Bool {
        return mimeType.contains("video")
    }
    
    /// Get the audio quality description
    var audioQuality: String {
        if bitrate >= 256000 { return "High" }
        if bitrate >= 128000 { return "Medium" }
        return "Low"
    }
}

// MARK: - Video Details

/// Basic information about a video
struct VideoDetails: Codable {
    let videoId: String
    let title: String
    let lengthSeconds: String       // duration in seconds
    let channelId: String
    let author: String              // channel/artist name
    let viewCount: String
    let shortDescription: String?
    let thumbnail: VideoThumbnail?
}

/// Thumbnails for a video
struct VideoThumbnail: Codable {
    let thumbnails: [Thumbnail]?
}

// MARK: - Browse Response (for home screen)

/// Response from a browse request (home, trending, library)
struct BrowseResponse: Codable {
    let contents: BrowseContents?
}

/// Contents of a browse response
struct BrowseContents: Codable {
    let singleColumnBrowseResultsRenderer: SingleColumnBrowseResults?
}

/// Single column browse results
struct SingleColumnBrowseResults: Codable {
    let tabs: [BrowseTab]?
}

/// A tab in browse results
struct BrowseTab: Codable {
    let tabRenderer: TabRenderer?
}

// MARK: - Search Response

/// Response from a search request
struct SearchResponse: Codable {
    let contents: SearchContents?
}

/// Contents of search results
struct SearchContents: Codable {
    let tabbedSearchResultsRenderer: TabbedSearchResults?
}

/// Tabbed search results (All, Songs, Videos, Albums, etc.)
struct TabbedSearchResults: Codable {
    let tabs: [SearchTab]?
}

/// A single search tab
struct SearchTab: Codable {
    let tabRenderer: TabRenderer?
}
