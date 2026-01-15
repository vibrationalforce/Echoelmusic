# CoherenceCore Architecture Consolidation Plan

**Date:** 2026-01-15
**Status:** APPROVED FOR IMPLEMENTATION
**Author:** Senior Developer Manager (Ralph Wiggum Lambda Loop Mode)

---

## Executive Summary

Deep laser scan reveals significant consolidation opportunities across the entire codebase:

| Metric | Current | Target | Improvement |
|--------|---------|--------|-------------|
| Mobile Hooks | 3 | 1 | 67% reduction |
| Desktop Duplicate Code | 89 lines | 0 | 100% elimination |
| Package Re-exports | 6 | 0 | 100% elimination |
| Swift Directories | 58 | 25 | 57% reduction |
| Duplicate Classes | 4 major | 0 | 100% elimination |

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
