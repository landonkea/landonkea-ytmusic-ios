import SwiftUI

/// The queue screen showing what's currently playing and what comes next.
///
/// HOW IT WORKS:
/// - Shows the currently playing song at the top
/// - Shows "Up Next" songs below it
/// - Users can remove songs (swipe or tap X) and reorder (drag)
///
/// IMPORTANT: The "Up Next" list is a SLICE of the full queue.
/// The full queue looks like: [past songs..., CURRENT, up next...]
/// `upNext` only returns songs AFTER currentIndex, so we do
/// index math to map from "up next index" back to "full queue index".
struct QueueView: View {
    
    /// Grab the audio player from the environment so we can read/modify the queue.
    /// "EnvironmentObject" means this view automatically stays updated
    /// whenever the audio player's published properties change.
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    /// `dismiss` is a SwiftUI environment value that lets us close this screen.
    /// We call `dismiss()` when the user taps "Done".
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        // NavigationView wraps the screen with a nav bar (title + toolbar buttons)
        NavigationView {
            // List = scrollable table view (like UITableView in UIKit)
            List {
                
                // ── SECTION 1: NOW PLAYING ──────────────────────────
                // `if let` safely unwraps the optional. If nothing is playing,
                // currentSong is nil and this entire section is hidden.
                if let currentSong = audioPlayer.currentSong {
                    Section {
                        // HStack = horizontal stack (row of items side by side)
                        HStack(spacing: 12) {
                            // Album art thumbnail
                            // AsyncImage loads an image from a URL asynchronously.
                            // While loading, it shows the gray placeholder rectangle.
                            AsyncImage(url: URL(string: currentSong.thumbnailUrl)) { image in
                                // When loaded: fill the frame with the image
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                // While loading: gray box
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 56, height: 56)
                            .cornerRadius(8)
                            
                            // Song title and artist, stacked vertically
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentSong.title)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .lineLimit(1) // Truncate with "..." if too long
                                
                                Text(currentSong.artist)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary) // Gray color
                                    .lineLimit(1)
                            }
                            
                            Spacer() // Pushes everything to the left
                            
                            // Speaker icon shows this song is currently playing
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.blue)
                        }
                    } header: {
                        Text("Now Playing")
                    }
                }
                
                // ── SECTION 2: UP NEXT ──────────────────────────────
                // `upNext` is a computed property that returns queue[currentIndex+1...]
                // If there are no songs after the current one, this section is hidden.
                if !audioPlayer.upNext.isEmpty {
                    Section {
                        // ── THE INDEX MATH EXPLANATION ────────────────
                        // `upNext` contains songs at positions [currentIndex+1, currentIndex+2, ...]
                        // in the full queue. But `enumerated()` gives us indices starting at 0.
                        //
                        // So if currentIndex=5, upNext[0] = queue[6], upNext[1] = queue[7], etc.
                        //
                        // To get the REAL index in the full queue from the "up next" index:
                        //   globalIndex = currentIndex + upNextIndex + 1
                        //
                        // Example: currentIndex=5, upNextIndex=0 → globalIndex=6
                        //          currentIndex=5, upNextIndex=2 → globalIndex=8
                        //
                        // We need the global index because removeFromQueue() and moveQueue()
                        // work on the FULL queue array, not the upNext slice.
                        
                        ForEach(Array(audioPlayer.upNext.enumerated()), id: \.element.id) { index, song in
                            // `enumerated()` wraps each element with its position (0, 1, 2...)
                            // `\.element.id` tells ForEach how to identify each row (needed for animations)
                            HStack(spacing: 12) {
                                // Drag handle icon — indicates this row can be dragged to reorder
                                // The three horizontal lines (hamburger icon) is the standard
                                // iOS drag handle pattern used in Reminders, Notes, etc.
                                Image(systemName: "line.3.horizontal")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                // Position number (1, 2, 3...) — display as index+1 so it starts at 1
                                Text("\(index + 1)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)
                                
                                // Album art thumbnail (same pattern as now playing, but smaller)
                                AsyncImage(url: URL(string: song.thumbnailUrl)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 48, height: 48)
                                .cornerRadius(6)
                                
                                // Song title and artist
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(song.title)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    
                                    Text(song.artist)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                // X button to remove this song from the queue
                                Button(action: {
                                    // Convert "up next index" to "full queue index"
                                    // This is the key math: we're removing from the FULL queue
                                    let globalIndex = audioPlayer.currentIndex + index + 1
                                    audioPlayer.removeFromQueue(at: globalIndex)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain) // Prevents blue button highlight
                            }
                            // SwipeActions = swipe left to reveal buttons (like iOS mail)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { // .destructive = red color
                                    // Same index math as the X button above
                                    let globalIndex = audioPlayer.currentIndex + index + 1
                                    audioPlayer.removeFromQueue(at: globalIndex)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                        // onMove enables drag-to-reorder. When the user drags a row,
                        // SwiftUI calls this closure with the source and destination indices.
                        .onMove { source, destination in
                            // Adjust destination to account for the "now playing" section above.
                            // The List's indices start at 0 for the first "up next" song,
                            // but in the full queue, those songs start at currentIndex + 1.
                            let adjustedDestination = audioPlayer.currentIndex + destination + 1
                            audioPlayer.moveQueue(from: source, to: adjustedDestination)
                        }
                    } header: {
                        // Show count in parentheses, e.g. "Up Next (5)"
                        Text("Up Next (\(audioPlayer.upNext.count))")
                    }
                } else {
                    // Empty state when there's nothing in the queue after current song
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "list.bullet")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            Text("No songs in queue")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity) // Center horizontally
                        .padding()
                    }
                }
            }
            .navigationTitle("Queue")
            // .inline = smaller title that doesn't become large on scroll
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // "Done" button on the left side of the nav bar
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss() // Closes this modal screen
                    }
                }
                
                // "Clear" button on the right — only shows if there's more than 1 song
                ToolbarItem(placement: .navigationBarTrailing) {
                    if audioPlayer.queue.count > 1 {
                        Button("Clear") {
                            audioPlayer.clearQueue() // Keeps current song, removes everything else
                        }
                        .foregroundColor(.red) // Red = destructive action
                    }
                }
            }
        }
    }
}

#Preview {
    QueueView()
        .environmentObject(AudioPlayer())
}
