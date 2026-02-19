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

498 classes consolidated into **10 unified Echoel\* tools + λ∞ Lambda**. All connected via **EngineBus** (lock-free pub/sub).

```
┌───────────────────────────────────────────────────────────────────────────┐
│                     λ∞ LambdaModeEngine (60Hz)                           │
│              Bio-Reactive Consciousness Orchestrator                      │
│                              │                                           │
│   ┌──────────┬──────────┬────┴────┬──────────┐                          │
│   │          │          │         │          │                          │
│ EchoelSynth EchoelMix EchoelFX EchoelSeq EchoelMIDI                  │
│ (5 DSP      (ProMix)  (28 DSP  (timer-   (CoreMIDI                   │
│  engines)             procs)   based)    + MPE)                       │
│   │          │          │         │          │                          │
│   ├──────────┼──────────┼─────────┼──────────┤                          │
│   │          │          │         │          │                          │
│ EchoelBio  EchoelField     EchoelBeam      EchoelNet                  │
│ (EEG+Neuro (Metal+       (Dante+NDI+     (17 protocols               │
│  +Polyvagal) Hilbert)     sACN+laser)     +collab+cloud)             │
│   │          │              │              │                            │
│   └──────────┴──────────────┴──────────────┘                            │
│                        EchoelMind                                        │
│    (LLM + AIComposer + StemSep + AudioToMIDI + QuantumIntelligence)    │
└───────────────────────────────────────────────────────────────────────────┘

Communication: EngineBus — lock-free publish/subscribe/request
Bio-Reactivity: All tools react to BioSnapshot via bus
Lambda: Consciousness state machine drives all tools through bus messages
```

### The 10 Tools + λ∞ Lambda

| Tool | Purpose | Key Capabilities |
|------|---------|-----------------|
| **EchoelSynth** | All synthesis | DDSP (vDSP vectorized, 12 bio-mappings, spectral morphing, timbre transfer), Modal, Cellular, Quantum, Sampler, EchoelBeat, 45+ presets |
| **EchoelMix** | Mixing & session | ProMixEngine + ProSessionEngine, console, metering, BPM sync, multi-track recording, clip launching, DJ crossfader |
| **EchoelFX** | Effects chain | 28 DSP processors: EQ, Comp, Reverb, Delay, Drive, Mod, Limiter, Neve/SSL emulation — all with full parameter passing |
| **EchoelSeq** | Sequencer | Step sequencer, patterns, automation, Lambda scripting |
| **EchoelMIDI** | MIDI/MPE control | MIDI 2.0, MPE, touch instruments, audio-to-MIDI, routing |
| **EchoelBio** | Biometrics hub | HRV, HR, breathing, face, gaze, hands, motion, EEG. Rausch-inspired bio-event graph + signal deconvolution |
| **EchoelField** | Visuals & video | 8 visual modes (particles, cymatics, Hilbert, 360), Metal 120fps, NLE video editor, multi-cam, ProRes, 3D avatars, procedural worlds |
| **EchoelBeam** | Lighting & stage | DMX 512, Art-Net, sACN, ILDA lasers, projection mapping, Dante/NDI, external displays, VR/XR, multi-screen output |
| **EchoelNet** | Collaboration | 17 protocols: SharePlay, Dante, EchoelSync, OSC, MSC, Mackie, cloud sync, dynamic NFTs |
| **EchoelMind** | Intelligence | CoreML, Apple Foundation Models, LLM, stem separation, AI composition, audio-to-MIDI, voice control, constitutional AI |

Plus **λ∞ Lambda** — bio-reactive consciousness orchestrator. Drives all tools through EngineBus state transitions (studio, live, meditation, video, DJ, collaboration, immersive, research modes).

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

### 5 Pro Engines

| Engine | Purpose |
|--------|---------|
| **ProMixEngine** | Professional mixing console with unlimited channel strips, bus routing, insert/send slots |
| **ProSessionEngine** | Session management, multi-track recording, punch-in, undo history, version snapshots |
| **ProColorGrading** | Professional color grading with LUTs, curves, color wheels, bio-reactive color shifts |
| **ProCueSystem** | Cue list with timed triggers, crossfades, follow cues, MIDI/timecode sync |
| **ProStreamEngine** | Multi-platform streaming (RTMP, SRT), scene management, transitions, overlays |

### λ∞ Lambda — Consciousness Orchestrator

Bio-reactive state machine that drives all 10 tools through 8 operating modes:

| Mode | Behavior |
|------|----------|
| **Studio** | Full DAW workflow — all tools active, recording enabled |
| **Live** | Low-latency performance — audio priority, visual sync, cue system |
| **Meditation** | Bio-focused — coherence tracking, brainwave entrainment, ambient synthesis |
| **Video** | Video production — NLE editor, multi-cam, color grading, ProRes export |
| **DJ** | Beat-matched — crossfader, clip launching, tempo sync, lighting chase |
| **Collaboration** | Multi-user — SharePlay, Dante, EchoelSync, cloud sync |
| **Immersive** | VR/XR — visionOS spatial audio, volumetric visuals, hand tracking |
| **Research** | Data capture — full bio-signal logging, EEG analysis, wellness tracking |

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
│   ├── EchoelToolkit.swift          # Master registry (10 tools + λ∞ Lambda)
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
├── Visual/                           # Metal rendering, shaders (EchoelField)
├── Video/                            # Camera, streaming, editing (EchoelField)
├── MIDI/                             # MIDI 2.0, MPE
├── LED/                              # DMX, Art-Net, Push 3 (EchoelBeam)
├── Stage/                            # External display pipeline, Dante, NDI, EchoelSync (EchoelBeam)
├── Lambda/                           # λ∞ Consciousness orchestrator
├── AI/                               # Intelligence engines (EchoelMind)
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

Copyright 2025-2026 Echoelmusic Studio. All rights reserved.

---

> "Echoelmusic is not just a music app — it's an interface to embodied consciousness.
> Through breath, biometrics, and intention, we transform life itself into art."

**breath → sound → light → consciousness**
