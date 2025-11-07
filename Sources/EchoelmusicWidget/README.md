# Echoelmusic Widgets 🎵

Real-time HRV and coherence widgets for iOS, iPadOS, and macOS.

---

## Features

- **Small Widget:** Current HRV value with coherence color indicator
- **Medium Widget:** HRV + Coherence gauge + Last updated
- **Large Widget:** Complete stats - HRV, Coherence, Heart Rate, Breathing Phase

---

## Xcode Setup

### 1. Create Widget Extension

1. In Xcode: **File → New → Target**
2. Choose **Widget Extension**
3. Product Name: `EchoelmusicWidget`
4. Check: **Include Configuration Intent** (optional)
5. Click **Finish**

### 2. Configure App Group

**Required for sharing data between main app and widget.**

#### Main App Target:
1. Select **Echoelmusic** target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **App Groups**
5. Click **+** and add: `group.com.echoelmusic.shared`

#### Widget Target:
1. Select **EchoelmusicWidget** target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **App Groups**
5. Select: `group.com.echoelmusic.shared` (same as main app)

### 3. Copy Source Files

Copy these files to the widget target:
- `EchoelmusicWidget.swift`
- `HRVTimelineProvider.swift`
- `HRVWidgetEntryView.swift`

Add to both main app and widget targets:
- `Sources/Echoelmusic/Shared/SharedDataManager.swift`

### 4. Update Info.plist

Widget target Info.plist should include:
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
</dict>
```

---

## Usage in Main App

### Update Widget Data

```swift
import Foundation

// In BiofeedbackEngine or HRVManager
let sharedData = SharedDataManager.shared

// Update current values
sharedData.updateHRVData(
    hrv: 67.5,
    coherence: 75.0,
    heartRate: 68,
    breathingPhase: "Inhale"
)

// Widget automatically updates!
```

### Save Completed Sessions

```swift
sharedData.saveSession(
    id: session.id,
    startTime: session.startTime,
    endTime: session.endTime,
    averageHRV: session.averageHRV,
    averageCoherence: session.averageCoherence
)
```

### Manual Widget Refresh

```swift
sharedData.reloadWidgets()
```

---

## Widget Sizes

### Small (68x68 pt)
- HRV value
- Heart icon
- Color-coded coherence indicator

### Medium (157x68 pt)
- HRV with waveform icon
- Coherence circular gauge
- Divider between sections

### Large (157x157 pt)
- Header with app name
- HRV statistic
- Coherence gauge
- Heart rate
- Breathing phase
- Last updated timestamp

---

## Deep Linking

All widgets support deep linking to the main app:

```swift
echoelmusic://hrv
```

Tapping any widget opens the app directly to the HRV monitoring view.

---

## Update Strategy

**Timeline Updates:**
- Automatic refresh every 15 minutes
- Manual refresh when app updates data via `SharedDataManager`
- Background refresh when app is active

**Best Practices:**
- Update shared data whenever HRV changes significantly (>5ms)
- Update at end of breathing cycles
- Update when session starts/ends
- Don't update more than once per second

---

## Platform Support

| Platform | Supported | Widget Families |
|----------|-----------|-----------------|
| **iOS 14+** | ✅ | Small, Medium, Large |
| **iPadOS 14+** | ✅ | Small, Medium, Large |
| **macOS 11+** | ✅ | Small, Medium |

---

## Example Integration

### BiofeedbackEngine Integration

```swift
import Combine

@MainActor
class BiofeedbackEngine: ObservableObject {
    private let sharedData = SharedDataManager.shared

    func updateBiometrics(hrv: Double, coherence: Double, heartRate: Double) {
        // Update internal state
        self.currentHRV = hrv
        self.currentCoherence = coherence
        self.currentHeartRate = heartRate

        // Update widgets
        sharedData.updateHRVData(
            hrv: hrv,
            coherence: coherence,
            heartRate: heartRate
        )
    }
}
```

### BreathingGuide Integration

```swift
@MainActor
class BreathingGuide: ObservableObject {
    private let sharedData = SharedDataManager.shared

    func updatePhase(_ phase: BreathingPhase) {
        sharedData.updateDuringBreathing(
            hrv: currentHRV,
            coherence: currentCoherence,
            heartRate: currentHeartRate,
            phase: phase
        )
    }
}
```

---

## Testing

### Xcode Widget Preview

1. Open `EchoelmusicWidget.swift`
2. Canvas shows live previews of all widget sizes
3. Cmd+Option+P to refresh

### Simulator Testing

1. Run widget scheme
2. Choose widget size to test
3. Widget appears on home screen

### Device Testing

1. Build and run on device
2. Long-press home screen
3. Tap **+** button
4. Search **Echoelmusic**
5. Choose widget size and add

---

## Troubleshooting

### Widget Not Updating

**Check App Group:**
- Verify both targets have same App Group ID
- Check capabilities are enabled

**Check Data Writing:**
```swift
SharedDataManager.shared.printSharedData()
```

**Force Widget Reload:**
```swift
SharedDataManager.shared.reloadWidgets()
```

### Widget Shows Placeholder

- Ensure app has run at least once
- Check shared UserDefaults has data
- Verify App Group is configured correctly

### Widget Not Appearing in Gallery

- Clean build folder (Cmd+Shift+K)
- Delete app from device/simulator
- Reinstall

---

## Performance

**Memory Usage:**
- Small widget: ~5 MB
- Medium widget: ~8 MB
- Large widget: ~12 MB

**Update Frequency:**
- Timeline refresh: Every 15 minutes
- Manual refresh: As needed via app
- Background refresh: When app is active

**Battery Impact:**
- Minimal (widget updates are efficient)
- No continuous background activity
- Updates only when data changes

---

## Future Enhancements

- [ ] Configurable widget (choose metric to display)
- [ ] Historical HRV chart in large widget
- [ ] Multiple widgets for different metrics
- [ ] Widget actions (iOS 17+)
- [ ] Live Activities integration
- [ ] StandBy mode optimization (iOS 17+)

---

## Resources

- [WidgetKit Documentation](https://developer.apple.com/documentation/widgetkit)
- [App Groups Documentation](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups)
- [Human Interface Guidelines - Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets)

---

**Built with ❤️ for the seamless "Erlebnisbad" experience**

Transform your breath. Transform your life. 💚
