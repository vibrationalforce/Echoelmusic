# Audio Module

Core audio processing engine for Echoelmusic.

## Overview

The Audio module provides audio synthesis, processing, and real-time playback capabilities. It handles spatial audio integration, effects processing, and preset management.

## Key Components

| Component | Description |
|-----------|-------------|
| `AudioEngine` | Main audio engine with master output, effects, and preset loading |
| `ProMixEngine` | Professional mixing console with channel strips and buses |
| `SpatialAudioEngine` | 3D/4D spatial audio rendering (HRTF binaural, ambisonics) |
| `LoopEngine` | Loop recording and playback |
| `RecordingEngine` | Multi-track recording and playback |
| `Nodes/` | Audio graph nodes for synthesis and effects |

## Usage

```swift
let engine = AudioEngine()
engine.start()

// Schedule playback
engine.schedulePlayback(buffer: audioBuffer)

// Control master volume
engine.masterVolume = 0.85
```

## Presets

The engine supports 74+ curated presets for professional audio production.

## Dependencies

- AVFoundation (iOS/macOS)
- Accelerate (SIMD optimization)
- Spatial module (3D audio)

## Performance

- Target latency: <10ms
- CPU usage: <30%
- Sample rate: 44.1kHz / 48kHz
