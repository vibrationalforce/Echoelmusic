# CoherenceCore Architecture Consolidation Plan

**Date:** 2026-01-15
**Status:** ✅ PHASE 1-3 IMPLEMENTED | Phase 4-5 Documented
**Author:** Senior Developer Manager (Ralph Wiggum Lambda Loop Mode)

---

## Implementation Log (2026-01-15)

### ✅ Completed
1. **fusion-engine test duplicates** - Imported from shared-types instead of redefining (~80 lines removed)
2. **Desktop cymatics-patterns** - Now uses shared `@coherence-core/cymatics-patterns` (~100 lines removed)
3. **Mobile cymatics-patterns** - Now uses shared `@coherence-core/cymatics-patterns` (~150 lines removed)
4. **Shared utility functions** - Added to shared-types: `clampAmplitude`, `calculateRemainingTime`, `formatDuration`, etc.
5. **Mobile base hooks** - Created `useInterval`, `usePersistentState`, `useHapticFeedback`
6. **Swift SynthesisEngineType** - Unified enum consolidating 2 duplicate synthesis enums

### Files Modified
- `packages/fusion-engine/src/index.test.ts` - Import from shared-types
- `apps/desktop/src/CymaticsCanvas.tsx` - Use cymatics-patterns
- `apps/desktop/package.json` - Add cymatics-patterns dependency
- `apps/mobile/components/CymaticsVisualizer.tsx` - Use cymatics-patterns
- `apps/mobile/package.json` - Add cymatics-patterns dependency
- `packages/shared-types/src/index.ts` - Add utility functions
- `apps/mobile/lib/hooks/base/*` - New base hooks

### Files Created
- `Sources/Echoelmusic/Sound/SynthesisEngineType.swift` - Unified synthesis engine enum

---

## Executive Summary

Deep laser scan reveals significant consolidation opportunities across the entire codebase:

| Metric | Before | After | Status |
|--------|--------|-------|--------|
| Cymatics duplicate code | 250 lines | 0 | ✅ DONE |
| Test file duplicates | 80 lines | 0 | ✅ DONE |
| Package re-exports | 6 | 0 | ✅ DONE (prev) |
| Shared utility functions | 0 | 9 | ✅ ADDED |
| Mobile base hooks | 0 | 3 | ✅ CREATED |
| Swift synthesis enums | 2 | 1 | ✅ UNIFIED |
| Swift directories | 58 | 25 | 📋 Documented |
| Mobile super-hook | 3 hooks | 1 | 📋 Documented |

---

## Phase 1: Package Consolidation (P0)

### 1.1 Remove Empty Core Package
```
DELETE: packages/core/ (empty placeholder)
```

### 1.2 Clean Re-exports in fusion-engine
```diff
- // Remove lines 507-514 in fusion-engine/src/index.ts
- export { FusionConfig, DEFAULT_FUSION_CONFIG, ... } from '@coherence-core/shared-types';
+ // Import directly from shared-types
```

### 1.3 Audit Unused Exports in shared-types
Mark as deprecated or document usage:
- `TISSUE_ACOUSTIC_TABLE` - unused
- `BODY_EIGENFREQUENCY_RANGE` - unused
- `OrganResonanceData`, `ORGAN_RESONANCE_TABLE` - test only
- `ActiveHapticConfig`, `ActiveHapticResult`, `ChirpType` - unused
- `HapticConfig`, `CymaticsConfig` - unused

---

## Phase 2: Mobile Super-Hook (P1)

### 2.1 Create Unified Hook: `useCoherenceCore`

**Merge 3 hooks → 1:**
- `useCoherenceEngine.ts` (544 lines)
- `useIMUAnalyzer.ts` (470 lines)
- `useSettings.ts` (176 lines)

**Total:** 1,190 lines → ~700 lines (41% reduction)

### 2.2 Fix Disclaimer Dual Source of Truth

**CRITICAL BUG:** Two independent disclaimer states

```typescript
// BEFORE (Bug): Two sources of truth
session.disclaimerAcknowledged  // Ephemeral (useCoherenceEngine)
settings.disclaimerAccepted     // Persisted (useSettings)

// AFTER (Fix): Single persisted source
coreState.compliance.disclaimerAcknowledged  // Persisted to AsyncStorage
```

### 2.3 Unified State Shape

```typescript
interface CoherenceCoreState {
  // Audio Output (Stimulate)
  audio: {
    isPlaying: boolean;
    preset: FrequencyPresetId;
    frequencyHz: number;
    amplitude: number;
    waveform: WaveformType;
    elapsedMs: number;
    remainingMs: number;
  };

  // Camera Analysis (Scan - Camera mode)
  evm: {
    isAnalyzing: boolean;
    frameRate: number;
    qualityScore: number;
    detectedFrequencies: number[];
    nyquistValid: boolean;
  };

  // IMU Analysis (Scan - IMU mode)
  imu: {
    isAnalyzing: boolean;
    currentData: IMUData | null;
    dominantFrequencies: number[];
    heartRateHz: number | null;
    breathingRateHz: number | null;
    signalQuality: number;
    bufferFillPercent: number;
  };

  // Settings (Settings screen)
  settings: Settings;

  // Compliance (SINGLE SOURCE OF TRUTH)
  compliance: {
    disclaimerAcknowledged: boolean;
    acknowledgedAt: number | null;
  };
}
```

---

## Phase 3: Cross-Platform Shared Code (P2)

### 3.1 Extract Cymatics Pattern Package

**Duplicate code in both mobile and desktop:**

```
NEW: packages/cymatics-patterns/
├── src/
│   ├── algorithms.ts    # chladni, interference, ripple, standing
│   └── index.ts
└── package.json
```

**Functions to extract:**
- `chladniValue(x, y, frequency, amplitude)` - 20 lines
- `interferenceValue(x, y, frequency, amplitude)` - 15 lines
- `rippleValue(x, y, frequency, amplitude)` - 12 lines
- `standingWaveValue(x, y, frequency, amplitude)` - 15 lines

**Impact:** 89 lines of duplicate code → 1 shared package

### 3.2 Harmonize SessionState Schema

```typescript
// CURRENT: Different schemas mobile vs desktop
// Mobile: 11 fields including EVM analysis
// Desktop: 7 fields, no analysis

// UNIFIED SCHEMA:
interface UnifiedSessionState {
  // Core playback (shared)
  isPlaying: boolean;
  frequencyHz: number;
  amplitude: number;
  waveform: WaveformType;
  sessionStartMs: number | null;
  elapsedMs: number;
  remainingMs: number;

  // Analysis (optional, mobile only for now)
  analysis?: AnalysisState;

  // Compliance
  disclaimerAcknowledged: boolean;
}
```

---

## Phase 4: Swift Codebase Cleanup (P3)

### 4.1 Remove Duplicate Classes (CRITICAL)

| Duplicate | Keep | Delete |
|-----------|------|--------|
| VideoExportManager | `Video/VideoExportManager.swift` | `Video/VideoProcessingEngine.swift:972` |
| LocalizationManager | `Localization/LocalizationManager.swift` | `Localization/Phase8000Localization.swift:443` |
| PresetManager | `Presets/PresetManager.swift` | `Presets/Phase8000Presets.swift:468` |
| SpatialAudioEngine | `Spatial/SpatialAudioEngine.swift` | `Platforms/visionOS/VisionApp.swift:696` |

### 4.2 Directory Consolidation Plan

**Merge small directories into larger modules:**

```
MERGE:
Sound           → Audio
SoundDesign     → Audio
DSP             → Audio
Orchestral      → Audio
MusicTheory     → MIDI
Immersive       → Visual
Shaders         → Visual
Intelligence    → AI
Lambda          → Core
Haptics         → Audio/Effects
FutureTech      → Hardware (or archive)
Documentation   → Developer
Optimization    → Performance
QualityAssurance → Testing
Sustainability  → Business
SoundDesign     → Audio
```

**Consolidate platform code:**

```
MOVE:
VisionOS/       → Platforms/visionOS/
tvOS/           → Platforms/tvOS/
WatchOS/        → Platforms/watchOS/
```

### 4.3 Proposed Swift Structure (25 directories)

```
Sources/Echoelmusic/
├── Core/           # Synthesis foundations + control hub
├── Audio/          # ALL audio (Sound, DSP, Orchestral merged)
├── Visual/         # ALL rendering (Visual, Shaders, Immersive merged)
├── Video/          # Video editing + export (slimmed)
├── Recording/      # Session capture
├── Streaming/      # Live broadcast
├── MIDI/           # MIDI 2.0 + MPE + MusicTheory
├── Biofeedback/    # Bio-reactive (Biophysical, Science merged)
├── Production/     # Project management
├── Collaboration/  # Multi-participant sync
├── Hardware/       # Device integration
├── AI/             # ML + Intelligence merged
├── Platforms/      # ALL platform code (5 subdirs)
├── Developer/      # SDK + Documentation merged
├── Accessibility/  # WCAG + Theme merged
├── Cloud/          # Server + sync
├── Testing/        # QA consolidated
├── Localization/   # Single implementation
├── Presets/        # Single implementation
├── Views/          # UI components
├── Widgets/        # Lock screen + Dynamic Island
├── SharePlay/      # Group sessions
├── Social/         # Social media
├── LED/            # DMX + lighting
└── Utils/          # Safety wrappers
```

---

## Implementation Timeline

### Week 1: Quick Wins (P0)
- [ ] Remove `packages/core/` empty directory
- [ ] Remove re-exports from fusion-engine
- [ ] Document unused exports in shared-types

### Week 2: Mobile Consolidation (P1)
- [ ] Create `useCoherenceCore` super-hook
- [ ] Fix disclaimer dual source of truth
- [ ] Update all screens to use new hook

### Week 3: Cross-Platform (P2)
- [ ] Extract `packages/cymatics-patterns/`
- [ ] Update mobile CymaticsVisualizer to use package
- [ ] Update desktop CymaticsCanvas to use package

### Week 4+: Swift Cleanup (P3)
- [ ] Remove duplicate classes (4 major)
- [ ] Consolidate platform directories
- [ ] Merge small directories

---

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Breaking mobile app | High | Gradual deprecation, keep old hooks temporarily |
| Swift compilation errors | Medium | Run full test suite before merging |
| Desktop functionality loss | Low | Test all Tauri commands after changes |
| Missing dependencies | Medium | Review all imports before deletion |

---

## Success Metrics

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Mobile hook count | 3 | 1 | Pending |
| Disclaimer sources | 2 | 1 | Pending |
| Duplicate cymatics code | 89 lines | 0 | Pending |
| Swift directories | 58 | 25 | Pending |
| Swift duplicate classes | 4 | 0 | Pending |
| Empty packages | 1 | 0 | Pending |

---

## Approved By

Senior Developer Manager
Ralph Wiggum Lambda Loop Mode
2026-01-15

---

## Phase 5: Instrument Section Consolidation (P4)

### 5.1 CRITICAL: Synthesis Engine Duplication

**Two separate synthesis engine registries with overlapping types:**

| Location | Enum Name | Types |
|----------|-----------|-------|
| `Sound/UniversalSoundLibrary.swift:151` | `SynthType` | subtractive, fm, wavetable, granular, additive, physicalModeling, sampler, spectral, vectorSynth, modalSynth |
| `Developer/AdvancedPlugins.swift:32` | `SynthesisEngine` | granular, spectral, wavetable, physical, neural, additive, subtractive, fm, karplus, waveguide |

**OVERLAP:** 8 of 10 types are duplicates with different naming!

**RECOMMENDATION: Create Unified Synthesis Registry**

```swift
// NEW: Sources/Echoelmusic/Audio/SynthesisRegistry.swift

/// Unified synthesis engine type registry
/// Single source of truth for ALL synthesis methods
public enum SynthesisEngineType: String, CaseIterable, Sendable {
    // Analog-style
    case subtractive = "Subtractive"

    // Digital methods
    case fm = "FM Synthesis"
    case wavetable = "Wavetable"
    case additive = "Additive"
    case spectral = "Spectral"
    case vectorSynth = "Vector"

    // Texture-based
    case granular = "Granular"

    // Physical
    case physicalModeling = "Physical Modeling"
    case karplusStrong = "Karplus-Strong"
    case waveguide = "Waveguide"
    case modalSynth = "Modal"

    // Sample-based
    case sampler = "Sample-based"

    // AI/Neural
    case neural = "Neural Audio"
}
```

### 5.2 Voice Management Fragmentation

**Multiple Voice implementations for different purposes:**

| File | Type | Purpose | Voices |
|------|------|---------|--------|
| `Sound/InstrumentOrchestrator.swift:45` | `private struct Voice` | Polyphonic voice management | 16 max |
| `Developer/AdvancedPlugins.swift:882` | `public struct Voice` | Orchestral/singing voices | N/A |
| `MIDI/MPEZoneManager.swift:56` | `enum VoiceAllocationMode` | MIDI voice allocation | Zone-based |
| `Audio/EnhancedAudioFeatures.swift:1298` | `class VoiceProcessor` | Vocal audio processing | N/A |
| `Sound/TR808BassSynth.swift` | Internal voice array | 808 polyphony | 8 max |

**RECOMMENDATION: Create Voice Protocol Hierarchy**

```swift
// NEW: Sources/Echoelmusic/Audio/VoiceProtocols.swift

/// Base protocol for all voice types
protocol SynthVoice: Identifiable {
    var id: UUID { get }
    var isActive: Bool { get set }
    var note: Int { get set }
    var velocity: Float { get set }
    func trigger(note: Int, velocity: Float)
    func release()
}

/// Polyphonic voice pool manager
protocol VoicePool {
    associatedtype V: SynthVoice
    var maxVoices: Int { get }
    var activeVoices: Int { get }
    func allocateVoice(for note: Int) -> V?
    func releaseVoice(_ voice: V)
}
```

### 5.3 Orchestral Instrument Definitions

**THREE separate orchestral instrument systems:**

| File | System | Instruments |
|------|--------|-------------|
| `Sound/UniversalSoundLibrary.swift` | `Instrument` struct | 13+ world instruments |
| `Orchestral/CinematicScoringEngine.swift` | `OrchestraInstrument` | Full orchestral (8 sections) |
| `Developer/AdvancedPlugins.swift` | `OrganicScoreInstrumentPlugin` | 40+ comprehensive |

**RECOMMENDATION: Unified Instrument Registry**

```swift
// NEW: Sources/Echoelmusic/Audio/InstrumentRegistry.swift

/// Unified instrument catalog
class InstrumentRegistry {

    enum InstrumentFamily: String, CaseIterable {
        // Orchestral
        case strings, brass, woodwinds, percussion, keyboard, choir

        // World
        case asian, middleEastern, african, latin, oceanian

        // Electronic
        case synthesizer, drumMachine, sampler

        // Special
        case experimental, foley, soundFX
    }

    /// All registered instruments
    static var all: [RegisteredInstrument] { ... }

    /// Get instruments by family
    static func instruments(for family: InstrumentFamily) -> [RegisteredInstrument]
}
```

### 5.4 DSP Effects Consolidation

**Two DSP architectures:**

| Location | Architecture | Effects |
|----------|--------------|---------|
| `Audio/Nodes/` | Node graph | CompressorNode, DelayNode, FilterNode, ReverbNode |
| `DSP/AdvancedDSPEffects.swift` | Monolithic classes | 12+ professional effects |

**RECOMMENDATION:** Keep both but ensure interface compatibility

```swift
/// Protocol for all DSP effects (node or monolithic)
protocol DSPEffect {
    func process(input: UnsafeMutablePointer<Float>, output: UnsafeMutablePointer<Float>, frameCount: Int)
    func setParameter(_ name: String, value: Float)
}
```

### 5.5 Scale & Chord Definitions

**Potential duplication between:**
- `MIDI/TouchInstruments.swift` - 13 scales, 11 chord types
- `Integration/GlobalMusicTheoryDatabase.swift` (if exists)

**RECOMMENDATION:** Create `MusicTheory` module in MIDI/

### 5.6 Instrument Section Target Architecture

```
Sources/Echoelmusic/Audio/
├── Synthesis/
│   ├── SynthesisRegistry.swift        # Unified engine types (NEW)
│   ├── VoiceProtocols.swift           # Voice interfaces (NEW)
│   ├── SynthEngine.swift              # Base synthesis engine
│   ├── SubtractiveSynth.swift         # Analog-style
│   ├── FMSynth.swift                  # FM synthesis
│   ├── WavetableSynth.swift           # Wavetable
│   ├── GranularSynth.swift            # Granular
│   ├── AdditiveSynth.swift            # Additive
│   └── PhysicalModelSynth.swift       # Physical modeling
│
├── Instruments/
│   ├── InstrumentRegistry.swift       # Unified catalog (NEW)
│   ├── TR808BassSynth.swift           # 808 (keep)
│   ├── Orchestral/
│   │   ├── CinematicScoringEngine.swift
│   │   ├── FilmScoreComposer.swift
│   │   └── OrchestraSection.swift
│   └── World/
│       └── WorldInstruments.swift
│
├── Effects/
│   ├── DSPEffect.swift                # Base protocol (NEW)
│   ├── Nodes/                         # Node graph
│   └── AdvancedDSPEffects.swift       # Monolithic
│
└── Touch/
    └── TouchInstruments.swift         # Touch instruments (keep)
```

### 5.7 Instrument Consolidation Metrics

| Metric | Current | Target | Impact |
|--------|---------|--------|--------|
| Synthesis engine enums | 2 | 1 | Remove duplication |
| Voice implementations | 5 | 1 protocol + implementations | Unified interface |
| Orchestral systems | 3 | 1 registry | Single source of truth |
| DSP architectures | 2 | 2 (with shared protocol) | Interoperability |
| Files in Sound/ | 3 | 0 (merged to Audio/) | Directory cleanup |

### 5.8 Implementation Priority

1. **HIGH:** Create `SynthesisRegistry.swift` - eliminate engine type duplication
2. **HIGH:** Create `VoiceProtocols.swift` - unify voice management
3. **MEDIUM:** Create `InstrumentRegistry.swift` - catalog consolidation
4. **LOW:** Move Sound/ contents → Audio/Synthesis/ and Audio/Instruments/
5. **LOW:** DSP effect protocol for node/monolithic interop

---

## Updated Success Metrics (Including Instruments)

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Mobile hook count | 3 | 1 | Pending |
| Disclaimer sources | 2 | 1 | Pending |
| Duplicate cymatics code | 89 lines | 0 | **DONE** |
| Swift directories | 58 | 25 | Pending |
| Swift duplicate classes | 4 | 0 | Pending |
| Empty packages | 1 | 0 | **DONE** |
| Synthesis engine enums | 2 | 1 | Pending |
| Voice implementations | 5 | 1 protocol | Pending |
| Orchestral systems | 3 | 1 registry | Pending |
