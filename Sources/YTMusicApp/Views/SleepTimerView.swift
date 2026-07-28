import SwiftUI // Imports the SwiftUI framework for building the user interface with native iOS components

/// A modal view that allows the user to set a sleep timer for music playback.
///
/// This view presents a list of preset durations (15, 30, 45, 60 minutes) and an
/// "End of current track" option. When a preset is selected, the timer is activated
/// on the audio player and the modal is dismissed. If a timer is already active,
/// the view shows the remaining time and a cancel button.
struct SleepTimerView: View { // Declares a SwiftUI View struct that displays the sleep timer configuration interface
    
    /// The audio player instance from the environment, which provides sleep timer controls
    @EnvironmentObject var audioPlayer: AudioPlayer // Reads the shared AudioPlayer from the SwiftUI environment; it manages sleep timer state
    
    /// The dismiss action provided by the SwiftUI environment to close this modal sheet
    @Environment(\.dismiss) var dismiss // Accesses the environment's dismiss function so this view can close itself
    
    /// The array of preset minute values displayed as options in the list
    let presets = [15, 30, 45, 60] // A constant array of integers representing the available timer durations in minutes
    
    var body: some View { // The required computed property that defines the layout and content of this view
        NavigationView { // Wraps the content in a navigation controller, providing a title bar and toolbar
            List { // Creates a grouped list that displays the timer sections and options
                // Active timer section — shown only when a sleep timer is already running
                if audioPlayer.isSleepTimerActive { // Conditional block; evaluates the player's boolean property to decide visibility
                    Section { // A grouped section in the list with its own visual divider
                        HStack { // Horizontally arranges the moon icon, timer info, and cancel button
                            Image(systemName: "moon.fill") // SF Symbol for a filled moon, representing the sleep timer
                                .foregroundColor(.purple) // Colors the moon icon in the app's accent purple
                            
                            VStack(alignment: .leading) { // Stacks the "Timer Active" label and remaining time vertically
                                Text("Timer Active") // A label indicating that the sleep timer is currently running
                                    .font(.headline) // Uses the system headline font for emphasis
                                
                                // Format remaining time as MM:SS (or H:MM:SS if more than an hour)
                                Text(formatRemaining(audioPlayer.sleepTimerRemaining)) // Calls formatRemaining to display a user-friendly countdown
                                    .font(.title2) // Uses a title-2 font for the remaining time, making it prominent
                                    .fontWeight(.bold) // Bold weight to make the countdown stand out
                                    .foregroundColor(.purple) // Purple color to match the app's theme
                            }
                            
                            Spacer() // A flexible spacer that pushes the cancel button to the right edge of the row
                            
                            // Cancel button — stops the active timer and dismisses the modal
                            Button(action: { // A tappable button that executes the closure when tapped
                                audioPlayer.stopSleepTimer() // Calls the player's method to cancel the active sleep timer
                                dismiss() // Calls the environment dismiss function to close this modal view
                            }) {
                                Text("Cancel") // The button's label
                                    .foregroundColor(.red) // Red text color to indicate a destructive action
                            }
                        }
                    }
                }
                
                // Preset options section — displays the available timer durations
                Section { // A grouped list section for the preset timer options
                    ForEach(presets, id: \.self) { minutes in // Iterates over each preset value; uses \.self as the identifier since integers are hashable
                        Button(action: { // Each preset is a tappable button
                            audioPlayer.setSleepTimer(minutes: minutes) // Activates the sleep timer with the selected minute duration on the player
                            dismiss() // Closes the modal after the timer is set
                        }) {
                            HStack { // Arranges the preset label, spacer, and optional checkmark horizontally
                                Text("\(minutes) minutes") // Displays the duration text, e.g. "15 minutes"
                                    .foregroundColor(.primary) // Uses the system primary text color for readability
                                
                                Spacer() // Pushes the checkmark to the trailing edge of the row
                                
                                // Show checkmark if this preset is currently active
                                if audioPlayer.isSleepTimerActive && // Only show a checkmark when the timer is actually running
                                   Int(audioPlayer.sleepTimerRemaining) / 60 == minutes { // And the remaining minutes match this preset value
                                    Image(systemName: "checkmark") // SF Symbol for a checkmark indicating the active selection
                                        .foregroundColor(.purple) // Purple color to match the app's theme
                                }
                            }
                        }
                    }
                } header: { // The header text for this section
                    Text("Stop after") // Section header label explaining the purpose of the options below
                } footer: { // The footer text for this section
                    Text("Playback will pause when the timer expires") // An explanatory note about what happens when the timer runs out
                }
                
                // End of current track option — sets the timer to match the remaining duration of the current song
                Section { // A grouped list section for the "end of track" option
                    Button(action: { // A tappable button
                        // Set timer to remaining duration of current song
                        // This will pause when the current song ends
                        if let song = audioPlayer.currentSong { // Safely unwraps the optional currentSong property
                            let remaining = audioPlayer.duration - audioPlayer.currentTime // Calculates how many seconds are left in the current track
                            if remaining > 0 { // Only starts the timer if there's actually time remaining (avoids negative or zero durations)
                                audioPlayer.startSleepTimer(duration: remaining) // Activates the sleep timer with the exact remaining duration
                            }
                        }
                        dismiss() // Closes the modal after the timer is set
                    }) {
                        Text("End of current track") // The button label explaining this option
                    }
                }
            }
            .navigationTitle("Sleep Timer") // Sets the title displayed in the navigation bar
            .navigationBarTitleDisplayMode(.inline) // Uses inline (compact) title mode instead of large titles
            .toolbar { // Adds buttons to the navigation bar
                ToolbarItem(placement: .navigationBarTrailing) { // Places this button on the trailing (right) side of the navigation bar
                    Button("Done") { // A simple "Done" button
                        dismiss() // Dismisses the modal without changing the timer
                    }
                }
            }
        }
    }
    
    /// Converts a `TimeInterval` (measured in seconds) into a human-readable countdown string.
    ///
    /// Examples:
    /// - 1800 seconds → "30:00 remaining"
    /// - 90 seconds → "1:30 remaining"
    /// - 45 seconds → "0:45 remaining"
    /// - 3725 seconds → "1:02:05 remaining" (when hours are present)
    ///
    /// - Parameter seconds: The number of seconds remaining on the timer.
    /// - Returns: A formatted string like "5:30 remaining" or "1:02:05 remaining".
    private func formatRemaining(_ seconds: TimeInterval) -> String { // A helper method that formats time for display
        let totalSeconds = Int(seconds) // Converts the TimeInterval (Double) to an integer for precise math operations
        let hours = totalSeconds / 3600 // Calculates the whole number of hours (3600 seconds per hour)
        let minutes = (totalSeconds % 3600) / 60 // Calculates remaining minutes after extracting hours
        let secs = totalSeconds % 60 // Calculates remaining seconds after extracting full minutes
        
        if hours > 0 { // If the duration includes one or more hours, include the hour component in the format
            return String(format: "%d:%02d:%02d remaining", hours, minutes, secs) // Formats as "H:MM:SS remaining"
        } else { // If the duration is less than an hour, omit the hour component
            return String(format: "%d:%02d remaining", minutes, secs) // Formats as "MM:SS remaining"
        }
    }
}

#Preview { // SwiftUI macro that generates a live preview in Xcode's canvas or Swift Previews
    SleepTimerView() // Creates an instance of the SleepTimerView with default values
        .environmentObject(AudioPlayer()) // Injects a fresh AudioPlayer into the environment for the preview to use
}
