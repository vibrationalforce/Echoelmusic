# CLAUDE.md — Echoelmusic v8.0 Soundscape

## IDENTITY

Repository: https://github.com/vibrationalforce/Echoelmusic
Developer: Echoel (Michael Terbuyken) @ Studio Hamburg
App Apple ID: 6757957358
Bundle: com.echoelmusic.*

Bio-reactive ambient soundscape generator. Your body, weather, and time of day create evolving sound.

**SCIENCE-ONLY.** No esoteric terminology. No chakras, auras, energy healing. Evidence-based biofeedback. Every wellness claim requires peer-reviewed citation.

---

## CURRENT STATE

- **Branch:** `main`
- **Mode:** RALPH WIGGUM LAMBDA — iterative tightening until tight
- **SDK:** Must target iOS 26 SDK (ITMS-90725, deadline April 28, 2026)
- **Architecture:** Focused soundscape generator (stripped from 12-tool suite)
- **Files:** 34 source / 9 tests | ~13,000 lines | **Swift 100%**

---

## BRAND

Echoelmusic — Bio-reactive ambient soundscape generator.

NEVER use "BLAB", "Vibrational Force", or legacy branding anywhere.

---

## ARCHITECTURE

```
EchoelmusicApp (@main)
├── AudioEngine (AVAudioEngine)
├── BioSourceManager (multi-wearable fusion)
│   ├── HealthKit (Apple Watch HR, HRV, breathing)
│   ├── CameraAnalyzer (rPPG pulse from finger/face)
│   ├── OuraRingClient (sleep, readiness, resting HR)
│   └── EEGSensorBridge (Muse/NeuroSky)
├── SoundscapeEngine (central hub)
│   ├── WeatherProvider (WeatherKit + time-based fallback)
│   ├── CircadianClock (4 phases + Oura sleep data)
│   ├── EchoelDDSP (bio-reactive harmonic pad)
│   ├── EchoelCellular (texture layer)
│   └── AVAudioSourceNode → AudioEngine → Speaker
├── EchoelStore (StoreKit 2 subscriptions)
└── Views
    ├── SoundscapeView (coherence ring, bio metrics, confidence)
    ├── SettingsView (bio sources, Oura connect, audio output)
    ├── OnboardingView (3-page HealthKit flow)
    └── SessionHistoryView (SwiftData)
```

AUv3 Generator Plugin (augn): Bio-reactive soundscape usable in Logic Pro, GarageBand, AUM.

Communication: Explicit wiring via `EchoelCreativeWorkspace` hub — `.connectAudioEngine()`, `.connectMixer()`, Combine observation. All tools react to BioSnapshot.

### Component Wiring (actual architecture)

```
EchoelmusicApp (init)
├─ AudioEngine(microphoneManager:)    ← master AVAudioEngine
│   └─ connectMixer(ProMixEngine)     ← routing hub
├─ RecordingEngine
│   └─ connectAudioEngine(AudioEngine)
└─ EchoelCreativeWorkspace.shared     ← central hub singleton
    ├─ connectAudioEngine(AudioEngine) ← wires Combine pipelines
    ├─ BPMGridEditEngine              ← beat/tempo sync
    ├─ ProSessionEngine               ← multi-track sessions
    ├─ VideoEditingEngine             ← timeline + compositing
    ├─ ProColorGrading                ← live color
    └─ EchoelDDSP (bioSynth)         ← bio-reactive synthesis
        └─ mic audioLevel → bioCoherence → applyBioReactive()
```

All inter-component communication uses explicit Combine observation (`.sink`, `$property`) stored in `cancellables`. No implicit message bus.

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
Sources/Echoelmusic/   ← Main iOS app (32 files)
  Audio/               ← AudioEngine, AudioConfiguration, BreathDetector, VibratoEngine
  Bio/                 ← BioSourceManager, EchoelBioEngine, OuraRingClient, CameraAnalyzer, EEG
  Core/                ← SoundscapeEngine, WeatherProvider, CircadianClock, EchoelStore, SessionStore
  DSP/                 ← EchoelDDSP, EchoelCellular, EchoelModalBank, EchoelVDSPKit
  Views/               ← SoundscapeView, SettingsView, OnboardingView, SessionHistoryView
Sources/EchoelmusicAUv3/ ← AUv3 Generator Plugin (2 files)
Tests/                 ← 9 test files (Audio, Bio, DSP, Core)
docs/                  ← Website (GitHub Pages — artist landing page)
.github/workflows/     ← CI/CD (testflight.yml, ci.yml, etc.)
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

## KEY TESTS (15 files, 1,060+ methods)

CoreSystemTests | CoreServicesTests | DSPTests | VDSPTests | AudioEngineTests | AdvancedEffectsTests | MIDITests | RecordingTests | BusinessTests | ExportTests | VideoTests | SoundTests | VocalAndNodesTests | HardwareThemeTests | IntegrationTests

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

### GitHub API Access

Token stored in `.claude/settings.local.json` (gitignored, NEVER committed).

**Read token:**
```bash
GITHUB_TOKEN=$(python3 -c "import json; print(json.load(open('.claude/settings.local.json'))['github']['token'])" 2>/dev/null)
```

**Available commands:**
- `/testflight-deploy` — Full pre-flight + deploy to TestFlight
- `/github` — GitHub API operations (PRs, issues, workflow status)

**If token missing:** Ask user to create `.claude/settings.local.json`:
```json
{
  "github": {
    "token_name": "claude-code",
    "token": "ghp_...",
    "owner": "vibrationalforce",
    "repo": "Echoelmusic"
  }
}
```

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

### Persistent Memory (memory/)

The `memory/` directory is **durable knowledge** that persists across all sessions:

| File | Purpose |
|------|---------|
| `decisions.md` | Architectural and strategic decisions with rationale and review dates |
| `people.md` | Key contributors, collaborators, contacts |
| `preferences.md` | User preferences for workflow, communication, tooling |
| `user.md` | User profile, project vision, working style |

**SESSION START (mandatory):**
1. Read ALL files in `memory/` to restore context
2. Read `scratchpads/SESSION_LOG.md` for recent session history
3. Read `memory/decisions.md` for any decisions due for review

**SESSION END (mandatory):**
1. Update `memory/` files with any new discoveries, decisions, or preferences learned during the session
2. Log new decisions to `memory/decisions.md` AND `decisions.csv` (see Decision Logging below)
3. Update `scratchpads/SESSION_LOG.md` with session summary

### Decision Logging (decisions.csv)

Machine-readable decision log at repo root. Format:
```
date,decision,reasoning,expected_outcome,review_date,status
```

- Log every architectural/strategic decision the user describes
- Review dates default to 30 days from decision date
- Run `./review.sh` to surface decisions due for review
- Daily cron job auto-flags overdue decisions with `REVIEW_DUE`

### Long-Term Memory (scratchpads/)

The `scratchpads/` directory is session-specific logs and plans:

| File | Purpose |
|------|---------|
| `SESSION_LOG.md` | **Read first** — session history, key discoveries, commits |
| `ARCHITECTURE_AUDIT_*.md` | Data flow diagrams, env object chains, init sequence |
| `PLAN_*.md` | Feature/fix plans before implementation |

**Start every session** by reading `memory/` first, then `scratchpads/SESSION_LOG.md`.

### 4-Phase Workflow

**Phase 1 — Plan:**
- Read `scratchpads/SESSION_LOG.md` for context
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
- Update `scratchpads/SESSION_LOG.md` with session summary
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

## UI DESIGN CONSTRAINTS (Uncodixfy)

When generating SwiftUI views, follow clean design principles. Avoid AI-default patterns.

**Reference aesthetic:** Linear, Raycast, Stripe, GitHub — functional, minimal, precise.

**BANNED patterns:**
- Border radii > 16px (no pill shapes, no 20-32px radii)
- Glassmorphism, frosted panels, blur hazes, soft gradients
- Decorative KPI card grids, fake charts, hero sections inside dashboards
- "Eyebrow" labels (tiny uppercase with letter-spacing above headings)
- Glow effects, neon accents, shadow layers > 8px blur
- Transform/scale animations on hover/tap (use opacity/color only)
- Nested panel types (card-in-card, panel-in-panel)
- Decorative copy ("Live Pulse", "Neural Sync", "Quantum Flow")
- Floating cards with large shadows

**REQUIRED patterns:**
- Solid fills or borders on buttons, 8-12px radius max
- Subtle borders (1px, muted color), max 8px shadow blur
- Sidebars: 240-260px fixed, solid background, 1px border
- Forms: labels above inputs, no floating labels, simple focus ring
- Tables: left-aligned text, subtle row hover, clean grid
- Color: use existing palette, dark muted backgrounds, avoid neon
- Transitions: 100-200ms, opacity/color only
- Bio-signal displays: legible numbers first, visualization second
- Flash rate: max 3 Hz (W3C WCAG epilepsy compliance)

**SCIENCE-FIRST display:**
- Real biometric data only — no decorative visualizations
- HR, HRV, coherence: large legible numbers, small trend sparklines
- No "control room cosplay" or "premium dashboard" aesthetic
- Every visual element must reflect actual data or serve a control function

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
