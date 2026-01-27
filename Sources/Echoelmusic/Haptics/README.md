# Haptics Module

Rich haptic feedback experiences for Echoelmusic.

## Overview

The Haptics module provides bio-synchronized haptic patterns, compositions, and feedback for immersive tactile experiences.

## Key Components

| Component | Description |
|-----------|-------------|
| `HapticCompositionEngine` | Haptic pattern composition |
| `HapticEvent` | Individual haptic events |
| `HapticPattern` | Pre-defined patterns |
| `BioHapticSync` | Bio-reactive haptics |

## Pattern Types (15)

| Pattern | Description |
|---------|-------------|
| Heartbeat | Sync to heart rate |
| Breathing | Inhale/exhale rhythm |
| Quantum Flutter | Rapid micro-pulses |
| Meditation | Slow, calming |
| Coherence Pulse | Based on HRV |
| Energy Boost | Stimulating rhythm |
| Focus | Attention-grabbing |
| Success/Error | Feedback patterns |

## Usage

```swift
let haptics = HapticCompositionEngine()

// Play simple pattern
haptics.play(.heartbeat)

// Bio-synced pattern
haptics.playBioSynced(
    heartRate: 72,
    coherence: 0.8
)

// Custom composition
let composition = HapticComposition()
composition.add(.transient, at: 0.0, intensity: 0.8)
composition.add(.continuous(duration: 0.5), at: 0.2)
composition.loop = true
haptics.play(composition)
```

## Event Types

| Type | Description |
|------|-------------|
| Transient | Sharp, quick tap |
| Continuous | Sustained vibration |
| Audio-Based | Driven by audio input |

## Bio-Reactive Mapping

- Heart rate → Tempo
- Coherence → Intensity
- Breathing → Pattern duration
- GSR → Sharpness

## Platform Support

| Platform | Engine |
|----------|--------|
| iOS | Core Haptics |
| watchOS | WKHapticType |
| visionOS | Spatial Haptics |

## Dependencies

- CoreHaptics
- Biofeedback module
