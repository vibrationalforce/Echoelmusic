# Spatial Module

3D/4D spatial audio rendering for immersive experiences.

## Overview

The Spatial module provides advanced spatial audio capabilities including head-tracked binaural rendering, Ambisonics, and Atmos-compatible output.

## Key Components

| Component | Description |
|-----------|-------------|
| `SpatialAudioEngine` | Core spatial renderer |
| `HeadTracker` | Device motion integration |
| `AmbisonicsEncoder` | B-format encoding |
| `AFAProcessor` | Acoustic Field Arrangement |

## Spatial Modes

| Mode | Description |
|------|-------------|
| Stereo | Traditional L/R |
| Binaural | HRTF-based headphone 3D |
| Ambisonics | 360° spherical field |
| Atmos | Object-based cinema audio |
| AFA | Fibonacci spatial arrangements |

## Usage

```swift
let spatial = SpatialAudioEngine()
spatial.setMode(.binaural)

// Position a sound source
spatial.setSourcePosition(source: 0, x: 0.5, y: 0.0, z: 1.0)

// Enable head tracking
spatial.enableHeadTracking(true)
```

## Bio-Reactive Spatial

High coherence activates Fibonacci spatial fields:
```swift
if coherence > 60 {
    fieldGeometry = .fibonacci(sourceCount: voiceCount)
} else {
    fieldGeometry = .grid(rows: 3, cols: 3, spacing: 0.5)
}
```

## Platform Support

- iOS/macOS: Core Audio + AVAudioEngine
- visionOS: Spatial Audio API
- Android: Oboe + spatial extensions
