# EOEL Xcode Setup Guide

Complete guide to creating and configuring the EOEL Xcode project for iOS development.

---

## Prerequisites

- ✅ macOS Sonoma 14.0+ (for Xcode 15+)
- ✅ Xcode 15.0+ (supports Swift 5.9+, iOS 17.0+)
- ✅ Apple Developer Account ($99/year)
- ✅ Mac with Apple Silicon (M1/M2/M3) or Intel recommended

---

## Step 1: Create New Xcode Project

### 1.1 Launch Xcode

```bash
# Open Xcode
open -a Xcode
```

### 1.2 Create Project

1. **File → New → Project** (⌘⇧N)
2. Select **iOS → App**
3. Click **Next**

### 1.3 Project Configuration

```yaml
Product Name: EOEL
Team: [Your Apple Developer Team]
Organization Identifier: com.eoel
Bundle Identifier: com.eoel.app
Interface: SwiftUI
Language: Swift
Storage: None (we'll use custom)
Include Tests: ✓ (check both Unit and UI Tests)
```

### 1.4 Save Location

```
Save to: /path/to/Echoelmusic/
```

This will create: `/path/to/Echoelmusic/EOEL/`

---

## Step 2: Import Existing Source Files

Our source files are already created in `EOEL/`. Xcode should detect them automatically.

### 2.1 Verify File Structure

```
EOEL/
├── App/
│   ├── EOELApp.swift ✓
│   └── ContentView.swift ✓
├── Core/
│   ├── Audio/
│   │   └── EOELAudioEngine.swift ✓
│   ├── EoelWork/
│   │   └── EoelWorkManager.swift ✓
│   ├── Lighting/
│   │   └── UnifiedLightingController.swift ✓
│   └── Photonics/
│       └── PhotonicSystem.swift ✓
├── Features/
│   ├── DAW/
│   │   └── DAWView.swift ✓
│   ├── VideoEditor/
│   │   └── VideoEditorView.swift ✓
│   ├── Lighting/
│   │   └── LightingControlView.swift ✓
│   ├── EoelWork/
│   │   └── EoelWorkView.swift ✓
│   └── Settings/
│       └── SettingsView.swift ✓
└── Resources/
```

### 2.2 Add Files to Project

If files aren't automatically included:

1. Right-click `EOEL` folder in Project Navigator
2. **Add Files to "EOEL"...**
3. Select all Swift files
4. Options:
   - ✓ Copy items if needed
   - ✓ Create groups
   - ✓ Add to targets: EOEL

---

## Step 3: Configure Project Settings

### 3.1 General Tab

```yaml
Display Name: EOEL
Bundle Identifier: com.eoel.app
Version: 3.0.0
Build: 1

Deployment Info:
  iOS: 17.0
  iPhone: ✓
  iPad: ✓
  Mac (Designed for iPad): ✓

Frameworks:
  - SwiftUI.framework
  - AVFoundation.framework
  - Accelerate.framework
  - CoreML.framework
  - ARKit.framework
  - RealityKit.framework
  - CoreLocation.framework
  - Combine.framework
```

### 3.2 Signing & Capabilities

#### Signing

```yaml
Automatically manage signing: ✓
Team: [Your Apple Developer Team]
Signing Certificate: Apple Development
Provisioning Profile: Xcode Managed Profile
```

#### Capabilities (click + to add)

1. **iCloud**
   - CloudKit
   - Documents (CloudKit container: iCloud.com.eoel.app)

2. **Push Notifications**

3. **Background Modes**
   - Audio, AirPlay, and Picture in Picture
   - Background fetch
   - Remote notifications

4. **HomeKit**
   - For smart lighting integration

5. **Network Extensions**
   - For network discovery (lighting systems)

6. **App Groups**
   - group.com.eoel.app

---

## Step 4: Configure Info.plist

### 4.1 Add Privacy Descriptions

Right-click `Info.plist` → **Open As → Source Code**, then add:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Display -->
    <key>CFBundleDisplayName</key>
    <string>EOEL</string>

    <!-- Privacy - Microphone -->
    <key>NSMicrophoneUsageDescription</key>
    <string>EOEL needs microphone access to record audio for your music production and audio analysis for lighting effects.</string>

    <!-- Privacy - Camera -->
    <key>NSCameraUsageDescription</key>
    <string>EOEL uses the camera for AR features, LiDAR scanning, and video editing.</string>

    <!-- Privacy - Photo Library -->
    <key>NSPhotoLibraryUsageDescription</key>
    <string>EOEL needs access to save your video projects and export your creations.</string>

    <!-- Privacy - Location -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>EoelWork uses your location to find nearby gigs and opportunities.</string>

    <!-- Privacy - Bluetooth -->
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>EOEL uses Bluetooth to connect with smart lighting systems and audio devices.</string>

    <!-- Privacy - Local Network -->
    <key>NSLocalNetworkUsageDescription</key>
    <string>EOEL needs local network access to discover and control lighting systems (Philips Hue, WiZ, DMX512, etc.).</string>

    <key>NSBonjourServices</key>
    <array>
        <string>_hue._tcp</string>
        <string>_wiz._udp</string>
        <string>_artnet._udp</string>
        <string>_sacn._udp</string>
    </array>

    <!-- Privacy - HomeKit -->
    <key>NSHomeKitUsageDescription</key>
    <string>EOEL integrates with HomeKit-enabled lights for unified lighting control.</string>

    <!-- Background Modes -->
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
        <string>fetch</string>
        <string>remote-notification</string>
    </array>

    <!-- Document Types -->
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>EOEL Project</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>com.eoel.project</string>
            </array>
        </dict>
    </array>

    <!-- Exported UTI -->
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.data</string>
                <string>public.content</string>
            </array>
            <key>UTTypeDescription</key>
            <string>EOEL Project</string>
            <key>UTTypeIdentifier</key>
            <string>com.eoel.project</string>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>eoel</string>
                </array>
            </dict>
        </dict>
    </array>

    <!-- Supported Interfaces -->
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>armv7</string>
    </array>

    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
</dict>
</plist>
```

---

## Step 5: Build Settings

### 5.1 Swift Compiler

```yaml
Swift Language Version: Swift 5
Enable Strict Concurrency Checking: Complete
Optimization Level (Debug): -Onone
Optimization Level (Release): -O
```

### 5.2 Linking

```yaml
Other Linker Flags: -ObjC
```

### 5.3 Search Paths

```yaml
Framework Search Paths: $(inherited)
Header Search Paths: $(inherited)
```

---

## Step 6: Add Assets

### 6.1 App Icon

1. Open `Assets.xcassets`
2. Select **AppIcon**
3. Design requirements:
   - 1024x1024 PNG (no alpha)
   - Clean, modern design
   - Purple/pink gradient theme
   - "E" or "EOEL" branding

### 6.2 Color Assets

Add custom colors:

```swift
// In Assets.xcassets, create Color Set:
- EOELPurple: #6366F1
- EOELPink: #EC4899
- EOELCyan: #06B6D4
```

---

## Step 7: Configure Schemes

### 7.1 Edit Scheme (⌘<)

**Run (Debug)**
```yaml
Build Configuration: Debug
Executable: EOEL.app
Debugger: LLDB
Launch: Automatically
```

**Test**
```yaml
Build Configuration: Debug
Test Plans: EOELTests + EOELUITests
Code Coverage: ✓ Gather coverage
```

**Profile**
```yaml
Build Configuration: Release
```

**Archive**
```yaml
Build Configuration: Release
```

---

## Step 8: Build and Test

### 8.1 First Build

```bash
# Select target: EOEL > iPhone 15 Pro (or your device)
⌘B  # Build
⌘R  # Build and Run
```

### 8.2 Expected Build Time

- **First build:** 30-60 seconds
- **Incremental:** 5-10 seconds

### 8.3 Common Build Errors & Fixes

#### Error: "No account for team"
**Fix:** Xcode → Preferences → Accounts → Add Apple ID

#### Error: "Code signing failed"
**Fix:** Select target → Signing & Capabilities → Select Team

#### Error: "Module 'X' not found"
**Fix:** Clean Build Folder (⌘⇧K), then rebuild

---

## Step 9: Run on Physical Device

### 9.1 Connect Device

1. Connect iPhone/iPad via USB
2. Trust computer on device
3. Select device in Xcode toolbar

### 9.2 First Run

```bash
⌘R  # Run on device
```

You may need to:
1. Settings → General → VPN & Device Management
2. Trust developer certificate

---

## Step 10: TestFlight Setup

### 10.1 Archive Build

```bash
# 1. Select "Any iOS Device" as destination
# 2. Product → Archive (⌘B then ⌘⇧B)
# 3. Wait for archiving to complete
```

### 10.2 Distribute to TestFlight

1. **Window → Organizer** (⌘⇧⌥O)
2. Select latest archive
3. Click **Distribute App**
4. Choose **TestFlight & App Store**
5. Next → Upload
6. Wait for processing (15-60 min)

### 10.3 Add Beta Testers

**In App Store Connect:**

1. Navigate to **TestFlight** tab
2. Create **Internal Group** (up to 100 testers)
3. Add testers by email
4. They'll receive TestFlight invite

---

## Step 11: App Store Connect Configuration

### 11.1 Create App Record

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. **My Apps → + → New App**

```yaml
Platform: iOS
Name: EOEL
Primary Language: English (U.S.)
Bundle ID: com.eoel.app
SKU: EOEL-2025
```

### 11.2 App Information

```yaml
Name: EOEL
Subtitle: Music Production & Multi-Industry Platform
Privacy Policy URL: https://eoel.com/privacy
Category: Primary = Music, Secondary = Productivity
```

### 11.3 Pricing

```yaml
Price: Free (with in-app purchases)

In-App Purchases:
  1. EOEL Pro - $9.99/month
  2. EoelWork - $6.99/month
  3. Bundle - $14.99/month
```

---

## Step 12: Continuous Integration (Optional)

### 12.1 Xcode Cloud

1. Product → Xcode Cloud → Create Workflow
2. Choose branch: `claude/echoelmusic-core-features-01RYjZhoa2SwT5GgGtKvkhe1`
3. Configure:
   - Build on: Every commit
   - Test on: iPhone 15 Pro simulator
   - Archive: On tag

---

## Next Steps After Setup

### Week 1: Core Audio Implementation

```swift
// Implement in EOELAudioEngine.swift:
1. Complete audio session configuration
2. Implement real-time audio processing
3. Add basic synthesizer
4. Test latency (<2ms target)
```

### Week 2: DAW Features

```swift
// Implement in DAWView.swift:
1. Multi-track recording
2. Instrument loading
3. Effect processing
4. Mixer UI
```

### Week 3: EoelWork Integration

```swift
// Implement in EoelWorkManager.swift:
1. User authentication
2. Gig discovery
3. Contract management
4. Payment integration
```

### Week 4: Beta Testing

```yaml
1. TestFlight internal testing
2. Fix critical bugs
3. Optimize performance
4. Add external beta testers
```

---

## Troubleshooting

### Build Issues

#### Slow Build Times
```bash
# Clear derived data
rm -rf ~/Library/Developer/Xcode/DerivedData
```

#### Memory Issues
```bash
# Increase Xcode memory limit
defaults write com.apple.dt.Xcode IDEBuildOperationMaxNumberOfConcurrentCompileTasks 4
```

### Runtime Issues

#### Audio Not Working
- Check: Settings → Privacy → Microphone → EOEL ✓
- Verify: Audio session configuration in `initialize()`

#### Lighting Discovery Fails
- Check: Settings → Privacy → Local Network → EOEL ✓
- Verify: Info.plist has NSLocalNetworkUsageDescription

#### LiDAR Not Available
- Device must have LiDAR: iPhone 12 Pro+, iPad Pro 2020+
- Check: ARWorldTrackingConfiguration.supportsSceneReconstruction

---

## Performance Targets

```yaml
Audio:
  Latency: <2ms (128 samples @ 48kHz)
  Sample Rate: 48kHz - 192kHz
  Bit Depth: 32-bit float (64-bit processing)

App:
  Launch Time: <1 second
  Memory Usage: <200 MB idle, <500 MB active
  Frame Rate: 60 FPS UI
  Battery: <5% per hour (background audio)
```

---

## Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Swift.org](https://swift.org)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [AVFoundation Guide](https://developer.apple.com/av-foundation/)
- [ARKit Documentation](https://developer.apple.com/documentation/arkit)
- [TestFlight Guide](https://developer.apple.com/testflight/)

---

## Support

For implementation questions:
- Review: `EOEL_V3_COMPLETE_OVERVIEW.md`
- Review: `EOEL_NEXT_STEPS_ROADMAP.md`
- Review: `EOEL_UNIFIED_LIGHTING_INTEGRATION.md`
- Review: `EOEL_LASER_SYSTEMS_INTEGRATION.md`

---

**🚀 EOEL Xcode Setup Complete!**

You now have a complete Xcode project structure ready for implementation. All core Swift files are in place, and the project is configured for iOS 17.0+ with all required capabilities.

**Next Action:** Open Xcode, build the project (⌘B), and start implementing the audio engine!
