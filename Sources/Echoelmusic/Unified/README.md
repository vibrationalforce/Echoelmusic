# Unified Module

Central control hub orchestrating all input sources at 60 Hz.

## Overview

The Unified module contains `UnifiedControlHub`, the heart of Echoelmusic's real-time control system. It processes inputs from biometrics, gestures, face tracking, voice, and MIDI, resolving conflicts and routing to audio, visual, and lighting systems.

## Key Components

| Component | Description |
|-----------|-------------|
| `UnifiedControlHub` | 60 Hz control loop orchestrator |
| `GestureRecognizer` | Hand gesture detection and mapping |
| `FaceToAudioMapper` | Facial expression to audio parameters |
| `VoiceInputProcessor` | Voice command and pitch detection |

## Control Priority

```
Touch > Gesture > Face > Gaze > Position > Bio
```

Higher priority inputs override lower priority ones for the same parameter.

## Usage

```swift
let hub = UnifiedControlHub()
hub.start()

// Bio signals automatically update audio
hub.updateFromBioSignals()

// Face tracking modulates expression
hub.updateFromFaceTracking()
```

## Control Loop (60 Hz)

```swift
private func controlLoopTick() {
    updateFromBioSignals()
    updateFromFaceTracking()
    updateFromHandGestures()
    resolveConflicts()
    updateAudioEngine()
    updateVisualEngine()
    updateLightSystems()
}
```

## Performance

- Loop frequency: 60 Hz
- Max latency: 16.67ms per tick
- Conflict resolution: Priority-based with smoothing
