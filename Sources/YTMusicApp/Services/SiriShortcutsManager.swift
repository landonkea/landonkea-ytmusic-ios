import Foundation  // NSObject, String, etc.
import Intents     // INInteraction, INPlayMediaIntent
import SwiftUI     // @MainActor

/// Donates Siri Shortcut activities so Siri learns user habits.
///
/// HOW IT WORKS:
/// iOS records "donated" activities and uses them to suggest Siri Shortcuts.
/// For example, if you always play "Workout Playlist" at 6 PM, Siri will
/// suggest it automatically. Users can also assign voice commands in
/// Settings → Siri & Search → Shortcuts.
///
/// This is a lightweight approach — no custom intent definition files needed.
/// We use NSUserActivity which is the simplest form of Siri integration.
@MainActor
struct SiriShortcutsManager {
    
    /// The activity type identifier — must be unique to the app.
    /// Reverse domain format: com.yourcompany.appname.action
    static let playMusicActivityType = "com.landonkea.ytmusic.play"
    
    /// Donate a "Play Music" shortcut whenever the user plays a song.
    ///
    /// Siri learns from repeated donations. NSUserActivity ensures the
    /// system knows this app can handle "play music" requests.
    ///
    /// - Parameters:
    ///   - title: Song title (e.g. "Bohemian Rhapsody")
    ///   - artist: Artist name (e.g. "Queen")
    ///   - videoId: YouTube video ID for deep linking
    static func donatePlaySong(title: String, artist: String, videoId: String) {
        // NSUserActivity = an activity the user performed that Siri can learn from
        let activity = NSUserActivity(activityType: playMusicActivityType)
        
        // Title appears in Siri Shortcuts UI
        activity.title = "Play \(title)"
        
        // Suggested invocation phrase — what user can say to Siri
        activity.suggestedInvocationPhrase = "Play \(title)"
        
        // UserInfo stores custom data (passed to the app when shortcut is triggered)
        activity.userInfo = [
            "videoId": videoId,
            "title": title,
            "artist": artist
        ]
        
        // Make it eligible for Siri suggestions
        activity.isEligibleForSearch = true           // Appears in Spotlight
        activity.isEligibleForPrediction = true       // Siri predicts it
        
        // Make it eligible for Handoff (continuity between devices)
        activity.isEligibleForHandoff = false
        
        // Persist the activity so Siri remembers it
        activity.becomeCurrent()
        
        // Log for debugging
        print("Donated Siri shortcut: Play \(title)")
    }
    
    /// Donate a shortcut for resuming playback.
    ///
    /// Called when the user starts/resumes listening. Siri can learn
    /// "Resume my music" as a common pattern.
    static func donateResumePlayback() {
        let activity = NSUserActivity(activityType: playMusicActivityType)
        activity.title = "Resume Music"
        activity.suggestedInvocationPhrase = "Play my music"
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.becomeCurrent()
    }
    
    /// Donate a shortcut for a specific playlist.
    ///
    /// - Parameter playlistName: The name of the playlist (e.g. "Workout Jams")
    static func donatePlayPlaylist(name: String) {
        let activity = NSUserActivity(activityType: playMusicActivityType)
        activity.title = "Play \(name)"
        activity.suggestedInvocationPhrase = "Play \(name)"
        activity.userInfo = [
            "playlist": name
        ]
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.becomeCurrent()
    }
}
