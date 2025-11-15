# OSC Integration Guide

Complete guide for integrating OSC functionality into Echoelmusic iOS app.

## Files Created

```
ios-app/Echoelmusic/OSC/
├── OSCManager.swift              # OSC client (UDP communication)
├── OSCBiofeedbackBridge.swift    # Bridges HealthKit/Mic → OSC
├── OSCSettingsView.swift         # SwiftUI settings UI
└── INTEGRATION_GUIDE.md          # This file
```

---

## Step 1: Add Files to Xcode Project

1. **Open Xcode**:
   ```bash
   cd ios-app
   open Package.swift  # or Echoelmusic.xcodeproj
   ```

2. **Add OSC folder**:
   - Right-click on "Echoelmusic" group in Project Navigator
   - Select "Add Files to Echoelmusic..."
   - Navigate to `ios-app/Echoelmusic/OSC/`
   - Select all 3 Swift files:
     - `OSCManager.swift`
     - `OSCBiofeedbackBridge.swift`
     - `OSCSettingsView.swift`
   - ✅ Check "Copy items if needed"
   - ✅ Check "Create groups"
   - ✅ Add to target: "Echoelmusic"
   - Click "Add"

---

## Step 2: Integrate into EchoelApp.swift

### Current EchoelApp.swift

Find your existing `EchoelApp.swift` file (likely in `ios-app/Echoelmusic/`).

### Add OSC Properties

Add these properties to your app:

```swift
import SwiftUI

@main
struct EchoelApp: App {

    // Existing properties
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var audioEngine = AudioEngine()
    @StateObject private var microphoneManager = MicrophoneManager()

    // ✨ NEW: OSC Integration
    @StateObject private var oscManager = OSCManager()
    @StateObject private var oscBridge: OSCBiofeedbackBridge

    init() {
        // Initialize OSC Bridge with dependencies
        let osc = OSCManager()
        let health = HealthKitManager()
        let mic = MicrophoneManager()

        _oscManager = StateObject(wrappedValue: osc)
        _oscBridge = StateObject(wrappedValue: OSCBiofeedbackBridge(
            oscManager: osc,
            healthKitManager: health,
            microphoneManager: mic
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitManager)
                .environmentObject(audioEngine)
                .environmentObject(microphoneManager)
                .environmentObject(oscManager)        // ✨ NEW
                .environmentObject(oscBridge)         // ✨ NEW
        }
    }
}
```

**Important**: If you already have an `init()`, merge the OSC initialization into it.

---

## Step 3: Add OSC Settings to ContentView

### Option A: Add to existing Settings/Menu

Find your settings view and add:

```swift
NavigationLink(destination: OSCSettingsView(
    oscManager: oscManager,
    bridge: oscBridge
)) {
    Label("OSC Connection", systemImage: "network")
}
```

### Option B: Add as Tab (if using TabView)

```swift
TabView {
    // Existing tabs...

    OSCSettingsView(oscManager: oscManager, bridge: oscBridge)
        .tabItem {
            Label("OSC", systemImage: "network")
        }
}
```

### Option C: Add as Toolbar Button

```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        NavigationLink(destination: OSCSettingsView(
            oscManager: oscManager,
            bridge: oscBridge
        )) {
            Image(systemName: oscManager.isConnected ? "wifi" : "wifi.slash")
                .foregroundColor(oscManager.isConnected ? .green : .red)
        }
    }
}
```

---

## Step 4: (Optional) Wire Microphone Pitch to OSC

If you want to send real-time pitch from microphone:

### In MicrophoneManager.swift

Find where pitch is detected (likely in `detectPitch()` method):

```swift
// After detecting pitch
let frequency = detectedPitch
let confidence = pitchConfidence

// ✨ NEW: Send to OSC
if let bridge = self.oscBridge {  // Add oscBridge reference
    bridge.sendPitch(frequency: Float(frequency), confidence: Float(confidence))
}
```

### Pass OSC Bridge to MicrophoneManager

Either:
1. Add `oscBridge` as property to `MicrophoneManager`
2. Or use `NotificationCenter` to publish pitch
3. Or use Combine publisher

**Simplest approach** (NotificationCenter):

```swift
// In MicrophoneManager.swift
NotificationCenter.default.post(
    name: .pitchDetected,
    object: PitchData(frequency: frequency, confidence: confidence)
)

// In OSCBiofeedbackBridge.swift setupObservers()
NotificationCenter.default.publisher(for: .pitchDetected)
    .compactMap { $0.object as? PitchData }
    .sink { [weak self] data in
        self?.sendPitch(frequency: data.frequency, confidence: data.confidence)
    }
    .store(in: &cancellables)

// Define notification name
extension Notification.Name {
    static let pitchDetected = Notification.Name("pitchDetected")
}

struct PitchData {
    let frequency: Float
    let confidence: Float
}
```

---

## Step 5: Build and Test

### 1. Build the App

```bash
cd ios-app
xcodebuild -scheme Echoelmusic -destination 'platform=iOS,name=Your iPhone'
```

Or in Xcode: **⌘B** (Build)

### 2. Run on Device

- Select your iPhone/iPad in device dropdown
- Click Run (⌘R)
- Grant permissions when prompted

### 3. Test OSC Connection

**Without Desktop Engine** (test sending only):

```bash
# On Mac, install oscdump
brew install liblo

# Listen for OSC messages
oscdump 8000
```

- In iOS app: Go to OSC Settings
- Enter your Mac's IP (e.g., `192.168.1.100`)
- Tap "Connect"
- Enable "Send Biofeedback Data"

You should see in terminal:
```
/echoel/bio/heartrate f 72.5
/echoel/bio/hrv f 45.2
/echoel/param/hrv_coherence f 0.65
```

**With Desktop Engine** (Week 2):
- Start Desktop Engine (JUCE app)
- Desktop listens on port 8000
- iOS connects and sends data
- Desktop reacts to biofeedback (e.g., HR affects audio pitch)

---

## Step 6: Troubleshooting

### "Cannot find 'OSCManager' in scope"

✅ Make sure OSCManager.swift is added to Xcode target
✅ Check file is in Project Navigator (left sidebar)
✅ Clean Build Folder: Product → Clean Build Folder (⇧⌘K)

### "OSC not connecting"

✅ Both devices on same WiFi network
✅ Desktop IP is correct (check with `ifconfig` or `ipconfig`)
✅ Firewall allows UDP port 8000
✅ Desktop Engine is running (or use `oscdump` for testing)

### "No biofeedback data sent"

✅ HealthKit permissions granted
✅ "Send Biofeedback Data" toggle is ON
✅ OSC connection status shows "Connected"
✅ Check Xcode console for "📡 OSC →" messages

### "High latency (>30ms)"

✅ Use 5GHz WiFi (not 2.4GHz)
✅ Reduce network congestion
✅ Move devices closer to router
✅ Disable WiFi power saving on iOS: Settings → WiFi → (i) → Low Data Mode OFF

---

## Testing Checklist

After integration, verify:

- [ ] App builds without errors
- [ ] OSC Settings view appears in UI
- [ ] Can enter Desktop IP address
- [ ] "Connect" button works
- [ ] Connection status updates (Connected/Disconnected)
- [ ] Biofeedback toggle works
- [ ] Messages sent counter increments
- [ ] Heart rate appears in `oscdump` (if testing with oscdump)
- [ ] Latency shows < 10ms (if connected to Desktop)

---

## Next Steps

### Week 2: Desktop Engine

1. Create JUCE project (see `desktop-engine/README.md`)
2. Add OSCManager.h/cpp from `osc-bridge/examples/`
3. Implement basic audio synthesis
4. Map biofeedback → audio parameters

### Future Enhancements

- **Auto-Discovery**: Use Bonjour to find Desktop automatically
- **Reconnection**: Auto-reconnect when connection lost
- **Bandwidth Optimization**: Adaptive message rate
- **Encryption**: OSC over TLS for remote sessions

---

## Files Reference

| File | Purpose | Lines |
|------|---------|-------|
| `OSCManager.swift` | OSC client (UDP), encoding/decoding | ~400 |
| `OSCBiofeedbackBridge.swift` | HealthKit/Mic → OSC bridge | ~200 |
| `OSCSettingsView.swift` | SwiftUI settings UI | ~250 |

**Total**: ~850 lines of production-ready code ✅

---

## Support

**Docs**:
- OSC Protocol: `/docs/osc-protocol.md`
- Architecture: `/docs/architecture.md`
- Setup Guide: `/docs/setup-guide.md`

**Issues**: https://github.com/vibrationalforce/Echoelmusic/issues

---

**Status**: ✅ **Ready to Integrate**
**Estimated Integration Time**: 30-60 minutes
**Next**: Build Desktop Engine (Week 2)
