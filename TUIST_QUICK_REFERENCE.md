# Tuist Quick Reference - Echoelmusic

## Essential Commands

```bash
# Generate Xcode project from Project.swift
tuist generate

# Open generated workspace in Xcode
tuist open

# Clean generated files
tuist clean

# Install Tuist
brew install tuist
```

## Project Structure

```
Project.swift              Main project definition (574 lines)
Tuist/Config.swift         Tuist configuration
*.entitlements             Platform-specific capabilities
TUIST_SETUP.md            Complete documentation (323 lines)
```

## All Targets

| Target | Platform | Bundle ID | Deployment |
|--------|----------|-----------|------------|
| **Echoelmusic** | iOS | `com.echoelmusic.app` | iOS 15.0+ |
| **EchoelmusicMac** | macOS | `com.echoelmusic.app` | macOS 12.0+ |
| **EchoelmusicWatch** | watchOS | `com.echoelmusic.app` | watchOS 8.0+ |
| **EchoelmusicTV** | tvOS | `com.echoelmusic.app` | tvOS 15.0+ |
| **EchoelmusicVision** | visionOS | `com.echoelmusic.app` | visionOS 1.0+ |
| **EchoelmusicWidgets** | iOS Ext | `com.echoelmusic.app.widgets` | iOS 15.0+ |
| **EchoelmusicAUv3** | iOS Ext | `com.echoelmusic.app.auv3` | iOS 15.0+ |
| **EchoelmusicTests** | iOS Tests | `com.echoelmusic.tests` | iOS 15.0+ |
| **EchoelmusicUITests** | iOS Tests | `com.echoelmusic.uitests` | iOS 15.0+ |

## Build Configurations

- **Debug**: Development with full debugging (GCC -O0)
- **Release**: Production optimized (Swift -O, GCC -Os)

## Schemes

- `Echoelmusic` - iOS app + tests
- `EchoelmusicMac` - macOS app
- `EchoelmusicWatch` - watchOS app
- `EchoelmusicTV` - tvOS app
- `EchoelmusicVision` - visionOS app
- `Echoelmusic-AllPlatforms` - Build everything

## Entitlements Summary

### Main App (Echoelmusic.entitlements)
✅ HealthKit (HRV, Heart Rate)
✅ iCloud (CloudKit, Documents)
✅ HomeKit (Smart Lighting)
✅ Network (Multicast, WiFi)
✅ Siri Integration
✅ Apple Music API
✅ Bluetooth (MIDI Controllers)
✅ Push Notifications
✅ Background Audio
✅ App Groups
✅ Keychain Sharing

### macOS (EchoelmusicMac.entitlements)
✅ Audio Input
✅ Camera Access
✅ USB Devices (MIDI)
✅ Network Server (OSC/Art-Net)
✅ File Access
✅ Hardened Runtime

### visionOS (EchoelmusicVision.entitlements)
✅ ARKit
✅ Hand Tracking
✅ Eye Tracking
✅ Passthrough Mode
✅ Extended Virtual Addressing

### watchOS (EchoelmusicWatch.entitlements)
✅ HealthKit
✅ Workout Processing
✅ Background Delivery
✅ App Groups

### Widgets/AUv3 (Extensions)
✅ App Groups (Data Sharing)
✅ Keychain Sharing
✅ Inter-App Audio (AUv3 only)

## Common Workflows

### First Time Setup
```bash
# Install Tuist
brew install tuist

# Generate project
cd /home/user/Echoelmusic
tuist generate

# Open in Xcode
tuist open

# Set your Team ID in Xcode Signing & Capabilities
```

### Daily Development
```bash
# After pulling changes to Project.swift
tuist generate

# Regular Xcode workflow
open Echoelmusic.xcworkspace
# Cmd+B to build, Cmd+R to run
```

### Adding New Target
1. Edit `Project.swift`, add new `Target(...)` to `targets` array
2. Create `TargetName.entitlements` if needed
3. Run `tuist generate`
4. Configure signing in Xcode

### Modify Build Settings
1. Edit `settings` in `Project.swift`
2. Run `tuist generate`
3. Changes apply to all configurations

## Key Features

### Swift 5.9 Configuration
- Strict Concurrency enabled
- SwiftUI Previews enabled
- Whole Module Optimization (Release)
- Testability enabled (Debug)

### Multi-Platform Support
- Single source codebase
- Platform-specific targets
- Shared frameworks via App Groups
- Conditional compilation available

### Testing Infrastructure
- Unit tests with code coverage
- UI tests with automation
- Parallel test execution
- Random execution ordering

### Resource Management
- Automatic asset catalog compilation
- Metal shader compilation
- String localization
- Font and plist resources

## Environment Variables

```bash
# Set your development team
export DEVELOPMENT_TEAM="YOUR_TEAM_ID"

# Then generate
tuist generate
```

## CI/CD Integration

```yaml
# GitHub Actions example
- name: Generate Project
  run: |
    brew install tuist
    tuist generate

- name: Build iOS
  run: |
    xcodebuild -workspace Echoelmusic.xcworkspace \
               -scheme Echoelmusic \
               -configuration Release \
               -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Command not found" | `brew install tuist` |
| Syntax error in Project.swift | Check Swift syntax, ensure valid Swift code |
| Signing errors | Set Team ID in Xcode or environment variable |
| Missing files | Ensure source paths match actual file structure |
| Build failures | `tuist clean && tuist generate` |

## Important Notes

⚠️ **DO NOT** commit generated files:
- `*.xcodeproj`
- `*.xcworkspace`
- `xcuserdata/`
- `DerivedData/`

✅ **DO** commit:
- `Project.swift`
- `Tuist/Config.swift`
- `*.entitlements`
- `Package.swift`

## Resources

- Full Documentation: `TUIST_SETUP.md`
- Project Configuration: `Project.swift`
- Tuist Config: `Tuist/Config.swift`
- Entitlements: `*.entitlements`
- Main Docs: `CLAUDE.md`

---

**Version**: Phase 10000.1 ULTRA MODE
**Organization**: Echoelmusic Technologies
**Swift**: 5.9
**Xcode**: 15.0+
