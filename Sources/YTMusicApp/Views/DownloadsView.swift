import SwiftUI
// ^ Import Apple's SwiftUI framework for building user interfaces

/// Shows all downloaded songs available for offline playback.
///
/// Displayed in the Library tab. Users can:
/// - Tap a song to play it from cache (no internet needed)
/// - Swipe to delete individual songs
/// - Clear all downloads (with confirmation)
/// - See storage usage and download count
struct DownloadsView: View {
    // ^ A full-screen view that lists every song saved for offline listening

    // MARK: - Injected Dependencies

    /// The offline manager handles downloads and cache
    @EnvironmentObject var offlineManager: OfflineManager
    // ^ Read from the environment: gives us access to the list of downloads + delete methods

    /// The audio player for playing cached songs
    @EnvironmentObject var audioPlayer: AudioPlayer
    // ^ Read from the environment: lets us play a song directly from local storage

    // MARK: - Local State

    /// Whether to show the "Clear All" confirmation alert
    @State private var showClearAllAlert = false
    // ^ Tracks whether the destructive confirmation dialog is visible

    // MARK: - UI Body

    var body: some View {
        // ^ The main view content — SwiftUI renders this on screen
        NavigationView {
            // ^ Wraps everything in a navigation controller (top bar + titles)
            Group {
                // ^ A container that applies the same modifiers to its children
                if offlineManager.downloads.isEmpty {
                    // ^ Check if the user has any saved downloads

                    // Empty state — no downloads yet
                    VStack(spacing: 16) {
                        // ^ Vertical stack with 16 points between each child
                        Image(systemName: "arrow.down.circle")
                            // ^ A cloud-with-down-arrow icon from SF Symbols
                            .font(.system(size: 60))
                            // ^ Large icon (60 points) to draw attention
                            .foregroundColor(.secondary)
                            // ^ Grey tint to keep it subtle

                        Text("No Downloads")
                            // ^ Main heading for the empty state
                            .font(.title2)
                            // ^ Slightly smaller than the default title

                        Text("Download songs from the player to listen offline")
                            // ^ Subtitle explaining what the user should do
                            .font(.subheadline)
                            // ^ Smaller secondary text
                            .foregroundColor(.secondary)
                            // ^ Grey colour to de-emphasise it
                            .multilineTextAlignment(.center)
                            // ^ Centre-align because the text wraps to multiple lines

                        // Call to action — tells user how to download
                        Text("Tap the download icon on any song")
                            // ^ A hint pointing to the download button on player rows
                            .font(.caption)
                            // ^ Very small caption text
                            .foregroundColor(.blue)
                        // ^ Blue to make it look like a tappable hint
                    }
                } else {
                    // ^ User has downloads — show the full list

                    // List of downloaded songs
                    List {
                        // ^ A vertical scrolling list of rows

                        // Storage info header with count
                        Section {
                            // ^ A grouped section in the list
                            HStack {
                                // ^ Horizontal row: "Storage Used" on the left, stats on the right
                                Text("Storage Used")
                                // ^ Label describing what the row shows
                                Spacer()
                                // ^ Pushes the stats to the right

                                // Show count and total size
                                Text("\(offlineManager.downloads.count) songs • \(ByteCountFormatter.string(
                                    // ^ Number of songs + a bullet separator
                                    fromByteCount: offlineManager.totalStorageUsed(),
                                    // ^ Convert the byte total into a human-readable string (e.g. "45.2 MB")
                                    countStyle: .file
                                    // ^ Use the file-style formatting (bytes, KB, MB, GB)
                                ))")
                                .foregroundColor(.secondary)
                                // ^ Grey text for the statistics
                            }
                        }

                        // Downloaded songs
                        Section {
                            // ^ A second section containing the actual song rows
                            ForEach(offlineManager.downloads) { song in
                                // ^ Loop over every downloaded song (uses Identifiable conformance)
                                DownloadRow(song: song)
                                    // ^ The visual row for a downloaded song
                                    .onTapGesture {
                                        // ^ When the user taps the row…
                                        playSong(song)
                                        // ^ …play that song from the local cache
                                    }
                            }
                            .onDelete { indexSet in
                                // ^ Swipe-to-delete handler for the list rows
                                // Swipe to delete
                                for index in indexSet {
                                    // ^ Loop over the indices being deleted
                                    let song = offlineManager.downloads[index]
                                    // ^ Get the song at that position
                                    offlineManager.delete(videoId: song.videoId)
                                    // ^ Remove its cached file and metadata from storage
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
            // ^ Set the title shown in the navigation bar at the top
            .toolbar {
                // ^ Add buttons to the top navigation bar
                if !offlineManager.downloads.isEmpty {
                    // ^ Only show the toolbar button when there are downloads

                    // "Clear All" button in the top-right
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // ^ Place a button on the right side of the bar
                        Button("Clear All") {
                            // ^ A text button labelled "Clear All"
                            showClearAllAlert = true
                            // ^ Show the confirmation alert when tapped
                        }
                        .foregroundColor(.red)
                        // ^ Red text indicating a destructive action
                    }
                }
            }
            // Confirmation alert before deleting all downloads
            .alert("Clear All Downloads?", isPresented: $showClearAllAlert) {
                // ^ A modal dialog; appears when showClearAllAlert becomes true
                Button("Cancel", role: .cancel) { }
                // ^ Dismisses the alert — role: .cancel means it's the safe default
                Button("Clear All", role: .destructive) {
                    // ^ Red-styled destructive button
                    offlineManager.deleteAll()
                    // ^ Delete every downloaded file and metadata entry
                }
            } message: {
                // ^ The body text below the alert title
                Text("This will remove all \(offlineManager.downloads.count) downloaded songs. This cannot be undone.")
                // ^ Warns the user about the irreversible action
            }
        }
    }

    // MARK: - Playback Helpers

    /// Play a downloaded song from the local cache.
    ///
    /// FLOW:
    /// 1. Get the local file URL from OfflineManager
    /// 2. Pass it to AudioPlayer's new playLocal() method
    /// 3. AudioPlayer plays from the file instead of streaming
    /// - Parameter song: The downloaded song to play
    private func playSong(_ song: DownloadedSong) {
        // ^ Private method called when the user taps a downloaded song row
        guard let localURL = offlineManager.localURL(for: song.videoId) else {
            // ^ Ask OfflineManager for the file path of the cached video
            print("Downloaded file not found for \(song.videoId)")
            // ^ Log a warning to the console for debugging
            return
        }

        // Play from local cache
        audioPlayer.playLocal(
            // ^ Call the player with a local file instead of streaming
            videoId: song.videoId,
            // ^ The unique YouTube video identifier
            title: song.title,
            // ^ The song title for the now-playing display
            artist: song.artist,
            // ^ The artist name for the now-playing display
            thumbnailUrl: song.thumbnailUrl,
            // ^ The album art URL for the now-playing display
            localURL: localURL,
            // ^ The local file URL — player reads from disk, not the network
            duration: 0 // Duration unknown for cached songs, AudioPlayer will detect it
            // ^ Pass 0 so the player auto-detects the track length from the file
        )
    }
}

// MARK: - Download Row

/// A single row in the downloads list.
///
/// Shows: album art, title, artist, and download date.
struct DownloadRow: View {
    // ^ A small reusable view used inside ForEach in DownloadsView

    let song: DownloadedSong
    // ^ The downloaded-song model to display (title, artist, thumbnail, video ID, etc.)

    var body: some View {
        // ^ The row's visual layout
        HStack(spacing: 12) {
            // ^ Horizontal stack with 12 points between elements

            // Album art thumbnail
            AsyncImage(url: URL(string: song.thumbnailUrl)) { image in
                // ^ Load an image from the web asynchronously (doesn't block the UI)
                image
                    // ^ The successfully loaded image
                    .resizable()
                    // ^ Allow the image to stretch/shrink to fit its frame
                    .aspectRatio(contentMode: .fill)
                // ^ Crop to fill the frame while keeping proportions
            } placeholder: {
                // ^ What to show while the image is downloading
                Rectangle()
                    // ^ A simple grey rectangle placeholder
                    .fill(Color.gray.opacity(0.3))
                // ^ Light grey fill so the row still has a visible thumbnail area
            }
            .frame(width: 48, height: 48)
            // ^ Fixed 48×48 point bounding box for the thumbnail
            .cornerRadius(6)
            // ^ Slightly rounded corners (6 point radius)

            // Song info
            VStack(alignment: .leading, spacing: 4) {
                // ^ Vertical stack, left-aligned, tight spacing

                Text(song.title)
                    // ^ The song title
                    .font(.subheadline)
                    // ^ Slightly smaller than body text
                    .lineLimit(1)
                // ^ Truncate to a single line if the title is long

                Text(song.artist)
                    // ^ The artist name
                    .font(.caption)
                    // ^ Very small text for secondary info
                    .foregroundColor(.secondary)
                    // ^ Grey colour to de-emphasise it
                    .lineLimit(1)
                // ^ Truncate to a single line if the artist name is long
            }

            Spacer()
            // ^ Pushes everything to the left; keeps the row full-width

            // Offline indicator
            Image(systemName: "arrow.down.circle.fill")
                // ^ A filled circle with a down-arrow — shows this song is cached
                .foregroundColor(.green)
            // ^ Green colour signals "available offline"
        }
    }
}

#Preview {
    // ^ Xcode preview canvas — renders this view without building the full app
    DownloadsView()
        .environmentObject(OfflineManager())
        // ^ Inject a fresh OfflineManager for preview
        .environmentObject(AudioPlayer())
        // ^ Inject a fresh AudioPlayer for preview
}
