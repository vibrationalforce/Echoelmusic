# Echoelmusic

**Create from Within — Bio-Reactive Platform for Music, Film, Visuals & Light**

[![Build](https://img.shields.io/badge/Build-Passing-brightgreen.svg)](../../actions)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Kotlin](https://img.shields.io/badge/Kotlin-1.9+-purple.svg)](https://kotlinlang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> Bio-reactive creative performance platform — turn your heartbeat, breath, and body into music, film, visuals, and light

---

## Downloads (Beta 2.6.1)

| Platform | Download | Formats | Status |
|----------|----------|---------|--------|
| **macOS** | [DMG](../../releases/latest/download/Echoelmusic-macOS.dmg) | VST3, AU, CLAP, Standalone | Ready |
| **Windows** | [Installer](../../releases/latest/download/Echoelmusic-Windows-Setup.exe) | VST3, CLAP, Standalone | Ready |
| **Linux** | [AppImage](../../releases/latest/download/Echoelmusic-Linux.AppImage) | VST3, CLAP, Standalone, Deb | Ready |
| **iOS** | App Store | AUv3 Plugin + Host, Standalone, HealthKit | Coming Soon |
| **Android** | Google Play | Standalone, Health Connect | Coming Soon |
| **visionOS** | App Store | Immersive, Spatial Audio | Coming 2026 |

---

## 100% JUCE-Free Architecture

Zero external dependencies. Pure platform-native.

| Platform | Audio Framework | License |
|----------|-----------------|---------|
| **iOS/macOS/watchOS/tvOS/visionOS** | AVFoundation + Accelerate | Apple (Free) |
| **Android** | Oboe + AAudio | Apache 2.0 (Free) |
| **Desktop Plugins** | iPlug2 | MIT (Free) |
| **DSP Engine** | Pure C++17 | MIT (Free) |

```bash
# Build
swift build                                              # iOS/macOS
cd android && ./gradlew build                            # Android
mkdir build && cd build && cmake .. && cmake --build .   # Desktop
```

---

## Architecture — EchoelToolkit

498 classes consolidated into **11 unified Echoel\* tools**. All connected via **EngineBus** (lock-free pub/sub).

```
┌───────────────────────────────────────────────────────────────────────────┐
│                        EchoelCore (120Hz)                                │
│                              │                                           │
│   ┌──────────┬──────────┬────┴────┬──────────┬──────────┐               │
│   │          │          │         │          │          │               │
│ EchoelSynth EchoelMix EchoelFX EchoelSeq EchoelMIDI  │               │
│ (synthesis) (mixing)  (effects) (sequencer)(control)   │               │
│   │          │          │         │          │          │               │
│   ├──────────┼──────────┼─────────┼──────────┼──────────┤               │
│   │          │          │         │          │          │               │
│ EchoelBio EchoelVis EchoelVid EchoelLux EchoelNet   │               │
│ (biometrics)(visuals) (video)   (lighting)(network)   │               │
│   │          │          │         │          │          │               │
│   └──────────┴──────────┴─────────┴──────────┴──────────┘               │
│                              │                                           │
│                    EchoelAI + Echoela                                    │
│              (intelligence)  (AI assistant)                              │
└───────────────────────────────────────────────────────────────────────────┘

Communication: EngineBus — lock-free publish/subscribe/request
Bio-Reactivity: All tools react to BioSnapshot via bus
```

### The 11 Tools

| Tool | Purpose | Key Capabilities |
|------|---------|-----------------|
| **EchoelSynth** | All synthesis | DDSP (vDSP vectorized, 12 bio-mappings, spectral morphing, timbre transfer), Modal, Cellular, Quantum, Sampler, TR-808, 45+ presets |
| **EchoelMix** | Mixing & session | Console, metering, BPM sync, multi-track recording |
| **EchoelFX** | Effects chain | 20+ types: EQ, Comp, Reverb, Delay, Drive, Mod, Limiter, Neve/SSL emulation |
| **EchoelSeq** | Sequencer | Step sequencer, patterns, automation, scripting |
| **EchoelMIDI** | MIDI/MPE control | MIDI 2.0, MPE, touch instruments, routing |
| **EchoelBio** | Biometrics hub | HRV, HR, breathing, face, gaze, hands, motion, EEG. Rausch-inspired bio-event graph + signal deconvolution |
| **EchoelVis** | Visuals | 8 modes (particles, cymatics, geometry, spectrum, 3D, 360, waveform, Hilbert), Metal 120fps |
| **EchoelVid** | Video & streaming | Capture, edit, stream, multi-cam, chroma key, ProRes |
| **EchoelLux** | Lighting | DMX 512, Art-Net, lasers, smart home, cue system |
| **EchoelNet** | Collaboration | SharePlay, 1000+ collab, cloud sync, <10ms |
| **EchoelAI** | Intelligence | CoreML, LLM, stem separation, composition, generative AI |

Plus **Echoela** — the AI assistant with 11 skills and constitutional AI.

### Bio-Signal Processing (Rausch-inspired)

Three algorithms inspired by computational genomics signal processing:

| Algorithm | Inspired By | Purpose |
|-----------|-------------|---------|
| **BioEventGraph** | DELLY (Rausch et al., 2012) | Graph-based bio-event detection + k-means clustering. Detects peaks, valleys, transitions, anomalies in HRV/HR/breathing |
| **HilbertSensorMapper** | Hilbert curves | Maps 1D sensor data to 2D via space-filling curves. Locality-preserving visualization for EEG, HRV patterns |
| **BioSignalDeconvolver** | Tracy (Rausch et al., 2017) | Separates composite bio-signals into cardiac (0.5-3Hz), respiratory (0.1-0.5Hz), artifact, baseline via adaptive biquad IIR |

### DDSP Engine

Harmonic+Noise synthesizer with 12 bio-reactive parameter mappings:

| Bio Input | Synthesis Parameter |
|-----------|-------------------|
| Coherence | Harmonicity (pure tone vs noise) |
| HRV | Spectral brightness |
| Heart rate | Vibrato rate + depth |
| Breath phase | Amplitude envelope |
| Breath depth | Noise level |
| LF/HF ratio | Spectral tilt |
| Coherence trend | Spectral shape morphing |

Additional: vDSP vectorized rendering, exponential ADSR, spectral morphing between 8 shapes, timbre transfer with 6 instrument profiles (violin, flute, trumpet, cello, clarinet, oboe).

---

## Key Features

### Audio
- Real-time voice processing (AVAudioEngine)
- FFT + YIN pitch detection
- Brainwave entrainment (8 states)
- 6 spatial modes (Stereo, 3D, 4D Orbital, AFA, Binaural, Ambisonics)
- Node-based audio graph, multi-track recording

### Biofeedback
- HealthKit (HRV, HR, RR intervals, coherence, LF/HF)
- Camera (TrueDepth, 4 positions, 120fps)
- ARKit face tracking (52 blend shapes)
- Hand gestures (Vision framework)
- CoreMotion, EEG bridge (Muse 2/S, NeuroSky, OpenBCI)
- Evidence-based wellness (BiophysicalWellnessEngine)

### Visuals
- 8 visualization modes including Hilbert curve bio-mapping
- Metal-accelerated 120fps rendering
- Bio-reactive colors (HRV/coherence → hue/intensity)

### Lighting
- Push 3 (8x8 RGB LED grid), DMX/Art-Net (512 channels)
- Addressable LED strips, lasers, projection mapping
- Bio-reactive scene control

### Platforms
- iOS 15+, macOS 12+, watchOS 8+, tvOS 15+, visionOS 1+, Android 8+
- watchOS companion (HR, HRV, coherence ring, breathing guidance)
- visionOS immersive (10 environments, 6 experience types)
- Live streaming (RTMP, Twitch, YouTube, Facebook)

---

## Project Structure

```
Sources/Echoelmusic/
├── Core/
│   ├── EchoelToolkit.swift          # Master registry (11 tools)
│   ├── EngineConsolidation.swift    # Hub protocols, EngineBus, BioSnapshot
│   └── EchoelCore.swift             # Core DSP node graph
├── DSP/
│   ├── EchoelDDSP.swift             # DDSP engine (vDSP, bio-reactive, morphing)
│   ├── BioSignalDSP.swift           # Rausch-inspired: EventGraph, Hilbert, Deconvolver
│   ├── EchoelModalBank.swift        # Modal synthesis
│   ├── EchoelCellular.swift         # Cellular automata synthesis
│   └── NeveInspiredDSP.swift        # Analog emulations
├── Audio/                            # Audio engine, effects, spatial
├── Biofeedback/                      # HealthKit, EEG, bio mapping
├── Biophysical/                      # Evidence-based wellness
├── Echoela/                          # AI assistant
├── Visual/                           # Metal rendering, shaders
├── Video/                            # Camera, streaming, editing
├── MIDI/                             # MIDI 2.0, MPE
├── LED/                              # DMX, Art-Net, Push 3
├── Platforms/                        # watchOS, tvOS, visionOS
└── ...                               # 70+ flat sibling directories

android/app/src/main/java/com/echoelmusic/app/
├── audio/AudioEngine.kt              # Oboe-based synthesis
├── bio/BioReactiveEngine.kt          # Health Connect
├── midi/MidiManager.kt               # Android MIDI
├── viewmodel/EchoelmusicViewModel.kt # MVVM architecture
└── ui/                               # Compose UI

Tests/EchoelmusicTests/                # 56 test files
```

---

## Performance Targets

| Metric | Target |
|--------|--------|
| Control Loop | 60 Hz |
| Audio Latency | <10ms |
| CPU Usage | <30% |
| Memory | <200 MB |
| Visual Frame Rate | 120fps (ProMotion) |
| Bio-Reactive Loop | 120Hz |

Lock-free queues, pre-allocated buffers, SIMD/Accelerate, atomic ops.

---

## Testing

```bash
swift test              # Run all tests
./test.sh --verbose     # With output
```

56 test suites including:
- `BioSignalDSPTests` — Graph clustering, Hilbert mapping, signal deconvolution
- `EchoelDDSPTests` — Synthesis, morphing, timbre transfer, bio-reactive
- `EchoelToolkitTests` — EngineBus, BioSnapshot, tool integration
- `ComprehensiveTestSuite` — Main integration tests
- Audio, Spatial, MIDI, HealthKit, Face, Pitch, ControlHub, Streaming, visionOS

---

## Configuration

### Info.plist Requirements:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Echoelmusic needs microphone access to process your voice</string>
<key>NSHealthShareUsageDescription</key>
<string>Echoelmusic needs access to heart rate data for bio-reactive music</string>
<key>NSCameraUsageDescription</key>
<string>Echoelmusic uses face tracking for expressive control</string>
```

### Network (DMX/Art-Net):
```
Address: 192.168.1.100 | Port: 6454 | Universe: 512 channels
```

---

## Commit Convention

`feat:` `fix:` `docs:` `refactor:` `test:` `chore:` `perf:`

---

## Documentation

- **[XCODE_HANDOFF.md](XCODE_HANDOFF.md)** — Xcode development guide
- **[CLAUDE.md](CLAUDE.md)** — Architecture reference & build patterns
- **[DAW_INTEGRATION_GUIDE.md](DAW_INTEGRATION_GUIDE.md)** — DAW integration

---

## License

Copyright 2025 Echoelmusic Studio. All rights reserved.

---

> "Echoelmusic is not just a music app — it's an interface to embodied consciousness.
> Through breath, biometrics, and intention, we transform life itself into art."

**breath → sound → light → consciousness**
