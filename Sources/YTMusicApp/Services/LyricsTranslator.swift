import Foundation

// MARK: - Lyrics Translator

/// Translates lyrics text to another language using a free translation API.
///
/// WHAT THIS DOES:
/// Takes lyrics text (either a single string or synced lines) and translates
/// them to the target language. Users can toggle between original and translated
/// lyrics while listening to a song.
///
/// TRANSLATION API:
/// Uses MyMemory (mymemory.translated.net) — a free, no-auth translation API.
/// It's based on Google Translate and other open-source translation engines.
/// Rate limit: 5000 characters/day for anonymous users (enough for ~10 songs).
///
/// HOW IT WORKS:
/// 1. User taps "Translate" in the lyrics view
/// 2. We send the lyrics text to the translation API
/// 3. API returns translated text
/// 4. We display the translated lyrics (or toggle between original/translated)
///
/// LIMITATIONS:
/// - Free API has daily character limits
/// - Song lyrics may not translate perfectly (poetic language, slang)
/// - Synced timestamps are preserved (we translate text, not timing)
class LyricsTranslator: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether a translation is currently in progress
    @Published var isTranslating = false
    
    /// The translated lyrics text (nil if not yet translated)
    @Published var translatedText: String?
    
    /// Error message if translation failed
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    /// The base URL for the MyMemory translation API
    private let apiBase = "https://api.mymemory.translated.net/get"
    
    // MARK: - Public Methods
    
    /// Translate lyrics text to the target language.
    ///
    /// - Parameters:
    ///   - text: The lyrics text to translate
    ///   - from: Source language code (e.g. "en" for English)
    ///   - to: Target language code (e.g. "es" for Spanish, "ja" for Japanese)
    func translate(_ text: String, from sourceLang: String = "en", to targetLang: String) {
        // Don't translate if already translating or text is empty
        guard !isTranslating, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isTranslating = true
        errorMessage = nil
        translatedText = nil
        
        Task {
            do {
                let translated = try await translateText(text, from: sourceLang, to: targetLang)
                await MainActor.run {
                    self.translatedText = translated
                    self.isTranslating = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Translation failed: \(error.localizedDescription)"
                    self.isTranslating = false
                }
            }
        }
    }
    
    /// Translate synced lyrics (preserving line structure).
    ///
    /// - Parameters:
    ///   - lines: Array of synced lyric lines with timestamps
    ///   - from: Source language code
    ///   - to: Target language code
    /// - Returns: Array of translated lines with same timestamps
    func translateSyncedLines(
        _ lines: [SyncedLine],
        from sourceLang: String = "en",
        to targetLang: String
    ) async -> [SyncedLine] {
        // Combine all line texts into one string (separated by newlines)
        // This is more efficient than translating each line individually
        let combinedText = lines.map(\.text).joined(separator: "\n")
        
        do {
            let translated = try await translateText(combinedText, from: sourceLang, to: targetLang)
            
            // Split the translated text back into lines
            let translatedLines = translated.components(separatedBy: "\n")
            
            // Re-pair with original timestamps
            // If translation produced more/fewer lines, pad or truncate
            return lines.enumerated().map { index, line in
                let text: String
                if index < translatedLines.count {
                    text = translatedLines[index]
                } else {
                    // Fallback to original text if translation is shorter
                    text = line.text
                }
                return SyncedLine(time: line.time, text: text)
            }
        } catch {
            // On error, return original lines unchanged
            print("Translation failed: \(error)")
            return lines
        }
    }
    
    /// Clear the current translation.
    func clearTranslation() {
        translatedText = nil
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    /// Call the MyMemory translation API.
    ///
    /// - Parameters:
    ///   - text: Text to translate
    ///   - from: Source language code (e.g. "en")
    ///   - to: Target language code (e.g. "es")
    /// - Returns: Translated text string
    private func translateText(_ text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        // URL-encode the text for the query parameter
        guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw TranslationError.encodingFailed
        }
        
        // Build the full URL with query parameters
        let urlString = "\(apiBase)?q=\(encodedText)&langpair=\(sourceLang)|\(targetLang)"
        
        guard let url = URL(string: urlString) else {
            throw TranslationError.invalidURL
        }
        
        // Make the HTTP request
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Check for HTTP errors
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TranslationError.apiError
        }
        
        // Parse the JSON response
        let result = try JSONDecoder().decode(TranslationResponse.self, from: data)
        
        // Check if the translation was successful
        guard result.responseStatus == 200,
              let translatedText = result.responseData?.translatedText else {
            throw TranslationError.noResult
        }
        
        return translatedText
    }
    
    // MARK: - Supported Languages
    
    /// Available target languages for translation.
    /// Each entry is (language code, display name).
    static let supportedLanguages: [(code: String, name: String, flag: String)] = [
        ("en", "English", "🇺🇸"),
        ("es", "Spanish", "🇪🇸"),
        ("fr", "French", "🇫🇷"),
        ("de", "German", "🇩🇪"),
        ("it", "Italian", "🇮🇹"),
        ("pt", "Portuguese", "🇧🇷"),
        ("ja", "Japanese", "🇯🇵"),
        ("ko", "Korean", "🇰🇷"),
        ("zh", "Chinese", "🇨🇳"),
        ("ru", "Russian", "🇷🇺"),
        ("ar", "Arabic", "🇸🇦"),
        ("hi", "Hindi", "🇮🇳"),
        ("tr", "Turkish", "🇹🇷"),
        ("nl", "Dutch", "🇳🇱"),
        ("sv", "Swedish", "🇸🇪")
    ]
}

// MARK: - API Response Models

/// Response from the MyMemory translation API.
struct TranslationResponse: Codable {
    let responseData: TranslationData?
    let responseStatus: Int
}

/// The actual translation data in the response.
struct TranslationData: Codable {
    let translatedText: String
    let match: Double?
}

// MARK: - Translation Errors

/// Errors that can occur during translation.
enum TranslationError: Error, LocalizedError {
    case encodingFailed
    case invalidURL
    case apiError
    case noResult
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode text for translation"
        case .invalidURL:
            return "Invalid translation URL"
        case .apiError:
            return "Translation API returned an error"
        case .noResult:
            return "No translation result returned"
        }
    }
}
