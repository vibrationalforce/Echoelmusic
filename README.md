# 🎵 Echoelmusic

**Biofeedback-Driven Audio-Visual Creation Platform**

Kombiniert physiologische Signale (Herzrate, HRV, Atmung, Stimme) mit Echtzeit-Musik- und Visual-Generierung.

## 🏗️ System-Architektur

```
iOS App (Swift)          OSC Bridge           Desktop Engine (JUCE)
┌──────────────┐         UDP:8000            ┌──────────────────┐
│ Biofeedback  │──────────────────────────►│ Audio DSP        │
│ • Herzrate   │  /echoel/bio/heartrate    │ • Synthesizer    │
│ • HRV        │  /echoel/bio/hrv          │ • Effects        │
│ • Atmung     │  /echoel/bio/breathrate   │ • Dolby Atmos    │
│ • Stimme     │  /echoel/audio/pitch      │ • Spatial Audio  │
└──────────────┘                           └──────────────────┘
       │                                             │
       └─────────────────◄───────────────────────────┘
              /echoel/analysis/rms
              /echoel/analysis/spectrum
```

## 🌟 Features

### iOS App
- **Biofeedback Sensing**: HealthKit integration für Herzrate, HRV
- **Audio Input**: Echtzeit-Pitch-Detection und Voice-Analysis
- **Visual Feedback**: Cymatics, Mandala, Spektral-Visualisierungen
- **Spatial Audio**: ARKit Face/Hand-Tracking für 3D-Audio-Steuerung
- **MIDI Control**: MIDI 2.0 / MPE Support
- **OSC Client**: Sendet Biofeedback-Daten an Desktop Engine

### Desktop Engine (In Development)
- **Audio Processing**: JUCE-basierte DSP-Pipeline
- **Spatial Audio**: Dolby Atmos / Multichannel-Support
- **Effects**: Reverb, Delay, Granular Synthesis
- **OSC Server**: Empfängt Biofeedback vom iOS Device
- **LED Control**: UDP Socket für externe LED-Controller

## 🚀 Quick Start

### iOS App
```bash
cd ios-app
open Echoelmusic.xcodeproj
# oder mit xcodegen:
xcodegen generate
```

### Desktop Engine
```bash
cd desktop-engine
open Echoelmusic.jucer
# In Projucer: Generate IDE project, dann kompilieren
```

### OSC Connection Setup
1. iOS und Desktop im gleichen WLAN
2. Desktop Engine starten (OSC Server auf Port 8000)
3. In iOS App: Desktop IP eingeben und connecten
4. Biofeedback-Daten werden automatisch gestreamt

## 📚 Dokumentation

- **[OSC Protocol](docs/osc-protocol.md)** - Vollständige OSC-Nachrichten-Spezifikation
- **[Architecture](docs/architecture.md)** - System-Übersicht und Datenfluss
- **[Setup Guide](docs/setup-guide.md)** - Detaillierte Setup-Anleitung

## 🛠️ Tech Stack

**iOS**: Swift 5.9+, SwiftUI, HealthKit, AVFoundation, ARKit
**Desktop**: C++17, JUCE 7.x, CoreAudio/ASIO
**Protocol**: OSC (Open Sound Control) über UDP
**Build**: Xcode 15+, CMake (Desktop)

## 📊 Project Structure

```
echoelmusic/
├── README.md                 # This file
├── docs/                     # Documentation
│   ├── architecture.md
│   ├── osc-protocol.md
│   └── setup-guide.md
├── ios-app/                 # Swift iOS Application
│   ├── Echoelmusic/         # Main app source
│   ├── Tests/               # Unit tests
│   ├── Resources/           # Assets, plists
│   └── Package.swift        # SPM dependencies
├── desktop-engine/          # JUCE Audio Engine (In Development)
│   ├── Source/              # C++ source code
│   └── Echoelmusic.jucer    # JUCE project
├── osc-bridge/              # OSC Protocol specification
│   ├── protocol.json
│   └── examples/
└── scripts/                 # Build and deployment scripts
```

## 🎯 Roadmap

- [x] iOS Biofeedback Integration (HealthKit, Pitch Detection)
- [x] iOS Spatial Audio Engine
- [x] iOS Visual Feedback System
- [ ] Desktop Engine: JUCE Audio Processing
- [ ] Desktop Engine: OSC Server Implementation
- [ ] OSC Bridge: Bidirectional Communication
- [ ] Desktop Engine: LED Controller Integration
- [ ] Cross-Platform Testing & Optimization

## 🔬 Development Status

**iOS App**: ✅ Active Development (v1.0.0-alpha)
**Desktop Engine**: 🚧 Architecture Planning
**OSC Bridge**: 📝 Specification Phase

## 🤝 Contributing

Dieses Projekt ist in aktiver Entwicklung. Für Fragen oder Anregungen:
- GitHub Issues: https://github.com/vibrationalforce/Echoelmusic/issues

## 📄 License

Proprietary - Tropical Drones Studio, Hamburg

## 🎨 Credits

**Echoel** - Biofeedback-Driven Audio-Visual Creation Platform
Tropical Drones Studio, Hamburg
https://tropicaldrones.de

---

**Status**: Active Development | v1.0.0-alpha
**Last Updated**: November 2025
