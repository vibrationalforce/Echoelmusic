# CLAUDE.md — Echoelmusic v7.0 ULTIMATE

## IDENTITY

Repository: https://github.com/vibrationalforce/Echoelmusic
Developer: Echoel (Michael Terbuyken) @ Studio Hamburg
App Apple ID: 6757957358
Bundle: com.echoelmusic.*

Bio-reactive creative performance platform. Physiological data → real-time music, visuals, light.

**SCIENCE-ONLY.** No esoteric terminology. No chakras, auras, energy healing. Evidence-based biofeedback. Every wellness claim requires peer-reviewed citation.

---

## CURRENT STATE

- **Branch:** `claude/analyze-test-coverage-9aFjV`
- **TestFlight Build:** `22572541274`
- **Mode:** RALPH WIGGUM LAMBDA — iterative tightening until tight
- **SDK:** Must target iOS 26 SDK (ITMS-90725, deadline April 28, 2026)
- **Architecture:** 100% JUCE-free, platform-native
- **Commits:** 1,560+ | **Tests:** 975+ methods / 214 classes / 14 files | **Swift 85%** | Kotlin 4.8% | C++ 4.7%

---

## BRAND

```
Echoelmusic          ← Hauptmarke
├── EchoelTools      ← Creative instruments
├── EchoelWorks      ← DAW integration
├── EchoelSync       ← Cross-platform sync (OSC, BLE, SharePlay)
└── EchoelWell       ← Wellness (NO health claims)
```

NEVER use "BLAB", "Vibrational Force", or legacy branding anywhere.

---

## THE 12 ECHOELTOOLS (via EngineBus)

```
EchoelCore (120Hz)
├── EchoelSynth    DDSP, 12 bio-mappings, vDSP, spectral morphing, timbre transfer
├── EchoelMix      Console, metering, BPM sync, multi-track
├── EchoelFX       20+ effects, Neve/SSL emulation
├── EchoelSeq      Step sequencer, patterns, automation
├── EchoelMIDI     MIDI 2.0, MPE, touch instruments
├── EchoelBio      HRV, HR, breathing, ARKit face (52 blendshapes), hands, EEG
├── EchoelVis      8 modes, Metal 120fps, Hilbert bio-mapping
├── EchoelVid      Capture, edit, stream, ProRes
├── EchoelLux      DMX 512, Art-Net, lasers, smart home
├── EchoelStage    External displays, projection mapping, AirPlay
├── EchoelNet      SharePlay, Dante, cloud sync, <10ms
└── EchoelAI       CoreML, LLM, stem separation, generative
```

Communication: EngineBus (lock-free pub/sub). All tools react to BioSnapshot.

---

## TECH STACK — Zero Dependencies

| Platform | Framework |
|---|---|
| Apple (all) | AVFoundation + Accelerate + Metal |
| Android | Oboe + AAudio + Health Connect |
| Desktop Plugins | iPlug2 (MIT) |
| DSP | Pure C++17 |
| Build | Tuist + Fastlane + Codemagic |

---

## REPO STRUCTURE

```
Echoelmusic/           ← Main iOS app target
EchoelmusicComplete/   ← Full feature set
EchoelmusicMVP/        ← MVP subset
CoherenceCore/         ← Swift Package (core DSP)
Sources/               ← Shared sources
Tests/                 ← 56 test suites
android/               ← Kotlin/Compose
docs/                  ← Website (GitHub Pages)
fastlane/              ← CI/CD
.ai/                   ← Session context
.claude/               ← Claude Code config
```

DO NOT create new top-level directories.

---

## BIO-SIGNAL DSP — DO NOT SIMPLIFY

| Algorithm | Basis | Function |
|---|---|---|
| BioEventGraph | DELLY (Rausch 2012) | Graph-based event detection, k-means clustering |
| HilbertSensorMapper | Hilbert curves | 1D→2D locality-preserving sensor mapping |
| BioSignalDeconvolver | Tracy (Rausch 2017) | Separates cardiac/respiratory/artifact via adaptive biquad IIR |

### DDSP Bio-Mappings

Coherence → Harmonicity | HRV → Brightness | Heart rate → Vibrato | Breath phase → Envelope | Breath depth → Noise | LF/HF → Spectral tilt | Coherence trend → Shape morphing

---

## PERFORMANCE — Hard Limits

| Metric | Target | FAIL |
|---|---|---|
| Audio Latency | <10ms | >15ms |
| CPU | <30% | >50% |
| Memory | <200MB | >300MB |
| Visual FPS | 120fps | <60fps |
| Bio Loop | 120Hz | <60Hz |

**Audio thread: NO locks, NO malloc, NO ObjC messaging, NO file I/O, NO GCD.**

---

## PLATFORM CONSTRAINTS

- Apple Watch HR: ~4-5 sec latency — NO beat-sync!
- RMSSD: Self-calculate (Apple only gives SDNN)
- Bluetooth Audio: 150-250ms latency
- Flash animations: Max 3 Hz (epilepsy W3C WCAG)

---

## SAFETY WARNINGS (must be in app)

- Brainwave Entrainment: NOT while operating vehicles
- NOT under influence of alcohol/drugs
- Therapeutic use: coordinate medications with provider
- Max 3 Hz visual flash rate
- Data for self-observation, NOT medical diagnosis

---

## RALPH WIGGUM LAMBDA PROTOCOL

```
1. git status && git log --oneline -10
2. swift build 2>&1 | tail -20
3. Identify ONE broken/unclear thing
4. Fix it (minimal change, max 3 files)
5. swift test --filter [relevant]
6. Commit: fix: [description]
7. Deploy to TestFlight
8. Evaluate on device
9. GOTO 1
```

ONE issue per cycle. No batching. Build fails = ONLY priority.
No features during fix cycles. Convergence only.

---

## "CLEAR SOFTWARE" CHECKLIST

1. Every screen does something (no placeholders)
2. Navigation works (tabs respond, back goes back)
3. Bio-feedback visible (HR, HRV, coherence front and center)
4. Audio works (tap synth = hear sound)
5. Buttons respond, states change, loading indicators work
6. No crashes (force unwraps banned, optionals handled)
7. Permission denials handled gracefully
8. Background/foreground transitions stable

---

## SESSION START

```bash
git status
git log --oneline -20
swift build 2>&1 | tail -30
cat .ai/*.md 2>/dev/null
swift test 2>&1 | tail -20
```

Priority: Build errors → Test failures → Crash code → Task → Cleanup

---

## CODE STYLE

- **SwiftUI + MVVM** | `@Observable` (iOS 17+) | async/await + `@MainActor`
- **Swift 6** strict concurrency | SwiftLint enforced
- `os_log` ONLY (never `print`) | Guard-let over if-let
- Conventional commits | One change per commit
- C++17 with namespace `Echoelmusic::`
- `///` for public API docs

---

## CRITICAL BUILD ERROR PATTERNS

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

## KEY TESTS (14 files, 975+ methods)

CoreSystemTests | CoreServicesTests | DSPTests | VDSPTests | AudioEngineTests | AdvancedEffectsTests | MIDITests | RecordingTests | BusinessTests | ExportTests | VideoTests | SoundTests | VocalAndNodesTests | HardwareThemeTests

Run before ANY commit.

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

## OSC (EchoelSync)

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

UDP. Target: <5ms LAN.

---

## PLATFORM NOTES

- **Simulator:** No HealthKit, Push 3, head tracking
- **Push 3:** Requires USB
- **DMX:** Requires network 192.168.1.100
- **Linux:** `apt install libasound2-dev`

---

## DEVELOPMENT WORKFLOW

### Long-Term Memory (scratchpads/)

The `scratchpads/` directory is persistent memory across sessions:

| File | Purpose |
|------|---------|
| `HEALING_LOG.md` | **Read first** — session history, key discoveries, commits |
| `ARCHITECTURE_AUDIT_*.md` | Data flow diagrams, env object chains, init sequence |
| `PLAN_*.md` | Feature/fix plans before implementation |

**Start every session** by reading `scratchpads/HEALING_LOG.md`.

### 4-Phase Workflow

**Phase 1 — Plan:**
- Read `scratchpads/HEALING_LOG.md` for context
- Break task into atomic steps (max 5 min each)
- Write plan to `scratchpads/PLAN_<feature>.md`
- Include exact file paths, expected changes, test strategy

**Phase 2 — Implement (TDD):**
- Write failing test FIRST when adding new functionality
- Run `swift test` — confirm RED
- Implement minimal code to pass
- Run `swift test` — confirm GREEN
- Refactor while GREEN

**Phase 3 — Verify:**
- `swift build` must pass (remember: `-warnings-as-errors`)
- `swift test` must pass
- No force unwraps, no divide-by-zero, no missing environmentObjects
- Guard all divisions, guard all array access, guard all optionals

**Phase 4 — Ship:**
- Commit with conventional prefix: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`, `perf:`
- Update `scratchpads/HEALING_LOG.md` with session summary
- Push to feature branch

### Parallel Agent Strategy

For large tasks, use 3-agent parallel audits:
```
Agent 1: Core systems (App entry, init sequence, data flow)
Agent 2: UI layer (Views, environment objects, navigation)
Agent 3: Domain logic (Audio, bio, visual, lighting pipelines)
```

### Code Review Checklist

- [ ] No `@EnvironmentObject` without matching `.environmentObject()` injection
- [ ] No division without guard (`.count`, heartRate, etc.)
- [ ] No `#if os()` missing for platform-specific APIs
- [ ] No hardcoded values where real data should flow
- [ ] All Combine subscriptions stored in cancellables
- [ ] `@MainActor` on all `ObservableObject` classes

---

## DO NOT

- Restructure project without approval
- Add dependencies without asking
- Create new targets or top-level dirs
- Modify Info.plist / CI config without asking
- Use force unwrap, `print()`, `ObservableObject`, `UIScreen.main`
- Simplify Rausch DSP algorithms
- Allocate memory on audio thread
- Batch unrelated fixes
- Add features during fix cycles
- Use esoteric terminology

---

## ACTIVATION

```
ECHOEL MODE ACTIVE
Branch: [branch]  Build: [number]
Priority: [errors | failures | task]
Mode: Ralph Wiggum Lambda — Fix → Build → Test → Ship → Loop
```

No intro. Audit → Fix → Build → Loop.
