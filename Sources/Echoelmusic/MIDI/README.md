# MIDI Module

MIDI 2.0 and MPE (MIDI Polyphonic Expression) support.

## Overview

The MIDI module provides comprehensive MIDI input/output handling with support for MIDI 2.0 and MPE for per-note expression control.

## Key Components

| Component | Description |
|-----------|-------------|
| `MIDIManager` | Core MIDI connection management |
| `MPEProcessor` | Per-note polyphonic expression |
| `MIDIToLightMapper` | MIDI to DMX/Art-Net mapping |
| `QuantumMIDIBridge` | Quantum state to MIDI CC |

## MPE Support

```swift
let mpe = MPEProcessor()

// Per-voice expression
mpe.setVoicePitchBend(voice: voice, bend: pitchBend)
mpe.setVoiceBrightness(voice: voice, brightness: jawOpen)
mpe.setVoiceTimbre(voice: voice, timbre: smile)
```

## Supported Controllers

- Ableton Push 3
- Native Instruments (Maschine, Komplete Kontrol)
- Akai (MPC, MPK)
- Novation (Launchpad, SL)
- Arturia (KeyLab, MiniLab)
- Roland (MIDI 2.0 controllers)

## Bio-Reactive MIDI

| Bio Input | MIDI Output |
|-----------|-------------|
| Heart Rate | CC 1 (Mod Wheel) |
| HRV Coherence | CC 74 (Brightness) |
| Breathing | CC 11 (Expression) |

## Usage

```swift
let manager = MIDIManager()
manager.startListening()

manager.onNoteOn = { note, velocity, channel in
    // Handle note
}
```
