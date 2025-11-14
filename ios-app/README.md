# Echoelmusic iOS App

Biofeedback sensing and visualization component of the Echoelmusic system.

## Features

- **Biofeedback Sensing**: Real-time heart rate, HRV, and respiratory rate via HealthKit
- **Audio Input**: Voice pitch detection and amplitude analysis
- **Visual Feedback**: Cymatics, Mandala, and Spectral visualizations (Metal shaders)
- **Spatial Audio**: ARKit-based face and hand tracking for 3D audio control
- **OSC Client**: Sends biofeedback data to Desktop Engine
- **MIDI Control**: MIDI 2.0 / MPE support for external controllers

## Requirements

- **iOS**: 16.0 or later
- **Device**: iPhone or iPad (physical device required for HealthKit)
- **Xcode**: 15.0 or later
- **Apple Developer Account**: Free tier sufficient

## Quick Start

### 1. Open Project

```bash
cd ios-app
open Package.swift  # Recommended (SPM)

# Or generate Xcode project with xcodegen
xcodegen generate
open Echoelmusic.xcodeproj
```

### 2. Configure Signing

1. Select project in Xcode
2. Select "Echoelmusic" target
3. Signing & Capabilities → Select your Team
4. Xcode generates Bundle ID automatically

**Note**: If Bundle ID conflicts, change to unique ID:
- Format: `com.yourname.echoelmusic`

### 3. Build and Run

1. Connect iOS device via USB
2. Select device in Xcode toolbar
3. Build and Run (⌘R)
4. On first launch: Grant HealthKit and Microphone permissions

## Project Structure

```
ios-app/
├── Echoelmusic/
│   ├── Core/
│   │   └── EchoelApp.swift           # App entry point
│   ├── Biofeedback/
│   │   ├── HealthKitManager.swift    # HealthKit integration
│   │   └── BioParameterMapper.swift  # Biofeedback processing
│   ├── Audio/
│   │   ├── MicrophoneManager.swift   # Audio input
│   │   ├── SpatialAudioEngine.swift  # 3D audio
│   │   └── Nodes/
│   │       └── EchoelNode.swift      # Custom audio node
│   ├── OSC/
│   │   └── (to be implemented)       # OSC client
│   ├── Visual/
│   │   ├── CymaticsRenderer.swift    # Metal-based visualization
│   │   ├── VisualizationMode.swift   # Scene management
│   │   ├── Shaders/
│   │   │   └── Cymatics.metal        # GPU shaders
│   │   └── Modes/
│   │       ├── WaveformMode.swift
│   │       ├── MandalaMode.swift
│   │       └── SpectralMode.swift
│   ├── Spatial/
│   │   ├── ARFaceTrackingManager.swift
│   │   └── HandTrackingManager.swift
│   ├── MIDI/
│   │   ├── MIDI2Manager.swift        # MIDI 2.0 support
│   │   └── MPEZoneManager.swift      # MPE handling
│   ├── Unified/
│   │   └── UnifiedControlHub.swift   # Central coordinator
│   └── Views/
│       ├── ContentView.swift
│       └── Components/
├── Tests/
│   └── EchoelTests/
│       ├── HealthKitManagerTests.swift
│       ├── PitchDetectorTests.swift
│       └── UnifiedControlHubTests.swift
├── Resources/
│   └── Info.plist
├── Package.swift                     # SPM manifest
├── project.yml                       # xcodegen config
└── README.md                         # This file
```

## Permissions

The app requires these permissions (configured in Info.plist):

- **HealthKit**: Heart rate, HRV, respiratory rate
- **Microphone**: Voice input and pitch detection
- **Camera**: ARKit face tracking
- **Motion**: Device orientation and gesture control

Users will be prompted on first use.

## OSC Client Setup

### 1. Install OSCManager

Create `Echoelmusic/OSC/OSCManager.swift` using template from `/docs/osc-protocol.md`:

```swift
import Foundation
import Network

class OSCManager: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var latencyMs: Double = 0

    private var connection: NWConnection?
    private let serverPort: UInt16 = 8000

    func connect(to host: String) {
        // UDP connection to Desktop
    }

    func sendHeartRate(_ bpm: Float) {
        send(address: "/echoel/bio/heartrate", [.float(bpm)])
    }

    // See full implementation in docs/osc-protocol.md
}
```

### 2. Integrate with HealthKitManager

```swift
// In HealthKitManager.swift
var oscManager: OSCManager?

func startHeartRateMonitoring() {
    // ... existing code ...

    // Send via OSC
    oscManager?.sendHeartRate(Float(heartRate))
}
```

### 3. Add Connection UI

```swift
// In Settings view
TextField("Desktop IP", text: $desktopIP)
Button("Connect") {
    oscManager.connect(to: desktopIP)
}
Text(oscManager.isConnected ? "Connected ✓" : "Disconnected")
```

## Building

### Development Build

```bash
cd ios-app
xcodebuild -scheme Echoelmusic -destination 'platform=iOS,name=Your iPhone'
```

### Testing

```bash
# Run unit tests
xcodebuild test -scheme Echoelmusic -destination 'platform=iOS Simulator,name=iPhone 15'

# Or in Xcode: ⌘U
```

### iOS 15 Compatibility

For iOS 15 support (if needed):

```bash
# Run compatibility test
../scripts/test-ios15.sh
```

## Debugging

### Xcode Console Logs

Enable verbose logging:
```swift
// In EchoelApp.swift
#if DEBUG
let logLevel = Logger.Level.debug
#endif
```

### HealthKit Debugging

If no heart rate data:
1. Check permissions: Settings → Privacy → Health → Echoelmusic
2. Ensure Apple Watch is paired and worn
3. Start a workout to activate sensors
4. Check Xcode console for HealthKit errors

### OSC Debugging

Monitor outgoing OSC messages:
```swift
// In OSCManager.swift
func send(address: String, _ args: [OSCArgument]) {
    print("OSC → \(address): \(args)")
    // ... send logic ...
}
```

## Performance

### Target Metrics

- **Frame Rate**: 60 FPS (visualization)
- **OSC Latency**: < 5ms (encoding + send)
- **Memory**: < 150 MB
- **Battery**: < 10% drain per hour

### Optimization Tips

1. **Throttle OSC messages**:
   ```swift
   let throttleInterval = 0.016 // 60 Hz max
   ```

2. **Metal optimization**:
   - Use instanced rendering
   - Minimize state changes
   - Profile with Metal Debugger (Xcode)

3. **Background modes**:
   - Enable "Audio" background mode
   - Use background delivery for HealthKit

## Dependencies

Managed via Swift Package Manager:

- No external dependencies currently
- All frameworks are Apple-native:
  - SwiftUI
  - HealthKit
  - AVFoundation
  - ARKit
  - Metal

## Common Issues

### Issue: "HealthKit is not available on this device"

**Solution**: HealthKit requires physical device (not Simulator)

### Issue: No heart rate data

**Solutions**:
- Pair Apple Watch
- Grant all HealthKit permissions
- Start a workout to activate sensors

### Issue: Build errors after reorganization

**Solutions**:
```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Clean build
xcodebuild clean -scheme Echoelmusic

# Rebuild
xcodebuild -scheme Echoelmusic
```

### Issue: "Failed to register bundle identifier"

**Solution**: Change Bundle ID to something unique in project settings

## Testing on Device

### Via Xcode (Recommended)

1. Connect device via USB
2. Select device in Xcode
3. Build and Run (⌘R)

### Via TestFlight

For distribution to testers:

```bash
# Archive for TestFlight
xcodebuild archive -scheme Echoelmusic \
  -archivePath ./build/Echoelmusic.xcarchive

# Export IPA
xcodebuild -exportArchive \
  -archivePath ./build/Echoelmusic.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist
```

See `/docs/archive/TESTFLIGHT_SETUP.md` for full guide.

## Next Steps

- [ ] Implement OSCManager (see `/docs/osc-protocol.md`)
- [ ] Add connection UI (IP input, status)
- [ ] Integrate OSC with existing managers
- [ ] Add latency display
- [ ] Test with Desktop Engine

## Contributing

For development guidelines, see `/docs/architecture.md`.

## License

Proprietary - Tropical Drones Studio, Hamburg

---

**Back to main docs**: [../README.md](../README.md)
**OSC Protocol**: [../docs/osc-protocol.md](../docs/osc-protocol.md)
**Setup Guide**: [../docs/setup-guide.md](../docs/setup-guide.md)
