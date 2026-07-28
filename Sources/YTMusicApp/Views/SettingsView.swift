import SwiftUI

/// Settings screen where users can customize app behavior.
///
/// HOW IT WORKS:
/// - Uses `@AppStorage` to persist settings in UserDefaults (iOS key-value store)
/// - Settings are automatically saved when changed and loaded on app launch
/// - Some settings (like streamQuality) are stored but not yet wired up to AudioPlayer
/// - Future work: connect these to actual behavior + add login for YouTube Music account
struct SettingsView: View {
    
    // MARK: - Persisted Settings
    
    // @AppStorage is a SwiftUI property wrapper that reads/writes to UserDefaults.
    // It works like @State, but the value persists between app launches.
    // The string key ("darkMode") is how it's stored in UserDefaults.
    
    /// Whether dark mode is enabled. When toggled, it immediately affects
    /// the `.preferredColorScheme` modifier at the bottom of this view.
    @AppStorage("darkMode") private var darkMode = true
    
    /// Whether to follow the system appearance.
    /// When true, ignores darkMode and uses the device's light/dark setting.
    @AppStorage("autoAppearance") private var autoAppearance = false
    
    /// Audio stream quality preference for playback.
    /// Controls which audio stream the player requests (affects data usage + quality).
    @AppStorage("streamQuality") private var streamQuality = "high"
    
    /// Audio stream quality preference for downloads.
    /// Separate from stream quality — lets users save storage by downloading lower quality.
    @AppStorage("downloadQuality") private var downloadQuality = "high"
    
    /// Whether crossfade between songs is enabled.
    /// Saved to UserDefaults so AudioPlayer can read it on launch.
    @AppStorage("crossfadeEnabled") private var crossfadeEnabled = false
    
    /// Crossfade duration in seconds (the overlap time between songs).
    /// Stored as a Double via string key for simplicity.
    @AppStorage("crossfadeDuration") private var crossfadeDuration = 5.0
    
    /// Whether to only download songs over Wi-Fi.
    @AppStorage("downloadOverWifiOnly") private var downloadOverWifiOnly = true
    
    /// Font size scale factor (0 = small, 1 = medium, 2 = large).
    /// Applied globally via a custom view modifier in ContentView.
    @AppStorage("fontSizeScale") private var fontSizeScale = 1
    
    // MARK: - Body
    
    var body: some View {
        // NavigationView provides the nav bar with title
        NavigationView {
            // List = scrollable grouped table (like iOS Settings app)
            List {
                
                // ── APPEARANCE SECTION ──────────────────────────────
                Section {
                    // Auto-appearance — follows the system light/dark setting
                    // When enabled, overrides the manual dark mode toggle
                    Toggle(isOn: $autoAppearance) {
                        Label("Auto (Follow System)", systemImage: "iphone")
                    }
                    
                    // Manual dark mode toggle — only adjustable when auto is off
                    // Dimmed appearance when auto is enabled to indicate it's disabled
                    Toggle(isOn: $darkMode) {
                        Label("Dark Mode", systemImage: "moon.fill")
                    }
                    .opacity(autoAppearance ? 0.5 : 1.0)
                    .disabled(autoAppearance)
                    
                    // Font size picker — adjusts text size across the app
                    // 0 = small, 1 = medium (default), 2 = large
                    Picker("Font Size", selection: $fontSizeScale) {
                        Text("Small").tag(0)
                        Text("Medium").tag(1)
                        Text("Large").tag(2)
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Auto follows your device's light/dark mode setting")
                }
                
                // ── PLAYBACK SECTION ────────────────────────────────
                Section {
                    // Picker = dropdown/segment selector for choosing from options.
                    // The `selection` binding tells SwiftUI which option is active.
                    // Each `.tag()` marks a case as a possible value for the picker.
                    Picker("Stream Quality", selection: $streamQuality) {
                        Text("Low (72kbps)").tag("low")
                        Text("Medium (128kbps)").tag("medium")
                        Text("High (256kbps)").tag("high")
                    }
                    
                    // Crossfade toggle — smooth transitions between songs
                    Toggle(isOn: $crossfadeEnabled) {
                        Label("Crossfade", systemImage: "shuffle")
                    }
                    
                    // Crossfade duration picker — only shown when crossfade is enabled
                    if crossfadeEnabled {
                        Picker("Fade Duration", selection: $crossfadeDuration) {
                            Text("2 seconds").tag(2.0)
                            Text("3 seconds").tag(3.0)
                            Text("5 seconds").tag(5.0)
                            Text("8 seconds").tag(8.0)
                            Text("10 seconds").tag(10.0)
                        }
                    }
                } header: {
                    Text("Playback")
                } footer: {
                    // Footer text appears below the section in smaller gray text
                    Text("Higher quality uses more data")
                }
                
                // ── DOWNLOADS SECTION ───────────────────────────────
                Section {
                    // Download quality picker — controls audio bitrate for downloads
                    Picker("Download Quality", selection: $downloadQuality) {
                        Text("Low (72kbps)").tag("low")
                        Text("Medium (128kbps)").tag("medium")
                        Text("High (256kbps)").tag("high")
                    }
                    
                    Toggle(isOn: $downloadOverWifiOnly) {
                        Label("Wi-Fi Only", systemImage: "wifi")
                    }
                } header: {
                    Text("Downloads")
                } footer: {
                    Text("Lower quality uses less storage space")
                }
                
                // ── ABOUT SECTION ───────────────────────────────────
                Section {
                    // Static info rows — just display text, no action
                    HStack {
                        Text("Version")
                        Spacer() // Pushes version number to the right
                        Text("1.0.0")
                            .foregroundColor(.secondary) // Gray color
                    }
                    
                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("Landon")
                            .foregroundColor(.secondary)
                    }
                    
                    // Link = tappable row that opens a URL in Safari.
                    // We use a force-unwrap URL(string:)! because these are
                    // hardcoded valid URLs that will never be nil.
                    // SAFETY: If these URLs were ever dynamic/user-input,
                    // we'd need to use `if let` or `guard let` instead.
                    Link(destination: URL(string: "https://github.com/landonkea/landonkea-ytmusic-ios")!) {
                        HStack {
                            Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                            Spacer()
                            // External link indicator icon
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://github.com/landonkea/landonkea-ytmusic-ios/issues")!) {
                        HStack {
                            Label("Report a Bug", systemImage: "ant.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            // This modifier overrides the app's color scheme based on the toggle.
            // When autoAppearance is on → use nil (follow system).
            // When autoAppearance is off → use darkMode toggle value.
            // nil means "inherit from the system" (auto mode).
            .preferredColorScheme(autoAppearance ? nil : (darkMode ? .dark : .light))
        }
    }
}

#Preview {
    SettingsView()
}
