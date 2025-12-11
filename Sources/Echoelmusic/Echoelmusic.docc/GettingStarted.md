# Getting Started with Echoelmusic

Learn how to set up and start using the Echoelmusic framework.

## Overview

Echoelmusic is designed to be easy to integrate while providing powerful bio-reactive audio capabilities. This guide walks you through the initial setup.

### Requirements

- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+ / visionOS 1.0+
- Xcode 15.0+
- Swift 5.9+

### Installation

#### Swift Package Manager

Add Echoelmusic to your project using SPM:

```swift
dependencies: [
    .package(url: "https://github.com/echoelmusic/echoelmusic-ios", from: "1.0.0")
]
```

### Basic Setup

1. **Initialize the Framework**

```swift
import Echoelmusic

@main
struct MyApp: App {
    init() {
        // Configure logging
        Logger.setMinLevel(.info)

        // Initialize dependency container
        let container = DependencyContainer.shared

        print("Echoelmusic initialized on \(Platform.current)")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

2. **Start Bio-Reactive Audio**

```swift
class AudioController: ObservableObject {
    private let audioActor = ThreadSafeManagers.audio
    private let bioActor = ThreadSafeManagers.biofeedback

    func startSession() async {
        // Configure audio
        await audioActor.setSampleRate(48000)
        await audioActor.setBufferSize(256)
        await audioActor.setRunning(true)

        // Start monitoring biofeedback
        // Audio will automatically respond to heart rate changes
    }
}
```

3. **Enable HealthKit Integration**

```swift
class HealthController {
    let healthManager = HealthKitManager()

    func requestAccess() async throws {
        try await healthManager.requestAuthorization()
        healthManager.startMonitoring()
    }
}
```

### Platform Detection

```swift
// Check current platform
switch Platform.current {
case .iOS, .iPadOS:
    // Enable touch instruments
    break
case .macOS:
    // Enable keyboard shortcuts
    break
case .visionOS:
    // Enable spatial audio and hand tracking
    break
default:
    break
}

// Check capabilities
if Platform.current.supportsARKit {
    // Enable face tracking
}

if Platform.current.supportsMetal {
    // Enable GPU visualizations
}
```

### Safe Programming Patterns

Echoelmusic eliminates force unwraps throughout. Use these patterns:

```swift
// Safe optional unwrapping
let value = optional.safely("default")

// Safe array access
let element = array[safe: index, default: defaultValue]

// Safe dictionary access
let dictValue = dict[safe: key, default: defaultValue]

// Validation
let validator = QuantumValidator()
let result = await validator.validateMIDI(noteNumber)
if result.isValid {
    // Process MIDI
}
```

## Topics

### Next Steps

- <doc:Architecture>
- <doc:ThreadSafety>
