# Utils Module

Utility classes and helpers for device capabilities and tracking.

## Overview

This module provides device-level utilities including capability detection, head tracking, and system information gathering.

## Key Components

### DeviceCapabilities

Detects device hardware and software capabilities:

```swift
let capabilities = DeviceCapabilities()

// Device info
capabilities.deviceModel       // "iPhone 16 Pro"
capabilities.iOSVersion        // "18.0"

// Feature support
capabilities.supportsASAF      // Apple Spatial Audio Features
capabilities.supportsAPACCodec // APAC codec (AirPods Pro 3)
capabilities.canUseSpatialAudio
capabilities.canUseHeadTracking
capabilities.canUseSpatialAudioEngine

// Audio output
capabilities.hasAirPodsConnected
capabilities.airPodsModel
```

### HeadTrackingManager

Real-time head tracking using CMHeadphoneMotionManager:

```swift
let tracker = HeadTrackingManager()

// Start tracking
tracker.startTracking()

// Access rotation data
tracker.headRotation       // HeadRotation (yaw, pitch, roll in radians)
tracker.normalizedPosition // NormalizedPosition (-1 to 1 range)

// Spatial audio integration
let audioPos = tracker.get3DAudioPosition()
let orientation = tracker.getListenerOrientation()

// UI helpers
let color = tracker.getVisualizationColor()
let arrow = tracker.getDirectionArrow()

// Stop tracking
tracker.stopTracking()
```

### Data Structures

**HeadRotation**
```swift
struct HeadRotation: Sendable {
    var yaw: Double   // Left-right (-π to π)
    var pitch: Double // Up-down (-π/2 to π/2)
    var roll: Double  // Tilt (-π to π)
    var degrees: (yaw: Double, pitch: Double, roll: Double)
}
```

**NormalizedPosition**
```swift
struct NormalizedPosition: Sendable {
    var x: Double // -1.0 (left) to 1.0 (right)
    var y: Double // -1.0 (down) to 1.0 (up)
    var z: Double // -1.0 (back) to 1.0 (forward)
}
```

## Features

### Device Detection
- iPhone models (15 through 20 series)
- iPad Pro models
- Apple Watch models
- Apple Vision Pro models
- iOS Simulator detection

### Capability Checks
- iOS version requirements
- ASAF (Apple Spatial Audio Features) support
- Head tracking availability
- AirPods model detection
- APAC codec support

### Audio Route Monitoring
- Real-time AirPods connection detection
- Automatic re-detection on route changes

## Platform Support

| Platform | DeviceCapabilities | HeadTrackingManager |
|----------|-------------------|---------------------|
| iOS | Full support | Full support |
| macOS | Partial | Stub only |
| watchOS | Stub only | N/A |
| tvOS | Stub only | N/A |
| visionOS | Full support | Native tracking |

## Usage Examples

### Adaptive Audio Configuration

```swift
let capabilities = DeviceCapabilities()

switch capabilities.recommendedAudioConfig {
case .spatialAudio:
    enableFullSpatialAudio()
case .binauralBeats:
    enableBinauralProcessing()
case .standard:
    enableStereoOutput()
}
```

### Head-Controlled Effects

```swift
let tracker = HeadTrackingManager()
tracker.startTracking()

// Map head position to filter cutoff
let cutoff = 200 + (tracker.normalizedPosition.x + 1) * 4800
filter.setCutoff(cutoff)

// Map head rotation to reverb positioning
spatialAudio.setListenerOrientation(tracker.getListenerOrientation())
```

## Files

| File | Description |
|------|-------------|
| `DeviceCapabilities.swift` | Device and capability detection |
| `HeadTrackingManager.swift` | CMHeadphoneMotionManager wrapper |
