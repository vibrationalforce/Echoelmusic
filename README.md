# Eoel 🎵

**Bio-Reactive Music Creation Platform**

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)

> Transform your biofeedback, voice, and gestures into immersive audio-visual experiences

---

## 🚀 Quick Start

```bash
# Clone
git clone https://github.com/vibrationalforce/Eoel.git
cd Eoel

# Open in Xcode
open Package.swift
```

**In Xcode:**
- `Cmd+B` to build
- `Cmd+R` to run
- `Cmd+U` to run tests

---

## 🎯 What is Eoel?

Eoel is an **embodied multimodal music system** that transforms biometric signals (HRV, heart rate, breathing), voice, gestures, and facial expressions into:

- 🌊 **Spatial Audio** (3D/4D/Fibonacci Field Arrays)
- 🎨 **Real-time Visuals** (Cymatics, Mandalas, Particles)
- 💡 **LED/DMX Lighting** (Push 3, Art-Net)
- 🎹 **MIDI 2.0 + MPE** output

---

## ✨ Core Features

### Audio System
- ✅ Real-time voice processing (AVAudioEngine)
- ✅ FFT frequency detection & YIN pitch detection
- ✅ Binaural beat generator (8 brainwave states)
- ✅ Node-based audio graph
- ✅ Multi-track recording
- ✅ 40+ professional DSP effects

### Spatial Audio
- ✅ 6 spatial modes: Stereo, 3D, 4D Orbital, AFA, Binaural, Ambisonics
- ✅ Fibonacci sphere distribution
- ✅ Head tracking (CMMotionManager @ 60 Hz)

### Visual Engine
- ✅ 5 visualization modes: Cymatics, Mandala, Waveform, Spectral, Particles
- ✅ Metal-accelerated rendering
- ✅ Bio-reactive colors (HRV → hue)

### Biofeedback
- ✅ HealthKit integration (HRV, Heart Rate)
- ✅ HeartMath coherence algorithm
- ✅ Real-time bio-parameter mapping

### MIDI Integration
- ✅ MIDI 2.0 UMP protocol
- ✅ MPE (MIDI Polyphonic Expression)
- ✅ Ableton Push 3 LED control

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│             UnifiedControlHub (60 Hz Loop)              │
│                                                         │
│    Bio → Gesture → Face → Voice → MIDI 2.0 + MPE       │
└──────────┬───────────────┬────────────────┬────────────┘
           │               │                │
    ┌──────▼──────┐  ┌────▼─────┐   ┌─────▼──────┐
    │   Spatial   │  │ Visuals  │   │  Lighting  │
    │   Audio     │  │ Mapper   │   │ Controller │
    └─────────────┘  └──────────┘   └────────────┘
```

---

## 📁 Project Structure

```
Eoel/
├── Package.swift              # Swift Package config
├── Sources/Eoel/              # Main iOS app
│   ├── Audio/                 # Audio engine & DSP
│   ├── Biofeedback/          # HealthKit integration
│   ├── MIDI/                  # MIDI 2.0 + MPE
│   ├── Spatial/               # 3D/4D spatial audio
│   ├── Visual/                # Metal visualizations
│   ├── LED/                   # Push 3 & DMX
│   └── Unified/               # Control hub
├── Sources/DSP/               # C++ DSP effects (40+)
├── Sources/Audio/             # C++ audio engine
├── Sources/Plugin/            # JUCE plugin
└── Tests/EoelTests/           # Unit tests
```

---

## 🛠️ Technical Stack

- **Language:** Swift 5.9+ / C++17
- **UI:** SwiftUI + Combine
- **Audio:** AVFoundation + JUCE
- **Graphics:** Metal + SwiftUI Canvas
- **Biofeedback:** HealthKit + CoreMotion
- **MIDI:** CoreMIDI + MIDI 2.0
- **Platforms:** iOS 15+, macOS 12+, watchOS 8+, tvOS 15+, visionOS 1+

---

## 🎨 Eoel Product Family

| Product | Description |
|---------|-------------|
| **EoelSync™** | Universal sync (Ableton Link, MIDI Clock, OSC) |
| **EoelCloud™** | Cloud rendering & processing |
| **EoelAI™** | Intelligent music production |
| **EoelSpatial™** | Spatial audio engine |
| **EoelHealth™** | Wellness & bio-reactive audio |

---

## 📊 Project Status

**Current Phase:** MVP Development
**Overall Progress:** ~75%

| Component | Status |
|-----------|--------|
| Audio Engine | 95% ✅ |
| DSP Effects (40+) | 87% ✅ |
| Biofeedback | 85% ✅ |
| MIDI 2.0 | 90% ✅ |
| Visualization | 80% ✅ |
| Streaming | 5% ⏳ |
| AI Features | 20% ⏳ |

---

## 🧪 Testing

```bash
swift test
# or in Xcode: Cmd+U
```

---

## 📖 Documentation

- [Audit Report](AUDIT_REPORT_2025_11_26.md)
- [Branding Inventory](BRANDING_INVENTORY_COMPLETE.md)
- [DAW Integration](DAW_INTEGRATION_GUIDE.md)

---

## 📜 License

Copyright © 2025 Eoel. All rights reserved.

---

## 🎵 Philosophy

> "Eoel transforms the invisible rhythms of your body into visible, audible art.
> Through breath, heartbeat, and intention, we create music that resonates with life itself."

**Built with** ❤️ **for artists, healers, and creators.**
