# tvOS Top Shelf Extension 📺

Showcase Echoelmusic content on Apple TV home screen when app is featured.

---

## What is Top Shelf?

**Top Shelf** is the featured content area at the top of the Apple TV home screen that appears when your app is at the top of the apps list.

**Features:**
- Prominent placement on TV home screen
- Rich visual content
- Quick actions to launch app features
- Recent activity showcase
- Achievements and milestones

---

## Content Types

### 1. Active Session (Inset Layout)

**When session is in progress:**
- Large background image
- "Session in Progress" title
- Actions: "Resume Session", "End Session"
- Deep links directly to active session

### 2. Recent Sessions (Sectioned Layout)

**Shows:**
- Recent session cards with stats (HRV, Coherence)
- Quick action buttons (Start HRV, Start Breathing, etc.)
- Achievements (if any)

**Layout:**
- Section 1: Quick Actions (4 buttons)
- Section 2: Recent Sessions (up to 5)
- Section 3: Achievements (up to 3)

### 3. Quick Actions Only (Sectioned Layout)

**First launch / No history:**
- 4 quick action buttons
- HRV Monitoring
- Breathing Exercise
- Coherence Training
- Group Session

---

## Xcode Setup

### 1. Create Top Shelf Extension

1. In Xcode: **File → New → Target**
2. Choose **tvOS → Top Shelf Extension**
3. Product Name: `EchoelmusicTVTopShelf`
4. Activate scheme when prompted

### 2. Configure App Group

**Required for sharing data between TV app and Top Shelf extension.**

#### TV App Target:
1. Select **EchoelmusicTV** target
2. Go to **Signing & Capabilities**
3. Add **App Groups** capability
4. Add: `group.com.echoelmusic.shared`

#### Top Shelf Extension:
1. Select **EchoelmusicTVTopShelf** target
2. Go to **Signing & Capabilities**
3. Add **App Groups** capability
4. Select: `group.com.echoelmusic.shared`

### 3. Copy Source Files

**Top Shelf Extension Target:**
- `TopShelfContentProvider.swift`

**TV App Target:**
- `TopShelf/TopShelfManager.swift`

### 4. Update Info.plist

Top Shelf extension Info.plist should include:
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.tv-top-shelf</string>
    <key>NSExtensionPrincipalClass</key>
    <string>TopShelfContentProvider</string>
</dict>
```

---

## Usage in TV App

### Update When Session Starts

```swift
import TopShelf

let topShelf = TopShelfManager.shared

// Session started
topShelf.sessionDidStart(id: sessionID, type: .hrvMonitoring)

// Top Shelf now shows "Session in Progress" with Resume/End actions
```

### Update When Session Ends

```swift
// Session ended
topShelf.sessionDidEnd(
    id: sessionID,
    startTime: session.startTime,
    averageHRV: session.averageHRV,
    averageCoherence: session.averageCoherence
)

// Top Shelf now shows this session in "Recent Sessions" section
```

### Update When Achievement Unlocked

```swift
// Achievement unlocked
topShelf.achievementUnlocked(
    id: "10-sessions",
    title: "Consistent Practice",
    description: "Completed 10 sessions"
)

// Top Shelf now shows this achievement
```

### Manual Reload

```swift
// Force reload Top Shelf content
topShelf.reloadTopShelf()
```

---

## Integration Examples

### TVSessionManager Integration

```swift
@MainActor
class TVSessionManager: ObservableObject {
    private let topShelf = TopShelfManager.shared

    func startSession(type: SessionType) {
        let sessionID = UUID().uuidString

        // Start session...
        self.currentSessionID = sessionID

        // Update Top Shelf
        topShelf.sessionDidStart(id: sessionID, type: type)
    }

    func endSession() {
        guard let sessionID = currentSessionID else { return }

        // Calculate session stats
        let averageHRV = calculateAverageHRV()
        let averageCoherence = calculateAverageCoherence()

        // End session...

        // Update Top Shelf
        topShelf.sessionDidEnd(
            id: sessionID,
            startTime: sessionStartTime,
            averageHRV: averageHRV,
            averageCoherence: averageCoherence
        )
    }
}
```

---

## Deep Linking

Top Shelf items use deep links to launch specific app features.

### Supported URLs

**Quick Actions:**
```
echoelmusic://start-hrv          # Start HRV monitoring
echoelmusic://start-breathing    # Start breathing exercise
echoelmusic://start-coherence    # Start coherence training
echoelmusic://start-group        # Start group session
```

**Active Session:**
```
echoelmusic://resume-session?id=<sessionID>
echoelmusic://end-session?id=<sessionID>
```

**Recent Sessions:**
```
echoelmusic://view-session?id=<sessionID>
```

**Achievements:**
```
echoelmusic://achievements
```

### Handle Deep Links in App

In `EchoelmusicTVApp.swift`:

```swift
@main
struct EchoelmusicTVApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "echoelmusic" else { return }

        switch url.host {
        case "start-hrv":
            // Start HRV monitoring
            sessionManager.startSession(type: .hrvMonitoring)

        case "start-breathing":
            // Start breathing exercise
            sessionManager.startSession(type: .breathing)

        case "resume-session":
            // Resume active session
            if let sessionID = url.queryParameters["id"] {
                sessionManager.resumeSession(id: sessionID)
            }

        // ... handle other URLs
        default:
            break
        }
    }
}
```

---

## Top Shelf Layouts

### Sectioned Content

**Multiple rows of content:**
- Best for showing variety of content
- Up to 3 sections
- Each section has title and items

**When to use:**
- Default layout
- Multiple content types (actions, sessions, achievements)
- Rich browsing experience

### Inset Content

**Single featured item:**
- Large background image
- Title and actions
- Prominent "hero" layout

**When to use:**
- Active session in progress
- Featured content or event
- Call-to-action focus

---

## Testing

### Simulator Testing

1. Run TV app in simulator
2. Home to TV home screen
3. Move Echoelmusic app to top of apps list
4. Top Shelf appears at top of screen

**Note:** Content updates when app state changes

### Device Testing

1. Install TV app on Apple TV
2. Move app to top of home screen
3. Top Shelf appears
4. Test deep links by selecting items

### Debug Top Shelf Content

```swift
let topShelf = TopShelfManager.shared
topShelf.printTopShelfData()
```

**Output:**
```
[TopShelf] 📊 Current Top Shelf data:
  Active Session: None
  Recent Sessions: 3
  Achievements: 1
```

---

## Content Update Strategy

### Automatic Updates

Top Shelf content updates automatically when:
- Session starts → Show active session
- Session ends → Show in recent sessions
- Achievement unlocked → Show in achievements
- App launches → Refresh all data

### Manual Updates

Call `reloadTopShelf()` after:
- Deleting session history
- Clearing achievements
- Changing app state

### Update Frequency

**iOS Limitation:** Top Shelf updates when:
- Extension process launches (user scrolls to app)
- App calls `TVTopShelfContentProvider.topShelfContentDidChange()`
- System decides to refresh (unpredictable)

**Best practice:** Call `reloadTopShelf()` whenever content changes

---

## Data Storage

**Shared via App Groups:**
- Active session ID and type
- Recent sessions (last 10)
- Achievements (last 5)

**Storage location:**
```
UserDefaults(suiteName: "group.com.echoelmusic.shared")
```

**Keys:**
- `activeSessionID` - Current session ID (String)
- `activeSessionType` - Current session type (String)
- `sessions` - Recent sessions array ([[String: Any]])
- `achievements` - Achievements array ([[String: Any]])

---

## Image Assets

### Required Images

**Quick Action Icons (400x400 pt):**
- HRV icon
- Breathing icon
- Coherence icon
- Group session icon

**Session Cards (800x450 pt):**
- Generated preview images
- Coherence gradient backgrounds

**Achievement Badges (400x400 pt):**
- Badge images for each achievement

### Image Generation

**Option 1:** Bundle static images in extension
**Option 2:** Generate images dynamically (coherence-colored gradients)

---

## Performance

**Memory Usage:**
- Extension: ~10-15 MB
- Minimal overhead on TV app

**CPU Usage:**
- Negligible (loads only when visible)
- No continuous background activity

**Storage:**
- Shared data: ~100 KB
- Images (optional): ~1-5 MB

---

## Limitations

### tvOS Restrictions

- **Update frequency:** Not guaranteed (system-controlled)
- **Content refresh:** Only when extension loads
- **Image size limits:** 5 MB per image
- **Total extension size:** 50 MB

### Design Constraints

- **Sectioned:** Max 3 sections
- **Items per section:** Recommended 5-10
- **Action buttons:** Max 4 per inset content

---

## Future Enhancements

- [ ] Live session statistics (update while visible)
- [ ] Video previews of visualizations
- [ ] Group session participant count
- [ ] Weekly/monthly statistics summary
- [ ] Personalized content recommendations

---

## Resources

- [Top Shelf Documentation](https://developer.apple.com/documentation/tvservices/tvtopshelfcontentprovider)
- [Top Shelf Design Guidelines](https://developer.apple.com/design/human-interface-guidelines/tvos/overview/top-shelf/)
- [TVServices Framework](https://developer.apple.com/documentation/tvservices)

---

**Built with ❤️ for the seamless "Erlebnisbad" experience**

From home screen to full immersive biofeedback! 🌊💚
