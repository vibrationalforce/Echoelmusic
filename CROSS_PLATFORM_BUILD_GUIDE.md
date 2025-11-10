# Echoelmusic Cross-Platform Build Guide

Complete guide for building and deploying Echoelmusic across all Apple platforms.

---

## Table of Contents

1. [Platform Overview](#platform-overview)
2. [Build Requirements](#build-requirements)
3. [Project Structure](#project-structure)
4. [Building for Each Platform](#building-for-each-platform)
5. [Code Signing](#code-signing)
6. [App Store Submission](#app-store-submission)
7. [Platform-Specific Features](#platform-specific-features)
8. [Troubleshooting](#troubleshooting)

---

## Platform Overview

Echoelmusic is a **universal multimedia production suite** supporting:

| Platform | Min. Version | Bundle ID | App Name | Target Devices |
|----------|--------------|-----------|----------|----------------|
| **iOS** | 15.0 | `com.echoelmusic.studio` | Echoelmusic | iPhone, iPad |
| **macOS** | 12.0 | `com.echoelmusic.studio.mac` | Echoelmusic Pro | Mac (Intel + Apple Silicon) |
| **watchOS** | 8.0 | `com.echoelmusic.studio.watchos` | Echoelmusic | Apple Watch |
| **tvOS** | 15.0 | `com.echoelmusic.studio.tv` | Echoelmusic | Apple TV 4K/HD |
| **visionOS** | 1.0 | `com.echoelmusic.studio.vision` | Echoelmusic Spatial | Apple Vision Pro |

### Platform Capabilities Matrix

| Feature | iOS | macOS | watchOS | tvOS | visionOS |
|---------|-----|-------|---------|------|----------|
| **Audio Recording** | ✅ | ✅ | ❌ | ❌ | ✅ |
| **Video Recording** | ✅ | ✅ | ❌ | ❌ | ✅ |
| **HealthKit/Biofeedback** | ✅ | ❌* | ✅ | ❌ | ✅ |
| **MIDI Control** | ✅ | ✅ | ❌ | ❌ | ✅ |
| **Spatial Audio** | ✅ | ✅ | ❌ | ✅ | ✅ |
| **3D Visuals** | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Multi-Window** | ✅† | ✅ | ❌ | ❌ | ✅ |
| **Hardware Controllers** | ✅ | ✅ | ❌ | ❌ | ✅ |

**Notes:**
- `*` macOS uses Bluetooth HR monitors instead of HealthKit
- `†` iOS multi-window requires iOS 16+

---

## Build Requirements

### Software Requirements

- **Xcode 15.0+** (for visionOS support)
- **macOS Sonoma 14.0+**
- **Swift 5.9+**
- **XcodeGen** (optional, for project generation)
- **CocoaPods** or **Swift Package Manager**

### Hardware Requirements

- **Mac** (Apple Silicon recommended for best performance)
- **iOS device** (for iOS testing)
- **Apple Watch** (for watchOS testing)
- **Apple TV** (for tvOS testing)
- **Apple Vision Pro** (for visionOS testing, or use Simulator)

### Apple Developer Account

- **Individual or Organization Account** ($99/year)
- **App Store Connect access**
- **Code signing certificates** for all platforms
- **Provisioning profiles** for each platform

---

## Project Structure

```
Echoelmusic/
├── Package.swift                        # Swift Package manifest (multi-platform)
├── project.yml                          # XcodeGen configuration (multi-platform targets)
├── Sources/
│   └── Echoelmusic/
│       ├── EchoelmusicApp.swift        # iOS/macOS entry point
│       ├── Platform/
│       │   └── PlatformBridge.swift    # Cross-platform compatibility layer
│       ├── Audio/                       # Shared audio engine (all platforms)
│       ├── Video/                       # Video capture/editing (iOS/macOS/visionOS)
│       ├── Biofeedback/                # HealthKit integration (iOS/watchOS/visionOS)
│       ├── Control/                     # MIDI/hardware control (iOS/macOS)
│       ├── Visuals/                     # Visualization engine (all platforms)
│       ├── watchOS/
│       │   └── WatchApp.swift          # watchOS entry point
│       ├── tvOS/
│       │   └── TVApp.swift             # tvOS entry point
│       └── visionOS/
│           └── VisionApp.swift         # visionOS entry point
└── Tests/
    └── EchoelmusicTests/
```

---

## Building for Each Platform

### 1. iOS/iPadOS

#### Using Xcode

1. Open `Echoelmusic.xcodeproj` in Xcode
2. Select scheme: **Echoelmusic-iOS**
3. Select destination: iPhone/iPad device or Simulator
4. Press **⌘ + B** to build
5. Press **⌘ + R** to run

#### Using xcodebuild

```bash
# Build for iOS Simulator
xcodebuild -scheme Echoelmusic-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  clean build

# Build for iOS Device (requires code signing)
xcodebuild -scheme Echoelmusic-iOS \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  clean archive \
  -archivePath ./build/Echoelmusic-iOS.xcarchive

# Export IPA
xcodebuild -exportArchive \
  -archivePath ./build/Echoelmusic-iOS.xcarchive \
  -exportPath ./build/iOS \
  -exportOptionsPlist ExportOptions.plist
```

#### Features Available

- Full audio production suite
- Video recording with ProRes 422 HQ
- HealthKit biofeedback integration
- MIDI 2.0 + MPE control
- 6 spatial audio modes
- Hardware controller support (Ableton Push, Stream Deck, DMX)
- ChromaKey video processing
- LUT color grading
- AI composition engine
- Live streaming (RTMP)

---

### 2. macOS

#### Using Xcode

1. Open `Echoelmusic.xcodeproj` in Xcode
2. Select scheme: **Echoelmusic-macOS**
3. Select destination: My Mac
4. Press **⌘ + B** to build
5. Press **⌘ + R** to run

#### Using xcodebuild

```bash
# Build for macOS
xcodebuild -scheme Echoelmusic-macOS \
  -destination 'platform=macOS' \
  clean build

# Create distributable app
xcodebuild -scheme Echoelmusic-macOS \
  -configuration Release \
  clean archive \
  -archivePath ./build/Echoelmusic-macOS.xcarchive

# Export .app
xcodebuild -exportArchive \
  -archivePath ./build/Echoelmusic-macOS.xcarchive \
  -exportPath ./build/macOS \
  -exportOptionsPlist ExportOptions-macOS.plist
```

#### macOS-Specific Features

- Multi-window support (mixer, visualizations, editor)
- Professional audio interface support (Focusrite, UAD, Apogee)
- Bluetooth HR monitor support (replaces HealthKit)
- Keyboard shortcuts and menu bar
- Dock integration
- Touch Bar support (MacBook Pro)

#### macOS Code Differences

The app uses `AppKit` instead of `UIKit`:

```swift
#if os(macOS)
import AppKit
typealias PlatformColor = NSColor
typealias PlatformView = NSView
#endif
```

---

### 3. watchOS

#### Using Xcode

1. Open `Echoelmusic.xcodeproj` in Xcode
2. Select scheme: **Echoelmusic-watchOS**
3. Select destination: Apple Watch Simulator or paired device
4. Press **⌘ + B** to build
5. Press **⌘ + R** to run

#### Using xcodebuild

```bash
# Build for watchOS Simulator
xcodebuild -scheme Echoelmusic-watchOS \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
  clean build

# Build for watchOS Device
xcodebuild -scheme Echoelmusic-watchOS \
  -destination 'generic/platform=watchOS' \
  -configuration Release \
  clean archive \
  -archivePath ./build/Echoelmusic-watchOS.xcarchive
```

#### watchOS Features

- Real-time HRV display
- Heart rate monitoring
- Coherence score visualization
- Remote transport controls (Play/Record/Stop)
- WatchConnectivity sync with iPhone
- Haptic feedback sync
- Complications (watch face widgets)

#### watchOS Limitations

- No audio recording (no microphone access)
- Limited processing power
- Small screen (optimize UI)
- Battery life considerations

---

### 4. tvOS

#### Using Xcode

1. Open `Echoelmusic.xcodeproj` in Xcode
2. Select scheme: **Echoelmusic-tvOS**
3. Select destination: Apple TV Simulator or device
4. Press **⌘ + B** to build
5. Press **⌘ + R** to run

#### Using xcodebuild

```bash
# Build for tvOS Simulator
xcodebuild -scheme Echoelmusic-tvOS \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  clean build

# Build for tvOS Device
xcodebuild -scheme Echoelmusic-tvOS \
  -destination 'generic/platform=tvOS' \
  -configuration Release \
  clean archive \
  -archivePath ./build/Echoelmusic-tvOS.xcarchive
```

#### tvOS Features

- **4K HDR visualizations** (full-screen)
- **Dolby Atmos support** (spatial audio output)
- **Siri Remote navigation** (focus-based UI)
- **5 visualization modes** (Cymatics, Mandala, Particles, Spectral, Waveform)
- **Preset selection** (voice/remote control)

#### tvOS UI Considerations

- **Focus-based navigation** (Siri Remote)
- **Large fonts** (10-foot viewing distance)
- **No touch input** (use `.focusable()`)
- **No HealthKit** (biofeedback disabled)

---

### 5. visionOS (Apple Vision Pro)

#### Using Xcode

1. Open `Echoelmusic.xcodeproj` in Xcode
2. Select scheme: **Echoelmusic-visionOS**
3. Select destination: Apple Vision Pro Simulator or device
4. Press **⌘ + B** to build
5. Press **⌘ + R** to run

#### Using xcodebuild

```bash
# Build for visionOS Simulator
xcodebuild -scheme Echoelmusic-visionOS \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro' \
  clean build

# Build for visionOS Device
xcodebuild -scheme Echoelmusic-visionOS \
  -destination 'generic/platform=visionOS' \
  -configuration Release \
  clean archive \
  -archivePath ./build/Echoelmusic-visionOS.xcarchive
```

#### visionOS Features

- **3D Volumetric Cymatics** (RealityKit)
  - 262 particles in Fibonacci sphere distribution
  - Real-time frequency-reactive scaling
  - Color-shifting based on audio spectrum
- **Immersive Space Mode** (full 360° environment)
- **Eye tracking** for note selection
- **Hand gestures** (6DOF control)
- **Spatial audio** (head-tracked)
- **Multi-window support** (mixer + editor + visuals)

#### visionOS Code Example

```swift
#if os(visionOS)
import RealityKit

struct Cymatics3DVolume: View {
    var body: some View {
        RealityView { content in
            // Create 3D particle system
            let particles = createFibonacciSphere(count: 262)
            particles.forEach { content.add($0) }
        } update: { content in
            // Update based on audio spectrum
            updateParticles(from: audioEngine.spectrum)
        }
    }
}
#endif
```

---

## Code Signing

### Development Certificates

1. Open Xcode → **Settings** → **Accounts**
2. Add your Apple ID
3. Select team → **Manage Certificates**
4. Click **+** → Create certificates for each platform:
   - iOS Development
   - Mac Development
   - watchOS Development
   - tvOS Development
   - visionOS Development

### Distribution Certificates

For App Store submission:

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. **Certificates, Identifiers & Profiles**
3. Create **App Store Distribution** certificate
4. Download and install in Keychain

### Provisioning Profiles

Create provisioning profiles for each platform:

1. **Identifiers** → Register App IDs:
   - `com.echoelmusic.studio` (iOS)
   - `com.echoelmusic.studio.mac` (macOS)
   - `com.echoelmusic.studio.watchos` (watchOS)
   - `com.echoelmusic.studio.tv` (tvOS)
   - `com.echoelmusic.studio.vision` (visionOS)

2. **Profiles** → Create provisioning profiles
   - Link each App ID to your distribution certificate
   - Download and install profiles

3. **Xcode** → Automatically manage signing:
   ```
   Target → Signing & Capabilities
   ✅ Automatically manage signing
   Team: [Your Team]
   ```

---

## App Store Submission

### Pre-Submission Checklist

- [ ] All platforms build successfully
- [ ] Code signed with distribution certificates
- [ ] App icons provided for all sizes
- [ ] Privacy descriptions added to Info.plist:
  - `NSMicrophoneUsageDescription`
  - `NSCameraUsageDescription`
  - `NSHealthShareUsageDescription`
  - `NSPhotoLibraryUsageDescription`
- [ ] TestFlight beta testing completed
- [ ] App Store Connect metadata prepared
- [ ] Screenshots for all platforms (required sizes)
- [ ] App Preview videos (optional but recommended)

### Creating Archives

#### iOS

```bash
xcodebuild -scheme Echoelmusic-iOS \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  clean archive \
  -archivePath ./build/Echoelmusic-iOS.xcarchive
```

#### macOS

```bash
xcodebuild -scheme Echoelmusic-macOS \
  -configuration Release \
  clean archive \
  -archivePath ./build/Echoelmusic-macOS.xcarchive
```

#### watchOS

```bash
xcodebuild -scheme Echoelmusic-watchOS \
  -destination 'generic/platform=watchOS' \
  -configuration Release \
  clean archive \
  -archivePath ./build/Echoelmusic-watchOS.xcarchive
```

#### tvOS

```bash
xcodebuild -scheme Echoelmusic-tvOS \
  -destination 'generic/platform=tvOS' \
  -configuration Release \
  clean archive \
  -archivePath ./build/Echoelmusic-tvOS.xcarchive
```

#### visionOS

```bash
xcodebuild -scheme Echoelmusic-visionOS \
  -destination 'generic/platform=visionOS' \
  -configuration Release \
  clean archive \
  -archivePath ./build/Echoelmusic-visionOS.xcarchive
```

### Upload to App Store Connect

#### Using Xcode

1. **Window** → **Organizer**
2. Select archive for each platform
3. Click **Distribute App**
4. Select **App Store Connect**
5. Upload

#### Using Transporter

1. Export archives as `.ipa`/`.app`/`.pkg`
2. Open **Transporter** app
3. Drag and drop archives
4. Click **Deliver**

#### Using Command Line

```bash
xcrun altool --upload-app \
  --type ios \
  --file ./build/iOS/Echoelmusic.ipa \
  --username "your@email.com" \
  --password "@keychain:AC_PASSWORD"
```

---

## Platform-Specific Features

### iOS/iPadOS

```swift
#if os(iOS)
import HealthKit

class HealthKitManager {
    func startMonitoring() {
        // Request HealthKit authorization
        // Monitor heart rate & HRV
    }
}
#endif
```

### macOS

```swift
#if os(macOS)
import AppKit

extension EchoelmusicApp {
    func openSecondaryWindow() {
        let window = NSWindow(...)
        window.contentView = NSHostingView(rootView: VisualizationView())
        window.makeKeyAndOrderFront(nil)
    }
}
#endif
```

### watchOS

```swift
#if os(watchOS)
import WatchConnectivity

class WatchSessionManager: NSObject, WCSessionDelegate {
    func sendCommand(_ command: Command) {
        WCSession.default.sendMessage(...)
    }
}
#endif
```

### tvOS

```swift
#if os(tvOS)
struct TVContentView: View {
    @FocusState private var focusedItem: Int?

    var body: some View {
        Button("Play") { ... }
            .focusable()
            .focused($focusedItem, equals: 0)
    }
}
#endif
```

### visionOS

```swift
#if os(visionOS)
import RealityKit

struct ImmersiveSpace: Scene {
    var body: some Scene {
        ImmersiveSpace(id: "Cymatics") {
            RealityView { content in
                // 3D content
            }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
#endif
```

---

## Troubleshooting

### Common Build Errors

#### "No such module 'HealthKit'" (macOS)

**Solution:** HealthKit is not available on macOS. Use conditional compilation:

```swift
#if os(iOS) || os(watchOS)
import HealthKit
#endif
```

#### "Use of unresolved identifier 'UIColor'" (macOS)

**Solution:** macOS uses `NSColor`. Use platform type aliases:

```swift
#if os(macOS)
typealias PlatformColor = NSColor
#else
typealias PlatformColor = UIColor
#endif
```

#### "Cannot find 'WKInterfaceController'" (iOS)

**Solution:** WatchKit is watchOS-only:

```swift
#if os(watchOS)
import WatchKit
#endif
```

#### Code Signing Error

**Solution:**
1. Check that provisioning profiles are installed
2. Verify bundle IDs match
3. Ensure certificates are valid
4. Clean build folder: **⇧⌘K**

### Performance Issues

#### iOS/iPadOS

- Use Metal for GPU acceleration
- Optimize buffer size (512 samples)
- Enable background audio mode

#### macOS

- Support multi-core processing
- Optimize for both Intel and Apple Silicon
- Use dispatch queues for parallel tasks

#### watchOS

- Minimize battery usage
- Reduce update frequency
- Use complications wisely

#### tvOS

- Optimize for 4K rendering
- Use Metal shaders for visualizations
- Limit real-time processing

#### visionOS

- Optimize 3D particle count
- Use instanced rendering
- Implement adaptive quality

---

## Next Steps

1. **Build all platforms** locally to verify compilation
2. **Run unit tests** for each platform
3. **Beta test** via TestFlight
4. **Prepare App Store metadata** (descriptions, screenshots, videos)
5. **Submit for review** to App Store Connect
6. **Monitor crash reports** via Xcode Organizer

---

## Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Xcode Release Notes](https://developer.apple.com/xcode/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [WWDC Videos](https://developer.apple.com/videos/)

---

**Echoelmusic** - Universal Audio/Video Production Suite for All Apple Platforms
Version 1.0 | © 2024 Echoelmusic | All platforms supported
