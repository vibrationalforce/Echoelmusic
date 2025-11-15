# 🎵 Echoelmusic

**Bio-Reactive DAW & Creative Ecosystem**

Transform your biometric signals, voice, gestures, and creativity into professional music, visuals, and immersive experiences.

---

## 🌟 What is Echoelmusic?

**Echoelmusic** is a revolutionary music production ecosystem combining:

- 🧠 **Bio-Reactive Control** - Heart rate, HRV, breath → music parameters
- 🎹 **Professional DAW** - Timeline, MIDI sequencer, multi-track recording
- 🎭 **Session View** - Ableton-style clip launcher for live performance
- 🌌 **Spatial Audio** - 3D audio with ARKit face/hand tracking
- 🎨 **Visual Engine** - Real-time cymatics and audio-reactive visuals
- 💡 **LED/DMX** - Ableton Push 3 + DMX512 integration
- 🖥️ **Cross-Platform** - iOS + macOS/Windows/Linux desktop engine

**Brand:**
- **Echoelmusic** = Product (DAW, App, System)
- **Echoel** = Artist Name
- **Echo+tools** = AI/ML Tools (planned)

---

## 🚀 Quick Start

### iOS App (iPhone/iPad)

```bash
# Clone repository
git clone https://github.com/vibrationalforce/Echoelmusic.git
cd Echoelmusic/ios-app

# Generate Xcode project
xcodegen generate

# Open and build
open Echoelmusic.xcworkspace
```

**Requirements:**
- Xcode 15+
- iOS 15+ device
- Apple Developer Account (for HealthKit)

### Desktop Engine (macOS/Windows/Linux)

```bash
cd desktop-engine

# Open in JUCE Projucer
# 1. Download JUCE: https://juce.com
# 2. Open Echoelmusic.jucer
# 3. Generate IDE project
# 4. Build and run
```

**Requirements:**
- JUCE Framework
- Xcode (macOS) / Visual Studio 2022 (Windows) / Make (Linux)

**Full guide:** See [QUICK_START_GUIDE.md](QUICK_START_GUIDE.md)

---

## 🎯 Key Features

### ✨ Bio-Reactive System
- ✅ HealthKit integration (Heart Rate, HRV)
- ✅ **HeartMath Coherence Algorithm** (0-100 score)
- ✅ HRV → Audio mapping (reverb, filter, amplitude)
- ✅ **Healing Frequencies** (432 Hz, 528 Hz, 396 Hz, 741 Hz)
- ✅ 4 Bio Presets (Meditation, Focus, Relaxation, Energize)

### 🎹 DAW Features (NEW!)
- ✅ **Timeline/Arrangement View** (Reaper + FL Studio style)
- ✅ **Session/Clip View** (Ableton Live style)
- ✅ **Piano Roll + MIDI Sequencer**
- ✅ Sample-accurate timeline
- ✅ Multi-track mixing
- ✅ Loop regions
- ✅ Quantization & humanization
- ✅ Undo/Redo (100 steps)

### 🎵 Audio Engine
- ✅ Professional effects chain (Reverb, Delay, Filter, Compressor)
- ✅ Multi-track recording
- ✅ 8-band FFT analysis
- ✅ Pitch detection
- ✅ Binaural beats
- ✅ Export (WAV, M4A, FLAC)

### 🎼 MIDI System
- ✅ MIDI 2.0 / MPE support
- ✅ 15-channel voice allocation
- ✅ Per-note expression
- ✅ MIDI → Spatial/LED/Visual mapping

### 🌌 Spatial Audio
- ✅ 3D audio engine (HRTF)
- ✅ ARKit face tracking → audio
- ✅ Hand tracking → parameters
- ✅ AirPods head tracking

### 🎨 Visual Engine
- ✅ Metal shader rendering
- ✅ Cymatics patterns
- ✅ 3 modes (Spectral, Waveform, Mandala)
- ✅ Audio-reactive visuals

### 💡 LED/DMX Integration
- ✅ Ableton Push 3 (64 RGB pads)
- ✅ DMX512 protocol
- ✅ Audio → LED mapping
- ✅ Cymatics LED patterns

### 🌐 OSC Bridge
- ✅ iOS ↔ Desktop sync
- ✅ <10ms latency
- ✅ FFT streaming
- ✅ Biofeedback transfer

---

## 📊 Project Structure

```
Echoelmusic/
│
├── 📱 ios-app/                 # iOS Application (22,966 lines Swift)
│   ├── Echoelmusic/
│   │   ├── Audio/              # Audio engine (4,500 lines)
│   │   ├── Timeline/           # DAW timeline (2,585 lines) ✨ NEW
│   │   ├── Sequencer/          # MIDI sequencer (1,087 lines) ✨ NEW
│   │   ├── Session/            # Clip launcher (662 lines) ✨ NEW
│   │   ├── Recording/          # Multi-track recording
│   │   ├── Biofeedback/        # HealthKit integration
│   │   ├── MIDI/               # MIDI 2.0/MPE
│   │   ├── Spatial/            # 3D audio + ARKit
│   │   ├── Visual/             # Cymatics renderer
│   │   ├── LED/                # Push 3 + DMX
│   │   ├── OSC/                # iOS ↔ Desktop sync
│   │   └── ...
│   └── Tests/EchoelTests/
│
├── 🖥️ desktop-engine/          # Desktop (1,912 lines C++)
│   ├── Source/
│   │   ├── Audio/              # Synthesizer + Effects
│   │   ├── DSP/                # FFT Analyzer
│   │   ├── OSC/                # OSC Manager
│   │   └── UI/                 # Desktop UI
│   └── Echoelmusic.jucer       # JUCE project
│
├── 🛠️ scripts/                 # Development tools
│   ├── osc_test.py             # OSC testing framework
│   ├── build.sh
│   └── deploy.sh
│
└── 📚 docs/                    # Documentation
    ├── architecture.md
    ├── osc-protocol.md
    └── setup-guide.md
```

**Total:** 24,878 lines of production code

---

## 🏗️ System Architecture

```
Bio Sensors (HealthKit)
    ↓
ARKit (Face/Hand Tracking)
    ↓
Audio/MIDI Input
    ↓
UnifiedControlHub
    ↓
┌─────────┬──────────┬─────────┬─────────┐
│         │          │         │         │
▼         ▼          ▼         ▼         ▼
Audio   Visual    LED/DMX   MIDI    OSC Bridge
Engine  Engine                          │
│                                       │
├─ Timeline                             ▼
├─ Session                        Desktop Engine
├─ Effects                        ├─ Synth
├─ Spatial                        ├─ Effects
└─ Recording                      └─ FFT
```

---

## 🧪 Tech Stack

**iOS:**
- Swift 5.9+, SwiftUI
- AVFoundation, Metal
- ARKit, HealthKit
- CoreML (planned)

**Desktop:**
- C++17, JUCE 7.x
- CoreAudio / ASIO
- Cross-platform

**Protocol:**
- OSC (Open Sound Control)
- MIDI 2.0 / MPE
- DMX512

**Build:**
- Xcode 15+
- XcodeGen
- JUCE Projucer

---

## 📚 Documentation

**Getting Started:**
- [Quick Start Guide](QUICK_START_GUIDE.md) - 15-minute setup
- [Ecosystem Overview](ECOSYSTEM_OVERVIEW.md) - Complete overview
- [Current Status](CURRENT_STATUS_REPORT.md) - Project status

**Technical:**
- [Architecture](docs/architecture.md) - System design
- [OSC Protocol](docs/osc-protocol.md) - OSC specification
- [Complete Inventory](VOLLSTÄNDIGE_BESTANDSAUFNAHME.md) - Full feature list

**Roadmaps:**
- [Master Implementation Plan](MASTER_IMPLEMENTATION_PLAN.md)
- [90-Day Roadmap](docs/archive/ECHOELMUSIC_90_DAY_ROADMAP.md)

---

## 🎯 Roadmap

### ✅ Phase 1-5: Complete (82%)
- Multimodal control (Bio, ARKit, MIDI, Voice)
- Spatial audio engine
- Visual feedback system
- Recording system
- Desktop engine (JUCE)

### ✅ Phase 5.5: DAW Foundation (NEW - 18%)
- Timeline/Arrangement View
- Session/Clip View
- MIDI Sequencer + Piano Roll

### 🚧 Phase 6: Super Intelligence (Planned)
- CoreML integration
- Pattern recognition
- Context detection
- AI composition tools

### 🚧 Future Phases
- Video timeline integration
- Advanced visual engine (VJ system)
- WebRTC collaboration
- Broadcasting system
- Social media export

---

## 🔬 Development Status

**Overall Progress:** ~30% of total vision

**What Works:**
- ✅ Bio-reactive performance system (world-class)
- ✅ Professional audio engine
- ✅ DAW timeline foundation
- ✅ MIDI sequencer
- ✅ Multi-track recording
- ✅ Spatial audio
- ✅ LED/DMX integration
- ✅ Cross-platform (iOS + Desktop)

**In Progress:**
- 🚧 Automation engine
- 🚧 VST/AU plugin hosting
- 🚧 Video timeline

**Planned:**
- ⏳ Advanced visual engine
- ⏳ AI/ML integration
- ⏳ Collaboration features
- ⏳ Broadcasting system

---

## 🤝 Contributing

This project is under active development.

**Workflow:**
1. Create feature branch from `main`
2. Make changes with clear commits
3. Test thoroughly
4. Create pull request
5. Request review

**Code Style:**
- Follow existing patterns
- Comment complex algorithms
- Write tests for new features

---

## 📄 License

Proprietary - Tropical Drones Studio, Hamburg

---

## 🎨 Credits

**Echoelmusic** - Bio-Reactive DAW & Creative Ecosystem

**Development:**
- Claude (Anthropic)
- vibrationalforce

**Frameworks:**
- Swift, JUCE, AVFoundation, Metal, ARKit, HealthKit

**Inspired by:**
- Ableton Live (Session View)
- FL Studio (Workflow)
- Reaper (Stability)
- Touch Designer (Visuals)

**Studio:**
Tropical Drones Studio, Hamburg
https://tropicaldrones.de

---

**Status:** Active Development | Ecosystem v1.0
**Last Updated:** November 2024

🌟 **Welcome to Echoelmusic - Where Biology Meets Creativity** 🌟
