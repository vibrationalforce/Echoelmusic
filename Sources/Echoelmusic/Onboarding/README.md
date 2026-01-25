# Onboarding Module

User onboarding flow and permission management for Echoelmusic.

## Overview

The Onboarding module provides a 5-step guided introduction to help new users set up the app, grant necessary permissions, and understand key features.

## Onboarding Steps

1. **Welcome** - Introduction to Echoelmusic
2. **Features** - Overview of core capabilities
3. **Permissions** - HealthKit and microphone access
4. **Watch Setup** - Apple Watch pairing
5. **Ready** - Confirmation and launch

## Components

### OnboardingManager

Singleton managing onboarding state:

```swift
let manager = OnboardingManager.shared

// Check if onboarding completed
if !manager.hasCompletedOnboarding {
    showOnboarding()
}

// Permission states
manager.hasGrantedHealthKit   // HealthKit authorized
manager.hasGrantedMicrophone  // Microphone access
manager.hasConnectedWatch     // Watch app installed

// Check current permissions
manager.checkPermissions()

// Mark complete
manager.completeOnboarding()

// Reset (for testing)
manager.resetOnboarding()
```

### OnboardingView

Main SwiftUI view container:

```swift
OnboardingView()
```

Features:
- Page-based navigation with TabView
- Custom page indicators
- Animated transitions
- Automatic dismissal on completion

## Permission Handling

### HealthKit

```swift
// Requested types
- heartRate
- heartRateVariabilitySDNN
```

### Microphone

```swift
// For voice-reactive features
AVAudioSession.requestRecordPermission()
```

### Watch Connectivity

```swift
// Check if Watch app is installed
WCSession.isSupported()
WCSession.default.isWatchAppInstalled
```

## Persistence

Onboarding state is persisted in UserDefaults:

```swift
UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
```

## Usage

```swift
// In your app's root view
@main
struct EchoelmusicApp: App {
    @StateObject var onboarding = OnboardingManager.shared

    var body: some Scene {
        WindowGroup {
            if onboarding.hasCompletedOnboarding {
                MainAppView()
            } else {
                OnboardingView()
            }
        }
    }
}
```

## Customization

The onboarding pages can be customized by modifying:

- `WelcomePage` - App branding and tagline
- `FeaturesPage` - Feature highlights
- `PermissionsPage` - Permission requests
- `WatchSetupPage` - Watch pairing instructions
- `ReadyPage` - Confirmation screen

## Accessibility

- VoiceOver-compatible navigation
- Dynamic Type support
- Reduced Motion support
- High contrast backgrounds

## Files

| File | Description |
|------|-------------|
| `OnboardingFlow.swift` | Complete onboarding implementation |

## Dependencies

- SwiftUI
- HealthKit (optional)
- AVFoundation
- WatchConnectivity (optional)
