import Foundation
import SwiftUI

// MARK: - Search History Manager

/// Manages the user's search history — saving, loading, and clearing past searches.
///
/// RESPONSIBILITIES:
/// - Save search queries when the user performs a search
/// - Load history from disk on app launch
/// - Provide history to the search view for display
/// - Allow clearing individual entries or all history
///
/// STORAGE:
/// - Uses a JSON file in the Documents directory
/// - Limited to 20 entries to keep the list manageable
/// - Most recent searches appear first
///
/// HOW IT WORKS:
/// When the user performs a search, SearchView calls addSearch().
/// This method prepends the query to the list, removes duplicates,
/// trims to 20 entries, and saves to disk. The search view reads
/// `searches` to display recent searches when the search bar is focused.
class SearchHistoryManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The list of recent search queries, most recent first.
    /// Views observe this and re-render when it changes.
    @Published var searches: [String] = []
    
    // MARK: - Private Properties
    
    /// Maximum number of search queries to keep.
    /// 20 is enough to show a useful history without cluttering the UI.
    private let maxSearches = 20
    
    /// File path for persisting search history as JSON.
    private let historyPath: URL
    
    // MARK: - Initialization
    
    /// Create the manager and load existing history from disk.
    ///
    /// Sets up the file path and calls loadHistory() to populate
    /// the `searches` array from the JSON file.
    init() {
        // Get the Documents directory — this is where iOS apps store user data
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.historyPath = documents.appendingPathComponent("search_history.json")
        
        // Load any existing history from disk
        loadHistory()
    }
    
    // MARK: - Public Methods
    
    /// Add a search query to the history.
    ///
    /// - Parameter query: The search text to save
    ///
    /// BEHAVIOR:
    /// 1. Trims whitespace and ignores empty queries
    /// 2. Removes the query if it already exists (to move it to the top)
    /// 3. Prepends the new query (most recent first)
    /// 4. Trims to maxSearches (removes oldest entries)
    /// 5. Saves to disk
    func addSearch(_ query: String) {
        // Trim whitespace — don't save empty or whitespace-only searches
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Remove duplicate if it exists (case-insensitive)
        // This moves the query to the top when searched again
        searches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        
        // Add to the beginning (most recent first)
        searches.insert(trimmed, at: 0)
        
        // Trim to max size — remove oldest entries
        if searches.count > maxSearches {
            searches = Array(searches.prefix(maxSearches))
        }
        
        // Save to disk
        saveHistory()
    }
    
    /// Remove a single search query from the history.
    ///
    /// - Parameter query: The exact query string to remove
    func removeSearch(_ query: String) {
        // Remove all case-insensitive matches
        searches.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
        saveHistory()
    }
    
    /// Clear all search history.
    ///
    /// Called when the user taps "Clear All" in the search view.
    func clearHistory() {
        searches = []
        saveHistory()
    }
    
    // MARK: - Private Methods
    
    /// Save the current search history to disk as JSON.
    ///
    /// Uses JSONEncoder to convert the [String] array to Data,
    /// then writes it to the history file. If encoding fails,
    /// we log the error but don't crash — history is nice-to-have.
    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(searches)
            try data.write(to: historyPath)
        } catch {
            print("Failed to save search history: \(error)")
        }
    }
    
    /// Load search history from disk.
    ///
    /// Reads the JSON file and decodes it back to [String].
    /// If the file doesn't exist or decoding fails, starts with empty history.
    private func loadHistory() {
        // Check if file exists — first launch won't have one
        guard FileManager.default.fileExists(atPath: historyPath.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: historyPath)
            searches = try JSONDecoder().decode([String].self, from: data)
        } catch {
            print("Failed to load search history: \(error)")
            searches = []
        }
    }
}
