# CLAUDE.md - Echoelmusic

## Overview
Bio-reactive audio-visual platform: biometrics (HRV, HR, breathing) → spatial audio, visuals, DMX lighting.

- **Languages:** Swift 5.9+, Kotlin 1.9+, C++17, Metal, GLSL
- **Platforms:** iOS 15+, macOS 12+, watchOS 8+, tvOS 15+, visionOS 1+, Android 8+
- **Build:** SPM (Swift), Gradle (Android), CMake (Desktop)
- **Dependencies:** Zero external (Apple frameworks only). Android: Compose, Health Connect, Oboe.

---

## Build & Test

```bash
# Swift
swift build
swift test

# Android
cd android && ./gradlew build && ./gradlew test

# Desktop (pure native, no JUCE)
mkdir build && cd build && cmake .. -DUSE_JUCE=OFF && cmake --build . --parallel
```

---

## Architecture

```
EchoelUniversalCore (120Hz) → UnifiedControlHub (60Hz) + VideoAICreativeHub
                                      │
              ┌───────────┬───────────┼───────────┬──────────┐
         Spatial Audio  Visuals   Lighting    Quantum    5 Pro Engines
```

### Key Components

| Component | Path | Purpose |
|-----------|------|---------|
| `UnifiedControlHub` | `Unified/` | Central 60Hz orchestrator |
| `EchoelCreativeWorkspace` | - | Bridges ALL engines via Combine |
| `AudioEngine` | `Audio/` | Core audio processing |
| `SpatialAudioEngine` | `Spatial/` | 3D/4D spatial (init, setMode, setPan, setReverbBlend) |
| `UnifiedHealthKitEngine` | `Biofeedback/` | HRV/HR (coherence, startStreaming, stopStreaming) |
| `VideoStreamingManager` | `Stream/` | Streaming (NOT VideoProcessingEngine) |
| `EchoelStage` | `Core/EchoelToolkit.swift` | Output routing (external displays, VR/XR, projection, Dante) |
| `ExternalDisplayRenderingPipeline` | `Stage/` | Metal-based multi-output rendering pipeline |
| `ProfessionalLogger` | `Core/` | Global `log` instance |

### 5 Pro Engines
ProMixEngine, ProSessionEngine, ProColorGrading, ProCueSystem, ProStreamEngine

### 2026 Expansion: 7 New Echoel* Engines + 2 Support Engines

| Component | Path | Purpose |
|-----------|------|---------|
| `EchoelTranslateEngine` | `Translation/` | Real-time translation (20+ languages, on-device, Apple Translation) |
| `EchoelSpeechEngine` | `Translation/` | Speech-to-text (SpeechAnalyzer iOS 26 / SFSpeech fallback) |
| `EchoelLyricsEngine` | `Lyrics/` | Lyrics extraction (vocal separation + ASR + sync) |
| `EchoelSubtitleRenderer` | `Subtitle/` | Real-time multilingual subtitles (WebVTT, HLS, SwiftUI overlay) |
| `EchoelMindEngine` | `Mind/` | On-device LLM (Apple Foundation Models, 3B params, bio-reactive) |
| `EchoelMintEngine` | `Mint/` | Bio-reactive Dynamic NFTs (capture, metadata, export) |
| `EchoelAvatarEngine` | `Avatar/` | Bio-reactive avatars (3DGS, ARKit 52 blendshapes, aura particles) |
| `EchoelWorldEngine` | `World/` | Procedural bio-reactive worlds (terrain, biomes, weather, narrative) |
| `EchoelGodotBridge` | `Godot/` | Godot 4.6 LibGodot/SwiftGodotKit rendering (visionOS, 3D worlds) |

### Android
- `EchoelmusicApplication` — minimal, loads native libs only
- `EchoelmusicViewModel` — holds audioEngine, midiManager, bioReactiveEngine
- All UI composables receive `viewModel` parameter (no singletons)

---

## Directory Structure

Sources/Echoelmusic/ has **70+ flat sibling directories**:

**Audio:** Audio, DSP, Sound, SoundDesign, Orchestral, MusicTheory, Spatial, Recording
**Input/Control:** MIDI, LED, Control, Automation, Sequencer, Haptics
**Intelligence:** AI, Intelligence, SuperIntelligence, Quantum, Lambda, ML
**Biometric:** Biofeedback, Biophysical, Wellness
**Visual:** Visual, Shaders, Video, VisionOS, Vision, Theme, ParticleView
**Platform:** Platforms, WatchOS, WatchSync, tvOS, AppClips, Widgets, LiveActivity, SharePlay, Shortcuts
**Infrastructure:** Core, Utils, Integration, Testing, Performance, Optimization, QualityAssurance
**Business:** Legal, Privacy, Security, Analytics, Social, Sustainability, Business, Localization
**Stage:** Stage (ExternalDisplayRenderingPipeline, DanteAudioTransport, VideoNetworkTransport, EchoelSyncProtocol)
**2026 New:** Translation, Lyrics, Subtitle, Mind, Mint, Avatar, World, Godot
**Other:** Creative, NeuroSpiritual, Onboarding, Scripting, Export, Hardware, Presets, Resources, Views

Entry points: `EchoelmusicApp.swift`, `ContentView.swift`

---

## Code Style

- **SwiftUI** for UI, **Combine** for reactive
- `@MainActor` for UI classes
- `guard` for early returns
- `///` for public API docs
- C++17 with namespace `Echoelmusic::`
- Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`, `perf:`

---

## Critical Build Error Patterns

### Swift Compiler Errors
| Pattern | Fix |
|---------|-----|
| UIKit refs on non-iOS | `#if canImport(UIKit)` |
| @MainActor in Sendable closure | `Task { @MainActor in }` |
| deinit calls @MainActor method | Nonisolated cleanup directly |
| `public let foo: InternalType` | Hard error — match access levels |
| `Color.magenta` | Doesn't exist. Use `Color(red:1,green:0,blue:1)` |
| WeatherKit | `@available(iOS 16.0, *)` AND `#if canImport(WeatherKit)` |
| vDSP overlapping accesses | Copy inputs to temp vars before `vDSP_DFT_Execute` |
| `self` before `super.init()` | Move setup AFTER `super.init()` |
| `inout` + escaping closure | Copy to local var first |

### Logger Usage (Global `log` is EchoelLogger instance)
```swift
// CORRECT:
log.log(.info, category: .audio, "message")

// WRONG - tries to call logger as function:
log(.info, ...)

// WRONG - instance method, not static:
ProfessionalLogger.log()

// Math log() is shadowed — use:
Foundation.log(value)
```

### API Gotchas
| Type | Correct API |
|------|-------------|
| `SpatialAudioEngine` | `init()`, `setMode()`, `currentMode`, `setPan()`, `setReverbBlend()` |
| `UnifiedHealthKitEngine` | `coherence`, `startStreaming()`, `stopStreaming()` |
| `NormalizedCoherence` | NOT BinaryFloatingPoint — use `.value` for arithmetic |
| `Swift.max/min` | Qualify when struct has static `.max` property |

### Type Conflict Resolution
Always prefix types to avoid conflicts:
- ProSessionEngine: `SessionMonitorMode`, `SessionTrackSend`, `SessionTrackType`
- ProStreamEngine: `StreamMonitorMode`, `StreamTransitionType`, `ProStreamScene`
- ProCueSystem: `CueTransitionType`, `CueSceneTransition`, `CueSourceFilter`
- ProColorGrading: `GradeTransitionType`
- `ChannelStrip`, `ArticulationType`, `SubsystemID` → top-level types, NOT nested

### Other Patterns
- `@escaping` required for `TaskGroup.addTask` closures
- Result builder: `buildBlock(_ components: [T]...)` when using `buildExpression`
- `CXProviderConfiguration.localizedName` is read-only in iOS 14+ (set via Info.plist)

---

## CI/CD

### Active Workflows (.github/workflows/)
| Workflow | Purpose |
|----------|---------|
| `testflight.yml` | **PRIMARY** — TestFlight builds (ID: 225043686) |
| `ci.yml` | Main CI (build, test, lint) |
| `build.yml` | General build |
| `quick-test.yml` | Fast test suite |
| `pr-check.yml` | PR validation |

Android build is disabled. TestFlight needs 60min timeout (30min+ compile).

---

## Key Patterns

### Control Loop (60Hz)
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

### Bio-Reactive Mapping
```swift
if coherence > 60 {
    fieldGeometry = .fibonacci(sourceCount: voiceCount)  // harmonious
} else {
    fieldGeometry = .grid(rows: 3, cols: 3, spacing: 0.5)  // grounded
}
```

---

## Performance Targets

| Metric | Target |
|--------|--------|
| Control Loop | 60 Hz |
| Audio Latency | <10ms |
| CPU Usage | <30% |
| Memory | <200 MB |

Use lock-free queues, pre-allocated buffers, SIMD/Accelerate, atomic ops.

---

## Testing

Tests in `Tests/EchoelmusicTests/`. Key suites:
- `ComprehensiveTestSuite.swift` — Main
- `ComprehensiveQuantumTests.swift` — Quantum
- `Comprehensive2000Tests.swift` / `Comprehensive8000Tests.swift` — Coverage
- Individual: ControlHub, BinauralBeat, HealthKit, FaceMapper, PitchDetector, Accessibility

---

## Platform Notes

- **Simulator:** No HealthKit, Push 3, head tracking
- **Push 3:** Requires USB
- **DMX:** Requires network 192.168.1.100
- **Linux:** `apt install libasound2-dev`
