import Foundation

/// Client for fetching song lyrics from lrclib.net.
///
/// lrclib.net is a free, open-source lyrics API that:
/// - Requires NO authentication (no API key needed)
/// - Returns both plain text and synced (timestamped) lyrics
/// - Has a large database of songs
///
/// API ENDPOINTS USED:
/// - `GET /api/get?track_name=X&artist_name=Y` — exact match lookup
/// - `GET /api/search?q=X` — fuzzy search (used as fallback)
///
/// NO LOGIN REQUIRED — this works completely anonymously.
class LyricsClient {
    
    // MARK: - Properties
    
    /// Base URL for the lrclib.net API
    private let baseURL = "https://lrclib.net/api"
    
    /// URL session for making HTTP requests
    private let session: URLSession
    
    // MARK: - Initialization
    
    /// Create a new lyrics client.
    ///
    /// - Parameter session: URL session to use (for testing, pass a mock)
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - Public Methods
    
    /// Fetch lyrics for a song by track name and artist.
    ///
    /// First tries an exact match (`/api/get`), then falls back to search (`/api/search`).
    ///
    /// - Parameters:
    ///   - trackName: Song title (e.g. "Bohemian Rhapsody")
    ///   - artistName: Artist name (e.g. "Queen")
    /// - Returns: Lyrics data with plain and/or synced lyrics, or nil if not found
    func fetchLyrics(trackName: String, artistName: String) async -> Lyrics? {
        // Step 1: Try exact match (faster, more accurate)
        if let lyrics = await fetchExactMatch(trackName: trackName, artistName: artistName) {
            return lyrics
        }
        
        // Step 2: Fall back to search (handles slight name differences)
        return await searchLyrics(query: "\(trackName) \(artistName)")
    }
    
    // MARK: - Private Methods
    
    /// Try to get an exact match for the song.
    ///
    /// Uses the `/api/get` endpoint which returns a single result
    /// if the track name and artist match exactly.
    private func fetchExactMatch(trackName: String, artistName: String) async -> Lyrics? {
        // Build the URL with query parameters
        // `.addingPercentEncoding` converts spaces to %20 for valid URLs
        guard let trackEncoded = trackName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let artistEncoded = artistName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        let urlString = "\(baseURL)/get?track_name=\(trackEncoded)&artist_name=\(artistEncoded)"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            // Check for HTTP errors (404 = not found, which is expected for some songs)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            // Decode the response
            let lrclibResponse = try JSONDecoder().decode(LrclibResponse.self, from: data)
            return lrclibResponse.toLyrics()
        } catch {
            print("Lyrics exact match failed: \(error)")
            return nil
        }
    }
    
    /// Search for lyrics using a query string.
    ///
    /// Uses the `/api/search` endpoint which returns multiple results.
    /// We take the first result as the best match.
    private func searchLyrics(query: String) async -> Lyrics? {
        guard let queryEncoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        let urlString = "\(baseURL)/search?q=\(queryEncoded)"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            // Search returns an array of results — take the first one
            let results = try JSONDecoder().decode([LrclibResponse].self, from: data)
            return results.first?.toLyrics()
        } catch {
            print("Lyrics search failed: \(error)")
            return nil
        }
    }
}

// MARK: - lrclib.net Response Models

/// The JSON response from lrclib.net's API.
///
/// Fields:
/// - `trackName`: Song title
/// - `artistName`: Artist name
/// - `plainLyrics`: Full lyrics as plain text (newlines between lines)
/// - `syncedLyrics`: Lyrics with timestamps in `[MM:SS.xx]` format (optional)
struct LrclibResponse: Codable {
    let trackName: String?
    let artistName: String?
    let plainLyrics: String?
    let syncedLyrics: String?
    
    /// Convert to our app's Lyrics model.
    ///
    /// Returns nil if there are no lyrics at all (both plain and synced are nil/empty).
    func toLyrics() -> Lyrics? {
        // Need at least plain lyrics to be useful
        guard let plainText = plainLyrics, !plainText.isEmpty else {
            return nil
        }
        
        // Parse synced lyrics if available
        let syncedLines = syncedLyrics.flatMap { parseSyncedLyrics($0) }
        
        return Lyrics(
            trackName: trackName ?? "Unknown",
            artistName: artistName ?? "Unknown",
            plainText: plainText,
            syncedLines: syncedLines
        )
    }
    
    /// The regex pattern that matches one synced-lyrics line, e.g.
    /// `"[00:25.29] I'm just a poor boy"`.
    ///
    /// Regex explanation (a "regular expression" is a mini pattern-matching
    /// language for finding/extracting pieces of text):
    /// \[        = literal opening bracket
    /// (\d{2})   = 2 digits for minutes (captured — "captured" means this
    ///             piece gets remembered so we can pull it out afterward)
    /// :         = literal colon
    /// (\d{2})   = 2 digits for seconds (captured)
    /// \.(\d+)   = dot followed by digits for milliseconds (captured)
    /// \]        = literal closing bracket
    /// (.*)      = the rest of the line (the lyrics text, captured)
    ///
    /// This is declared once as a `static let` (shared by all instances,
    /// computed only the first time it's needed) instead of being rebuilt
    /// inside the per-line loop below — compiling a regex pattern has a
    /// real cost, and re-doing it for every single lyric line would be
    /// wasteful when the pattern never changes.
    private static let syncedLinePattern = try? NSRegularExpression(
        pattern: #"\[(\d{2}):(\d{2})\.(\d+)\](.*)"#
    )

    /// Parse synced lyrics from the `[MM:SS.xx] line text` format.
    ///
    /// Splits the raw multi-line string into individual lines, then hands
    /// each one to `parseSyncedLine(_:)` to do the actual pattern matching.
    /// Keeping the "loop over lines" logic separate from the "parse one
    /// line" logic makes each function easier to read and test on its own.
    ///
    /// Returns nil if no lines could be parsed (e.g. if the format is
    /// completely unexpected).
    private func parseSyncedLyrics(_ text: String) -> [SyncedLine]? {
        // `compactMap` transforms each element and drops any nil results —
        // exactly what we want here, since parseSyncedLine returns nil for
        // lines that don't match the expected timestamp format.
        let lines = text
            .components(separatedBy: .newlines)
            .compactMap { parseSyncedLine($0) }

        return lines.isEmpty ? nil : lines
    }

    /// Parse a single line of synced lyrics, e.g. `"[00:25.29] I'm just a poor boy"`.
    ///
    /// - Returns: A `SyncedLine` with the timestamp converted to seconds,
    ///   or nil if this line doesn't match the expected format (blank line,
    ///   header line, malformed timestamp, etc.).
    private func parseSyncedLine(_ rawLine: String) -> SyncedLine? {
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Run the shared regex against this one line. `NSRange(trimmed.startIndex..., in: trimmed)`
        // converts Swift's native String range into the legacy NSString-style
        // range that NSRegularExpression (an Objective-C-based API) expects.
        guard let regex = Self.syncedLinePattern,
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) else {
            return nil
        }

        // Pull out the 4 captured groups (minutes, seconds, milliseconds, text).
        // `match.range(at:)` gives an NSRange; `Range(_:in:)` converts that
        // back into a Swift String range so we can subscript `trimmed` with it.
        guard let minutesRange = Range(match.range(at: 1), in: trimmed),
              let secondsRange = Range(match.range(at: 2), in: trimmed),
              let msRange = Range(match.range(at: 3), in: trimmed),
              let textRange = Range(match.range(at: 4), in: trimmed) else {
            return nil
        }

        let minutes = Double(trimmed[minutesRange]) ?? 0
        let seconds = Double(trimmed[secondsRange]) ?? 0
        let milliseconds = Double(trimmed[msRange]) ?? 0

        // Calculate total seconds: minutes×60 + seconds + milliseconds/1000.
        // The milliseconds group can be 2 or 3 digits (".29" vs ".290"), so
        // we divide by 10^(digit count) rather than a fixed 1000 to scale
        // it correctly either way.
        let time = minutes * 60 + seconds + milliseconds / pow(10, Double(trimmed[msRange].count))

        let lineText = String(trimmed[textRange]).trimmingCharacters(in: .whitespaces)

        // Skip empty lines (instrumental breaks have a timestamp but no text)
        guard !lineText.isEmpty else { return nil }

        return SyncedLine(time: time, text: lineText)
    }
}

// MARK: - Lyrics Models

/// Lyrics data for a song.
///
/// Contains both plain text lyrics (always available if the song has lyrics)
/// and optionally synced (timestamped) lyrics for karaoke-style display.
struct Lyrics {
    /// Song title (from the lyrics API, may differ slightly from YouTube's title)
    let trackName: String
    /// Artist name (from the lyrics API)
    let artistName: String
    /// Full lyrics as plain text, with newlines between lines
    let plainText: String
    /// Synced lyrics with timestamps (nil if not available)
    /// When available, allows karaoke-style highlighting that follows playback
    let syncedLines: [SyncedLine]?
    
    /// Whether synced (timestamped) lyrics are available
    var hasSyncedLyrics: Bool {
        return syncedLines != nil && !(syncedLines?.isEmpty ?? true)
    }
}

/// A single line of synced lyrics with a timestamp.
///
/// The timestamp indicates when this line should be highlighted
/// during playback (karaoke-style).
struct SyncedLine {
    /// When this line starts, in seconds (e.g. 25.29 = 25 seconds and 290ms)
    let time: Double
    /// The lyrics text for this line
    let text: String
}
