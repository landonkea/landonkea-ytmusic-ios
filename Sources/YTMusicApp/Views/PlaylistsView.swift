import SwiftUI
// ^ Import Apple's SwiftUI framework for building user interfaces

/// The Library tab showing downloaded songs and local playlists.
///
/// This is the main library screen where users can:
/// - View their downloaded songs for offline playback
/// - Create and manage local playlists
/// - Tap a playlist to see its songs
struct PlaylistsView: View {

    // MARK: - Injected Dependencies

    /// The playlist manager for creating/managing playlists
    @EnvironmentObject var playlistManager: PlaylistManager

    /// The audio player for playing songs
    @EnvironmentObject var audioPlayer: AudioPlayer

    /// The offline manager for downloaded songs
    @EnvironmentObject var offlineManager: OfflineManager

    // MARK: - Local State

    /// Whether to show the "New Playlist" alert
    @State private var showNewPlaylistAlert = false

    /// The name for the new playlist being created
    @State private var newPlaylistName = ""

    // MARK: - UI Body

    var body: some View {
        // ^ The main view content — SwiftUI renders this on screen
        NavigationView {
            // ^ Wraps everything in a navigation controller (top bar + titles)
            List {
                // ^ A vertical scrolling list of sections and rows

                // ── PLAYLISTS SECTION ──────────────────────────────
                Section {
                    // ^ A grouped section in the list with a header
                    if playlistManager.playlists.isEmpty {
                        // ^ Check if the user has any playlists yet

                        // Empty state — no playlists yet
                        VStack(spacing: 8) {
                            // ^ Vertical stack to lay out empty-state elements
                            Image(systemName: "music.note.list")
                                // ^ A music-note list icon from SF Symbols
                                .font(.title2)
                                // ^ Set the icon size to title2
                                .foregroundColor(.secondary)
                                // ^ Use the secondary (grey) tint color

                            Text("No playlists yet")
                                // ^ A label telling the user no playlists exist
                                .font(.subheadline)
                                // ^ Smaller font than body text
                                .foregroundColor(.secondary)
                                // ^ Grey text to keep it subtle
                        }
                        .frame(maxWidth: .infinity)
                        // ^ Stretch the VStack to fill the row width
                        .padding(.vertical, 8)
                        // ^ Add 8 points of vertical spacing around it
                    } else {
                        // ^ User has playlists — show them

                        // List of playlists
                        ForEach(playlistManager.playlists) { playlist in
                            // ^ Loop over every playlist using its Identifiable conformance
                            NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                                // ^ A tappable row that navigates to the detail view
                                PlaylistRow(playlist: playlist)
                                // ^ The visual row showing playlist name / counts
                            }
                            .contextMenu {
                                // Pin/Unpin toggle
                                Button {
                                    playlistManager.togglePin(playlist)
                                } label: {
                                    Label(
                                        playlist.isPinned ? "Unpin" : "Pin to Top",
                                        systemImage: playlist.isPinned ? "pin.slash" : "pin"
                                    )
                                }
                                
                                // Delete
                                Button(role: .destructive) {
                                    playlistManager.deletePlaylist(playlist)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { indexSet in
                            // ^ Attach swipe-to-delete to each row
                            // Swipe to delete playlists
                            for index in indexSet {
                                // ^ Loop over every index the user swiped
                                playlistManager.deletePlaylist(playlistManager.playlists[index])
                                // ^ Remove that playlist from storage
                            }
                        }
                    }
                } header: {
                    // ^ The section's header — shown above the playlist rows
                    HStack {
                        // ^ Horizontal row for "Playlists" label + plus button
                        Text("Playlists")
                        // ^ Section title
                        Spacer()
                        // ^ Pushes the button to the right side

                        // Add playlist button
                        Button(action: {
                            // ^ Tapping this button…
                            showNewPlaylistAlert = true
                            // ^ …shows the alert for naming a new playlist
                        }) {
                            Image(systemName: "plus")
                                // ^ A "+" icon from SF Symbols
                                .font(.subheadline)
                                // ^ Small font to match the header size
                        }
                    }
                }

                // ── DOWNLOADED SONGS SECTION ────────────────────────
                if !offlineManager.downloads.isEmpty {
                    // ^ Only show this section if at least one song is downloaded
                    Section {
                        // ^ A second grouped section
                        ForEach(offlineManager.downloads) { song in
                            // ^ Loop over every downloaded song
                            DownloadRow(song: song)
                                // ^ The visual row for a downloaded song
                                .onTapGesture {
                                    // ^ When the user taps the row…
                                    playSong(song)
                                    // ^ …play that song from the local cache
                                }
                        }
                        .onDelete { indexSet in
                            // ^ Swipe-to-delete for downloaded songs
                            for index in indexSet {
                                // ^ Loop over the indices being deleted
                                let song = offlineManager.downloads[index]
                                // ^ Get the song at that position
                                offlineManager.delete(videoId: song.videoId)
                                // ^ Remove its cached file and metadata
                            }
                        }
                    } header: {
                        // ^ Section header showing download count
                        Text("Downloads (\(offlineManager.downloads.count))")
                        // ^ E.g. "Downloads (3)"
                    }
                }
            }
            .navigationTitle("Library")
            // ^ Set the title shown in the navigation bar at the top
            .toolbar {
                // ^ Add buttons to the top navigation bar
                ToolbarItem(placement: .navigationBarTrailing) {
                    // ^ Place a button on the right side of the bar
                    Button(action: {
                        // ^ Tapping shows the new-playlist alert
                        showNewPlaylistAlert = true
                    }) {
                        Image(systemName: "plus")
                        // ^ "+" icon in the toolbar
                    }
                }
            }
            // Alert for creating a new playlist
            .alert("New Playlist", isPresented: $showNewPlaylistAlert) {
                // ^ A modal alert that appears when showNewPlaylistAlert is true
                TextField("Playlist Name", text: $newPlaylistName)
                // ^ A text field where the user types the playlist name
                Button("Create") {
                    // ^ The "Create" button inside the alert
                    guard !newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    // ^ Don't create if the name is empty or only spaces
                    playlistManager.createPlaylist(name: newPlaylistName)
                    // ^ Tell the manager to persist the new playlist
                    newPlaylistName = ""
                    // ^ Reset the text field for next time
                }
                Button("Cancel", role: .cancel) {
                    // ^ Dismisses the alert without doing anything
                    newPlaylistName = ""
                    // ^ Clear the text field on cancel too
                }
            } message: {
                // ^ The body text below the alert title
                Text("Enter a name for your new playlist")
            }
        }
    }

    // MARK: - Playback Helpers

    /// Play a downloaded song from the local cache.
    /// - Parameter song: The downloaded song to play
    private func playSong(_ song: DownloadedSong) {
        // ^ Private method called when the user taps a downloaded song
        guard let localURL = offlineManager.localURL(for: song.videoId) else {
            // ^ Ask OfflineManager for the file path of the cached video
            // ^ If the file is missing, exit early
            return
        }

        // playLocal is async — wrap the call in a Task.
        Task {
            await audioPlayer.playLocal(
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
                duration: 0
                // ^ Duration unknown for cached songs; AudioPlayer will detect it
            )
        }
    }
}

// MARK: - Playlist Row

/// A single row in the playlists list.
///
/// Shows: playlist name, song count, and total duration.
struct PlaylistRow: View {
    // ^ A small reusable view used inside ForEach in PlaylistsView

    let playlist: Playlist
    // ^ The playlist model to display (name, song count, duration, etc.)

    var body: some View {
        // ^ The row's visual layout
        HStack(spacing: 12) {
            // ^ Horizontal stack with 12 points between elements

            // Playlist icon (stacked music notes)
            Image(systemName: "square.stack.fill")
                // ^ SF Symbol: stacked squares (represents a playlist)
                .font(.title2)
                // ^ Medium-large icon size
                .foregroundColor(.blue)
                // ^ Blue tint for the icon
                .frame(width: 48, height: 48)
                // ^ Fixed 48×48 point bounding box
                .background(Color.blue.opacity(0.1))
                // ^ Light blue background circle/square
                .cornerRadius(8)
                // ^ Rounded corners (8 point radius)

            // Playlist info
            VStack(alignment: .leading, spacing: 4) {
                // ^ Vertical stack, left-aligned, tight spacing

                Text(playlist.name)
                    // ^ The playlist's display name
                    .font(.body)
                    // ^ Standard body text size
                    .fontWeight(.medium)
                    // ^ Slightly bold for emphasis
                    .lineLimit(1)
                    // ^ Truncate to a single line if the name is long

                // Song count and total duration
                Text("\(playlist.songCount) songs • \(playlist.totalDuration)")
                    // ^ E.g. "12 songs • 45 min"
                    .font(.subheadline)
                    // ^ Smaller secondary text
                    .foregroundColor(.secondary)
                    // ^ Grey colour to de-emphasise it
            }

            Spacer()
            // ^ Pushes everything to the left; keeps the row full-width
        }
    }
}

#Preview {
    // ^ Xcode preview canvas — renders this view without building the full app
    PlaylistsView()
        .environmentObject(PlaylistManager())
        // ^ Inject a fresh PlaylistManager for preview
        .environmentObject(AudioPlayer())
        // ^ Inject a fresh AudioPlayer for preview
        .environmentObject(OfflineManager())
        // ^ Inject a fresh OfflineManager for preview
}
