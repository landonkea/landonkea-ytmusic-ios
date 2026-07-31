import SwiftUI

/// Displays lyrics for the currently playing song.
///
/// Supports two modes:
/// 1. **Synced mode**: Highlights the current line as the song plays (karaoke-style)
/// 2. **Plain mode**: Shows all lyrics as scrollable text (when synced not available)
///
/// Also supports translation to other languages via a translate button.
///
/// HOW IT WORKS:
/// - Fetches lyrics from lrclib.net when the song changes
/// - Uses a Timer to check playback position every 0.5 seconds
/// - Scrolls to and highlights the line that matches the current time
/// - Falls back to plain text if synced lyrics aren't available
/// - Users can tap translate to see lyrics in another language
struct LyricsView: View {
    
    /// The audio player — provides current playback time and song info
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    /// The lyrics client for fetching lyrics
    @StateObject private var lyricsClient = LyricsClientWrapper()
    
    /// The lyrics translator for multi-language support
    @StateObject private var translator = LyricsTranslator()
    
    /// The fetched lyrics (nil while loading)
    @State private var lyrics: Lyrics?
    
    /// Whether lyrics are currently being fetched
    @State private var isLoading = false
    
    /// The index of the currently highlighted line (synced mode)
    @State private var currentLineIndex: Int = -1
    
    /// Timer that checks playback position for synced lyrics
    @State private var timer: Timer?
    
    /// Whether to show the translated lyrics instead of original
    @State private var showTranslated = false
    
    /// Whether the language picker is showing
    @State private var showLanguagePicker = false
    
    /// The target language for translation
    @State private var targetLanguage = ("es", "Spanish")
    
    /// Translated synced lines (preserving timestamps)
    @State private var translatedSyncedLines: [SyncedLine]?
    
    /// Translated plain text
    @State private var translatedPlainText: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // ── TRANSLATE BUTTON ──────────────────────────────────
            // Shows at the top of the lyrics view when lyrics are available
            if lyrics != nil && !isLoading {
                HStack {
                    Spacer()
                    
                    // Language picker button
                    Button(action: {
                        showLanguagePicker = true
                    }) {
                        HStack(spacing: 4) {
                            // Show the flag of the target language
                            Text(targetLanguage.1 == "Spanish" ? "🇪🇸" :
                                 targetLanguage.1 == "French" ? "🇫🇷" :
                                 targetLanguage.1 == "Japanese" ? "🇯🇵" :
                                 targetLanguage.1 == "Korean" ? "🇰🇷" :
                                 targetLanguage.1 == "German" ? "🇩🇪" :
                                 "🌐")
                            Text(showTranslated ? "Original" : "Translate")
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(12)
                    }
                    .disabled(translator.isTranslating)
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
            }
            
            if translator.isTranslating {
                // Translation loading state
                Spacer()
                ProgressView("Translating...")
                Spacer()
            } else if isLoading {
                // Loading state
                Spacer()
                ProgressView("Loading lyrics...")
                Spacer()
            } else if let lyrics = lyrics {
                if lyrics.hasSyncedLyrics {
                    // Synced lyrics mode (karaoke-style)
                    // Show translated lines if available and toggle is on
                    let displayLines = showTranslated ? translatedSyncedLines : lyrics.syncedLines
                    
                    SyncedLyricsDisplay(
                        lyrics: Lyrics(
                            trackName: lyrics.trackName,
                            artistName: lyrics.artistName,
                            plainText: lyrics.plainText,
                            syncedLines: displayLines
                        ),
                        currentLineIndex: currentLineIndex,
                        onLineTap: { index in
                            // Seek to the tapped line's timestamp
                            guard let line = displayLines?[index] else { return }
                            audioPlayer.seekToTime(line.time)
                        }
                    )
                } else {
                    // Plain text mode
                    // Show translated text if available and toggle is on
                    let displayText = showTranslated ? (translatedPlainText ?? lyrics.plainText) : lyrics.plainText
                    
                    PlainLyricsDisplay(lyrics: Lyrics(
                        trackName: lyrics.trackName,
                        artistName: lyrics.artistName,
                        plainText: displayText,
                        syncedLines: nil
                    ))
                }
            } else {
                // No lyrics found
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("No lyrics found")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Lyrics for this song aren't available")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
        .cornerRadius(16)
        .padding(.horizontal)
        .onAppear {
            fetchLyrics()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: audioPlayer.currentSong?.id) { _ in
            // Song changed — fetch new lyrics and clear translation
            fetchLyrics()
            showTranslated = false
            translator.clearTranslation()
        }
        // Language picker sheet for translation target
        .sheet(isPresented: $showLanguagePicker) {
            NavigationView {
                List {
                    ForEach(LyricsTranslator.supportedLanguages, id: \.code) { lang in
                        Button(action: {
                            targetLanguage = (lang.code, lang.name)
                            showLanguagePicker = false
                            // Trigger translation with new language
                            translateLyrics()
                        }) {
                            HStack {
                                Text(lang.flag)
                                Text(lang.name)
                                Spacer()
                                if lang.code == targetLanguage.0 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                .navigationTitle("Translate To")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            showLanguagePicker = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Lyrics Fetching
    
    /// Fetch lyrics for the current song.
    private func fetchLyrics() {
        guard let song = audioPlayer.currentSong else {
            lyrics = nil
            return
        }
        
        isLoading = true
        lyrics = nil
        currentLineIndex = -1
        
        Task {
            let fetchedLyrics = await lyricsClient.client.fetchLyrics(
                trackName: song.title,
                artistName: song.artist
            )
            
            await MainActor.run {
                self.lyrics = fetchedLyrics
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Translation
    
    /// Translate the current lyrics to the target language.
    ///
    /// Called when the user taps the translate button.
    /// Handles both synced and plain lyrics.
    private func translateLyrics() {
        guard let lyrics = lyrics else { return }
        
        // Toggle between original and translated
        if showTranslated {
            // Already showing translated — switch back to original
            showTranslated = false
            return
        }
        
        // If we already have a translation, just show it
        if translator.translatedText != nil || translatedSyncedLines != nil {
            showTranslated = true
            return
        }
        
        // Perform the translation
        if lyrics.hasSyncedLyrics, let syncedLines = lyrics.syncedLines {
            // Translate synced lyrics (preserving timestamps)
            Task {
                let translated = await translator.translateSyncedLines(
                    syncedLines,
                    to: targetLanguage.0
                )
                await MainActor.run {
                    self.translatedSyncedLines = translated
                    self.showTranslated = true
                }
            }
        } else {
            // Translate plain text
            translator.translate(lyrics.plainText, to: targetLanguage.0)
            // Observe when translation completes
            Task {
                // Wait for translation to complete
                while translator.isTranslating {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                }
                await MainActor.run {
                    self.translatedPlainText = translator.translatedText
                    self.showTranslated = true
                }
            }
        }
    }
    
    // MARK: - Synced Lyrics Timer
    
    /// Start a timer that checks playback position for synced lyrics.
    ///
    /// The timer fires every 0.5 seconds and finds the current line
    /// based on the audio player's currentTime.
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                updateCurrentLine()
            }
        }
    }
    
    /// Stop the timer when the view disappears.
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Find and highlight the line that matches the current playback time.
    ///
    /// ALGORITHM:
    /// 1. Get the current playback time from the audio player
    /// 2. Walk through synced lines from the current position
    /// 3. Find the last line whose timestamp is ≤ currentTime
    /// 4. Highlight that line
    private func updateCurrentLine() {
        guard let syncedLines = lyrics?.syncedLines,
              !syncedLines.isEmpty else {
            return
        }
        
        let currentTime = audioPlayer.currentTime
        
        // Find the line that should be highlighted
        // Walk backwards from the end to find the last line at or before currentTime
        var foundIndex = -1
        for (index, line) in syncedLines.enumerated() {
            if line.time <= currentTime {
                foundIndex = index
            } else {
                // We've passed this line's time, stop looking
                break
            }
        }
        
        // Only update if the index changed (avoids unnecessary view updates)
        if foundIndex != currentLineIndex {
            currentLineIndex = foundIndex
        }
    }
}

// MARK: - Synced Lyrics Display

/// Karaoke-style lyrics that highlight the current line.
///
/// Shows lines in a scrollable list. The current line is bright white,
/// while other lines are dimmed. Automatically scrolls to keep the
/// current line visible. Tapping a line seeks to that timestamp.
struct SyncedLyricsDisplay: View {
    
    let lyrics: Lyrics
    let currentLineIndex: Int
    
    /// Called when the user taps a lyrics line — passes the line index
    /// so the parent can seek to that timestamp
    var onLineTap: ((Int) -> Void)?
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(Array((lyrics.syncedLines ?? []).enumerated()), id: \.offset) { index, line in
                        Text(line.text)
                            // Bigger font — title2 for inactive, title for active (karaoke feel)
                            .font(index == currentLineIndex ? .title : .title2)
                            .fontWeight(index == currentLineIndex ? .bold : .regular)
                            // Current line is bright white, others are dimmed
                            .foregroundColor(index == currentLineIndex ? .white : .white.opacity(0.35))
                            // Current line scales up for emphasis
                            .scaleEffect(index == currentLineIndex ? 1.1 : 1.0)
                            // Animate scale + opacity changes smoothly
                            .animation(.easeInOut(duration: 0.35), value: currentLineIndex)
                            .id(index) // Needed for ScrollViewReader to scroll to this view
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 8)
                            // Pill-shaped background behind the active line (karaoke highlight)
                            .background(
                                Group {
                                    if index == currentLineIndex {
                                        // White background pill at 15% opacity
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.15))
                                    } else {
                                        // "Previous" lines get a subtle purple tint,
                                        // "upcoming" lines have no background
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.clear)
                                    }
                                }
                            )
                            // Tap to seek — tapping any line jumps playback to that timestamp
                            .onTapGesture {
                                onLineTap?(index)
                            }
                            // Long press to copy this line
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = line.text
                                } label: {
                                    Label("Copy Line", systemImage: "doc.on.doc")
                                }
                                
                                Button {
                                    let allText = lyrics.syncedLines?.map(\.text).joined(separator: "\n") ?? ""
                                    UIPasteboard.general.string = allText
                                    let activityVC = UIActivityViewController(
                                        activityItems: [allText],
                                        applicationActivities: nil
                                    )
                                    // Get the root view controller to present the share sheet
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let rootVC = windowScene.windows.first?.rootViewController {
                                        rootVC.present(activityVC, animated: true)
                                    }
                                } label: {
                                    Label("Share Lyrics", systemImage: "square.and.arrow.up")
                                }
                            }
                    }
                }
                .padding(.vertical, 60)
            }
            .onChange(of: currentLineIndex) { newIndex in
                // Auto-scroll to keep the current line visible
                guard newIndex >= 0 else { return }
                withAnimation {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Plain Lyrics Display

/// Simple scrollable text view for plain lyrics (no timestamps).
struct PlainLyricsDisplay: View {
    
    let lyrics: Lyrics
    
    var body: some View {
        ScrollView {
            Text(lyrics.plainText)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = lyrics.plainText
                    } label: {
                        Label("Copy Lyrics", systemImage: "doc.on.doc")
                    }
                    
                    Button {
                        let activityVC = UIActivityViewController(
                            activityItems: [lyrics.plainText],
                            applicationActivities: nil
                        )
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            rootVC.present(activityVC, animated: true)
                        }
                    } label: {
                        Label("Share Lyrics", systemImage: "square.and.arrow.up")
                    }
                }
        }
    }
}

// MARK: - Lyrics Client Wrapper

/// A wrapper around LyricsClient that works with SwiftUI's @StateObject.
///
/// @StateObject requires an ObservableObject, but LyricsClient is a plain class.
/// This wrapper creates and holds the LyricsClient instance.
class LyricsClientWrapper: ObservableObject {
    /// The actual lyrics client
    let client = LyricsClient()
}

// MARK: - Preview

#Preview {
    LyricsView()
        .environmentObject(AudioPlayer())
}
