# Audio Module

Core audio processing engine for Echoelmusic.

## Overview

The Audio module provides the fundamental audio synthesis, processing, and playback capabilities. It handles binaural beat generation, spatial audio integration, and preset management.

## Key Components

| Component | Description |
|-----------|-------------|
| `AudioEngine` | Main audio engine with binaural generation, reverb, and preset loading |
| `BinauralBeatGenerator` | Generates binaural beats for brainwave entrainment |
| `SpatialAudioEngine` | 3D/4D spatial audio rendering |
| `Nodes/` | Audio graph nodes for synthesis and effects |

## Usage

```swift
let engine = AudioEngine()
engine.start()

// Load a preset
engine.loadPreset(named: "Deep Meditation")

// Configure binaural beats
engine.binauralGenerator.configure(carrier: 432.0, beat: 6.0, amplitude: 0.3)
engine.binauralBeatsEnabled = true
```

## Presets

The engine supports 74+ curated presets including:
- **Meditation**: Delta, Theta, Alpha frequencies
- **Focus**: Beta, Gamma frequencies
- **Creative**: Bio-reactive audio synthesis

## Dependencies

- AVFoundation (iOS/macOS)
- Accelerate (SIMD optimization)
- Spatial module (3D audio)

## Performance

- Target latency: <10ms
- CPU usage: <30%
- Sample rate: 44.1kHz / 48kHz
