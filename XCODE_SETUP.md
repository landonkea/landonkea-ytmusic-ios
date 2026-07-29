# Xcode Setup & Next Steps

## When Xcode Is Installed

### 1. Open the Project
```bash
open -a Xcode /Users/landonkea/dev/landonkea-ytmusic-ios/Package.swift
```
This opens the Swift Package. You'll need to create an Xcode project or use `xcodegen` if a `.xcodeproj` is needed.

### 2. First Build & Run
1. Select an iOS simulator (iPhone 16 Pro recommended)
2. Product → Run (Cmd+R)
3. Fix any signing errors:
   - Set Team to "None" or your Apple ID
   - Bundle Identifier: `com.landonkea.ytmusic`
4. If `YTMusicApp` target isn't found:
   - Create a new iOS App target named `YTMusicApp`
   - Set the SwiftUI lifecycle
   - Set the minimum deployment target to iOS 17.0
   - Point it to `Sources/YTMusicApp/YTMusicApp.swift` as the entry point
   - Add `Sources/YTMusicAPI` as a local package dependency

### 3. Run Tests
```bash
# After Xcode project is set up:
xcodebuild test -scheme YTMusicApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```
Or use the test navigator in Xcode.

---

## Features Blocked by Xcode

### Must-Do Before Release

#### 1. Notification Center Widget
- Add a Widget Extension target
- Create a `NowPlayingWidget` that shows current song + play/pause
- Use `WidgetKit` with `AppEntity` for configuration
- Timeline provider refreshes every 5 minutes while playing
- Deep link taps open the app to the player

#### 2. Live Activities (Dynamic Island)
- Add a `LiveActivity` extension target
- Show now-playing info on the Dynamic Island / Lock Screen
- Use `ActivityAttributes` with song title, artist, album art
- Update via `LiveActivityManager` when the song changes

#### 3. CarPlay
- Add a `CPTemplateApplicationScene` to the Info.plist
- Create a `CarPlaySceneDelegate` with `CPListTemplate` for now-playing
- Implement `CPNowPlayingTemplate` for playback controls
- Wire up `MPRemoteCommandCenter` (already set up in AudioPlayer)

#### 4. SharePlay
- Add `GroupActivity` support for shared listening sessions
- Create a `YTMusicGroupActivity` with song metadata
- Use `AVPlayer`'s coordinated playback for sync
- Requires `GroupActivities` entitlement

#### 5. Handoff
- Add `NSUserActivity` support to `ContentView`
- Set `isEligibleForHandoff` on activity
- Implement `restoreUserActivityState` in the scene delegate
- Already partially set up via `SiriShortcutsManager`

#### 6. Spotlight Search
- Add `CSSearchableItem` indexing for songs and artists
- Index songs when they're played (in `addToRecentlyPlayed`)
- Index playlists when they're created
- Use `CSSearchableIndex` for batch updates

#### 7. App Store Connect
- Create app listing at https://appstoreconnect.apple.com
- Upload screenshots (iPhone + iPad + Mac)
- Write description, keywords, privacy policy
- Submit for review (requires Apple Developer Program)

---

## Features to Add After Xcode Setup

### Phase 8: Short Session (1-2 days)

#### 8.1 Listening Party / SharePlay
- Real-time sync via `GroupActivity`
- Share queue with friends
- Chat/messages in-app

#### 8.2 Custom Themes
- Accent color picker in Settings
- 10+ preset color palettes (like Metrolist's Material You)
- Album art-based dynamic coloring

#### 8.3 Canvas/Artwork Display
- Full-screen album art view on tap (like Apple Music)
- Zoom, pan, share artwork as image
- Crossfade between album arts in queue

### Phase 9: Medium Session (3-5 days)

#### 9.1 Song Credits
- Browse endpoint with `getSongCredits` 
- Show producers, writers, engineers
- Link to related artists

#### 9.2 Podcast Support
- Browse `FEmusic_podcasts` endpoint
- Podcast detail view with episodes
- Playback speed remembers per-podcast

#### 9.3 Smart Playlists
- "Recently Added" auto-playlist
- "Most Played" auto-playlist (already in HomeView)
- "Liked Songs" auto-playlist (data ready in LikedSongsManager)

#### 9.4 Import/Export Playlists
- Import from URL/text
- Export as text, JSON, or share link
- Share playlist as image

#### 9.5 Offline Mode Improvements
- Smart caching (cache on play)
- Offline-only toggle in Settings
- Storage management UI with per-song delete

### Phase 10: Long Session (1-2 weeks)

#### 10.1 Account Login (YouTube Music)
- Google Sign-In via `GoogleSignIn` SDK
- Liked songs sync
- Library sync (albums, artists, playlists)
- Subscriptions/followed artists
- Like/dislike via API (`like/like`, `like/dislike`)
- Subscribe/unsubscribe via API

#### 10.2 Audio Enhancements
- EQ wiring (EqualizerManager has data, but `applyGainsToEQ()` is a stub)
- Tempo/pitch control (independent of speed)
- Audio normalization / loudness
- Skip silence
- Gapless playback

#### 10.3 Algorithmic Recommendations
- Taste profile setup (`getTasteprofile`/`setTasteprofile`)
- Personalized mixes (Daily Mix, Discover Weekly-style)
- Radio station builder (`FEmusic_radio_builder`)

#### 10.4 Analytics Dashboard
- Full stats view with charts
- Time listened per day/week/month
- Top genres (if we could determine genre)
- Year in Review feature

### Phase 11: Polish (ongoing)

#### 11.1 UI Touch-Ups
- Haptic feedback on all interactions
- Fluid animations (matched geometry, transitions)
- Drag to reorder queue with haptic
- Mini player drag up to expand
- Landscape/tablet adaptive layouts

#### 11.2 Performance
- Lazy loading all images
- Pagination for long lists
- Memory management for large queues
- Profile with Instruments

#### 11.3 Accessibility
- Dynamic Type testing
- VoiceOver audit on every screen
- Reduce Motion support
- Keyboard navigation (iPad/Mac)

---

## Testing Checklist

Before every release:

- [ ] `npm run test:run` equivalent in Xcode (Cmd+U)
- [ ] Build with no warnings
- [ ] Test on iPhone (compact) and iPad (regular) size classes
- [ ] Test light and dark mode
- [ ] Test with VoiceOver enabled
- [ ] Test background audio (press home, lock screen controls)
- [ ] Test offline mode (airplane mode)
- [ ] Test downloads (start, cancel, play offline)
- [ ] Test queue operations (add, remove, reorder, shuffle, repeat)
- [ ] Test sleep timer
- [ ] Test crossfade
- [ ] Test equalizer
- [ ] Test search (text + voice)
- [ ] Test playlists (create, rename, delete, reorder)
- [ ] Test Siri Shortcuts
- [ ] Test on iOS 17 minimum

---

## Git Workflow

1. Feature branch from `dev`: `git checkout -b feature/your-feature dev`
2. Commit with conventional commit messages (`feat:`, `fix:`, `chore:`)
3. Push feature branch: `git push origin feature/your-feature`
4. Create PR into `dev` (via GitHub CLI or web)
5. After review, merge into `dev`
6. Test on `dev`
7. Merge `dev` → `main`
8. Push `main`: `git push origin main`

---

## File Reference

Key files to know:

| File | Purpose |
|------|---------|
| `Sources/YTMusicApp/YTMusicApp.swift` | App entry, environment objects, APIClient |
| `Sources/YTMusicApp/Services/AudioPlayer.swift` | Full playback engine |
| `Sources/YTMusicAPI/InnerTubeClient.swift` | All YouTube Music API calls |
| `Sources/YTMusicAPI/Models.swift` | Simple UI models |
| `Sources/YTMusicAPI/InnerTubeModels.swift` | Raw API response models |

Feature files:
| File | What it does |
|------|--------------|
| `Views/ArtistView.swift` | Artist page |
| `Views/AlbumView.swift` | Album page |
| `Views/ExploreView.swift` | Explore/Discover tab |
| `Services/LikedSongsManager.swift` | Local liked songs |
| `Services/StatsManager.swift` | Listening stats |
| `Views/PlayerView.swift` | Full player with speed control |
| `Views/ContentView.swift` | Root with keyboard shortcuts |
