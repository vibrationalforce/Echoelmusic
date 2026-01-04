# CLAUDE.md - Claude Code Guide for Echoelmusic

## Project Overview

**Echoelmusic** is a bio-reactive audio-visual platform that transforms biometric signals (HRV, heart rate, breathing), voice, gestures, and facial expressions into spatial audio, real-time visuals, and LED/DMX lighting.

### Quick Stats
- **Languages:** Swift 5.9+, Kotlin 1.9+, C++17
- **Platforms:** iOS 15+, macOS 12+, watchOS 8+, tvOS 15+, visionOS 1+, Android, Windows, Linux
- **Build Systems:** Swift Package Manager, Gradle (Android), CMake (Desktop plugins)
- **Current Phase:** Phase 3 Complete (Spatial Audio + Visual + LED)
- **Overall MVP Progress:** ~75%

---

## Build & Test Commands

### Swift (iOS/macOS/watchOS/tvOS/visionOS)
```bash
# Build
swift build

# Run tests
swift test
./test.sh              # With nice output
./test.sh --verbose    # Verbose mode

# Open in Xcode
open Package.swift
# Then: Cmd+B (build), Cmd+R (run), Cmd+U (test)
```

### Android
```bash
cd android
./gradlew build
./gradlew assembleDebug
./gradlew test
```

### Desktop Plugins (CMake/JUCE)
```bash
mkdir build && cd build
cmake .. -DUSE_JUCE=ON -DCMAKE_BUILD_TYPE=Release
cmake --build . --parallel
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│           UnifiedControlHub (60 Hz Loop)                │
│                                                         │
│  Bio → Gesture → Face → Voice → MIDI 2.0 + MPE        │
└──────────┬───────────────┬────────────────┬────────────┘
           │               │                │
    ┌──────▼──────┐  ┌────▼─────┐   ┌─────▼──────┐
    │   Spatial   │  │ Visuals  │   │  Lighting  │
    │   Audio     │  │ Mapper   │   │ Controller │
    └─────────────┘  └──────────┘   └────────────┘
```

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `UnifiedControlHub` | `Sources/Echoelmusic/Unified/` | Central 60Hz orchestrator |
| `AudioEngine` | `Sources/Echoelmusic/Audio/` | Core audio processing |
| `SpatialAudioEngine` | `Sources/Echoelmusic/Spatial/` | 3D/4D spatial rendering |
| `HealthKitManager` | `Sources/Echoelmusic/Biofeedback/` | HRV/Heart Rate |
| `MIDIToVisualMapper` | `Sources/Echoelmusic/Visual/` | MIDI→Visual mapping |
| `Push3LEDController` | `Sources/Echoelmusic/LED/` | Ableton Push 3 LEDs |
| `MIDIToLightMapper` | `Sources/Echoelmusic/LED/` | DMX/Art-Net lighting |

---

## Directory Structure

```
Echoelmusic/
├── Package.swift                    # Swift Package config
├── CMakeLists.txt                   # C++ Desktop build
├── Sources/
│   ├── Echoelmusic/                 # Swift sources (iOS/macOS)
│   │   ├── Audio/                   # Audio engine, effects, nodes
│   │   ├── Spatial/                 # Spatial audio (3D/4D/AFA)
│   │   ├── Visual/                  # Visualization modes
│   │   ├── LED/                     # Push 3 & DMX control
│   │   ├── MIDI/                    # MIDI 2.0 + MPE
│   │   ├── Unified/                 # Control hub & gesture
│   │   ├── Biofeedback/             # HealthKit integration
│   │   ├── Recording/               # Multi-track recording
│   │   ├── Stream/                  # Live streaming
│   │   ├── AI/                      # AI composition
│   │   ├── Performance/             # Adaptive quality
│   │   └── Core/                    # Utilities & constants
│   ├── DSP/                         # C++ DSP effects (JUCE)
│   ├── Plugin/                      # VST3/AU plugin code
│   ├── UI/                          # C++ desktop UI
│   └── Desktop/                     # iPlug2 integration
├── Tests/EchoelmusicTests/          # Swift unit tests
├── android/                         # Android Kotlin app
└── .github/workflows/               # CI/CD pipelines
```

---

## Code Style & Conventions

### Swift
- **SwiftUI** for UI, **Combine** for reactive patterns
- Use `@MainActor` for UI-related classes
- Prefix private methods with no underscore
- Use `guard` for early returns
- Document public APIs with `///` comments

### C++
- **C++17** standard
- JUCE framework for desktop plugins
- Namespace: `Echoelmusic::`
- Header guards or `#pragma once`

### Commit Messages
```
feat: Add new feature
fix: Bug fix
docs: Documentation
refactor: Code refactoring
test: Add/update tests
chore: Maintenance
perf: Performance improvement
```

---

## Important Patterns

### 1. Control Loop (60 Hz)
The `UnifiedControlHub` runs at 60 Hz for real-time control:
```swift
// Priority: Touch > Gesture > Face > Gaze > Position > Bio
private func controlLoopTick() {
    updateFromBioSignals()
    updateFromFaceTracking()
    updateFromHandGestures()
    resolveConflicts()
    updateAudioEngine()
    updateVisualEngine()
    updateLightSystems()
}
```

### 2. Bio-Reactive Audio Mapping
HRV coherence drives audio parameters:
```swift
// High coherence → Fibonacci spatial field (harmonious)
// Low coherence → Grid spatial field (grounded)
if coherence > 60 {
    fieldGeometry = .fibonacci(sourceCount: voiceCount)
} else {
    fieldGeometry = .grid(rows: 3, cols: 3, spacing: 0.5)
}
```

### 3. MPE (MIDI Polyphonic Expression)
Per-note expression for each voice:
```swift
mpe.setVoicePitchBend(voice: voice, bend: pitchBend)
mpe.setVoiceBrightness(voice: voice, brightness: jawOpen)
mpe.setVoiceTimbre(voice: voice, timbre: smile)
```

---

## Known TODOs & Limitations

### Active TODOs (Non-Critical)

| File | Line | TODO | Status |
|------|------|------|--------|
| `UnifiedControlHub.swift` | 54 | Add GazeTracker integration | Future Phase |
| `UnifiedControlHub.swift` | 429 | Apply AFA field to SpatialAudioEngine | Phase 4 |
| `UnifiedControlHub.swift` | 626-627 | Calculate breathing rate from HRV, get audio level | Uses fallback values |
| `StreamEngine.swift` | 329, 365, 547 | Scene rendering, crossfade, frame encoding | Streaming feature |
| `AIComposer.swift` | 21, 31 | Load CoreML models, LSTM melody generation | AI Phase |
| `CMakeLists.txt` | 349-350 | DynamicEQ.cpp, SpectralSculptor.cpp need JUCE fixes | Desktop plugins |

### Platform Limitations
- **Simulator:** No HealthKit, Push 3, or head tracking
- **iOS 15-18:** Full functionality except iOS 19+ spatial features
- **Push 3:** Requires USB connection
- **DMX:** Requires network 192.168.1.100

---

## Testing

### Current Coverage: ~40% (Target: 80%+)

### Test Suites
```
Tests/EchoelmusicTests/
├── ComprehensiveTestSuite.swift     # Main test suite
├── UnifiedControlHubTests.swift     # Control hub tests
├── BinauralBeatTests.swift          # Audio tests
├── HealthKitManagerTests.swift      # Biofeedback tests
├── FaceToAudioMapperTests.swift     # Face mapping tests
└── PitchDetectorTests.swift         # DSP tests
```

### Test Recommendations
1. Add integration tests for Phase 3 components
2. Add performance benchmarks for 60 Hz control loop
3. Add UI snapshot tests
4. Mock HealthKit for simulator testing
5. Add edge case tests for bio-reactive mapping

---

## Performance Targets

| Metric | Target | Current |
|--------|--------|---------|
| Control Loop | 60 Hz | 60 Hz |
| Audio Latency | <10ms | <10ms |
| CPU Usage | <30% | ~25% |
| Memory | <200 MB | ~150 MB |
| Frame Rate | 60 FPS (120 ProMotion) | 60 FPS |

### Zero-Latency Best Practices
1. Use lock-free queues for audio thread
2. Pre-allocate buffers, avoid heap allocation in audio callback
3. Use SIMD (Accelerate framework) for DSP
4. Prefer atomic operations over locks
5. Profile with Instruments regularly

---

## CI/CD Pipeline

### GitHub Actions Workflows
- `ci.yml` - Main CI (build, test, lint)
- `android.yml` - Android build
- `ios-build.yml` - iOS build
- `build.yml` - Desktop builds

### Quality Gates
- SwiftLint (strict mode)
- swift-format
- Code coverage reports
- Security scanning

---

## Dependencies

### Swift (Package.swift)
- No external dependencies (uses Apple frameworks)

### Android (build.gradle.kts)
- Compose BOM
- Health Connect
- Oboe (low-latency audio)

### Desktop (CMakeLists.txt)
- JUCE Framework (optional)
- iPlug2 (MIT license alternative)

---

## Quick Reference

### Run Everything
```bash
# Swift
swift build && swift test

# Android
cd android && ./gradlew build

# Desktop
mkdir build && cd build && cmake .. && make
```

### Common Issues

| Issue | Solution |
|-------|----------|
| HealthKit not available | Run on real device, not simulator |
| Push 3 not detected | Check USB connection |
| Build fails on Linux | Install ALSA dev: `apt install libasound2-dev` |
| CMake JUCE error | Set `-DUSE_JUCE=OFF` for Swift-only build |

### Useful Files
- `XCODE_HANDOFF.md` - Xcode development guide
- `PHASE_3_OPTIMIZED.md` - Phase 3 details
- `.github/CLAUDE_TODO.md` - Detailed sprint planning
- `ARCHITECTURE_SCIENTIFIC.md` - Scientific background

---

## Development Philosophy

> "Echoelmusic is not just a music app - it's an interface to embodied consciousness.
> Through breath, biometrics, and intention, we transform life itself into art."

**breath → sound → light → consciousness**

---

*Last Updated: 2026-01-04 | Claude Code Audit*
