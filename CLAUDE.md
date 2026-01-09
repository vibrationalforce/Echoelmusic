# Echoelmusic - Claude Code Context

## Project Overview

Echoelmusic is a sophisticated **bio-reactive audio-visual music platform** with quantum AI capabilities. It's a cross-platform system that transforms biometric signals (heart rate, HRV, breathing), voice, gestures, and facial expressions into spatial audio, real-time visualizations, and LED/lighting control.

**Status:** MVP ~75% complete (Phase 3 optimized)

## Quick Commands

```bash
# Build iOS
swift build

# Run tests
swift test

# Build Desktop (VST3, AU, AAX, CLAP, Standalone)
mkdir -p build && cd build && cmake .. && make -j$(nproc)
```

## Architecture

```
UnifiedControlHub (Central Orchestrator @ 60 Hz)
├── Input Fusion: Bio | Gesture | Face | Voice | MIDI 2.0 + MPE
├── → SpatialAudioEngine (3D/4D/Fibonacci/Ambisonics)
├── → MIDIToVisualMapper (Cymatics, Mandala, Particles)
├── → Push3LEDController (8x8 RGB LED grid)
└── → MIDIToLightMapper (DMX/Art-Net 512 channels)
```

## Key Source Locations

### Swift (iOS/macOS) - `Sources/Echoelmusic/`
| Module | Path | Purpose |
|--------|------|---------|
| Core | `Core/` | EchoelUniversalCore, SelfHealingEngine |
| Audio | `Audio/` | AudioEngine, BinauralBeatGenerator, EffectsChain |
| MIDI | `MIDI/` | MIDI2Manager, MPEZoneManager, MIDIToSpatialMapper |
| Spatial | `Spatial/` | SpatialAudioEngine, HeadTracking |
| Visual | `Visual/` | CymaticsRenderer, MIDIToVisualMapper |
| Biofeedback | `Biofeedback/` | HealthKitManager, BioParameterMapper |
| LED | `LED/` | Push3LEDController, MIDIToLightMapper |
| Unified | `Unified/` | UnifiedControlHub, GestureRecognizer |

### C++ (Desktop) - `Sources/`
| Module | Path | Purpose |
|--------|------|---------|
| Audio | `Audio/` | AudioEngine.cpp, AudioExporter.cpp |
| DSP | `DSP/` | Signal processing modules |
| Synth | `Synth/` | WaveWeaver, FrequencyFusion synthesis |
| UI | `UI/` | MainWindow, EchoelMusicMainUI |
| Plugin | `Plugin/` | VST3/AU/AAX wrappers |

### Tests - `Tests/EchoelmusicTests/`
- `ComprehensiveTestSuite.swift` - Full system tests
- `UnifiedControlHubTests.swift` - Control hub tests
- `HealthKitManagerTests.swift` - Coherence algorithm tests
- `BinauralBeatTests.swift` - Audio generation tests
- `FaceToAudioMapperTests.swift` - Face tracking tests

## Input Priority

Touch > Gesture > Face > Gaze > Position > Bio

## Platform Support

- iOS 15+, macOS 12+, watchOS 8+, tvOS 15+, visionOS 1+
- Windows (ASIO/WASAPI), Linux (ALSA/JACK)
- Android 11+ (Kotlin/Gradle)
- Plugin formats: VST3, AU, AAX, CLAP, AUv3

## Key Concepts

### HeartMath Coherence (0-100)
- 0-40: Low coherence (stress) → Grid spatial geometry
- 40-60: Medium coherence → Circle spatial geometry
- 60-100: High coherence (flow) → Fibonacci sphere

### Binaural Beat States
- Delta (2 Hz): Deep sleep
- Theta (6 Hz): Meditation
- Alpha (10 Hz): Relaxation
- Beta (20 Hz): Focus
- Gamma (40 Hz): Peak performance

### Spatial Audio Modes
- Stereo, 3D, 4D Orbital, AFA (Aura Field Audio), Binaural, Ambisonics

## Code Style

- Swift: Use `@MainActor`, `async/await`, Combine publishers
- Real-time audio: No heap allocations on audio thread
- Testing: XCTest with `@MainActor` annotations
- Comments: German and English mixed in documentation

## Common Tasks

### Adding a New Effect
1. Create Swift class in `Sources/Echoelmusic/Audio/`
2. Implement DSP in C++ in `Sources/DSP/` if needed
3. Add to `EffectsChain` or `NodeGraph`
4. Add tests in `Tests/EchoelmusicTests/`

### Adding a New Input Modality
1. Create manager class (e.g., `NewInputManager`)
2. Add enable/disable methods in `UnifiedControlHub`
3. Subscribe to changes via Combine
4. Add mapping to audio/visual/light systems

### Running Specific Tests
```bash
swift test --filter HealthKitManagerTests
swift test --filter UnifiedControlHubTests
```

## Dependencies

**No external package dependencies** - fully self-contained.

Core frameworks: AVFoundation, CoreAudio, Metal, SwiftUI, Combine, HealthKit, ARKit, Vision, CoreMIDI, Network

## Important Files

- `Package.swift` - Swift Package Manager manifest
- `CMakeLists.txt` - Desktop build configuration (570+ lines)
- `project.yml` - XcodeGen configuration
- `Sources/Echoelmusic/EchoelmusicApp.swift` - iOS app entry point
- `Sources/Echoelmusic/Unified/UnifiedControlHub.swift` - Central control system

## Git Workflow

- Branch naming: `claude/<feature>-<session-id>`
- Commit style: Conventional commits (feat:, fix:, perf:, chore:)
- Push with: `git push -u origin <branch-name>`
