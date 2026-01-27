# Tuist Setup Guide for Echoelmusic

This document explains how to use Tuist to generate and manage the Xcode project for Echoelmusic.

## What is Tuist?

Tuist is a command-line tool that helps you generate, maintain, and interact with your Xcode projects. It uses Swift to define your project structure, making it version-control friendly and easier to maintain than traditional `.xcodeproj` files.

## Installation

### Using Homebrew (Recommended)
```bash
brew install tuist
```

### Using Mise (Alternative)
```bash
mise install tuist
```

### Manual Installation
```bash
curl -Ls https://install.tuist.io | bash
```

Verify installation:
```bash
tuist version
```

## Project Structure

```
Echoelmusic/
├── Project.swift                    # Main project definition (Tuist manifest)
├── Tuist/
│   └── Config.swift                # Tuist configuration
├── *.entitlements                   # All platform entitlements files
├── Sources/                         # Source code
├── Tests/                           # Test code
└── Resources/                       # Assets and resources
```

## Usage

### Generate Xcode Project

From the Echoelmusic directory, run:

```bash
tuist generate
```

This will:
1. Parse `Project.swift`
2. Generate `Echoelmusic.xcworkspace`
3. Create all target configurations
4. Set up dependencies between targets
5. Configure build settings

### Open in Xcode

After generation:

```bash
tuist open
# or
open Echoelmusic.xcworkspace
```

### Clean Generated Files

To remove generated Xcode project files:

```bash
tuist clean
```

### Edit Project Definition

The project structure is defined in `/home/user/Echoelmusic/Project.swift`. Edit this file to:
- Add new targets
- Modify build settings
- Change dependencies
- Update entitlements
- Configure schemes

After editing, regenerate:
```bash
tuist generate
```

## Project Configuration

### Targets Included

1. **Echoelmusic** (iOS App)
   - Bundle ID: `com.echoelmusic.app`
   - Deployment Target: iOS 15.0+
   - Main application target

2. **EchoelmusicMac** (macOS App)
   - Bundle ID: `com.echoelmusic.app`
   - Deployment Target: macOS 12.0+
   - Native macOS application

3. **EchoelmusicWatch** (watchOS App)
   - Bundle ID: `com.echoelmusic.app`
   - Deployment Target: watchOS 8.0+
   - Apple Watch standalone app (Universal Purchase)

4. **EchoelmusicTV** (tvOS App)
   - Bundle ID: `com.echoelmusic.app`
   - Deployment Target: tvOS 15.0+
   - Apple TV big screen experience

5. **EchoelmusicVision** (visionOS App)
   - Bundle ID: `com.echoelmusic.app`
   - Deployment Target: visionOS 1.0+
   - Spatial computing experience

6. **EchoelmusicWidgets** (Widget Extension)
   - Bundle ID: `com.echoelmusic.app.widgets`
   - Home screen widgets for iOS

7. **EchoelmusicAUv3** (Audio Unit Plugin)
   - Bundle ID: `com.echoelmusic.app.auv3`
   - AUv3 audio plugin for DAWs

8. **EchoelmusicTests** (Unit Tests)
   - Test target for all unit tests

9. **EchoelmusicUITests** (UI Tests)
   - Test target for UI automation

### Build Configurations

- **Debug**: Development builds with full debugging
  - `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG`
  - `GCC_OPTIMIZATION_LEVEL = 0`
  - Testability enabled

- **Release**: Production builds
  - `SWIFT_OPTIMIZATION_LEVEL = -O`
  - `GCC_OPTIMIZATION_LEVEL = s`
  - Whole module optimization

### Schemes Available

- **Echoelmusic**: iOS app with tests
- **EchoelmusicMac**: macOS app
- **EchoelmusicWatch**: watchOS app
- **EchoelmusicTV**: tvOS app
- **EchoelmusicVision**: visionOS app
- **Echoelmusic-AllPlatforms**: Build all targets at once

## Signing Configuration

The project uses automatic signing by default. To configure:

1. Set your development team in Xcode:
   - Select the project in navigator
   - Choose a target
   - Go to "Signing & Capabilities"
   - Select your Team

2. Or set the `DEVELOPMENT_TEAM` environment variable:
   ```bash
   export DEVELOPMENT_TEAM="YOUR_TEAM_ID"
   tuist generate
   ```

3. For production builds, update the signing settings in `Project.swift`

## Entitlements

Each target has its own entitlements file:

- `Echoelmusic.entitlements` - Main iOS app (HealthKit, iCloud, HomeKit, etc.)
- `EchoelmusicMac.entitlements` - macOS app (USB, Audio, Network, etc.)
- `EchoelmusicWatch.entitlements` - watchOS app (HealthKit, Workout processing)
- `EchoelmusicTV.entitlements` - tvOS app (Network, HomeKit)
- `EchoelmusicVision.entitlements` - visionOS app (ARKit, Eye tracking, Hand tracking)
- `EchoelmusicWidgets.entitlements` - Widget extension (App Groups)
- `EchoelmusicAUv3.entitlements` - Audio Unit plugin (Inter-App Audio)

## Advanced Features

### Focused Mode

Generate only specific targets:

```bash
tuist generate --no-open Echoelmusic EchoelmusicMac
```

### Custom Configurations

To add a new configuration (e.g., Staging):

1. Edit `Project.swift`
2. Add to `configurations` array in `settings`
3. Regenerate project

### Cache

Speed up project generation with cache:

```bash
tuist cache warm
tuist generate --cache
```

### Dependencies

The project uses Swift Package Manager dependencies. To update:

```bash
tuist fetch
```

## Integration with Existing Workflow

### With Swift Package Manager

Tuist works alongside SPM. The `Package.swift` file defines dependencies, while `Project.swift` defines the Xcode project structure.

### With CI/CD

In your CI pipeline:

```bash
# Install Tuist
brew install tuist

# Generate project
tuist generate

# Build
xcodebuild -workspace Echoelmusic.xcworkspace -scheme Echoelmusic -configuration Release
```

### With Git

Add to `.gitignore`:
```
*.xcodeproj
*.xcworkspace
xcuserdata/
DerivedData/
.build/
Tuist/Dependencies/
```

Keep in version control:
```
Project.swift
Tuist/Config.swift
*.entitlements
Package.swift
```

## Troubleshooting

### "Command not found: tuist"

Install Tuist using one of the methods above.

### "Project.swift: error: ..."

Check Swift syntax in `Project.swift`. The file must be valid Swift code.

### Missing entitlements

Ensure all `.entitlements` files exist in the project root.

### Signing errors

1. Check your development team is set
2. Verify bundle IDs are unique
3. Ensure provisioning profiles are valid

### Clean build issues

```bash
tuist clean
rm -rf DerivedData
tuist generate
```

## Resources

- [Tuist Documentation](https://docs.tuist.io)
- [Tuist Examples](https://github.com/tuist/tuist/tree/main/fixtures)
- [Project.swift Reference](https://docs.tuist.io/manifests/project/)

## Customization

### Adding a New Target

1. Edit `Project.swift`
2. Add new `Target(...)` to the `targets` array
3. Create corresponding entitlements file if needed
4. Add source files
5. Run `tuist generate`

### Modifying Build Settings

1. Edit the `settings` section in `Project.swift`
2. Add/modify base settings or configuration-specific settings
3. Regenerate project

### Adding Dependencies

1. Add framework to `dependencies` array in target
2. For external dependencies, use Swift Package Manager in `Package.swift`
3. Run `tuist fetch && tuist generate`

---

**Note**: Always regenerate the project after modifying `Project.swift` or `Tuist/Config.swift`.

For questions or issues, refer to the main `CLAUDE.md` documentation.
