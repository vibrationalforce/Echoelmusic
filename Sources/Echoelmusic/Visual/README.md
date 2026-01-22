# Visual Module

Real-time visualization engine for bio-reactive graphics.

## Overview

The Visual module generates real-time graphics that respond to biometric data, audio, and MIDI input. It supports multiple rendering backends including Metal, OpenGL, and WebGL.

## Key Components

| Component | Description |
|-----------|-------------|
| `MIDIToVisualMapper` | Maps MIDI to visual parameters |
| `VisualStepSequencer` | 16-step pattern-based visual triggers |
| `VisualMethodMapper` | Connects input sources to visual methods |
| `Intelligent360VisualEngine` | 360° immersive visualization |

## Visual Modes (30+)

- Sacred Geometry
- Fractals
- Quantum Waves
- Cosmic Nebula
- Particle Life
- Mandala
- Bio-Reactive Aura

## Usage

```swift
let mapper = MIDIToVisualMapper()
mapper.mapNoteToHue(note: 60, velocity: 100)

// Bio-reactive visuals
mapper.updateFromBioData(coherence: 0.85, heartRate: 72)
```

## Input Sources

| Source | Visual Effect |
|--------|--------------|
| Heart Rate | Pulse, intensity |
| HRV Coherence | Harmony, complexity |
| Breathing | Scale, opacity |
| MIDI Notes | Color, position |
| Audio Level | Particle emission |

## Performance

- Target: 60 FPS (120 on ProMotion)
- GPU-accelerated rendering
- Adaptive quality based on device
