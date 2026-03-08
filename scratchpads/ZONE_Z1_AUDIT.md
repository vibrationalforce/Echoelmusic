# Z1 Audio Core — SCAN Audit

**Date:** 2026-03-08
**Scope:** Audio/ (41 files), DSP/ (8 files), Sound/ (8 files)
**Total before:** 37,817 LOC | **After:** ~30,000 LOC
**Deleted:** 7,822 LOC (7,335 + 487)

---

## Deleted Files (Dead Code)

| File | LOC | Reason |
|------|-----|--------|
| `DSP/AdvancedDSPEffects.swift` | 1,245 | 0 refs in Sources, stub implementation |
| `DSP/EchoelCore.swift` | 643 | TheConsole duplicates AnalogConsole, rest unused |
| `Audio/AudioGraphBuilder.swift` | 549 | 0 refs in Sources |
| `Audio/UltraLowLatencyBluetoothEngine.swift` | 1,490 | 0 refs in Sources |
| `Audio/VoiceProfileSystem.swift` | 1,110 | 0 refs in Sources |
| `Audio/VocalAlignmentView.swift` | 520 | 0 refs in Sources |
| `Sound/SynthesisEngineType.swift` | 204 | Only referenced by tests, not app |

## Trimmed Files

| File | Before | After | Removed |
|------|--------|-------|---------|
| `Audio/EnhancedAudioFeatures.swift` | 1,522 | 167 | 6 dead classes |
| `Tests/DSPTests.swift` | 652 | 224 | Tests for deleted code |
| `Tests/AdvancedEffectsTests.swift` | 163 | 86 | SynthesisEngineType tests |
| `Tests/SoundTests.swift` | 1,226 | 1,028 | SynthesisEngineType tests |

---

## DSP/ Status (7 files remaining)

| File | LOC | Status | Quality |
|------|-----|--------|---------|
| EchoelDDSP.swift | 1,105 | AKTIV | Exemplary, audio-safe |
| ClassicAnalogEmulations.swift | 1,001 | AKTIV | Good, 8 hardware emulations |
| EchoelModalBank.swift | 805 | AKTIV | Good, physics-based |
| NeveInspiredDSP.swift | 663 | AKTIV | Exemplary |
| EchoelVDSPKit.swift | 657 | AKTIV | Exemplary, foundation |
| EchoelCellular.swift | 516 | AKTIV | Good, CA synthesis |
| PitchDetector.swift | 442 | AKTIV | Exemplary, YIN algorithm |

**DSP Verdict: 7/7 production-ready. No further cleanup needed.**

---

## Audio/ Status (35 files remaining)

### Core Pipeline (AKTIV)
- AudioEngine.swift (395) — master AVAudioEngine
- AudioConfiguration.swift (411) — config + AudioUnfairLock
- ProMixEngine.swift (1,286) — routing hub
- ProSessionEngine.swift (1,445) — multi-track sessions
- MixerDSPKernel.swift (639) — DSP kernel

### Effects/Nodes (AKTIV)
- Audio/Nodes/ (5 files, ~1,735) — CompressorNode, DelayNode, FilterNode, ReverbNode, NodeGraph
- Audio/Effects/BreakbeatChopper.swift (1,110) — referenced by SynthPresetLibrary

### Vocal Pipeline (AKTIV)
- VocalProcessing/ (7 files, ~2,803) — Breath, Pitch, Harmony, Doubling, PostProcessor
- VocalAlignment/AutomaticVocalAligner.swift (645) — referenced externally

### Instruments (AKTIV)
- ChromaticTuner.swift (333) — via TuningBridge
- TuningBridge.swift (80) / TuningManager.swift (158)
- MetronomeEngine.swift (463) — via DAWArrangementView
- MIDIController.swift (362)

### Session/Transport (AKTIV)
- AudioClipScheduler.swift (525)
- LoopEngine.swift (551)
- CrossfadeEngine.swift (248) — via ProSessionEngine
- TrackFreezeEngine.swift (489) — via ProSessionEngine
- BPMTransitionEngine.swift (743) — via AbletonLinkClient

### Network (AKTIV)
- AbletonLinkClient.swift (751) — via EchoelCreativeWorkspace

### Views in Audio/ (should move to Views/)
- EffectsChainView.swift (524)
- EffectParametersView.swift (501)
- KammertonWheelView.swift (330)

### Remaining 1K+ Files (need attention in CLEAN phase)
- ProSessionEngine.swift (1,445) — 42 methods
- ProMixEngine.swift (1,286) — mixing + routing + metering
- BreakbeatChopper.swift (1,110) — standalone but monolithic

---

## Sound/ Status (7 files remaining)

| File | LOC | Status | Refs |
|------|-----|--------|------|
| TR808BassSynth.swift | 1,430 | AKTIV | via SynthPresetLibrary |
| SynthPresetLibrary.swift | 1,326 | AKTIV | 5 file refs |
| EchoelBass.swift | 1,255 | AKTIV | via EchoelSynthView |
| EchoelBeat.swift | 1,234 | AKTIV | 9 file refs |
| UniversalSoundLibrary.swift | 926 | AKTIV | 2 external refs |
| EchoelSampler.swift | 855 | AKTIV | 6 file refs |
| InstrumentOrchestrator.swift | 684 | AKTIV | 2 external refs |

**Sound Verdict: All 7 files active. No dead code. But 4 files >1K LOC need splitting in CLEAN phase.**

---

## Duplicate Analysis

### Confirmed Duplicates (DELETED)
- `TheConsole` (EchoelCore) duplicated `AnalogConsole` (ClassicAnalogEmulations)

### Potential Overlap (investigate in CLEAN)
- TR808BassSynth vs EchoelBass — both are bass synths with pitch glide, envelopes, filter
  - TR808: 808-specific (sine core, exponential decay)
  - EchoelBass: 5-engine morph (sub808, reese, moog, acid, growl)
  - Verdict: Different enough to keep separate, but shared base class possible
- SynthPresetLibrary — 1,326 LOC of hardcoded presets → should be JSON files

---

## Next Steps (Z1 CLEAN)

1. ProSessionEngine (1,445) — extract TrackManager, AutomationEngine, TransportManager
2. ProMixEngine (1,286) — extract routing from metering from automation
3. SynthPresetLibrary (1,326) — move preset data to JSON
4. TR808BassSynth (1,430) — extract sequencer logic
5. BreakbeatChopper (1,110) — review if monolith is justified
6. Move Audio/Views to Views/ (EffectsChainView, EffectParametersView, KammertonWheelView)
