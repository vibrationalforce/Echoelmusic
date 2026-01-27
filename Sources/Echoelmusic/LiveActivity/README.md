# LiveActivity Module

Dynamic Island and Lock Screen Live Activities for Echoelmusic.

## Overview

This module provides Live Activities support for iOS 16.1+, displaying real-time session information on the Dynamic Island and Lock Screen.

## Features

### Dynamic Island

Compact and expanded views showing:
- Session timer
- Coherence level (color-coded)
- Heart rate
- Quick controls

### Lock Screen

Persistent session information:
- Session name
- Duration timer
- Bio-metrics summary
- Coherence graph

## Key Components

### QuantumLiveActivityManager

Singleton managing live activities:

```swift
let manager = QuantumLiveActivityManager.shared

// Start live activity
try await manager.startSession(
    name: "Morning Meditation",
    mode: "Bio-Coherent",
    targetDuration: 600
)

// Update with bio data
manager.updateCoherence(0.85)
manager.updateHeartRate(72)
manager.updateTimer(elapsed: 180)

// End activity
manager.endSession()
```

### Activity Attributes

```swift
struct EchoelmusicActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var coherenceLevel: Float
        var heartRate: Int
        var elapsedSeconds: Int
        var isActive: Bool
    }

    var sessionName: String
    var mode: String
    var targetDuration: Int
}
```

### Live Activity Views

**Compact View** (Dynamic Island pill)
```swift
DynamicIslandCompactView(context: context)
// Shows: Timer | Coherence indicator
```

**Expanded View** (Dynamic Island expanded)
```swift
DynamicIslandExpandedView(context: context)
// Shows: Full session info, controls
```

**Lock Screen View**
```swift
LockScreenLiveActivityView(context: context)
// Shows: Session details, coherence graph
```

## Update Frequency

Live Activities update at optimal intervals:
- Coherence: Every 5 seconds
- Heart rate: Every 3 seconds
- Timer: Every 1 second
- Graph: Every 10 seconds

## Visual States

### Coherence Indicators

| Level | Color | State |
|-------|-------|-------|
| 0-30% | Red | Low |
| 30-60% | Yellow | Medium |
| 60-80% | Green | Good |
| 80-100% | Cyan | Excellent |

### Activity States

```swift
enum SessionState {
    case starting    // Warming up
    case active      // In session
    case paused      // Temporarily stopped
    case completing  // Winding down
    case ended       // Session complete
}
```

## Configuration

Enable/disable Live Activities:

```swift
// Check availability
if ActivityAuthorizationInfo().areActivitiesEnabled {
    // Start activity
}

// User preference
UserDefaults.standard.set(true, forKey: "enableLiveActivity")
```

## Privacy

- Bio data visible on Lock Screen
- Option to hide sensitive info when locked
- Respects system privacy settings

## Battery Optimization

- Updates batched when possible
- Reduced frequency in low power mode
- Automatic cleanup after 8 hours

## Requirements

- iOS 16.1+
- iPhone 14 Pro+ for Dynamic Island
- ActivityKit framework

## Files

| File | Description |
|------|-------------|
| `QuantumLiveActivityManager.swift` | Activity management |
| `EchoelmusicActivityAttributes.swift` | Activity data model |
| `DynamicIslandViews.swift` | Dynamic Island UI |
| `LockScreenActivityView.swift` | Lock Screen UI |
