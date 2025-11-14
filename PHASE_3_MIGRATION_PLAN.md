# PHASE 3 - MIGRATION PLAN

**Status:** In Progress
**Branch:** `claude/echoelmusic-phase3-migrate-01DsM`
**Base:** Phase 1+2 complete

---

## Migration Strategy

Migrate 56 existing Swift files from `Sources/Echoelmusic/` into the 9 new module targets created in Phase 2.

### Principles

1. **Preserve Git History:** Use `git mv` for all file moves
2. **Buildable Commits:** Each commit must build successfully
3. **Update Imports:** Change `@testable import Echoelmusic` → `@testable import <ModuleName>`
4. **Resolve Dependencies:** Core remains dependency-free
5. **Test Coverage:** Maintain existing tests, add new ones

---

## File Migration Mapping

### 1. EchoelmusicCore (Foundation - Shared Types)

| Old Path | New Path | Reason |
|----------|----------|--------|
| `Recording/Session.swift` | `EchoelmusicCore/Types/Session.swift` | Core data model |
| `Recording/Track.swift` | `EchoelmusicCore/Types/Track.swift` | Core data model |
| `Audio/Nodes/EchoelmusicNode.swift` | Already in `EchoelmusicCore/Protocols/` | Migrated in Phase 2 |

**Total:** 2 files

---

### 2. EchoelmusicAudio (Audio Engine & DSP)

| Old Path | New Path | Notes |
|----------|----------|-------|
| `Audio/AudioConfiguration.swift` | `EchoelmusicAudio/Engine/AudioConfiguration.swift` | Config types |
| `Audio/AudioEngine.swift` | `EchoelmusicAudio/Engine/AudioEngine.swift` | Main engine |
| `MicrophoneManager.swift` | `EchoelmusicAudio/Engine/MicrophoneManager.swift` | Input handling |
| `Audio/LoopEngine.swift` | `EchoelmusicAudio/Engine/LoopEngine.swift` | Loop recording |
| `Audio/DSP/PitchDetector.swift` | `EchoelmusicAudio/DSP/PitchDetector.swift` | YIN algorithm |
| `Audio/Effects/BinauralBeatGenerator.swift` | `EchoelmusicAudio/Effects/BinauralBeatGenerator.swift` | Brainwave generator |
| `Audio/Nodes/CompressorNode.swift` | `EchoelmusicAudio/Effects/CompressorNode.swift` | Effect node |
| `Audio/Nodes/DelayNode.swift` | `EchoelmusicAudio/Effects/DelayNode.swift` | Effect node |
| `Audio/Nodes/FilterNode.swift` | `EchoelmusicAudio/Effects/FilterNode.swift` | Effect node |
| `Audio/Nodes/ReverbNode.swift` | `EchoelmusicAudio/Effects/ReverbNode.swift` | Effect node |
| `Audio/Nodes/NodeGraph.swift` | `EchoelmusicAudio/Routing/NodeGraph.swift` | Already have RoutingGraph, merge |
| `Spatial/SpatialAudioEngine.swift` | `EchoelmusicAudio/Spatial/SpatialAudioEngine.swift` | 6 spatial modes |
| `Recording/RecordingEngine.swift` | `EchoelmusicAudio/Recording/RecordingEngine.swift` | Multi-track recording |
| `Recording/ExportManager.swift` | `EchoelmusicAudio/Recording/ExportManager.swift` | Audio export |
| `Recording/AudioFileImporter.swift` | `EchoelmusicAudio/Recording/AudioFileImporter.swift` | Audio import |

**Total:** 15 files

---

### 3. EchoelmusicBio (Biofeedback)

| Old Path | New Path | Notes |
|----------|----------|-------|
| `Biofeedback/HealthKitManager.swift` | `EchoelmusicBio/HealthKit/HealthKitManager.swift` | HRV/HR monitoring |
| `Biofeedback/BioParameterMapper.swift` | `EchoelmusicBio/Mapping/BioParameterMapper.swift` | Bio→Audio mapping |

**Total:** 2 files

---

### 4. EchoelmusicVisual (Rendering & Modes)

| Old Path | New Path | Notes |
|----------|----------|-------|
| `Visual/CymaticsRenderer.swift` | `EchoelmusicVisual/Renderer/CymaticsRenderer.swift` | Cymatics mode |
| `Visual/VisualizationMode.swift` | `EchoelmusicVisual/Renderer/VisualizationMode.swift` | Mode enum |
| `Visual/MIDIToVisualMapper.swift` | `EchoelmusicVisual/Modes/MIDIToVisualMapper.swift` | MIDI→Visual |
| `Visual/Modes/MandalaMode.swift` | `EchoelmusicVisual/Modes/MandalaMode.swift` | Mandala viz |
| `Visual/Modes/SpectralMode.swift` | `EchoelmusicVisual/Modes/SpectralMode.swift` | FFT viz |
| `Visual/Modes/WaveformMode.swift` | `EchoelmusicVisual/Modes/WaveformMode.swift` | Waveform viz |
| `ParticleView.swift` | `EchoelmusicVisual/Modes/ParticleView.swift` | Particle viz |

**Total:** 7 files

---

### 5. EchoelmusicControl (Unified Hub & Input)

| Old Path | New Path | Notes |
|----------|----------|-------|
| `Unified/UnifiedControlHub.swift` | `EchoelmusicControl/Hub/UnifiedControlHub.swift` | Central hub |
| `Unified/FaceToAudioMapper.swift` | `EchoelmusicControl/Gesture/FaceToAudioMapper.swift` | Face tracking |
| `Unified/GestureRecognizer.swift` | `EchoelmusicControl/Gesture/GestureRecognizer.swift` | Gesture recognition |
| `Unified/GestureConflictResolver.swift` | `EchoelmusicControl/Gesture/GestureConflictResolver.swift` | Conflict resolution |
| `Unified/GestureToAudioMapper.swift` | `EchoelmusicControl/Gesture/GestureToAudioMapper.swift` | Gesture→Audio |
| `Spatial/ARFaceTrackingManager.swift` | `EchoelmusicControl/Gesture/ARFaceTrackingManager.swift` | ARKit face tracking |
| `Spatial/HandTrackingManager.swift` | `EchoelmusicControl/Gesture/HandTrackingManager.swift` | Vision hand tracking |

**Total:** 7 files

---

### 6. EchoelmusicMIDI (MIDI 2.0/MPE)

| Old Path | New Path | Notes |
|----------|----------|-------|
| `MIDI/MIDI2Manager.swift` | `EchoelmusicMIDI/Core/MIDI2Manager.swift` | MIDI 2.0 UMP |
| `MIDI/MIDI2Types.swift` | `EchoelmusicMIDI/Core/MIDI2Types.swift` | MIDI 2.0 types |
| `MIDI/MPEZoneManager.swift` | `EchoelmusicMIDI/MPE/MPEZoneManager.swift` | MPE voice allocation |
| `MIDI/MIDIToSpatialMapper.swift` | `EchoelmusicMIDI/Routing/MIDIToSpatialMapper.swift` | MIDI→Spatial |
| `Audio/MIDIController.swift` | `EchoelmusicMIDI/Core/MIDIController.swift` | MIDI I/O |

**Total:** 5 files

---

### 7. EchoelmusicHardware (LED & Devices)

| Old Path | New Path | Notes |
|----------|----------|-------|
| `LED/Push3LEDController.swift` | `EchoelmusicHardware/LED/Push3LEDController.swift` | Ableton Push 3 |
| `LED/MIDIToLightMapper.swift` | `EchoelmusicHardware/Bridges/MIDIToLightMapper.swift` | DMX/Art-Net |

**Total:** 2 files

---

### 8. EchoelmusicUI (SwiftUI Screens & Components)

| Old Path | New Path | Notes |
|----------|----------|-------|
| `EchoelmusicApp.swift` | `EchoelmusicUI/App/EchoelmusicApp.swift` | App entry point |
| `ContentView.swift` | `EchoelmusicUI/Screens/ContentView.swift` | Main view |
| `Audio/EffectParametersView.swift` | `EchoelmusicUI/Components/EffectParametersView.swift` | Effect params |
| `Audio/EffectsChainView.swift` | `EchoelmusicUI/Components/EffectsChainView.swift` | Node chain |
| `Recording/RecordingControlsView.swift` | `EchoelmusicUI/Components/RecordingControlsView.swift` | Recording UI |
| `Recording/MixerView.swift` | `EchoelmusicUI/Components/MixerView.swift` | Mixer UI |
| `Recording/MixerFFTView.swift` | `EchoelmusicUI/Components/MixerFFTView.swift` | FFT viz |
| `Recording/RecordingWaveformView.swift` | `EchoelmusicUI/Components/RecordingWaveformView.swift` | Waveform UI |
| `Recording/SessionBrowserView.swift` | `EchoelmusicUI/Screens/SessionBrowserView.swift` | Session browser |
| `Recording/TrackListView.swift` | `EchoelmusicUI/Components/TrackListView.swift` | Track list |
| `Views/Components/BioMetricsView.swift` | `EchoelmusicUI/Components/BioMetricsView.swift` | Bio display |
| `Views/Components/HeadTrackingVisualization.swift` | `EchoelmusicUI/Components/HeadTrackingVisualization.swift` | Head tracking viz |
| `Views/Components/SpatialAudioControlsView.swift` | `EchoelmusicUI/Components/SpatialAudioControlsView.swift` | Spatial controls |

**Total:** 13 files

---

### 9. EchoelmusicPlatform (iOS Integration)

| Old Path | New Path | Notes |
|----------|----------|-------|
| `Utils/DeviceCapabilities.swift` | `EchoelmusicPlatform/iOS/DeviceCapabilities.swift` | Device detection |
| `Utils/HeadTrackingManager.swift` | `EchoelmusicPlatform/iOS/HeadTrackingManager.swift` | CMMotionManager |

**Total:** 2 files

---

## Migration Statistics

| Module | Files to Migrate |
|--------|------------------|
| EchoelmusicCore | 2 |
| EchoelmusicAudio | 15 |
| EchoelmusicBio | 2 |
| EchoelmusicVisual | 7 |
| EchoelmusicControl | 7 |
| EchoelmusicMIDI | 5 |
| EchoelmusicHardware | 2 |
| EchoelmusicUI | 13 |
| EchoelmusicPlatform | 2 |
| **TOTAL** | **55** |

---

## Import Updates Required

### Test Files

Update all test imports:
```swift
// Old
@testable import Echoelmusic

// New
@testable import EchoelmusicCore
@testable import EchoelmusicAudio
// etc.
```

### Cross-Module Imports

Example - `AudioEngine.swift` will need:
```swift
import EchoelmusicCore  // For AudioNodeProtocol
```

---

## Commit Strategy

### Commit 1: Core + Types Migration
- Move Session.swift and Track.swift to EchoelmusicCore/Types/
- Update Package.swift if needed
- Build and test

### Commit 2: Audio Module Migration
- Move all 15 audio files
- Update imports
- Merge NodeGraph with RoutingGraph
- Build and test

### Commit 3: Bio + Visual + MIDI Migration
- Move Bio (2), Visual (7), MIDI (5) files
- Update imports
- Build and test

### Commit 4: Control + Hardware + Platform Migration
- Move Control (7), Hardware (2), Platform (2) files
- Update imports
- Build and test

### Commit 5: UI Migration
- Move all 13 UI files
- Update imports
- Build and test

### Commit 6: Implement AudioCore Features
- Add start/stop/record/play functionality
- Add unit tests

### Commit 7: Implement UnifiedControlHub 60Hz Loop
- Implement control loop
- Wire to EventBus
- Add tests

### Commit 8: Implement SessionModel Save/Load
- Add Codable conformance
- Implement save/load
- Add roundtrip tests

---

## Risk Mitigation

1. **Circular Dependencies:** Keep Core dependency-free
2. **Build Breakage:** Test build after each commit
3. **Test Failures:** Update test imports immediately
4. **Git History:** Use `git mv` for all moves

---

## Next Steps

1. Execute migration commits 1-5
2. Implement features in commits 6-8
3. Create P1/P2/P3 issue list
4. Generate migration report
5. Create draft PR

---

**Ready to execute migration!**
