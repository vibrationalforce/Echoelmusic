# PLAN — Release passage · voice FX (autotune · harmonizer · granular) · tone→colour · workstation base

Founder 2026-10-03, verbatim: *„Mache die Passage und entscheide, wie wir das mit unserem Audio
Input Autotune Harmonizer/Granulat Synthese Plugin machen. Farbton Übersetzung inbegriffen. Du
entscheidest über Grundarchitektur der Workstation."*

This file records four decisions taken under that delegation, and the slices that follow.
Product law: `docs/dev/FOUNDER_PRODUCT_LAW.md` (a historical deletion revokes an
IMPLEMENTATION, not the capability). Build order: `docs/dev/ECHOELMUSIC_MASTER_PLAN.md`.

---

## D1 — The Release passage is a BREATHING PATTERN, not a mode

**Built (R1, 2ecd00a6a):** `BreathPattern.release` paces 4 s in and 8 s out (5.0/min, no holds),
and carries `exhaleCue` = "Breathe out slowly — pff, shh or hum". `BreathCoachStrip` (bioPanel,
reached from the pulse pill) has a second button, "Release", next to Start.

- **Why 8 s and not longer:** 5.0/min sits inside `RespirationEstimator.reportableRange`
  ([3.77, 31.8]), so Echoel can read back the pace it guides. A 10 s exhale (4.3/min) would still
  be inside the band; 12 s (3.75/min) would not. 4/8 keeps the 1:2 ratio and a margin.
- **No microphone:** the voice ("pff", "shh", a hum) is the user's own. Echoel paces the breath and
  shows the body's answer (HRV, coherence). It does not listen.
- **Copy law:** neutral words only — no healing, no release-of-anything, nothing religious. "Jesus
  Mode" / "Ultrajesusmode" stays the founder's private name. App text is "Release".
- **Guards:** `ThePacedRateMustBeReadableTests` pins 5.0/min on the readable side.
  `TheBreathingPracticeIsInTheMainViewTests.testEveryPatternTheStripCanStartIsHoldFree` resolves
  every `pacer.pattern = .X` in the strip to a curated pattern and requires it to have no holds,
  because the strip has no hold-acknowledgement step.

**Next slices of the passage:**
- **R2 — a held drone that swells with the exhale.** While Release runs, the armed body voice
  (`BioReactiveSynthVoice.playNote(frequency:)`) holds one tone. Its level follows
  `pacer.guidance`, inverted so the sound opens as the lungs empty. The drone pitch is a
  sound-preset value. **117 Hz is offered as a frequency, never as a claim.**
  - Its colour comes out of D3 by itself: 117 Hz × 2⁴² ≈ 514.6 THz ≈ **583 nm, yellow-orange**.
  - "0.5 Hz on two outputs" becomes an optional slow L/R alternation of the drone (pan LFO at
    ≤ 0.5 Hz). That is a sound parameter, not entrainment.
  - Visual flash stays ≤ 3 Hz; `EntrainmentEngine` keeps the 4–70 Hz hazard band.
  - Constraint: the strip is a leaf view. Guidance is read there and pushed to the voice through
    the existing main-actor tick, never from the root body.
- **R3 — the passage as a scene.** Release as a saved look plus sound plus pacing, so a performer
  can call it up in an installation. This waits for WA4 scenes to carry bio settings.

---

## D2 — Voice FX: pure kernels → one device → every host. Files first, microphone last

**Decision.** Autotune, harmonizer and granular come back as **devices on an audio track**. They
are not a mode of the instrument and not a separate screen. Each has three layers, and only the
outermost one knows where the audio comes from:

```
DSP kernel (DSP/, Foundation + Accelerate only — compiles inside the AUv3 in isolation)
  └─ native device adapter (canonical parameter identity, WA3.2 / EchoelDeviceState)
       ├─ track insert in the workstation (AudioEngine owns the graph)
       └─ AUv3 effect (aumf) in AUM / Logic / GarageBand — later VST3/CLAP via the same kernel
```

**Kernels — reuse first:**

| Capability | Built on (exists) | New, pure, in `DSP/` |
|---|---|---|
| Pitch detection | `DSP/PitchTracker` (YIN, live via `Sequencer/AudioKeyAnalysis`) | — |
| Pitch correction ("autotune") | `WSOLAStretcher` (time stretch) | `PitchShifter` = WSOLA stretch + resample, grain-synchronous; `PitchSnapper` = Hz → nearest allowed pitch with retune speed and humanize |
| Harmonizer | the shifter above | `Harmonizer` = N shifter voices at **named** scale intervals (third, fifth, octave — never raw semitone counts; the 2026-07-29 founder ask) |
| Granular | — | `GrainCloud` = pre-allocated grain pool, Hann window, position · size · density · spray · pitch, ring buffer |

- **The tone system stays outside `DSP/`.** `TuningSystem` lives in `Sequencer/`, so the snapper
  takes a plain table of allowed pitches in cents. The adapter builds that table from the
  project's key, scale and A4 (`SessionContext` is the one owner).
- **Detection reports; it never writes the key** (the `TuningDetector` law).
- **Realtime:** every kernel allocates at `prepare(maxFrames:sampleRate:)` and never in `process`.
  No locks, no ObjC, no GCD, no `Task`. Parameters come in as atomic-width mirrors. The
  audio-thread reviewer checks every kernel slice before merge.

**Order — files first, because they need no founder gate and no risky graph change:**
1. **V1 `GrainCloud` kernel** plus a unit guard (silence in → silence out, bounded output, no
   allocation in `process`, NaN-safe controls).
2. **V2 granular as an insert on an imported audio clip.** The source is a file
   (`MediaLibrary` / `TimelineAudioSink`), not a microphone, so the capability is back with zero
   permission change.
3. **V3 `PitchSnapper`** (pure maths, fully testable without audio). Then **V4 `PitchShifter`**.
4. **V5 `Harmonizer`** with named intervals and key-aware voices.
5. **V6 AUv3 effect target (`aumf`).** This needs a new component or target in `project.yml` →
   **founder-gated** (FOUNDER_INBOX E20). Until then the kernels ship inside the app only.
6. **V7 live audio input.** It comes back as ONE new input owner, not the old graph (E10):
   - **Founder-gated:** `NSMicrophoneUsageDescription` returns to `Resources/iOS/Info.plist` in
     the SAME commit that adds a `RecordRouteOwner` case (`EveryPermissionPromptHasACapabilityTests`
     enforces this).
   - The input node is attached only while a track is armed, and detached on disarm.
   - Monitoring is off by default. Monitoring through the speaker is blocked; headphones are
     required for it (feedback).
   - Every attach and detach writes a lifecycle-ladder breadcrumb before the call.
   - Read `avaudio-route-resilience` first. The `isInputConnToConverter` crash family is
     **unsolved**: whoever re-adds an input inherits it, and V7 must carry a device test plan.
   - Store and website copy change only when V7 ships (`ContentPipeline/CLAIMS.md` §11).

**Rejected alternatives:**
- A monolithic "voice mode" screen: a new surface, not a device. It breaks E18 (one shell).
- Re-attaching the deleted `MicrophoneManager` / `VoicePitchCorrector`: the graph that held the
  crash family. Product law says port the proven core, never copy a subsystem back.
- A third-party SDK: zero deps, no JUCE.

---

## D3 — Tone→colour ("Farbton-Übersetzung") already exists, and there is exactly ONE

`Core/SpectralColor` is the app's single tone→colour language (founder 2026-07-27, "physikalisch
korrekt hochoktavierten Farbfrequenzen"):
- the tone is transposed up by whole octaves into the visible band;
- then CIE 1931 → linear sRGB, with the purple line closing the circle;
- chords mix in OKLab.

The note grids, the immersive visual, the header monitors and Art-Net/sACN fixtures all read it.
The rival pitch-class hue circle was **retired 2026-07-28** for making the lamp and the grid
disagree.

**Decision:**
- Every new pitch source feeds the same function — the R2 drone, the V3 detected voice pitch,
  harmonizer voices. **No second mapping**, no "voice colour" table.
- The detected-voice colour is display-only and goes through the existing visual and lighting
  path.
- Amplitude or confidence may modulate saturation or lightness of the physical colour (the file
  header allows exactly that). They never change the hue.
- **Claim law:** the octave transposition is an artistic convention (`SpectralColor` says so
  itself). No colour therapy, no colour→organ (REJECT in `inspiration.csv`).

---

## D4 — Workstation base architecture (decided; it is the master plan made concrete)

```
DMMWProject (the ONE canonical Session root, WA2)
├─ Transport — PatternEngine is the one clock (T1–T3 tempo invariant)
├─ Tracks — each = Source → Device chain → Sends → Master
│    Source:  instrument (Echoel generator, poly synth, AUv3 later) · audio clip (MediaLibrary)
│             · MIDI clip · live input (V7, gated)
│    Devices: kernels from DSP/ behind the canonical parameter registry
│             (automatable · modulatable · persisted · host-exposed = four separate facts)
├─ Modulation — ModulationEngine: body (bio snapshot) + automation lanes → any registered parameter
└─ Outputs — subscribers, never surfaces: MusicalFrame + bio snapshot →
             visual (MetalBioView) · light (Art-Net/sACN) · space (ADM-OSC) · OSC/MIDI out
AudioEngine owns the audio graph alone. The UI (StageShell: Arrange · Mixer · Instrument ·
Browse · Project) is a projection of this model and holds no state of its own.
```

**Consequences for everything above:**
- Voice FX are devices (D2). The Release passage is a bio practice that modulates a device (D1/R2).
- Colour is an output subscriber (D3).
- **No new persistence root, no new top-level directory, no new modal on the instrument chain.**
- AUv3 effect hosting (E11) uses the same device slot: a hosted plugin is just another device kind.

---

## Founder-gated (report, do not edit)
- **E10** — live audio input: `NSMicrophoneUsageDescription` in `Resources/iOS/Info.plist`
  (Info.plist is founder-gated) plus store copy.
- **E20** — AUv3 *effect* component (`aumf`) in `project.yml`.

## Verification honesty
R1 is compile-gated only. Whether 4/8 feels right, whether the cue is legible and whether the
button sits well at 375 pt are device checks. Nothing here is a health claim.
