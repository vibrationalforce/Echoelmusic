# PLAN: Missing Systems Roadmap

Based on deep dive audit (2026-03-10). These are the systems that exist in CLAUDE.md documentation but have NO or STUB implementations.

---

## Priority 1: HealthKit Bio (CRITICAL PATH)

**Current state:** Mic audio level used as fake coherence. HRV/HR/breath hardcoded to 0.5.
**Impact:** Unlocks the entire bio-reactive value proposition.

### Implementation Plan

1. **EchoelBioEngine.swift** (new file in `Sources/Echoelmusic/Bio/`)
   - `HKHealthStore` initialization + authorization request
   - `HKQuantitySampleQuery` for real-time heart rate
   - RMSSD calculation from RR intervals (Apple only gives SDNN)
   - Breathing rate from HealthKit (iOS 17+)
   - `@Observable` class publishing: `heartRate`, `hrv`, `coherence`, `breathPhase`, `breathDepth`

2. **Wire into EchoelCreativeWorkspace**
   - Replace `observeAudioLevel()` mic proxy with real HKHealthStore queries
   - Keep mic fallback when HealthKit unavailable (Simulator)
   - Smooth bio parameters with 100ms EMA

3. **BioSignalDeconvolver** (Rausch 2017)
   - Separate cardiac, respiratory, and artifact signals
   - Adaptive biquad IIR filter bank
   - Already documented in CLAUDE.md — implement from paper

4. **ARKit Face Tracking** (52 blendshapes)
   - `ARFaceTrackingConfiguration` for breathing detection via nose/mouth
   - Map blendshapes to breath phase/depth
   - Fallback when TrueDepth camera unavailable

5. **Safety**
   - All disclaimers from bio-safety-reviewer checklist
   - Apple Watch HR: show ~4-5 sec latency warning
   - Permission denial → graceful fallback UI

### Files to create/modify
- NEW: `Sources/Echoelmusic/Bio/EchoelBioEngine.swift`
- NEW: `Sources/Echoelmusic/Bio/BioSignalDeconvolver.swift`
- NEW: `Sources/Echoelmusic/Bio/ARKitBreathTracker.swift`
- MODIFY: `Sources/Echoelmusic/Core/EchoelCreativeWorkspace.swift` (replace mic proxy)
- NEW: `Tests/EchoelmusicTests/BioEngineTests.swift`

---

## Priority 2: Lighting/DMX (EchoelLux)

**Current state:** Zero code. Only permission strings in Project.swift.
**Impact:** Enables live performance stage control.

### Implementation Plan

1. **EchoelLuxEngine.swift** (new file in `Sources/Echoelmusic/Lighting/`)
   - DMX 512 over Art-Net (UDP port 6454)
   - Art-Net packet encoder: OpDmx (0x5000), OpPoll (0x2000)
   - 512 channels per universe, up to 32,768 universes
   - Fixture library: generic dimmer, RGB, RGBW, moving head
   - Channel mapping: fixture → DMX address → universe

2. **Bio-reactive lighting**
   - Coherence → color temperature (warm = high coherence)
   - Heart rate → strobe rate (capped at 3 Hz for safety!)
   - HRV → color saturation
   - Breath phase → dimmer level (fade in/out with breath)

3. **Timeline integration**
   - Sync DMX cues to BPMGridEditEngine
   - Beat-aligned color changes
   - Scene presets (ambient, performance, meditation)

4. **Smart Home** (HomeKit)
   - `HMHomeManager` for local smart lights
   - Map bio-reactive parameters to HomeKit accessories
   - Hue, LIFX, Nanoleaf via HomeKit bridge

### Files to create
- NEW: `Sources/Echoelmusic/Lighting/EchoelLuxEngine.swift`
- NEW: `Sources/Echoelmusic/Lighting/ArtNetProtocol.swift`
- NEW: `Sources/Echoelmusic/Lighting/DMXFixture.swift`
- NEW: `Sources/Echoelmusic/Lighting/LightingCueSystem.swift`
- NEW: `Tests/EchoelmusicTests/LightingTests.swift`

---

## Priority 3: AI/ML (EchoelAI)

**Current state:** DDSP is pure DSP, no actual ML. No CoreML models.
**Impact:** Stem separation, generative composition, intelligent mixing.

### Implementation Plan

1. **Stem Separation** (CoreML)
   - Convert Demucs v4 (Meta) to CoreML format
   - 4-stem: vocals, drums, bass, other
   - Process audio clips in background
   - Display separated stems in mixer

2. **Intelligent Mixing** (on-device)
   - Loudness normalization (LUFS targeting)
   - Auto-EQ based on spectral analysis
   - Compression suggestions based on genre

3. **Generative** (future — LLM-assisted)
   - Melody suggestion from chord progression
   - Pattern generation from bio-data history
   - Text-to-music prompt (requires cloud API)

### Files to create
- NEW: `Sources/Echoelmusic/AI/StemSeparationEngine.swift`
- NEW: `Sources/Echoelmusic/AI/IntelligentMixer.swift`
- NEW: ML model files in `Resources/Models/`

---

## Priority 4: Step Sequencer UI (EchoelSeq)

**Current state:** BPMGridEditEngine has quantize/snap infrastructure. No dedicated step sequencer view.
**Impact:** Completes the beat-making workflow alongside EchoelBeat.

### Implementation Plan

1. **StepSequencerView.swift**
   - 16/32/64 step grid
   - Per-step velocity, probability, note length
   - Pattern banks (A/B/C/D)
   - Swing/shuffle control
   - Polyrhythm support (different lengths per track)

2. **Integration**
   - Each row → EchoelBeat drum slot
   - Melodic mode → EchoelSynth notes
   - Sync to BPMGridEditEngine tempo
   - Pattern → clip export for SessionClipView

### Files to create
- NEW: `Sources/Echoelmusic/Views/StepSequencerView.swift`
- MODIFY: `Sources/Echoelmusic/Sound/EchoelBeat.swift` (pattern playback)

---

## Priority 5: OSC Network (EchoelSync)

**Current state:** Message format defined in CLAUDE.md. No UDP implementation.
**Impact:** External app integration (Max/MSP, Resolume, TouchDesigner, Ableton).

### Implementation Plan

1. **OSCEngine.swift**
   - `NWConnection` UDP sender/receiver (Network.framework)
   - OSC message encoding/decoding (type tags: f, i, s, b)
   - OSC bundle support (timetag + messages)
   - Configurable send/receive ports

2. **Predefined addresses**
   ```
   /echoelmusic/bio/heart/bpm       float [40-200]
   /echoelmusic/bio/heart/hrv       float [0-1]
   /echoelmusic/bio/breath/rate     float [4-30]
   /echoelmusic/bio/breath/phase    float [0-1]
   /echoelmusic/bio/coherence       float [0-1]
   /echoelmusic/bio/eeg/{band}      float [0-1]
   /echoelmusic/audio/rms           float [0-1]
   /echoelmusic/audio/pitch         float Hz
   ```

3. **Bidirectional**
   - Send bio-data to external apps
   - Receive control messages (BPM, transport, parameters)

### Files to create
- NEW: `Sources/Echoelmusic/Network/OSCEngine.swift`
- NEW: `Sources/Echoelmusic/Network/OSCMessage.swift`
- NEW: `Tests/EchoelmusicTests/OSCTests.swift`

---

## Implementation Order

```
Sprint 1: HealthKit Bio    → unlocks core value prop
Sprint 2: OSC Network      → easy win, enables external control
Sprint 3: Step Sequencer    → completes beat workflow
Sprint 4: Lighting/DMX     → enables live performance
Sprint 5: AI/ML            → advanced features, needs ML models
```

Each sprint follows Ralph Wiggum Lambda: build → test → ship → loop.
