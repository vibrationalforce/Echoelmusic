# Sequencer Module

Visual step sequencer with bio-reactive modulation for Echoelmusic.

## Overview

The VisualStepSequencer provides a 16-step, 8-channel pattern sequencer inspired by [nw_wrld](https://github.com/aagentah/nw_wrld). It features bio-feedback modulation where HRV and coherence data influence sequencer behavior.

## Key Components

### VisualStepSequencer

Main sequencer engine (singleton):

```swift
let sequencer = VisualStepSequencer.shared

// Playback control
sequencer.play()
sequencer.pause()
sequencer.stop()

// Pattern editing
sequencer.toggleStep(channel: .visual1, step: 0)
sequencer.setVelocity(channel: .visual1, step: 0, velocity: 0.8)
sequencer.clearChannel(.visual1)
sequencer.clearAll()

// Bio-feedback integration
sequencer.updateBioState(coherence: 0.8, heartRate: 72, hrvVariability: 0.6)

// Load presets
sequencer.loadPreset(.fourOnFloor)
```

### Channels

8 independent trigger channels:

| Channel | Purpose | Color |
|---------|---------|-------|
| `.visual1` | Visual A | Cyan |
| `.visual2` | Visual B | Purple |
| `.visual3` | Visual C | Pink |
| `.visual4` | Visual D | Orange |
| `.lighting` | DMX/Lighting | Yellow |
| `.effect1` | Effect 1 | Green |
| `.effect2` | Effect 2 | Blue |
| `.bioTrigger` | Bio Events | Red |

### SequencerPattern

Pattern data structure:

```swift
var pattern = SequencerPattern()

// Query state
pattern.isActive(channel: .visual1, step: 0)  // Bool
pattern.velocity(channel: .visual1, step: 0)  // Float

// Modify pattern
pattern.toggle(channel: .visual1, step: 0)
pattern.setVelocity(channel: .visual1, step: 0, velocity: 0.7)
pattern.clearChannel(.visual1)
```

### Bio-Reactive Features

**Heart Rate → BPM Lock**
```swift
sequencer.bioModulation.tempoLockEnabled = true
// BPM smoothly follows heart rate (60-180 range)
```

**HRV → Pattern Density**
- High HRV variability = full pattern playback
- Low HRV variability = up to 30% step skip probability

**Coherence → Velocity Modulation**
- High coherence = louder triggers
- Low coherence = softer triggers

### Presets

| Preset | BPM | Description |
|--------|-----|-------------|
| `fourOnFloor` | 120 | Classic kick pattern on beats |
| `breakbeat` | 90 | Syncopated rhythm |
| `ambient` | 70 | Sparse, atmospheric |
| `bioReactive` | 100 | Dense pattern for bio-modulation |
| `minimal` | 110 | Less is more |

## Events

Listen for step triggers:

```swift
NotificationCenter.default.addObserver(
    forName: .sequencerStepTriggered,
    object: nil,
    queue: .main
) { notification in
    if let userInfo = notification.userInfo,
       let channel = userInfo["channel"] as? VisualStepSequencer.Channel,
       let step = userInfo["step"] as? Int,
       let velocity = userInfo["velocity"] as? Float {
        triggerVisual(channel: channel, velocity: velocity)
    }
}
```

## SwiftUI View

```swift
// Add to your view hierarchy
VisualStepSequencerView()
```

Features:
- 16-step × 8-channel grid
- BPM slider (60-180)
- Play/pause/stop transport
- Preset menu
- Bio-lock toggle
- Real-time bio status display

## Technical Details

### Timing

- 16th note resolution
- Step interval = 60 / BPM / 4
- 60 Hz timer for smooth updates

### Bio Modulation

```swift
// Skip probability from HRV
skipProbability = (1.0 - hrvVariability) * 0.3

// Velocity modulation from coherence
modulatedVelocity = velocity * (0.5 + coherence * 0.5)

// BPM from heart rate (when tempo-locked)
bpm = bpm * 0.95 + targetBPM * 0.05  // Smooth transition
```

## Files

| File | Description |
|------|-------------|
| `VisualStepSequencer.swift` | Complete sequencer implementation |

## Dependencies

- SwiftUI
- Combine
- Foundation
