# PLAN — Phase E: the tuning detector gets a producer (2026-09-22)

**Status: PLANNED.** Nothing here is implemented. Written after the Phase C census (#C1) so the
next slice starts from measurement rather than from the phase list's wording.

## The measurement this plan rests on

Re-derive before trusting any line below; each number is a date, not a fact.

```bash
git grep -n "TuningDetector" -- Sources | grep -v ': *//'   # 1 hit: its own declaration
git grep -n "PitchTracker"   -- Sources | grep -v ': *//'   # 1 hit: its own declaration
git grep -n "detectedKey\|isDetected\|userSet\|keySource" -- Sources | grep -v ': *//'   # 0
```

Three facts:

1. **`Core/TuningDetector` and `DSP/PitchTracker` are two orphans that are two halves of ONE
   capability.** YIN produces exactly the input Krumhansl–Kessler key-finding consumes — a list
   of fundamental frequencies in Hz. Both are pure value math, both are unit-tested in
   `Tests/EchoelmusicTests`, neither has a production caller. The missing piece is not an
   algorithm; it is **reading PCM windows out of a file.**
2. **The owner of musical key already exists and must not be duplicated.** `SessionContext`
   holds `keyRoot`, `keyScale` and `a4Hz`, persisted under `echoel.keyRoot` /
   `echoel.keyScale` / `echoel.a4Hz`, and `MusicalFrame` already projects root, scale and
   tempo. A second key value would be the dead abstraction the loop forbids.
3. **There is no detected-vs-user-set distinction anywhere in `Sources/` today.** Whatever this
   slice does becomes the first one, so it sets the precedent.

## The decision: detection REPORTS, the user DECIDES

V1 writes nothing into `SessionContext`. The detected key and Kammerton are shown, and the
existing key control stays the only writer.

**Why, and it is not timidity.** `TuningDetector`'s own header already draws this line —
*"Genre/style/character are NOT guessed from audio here (that would be a stub); the UI lets the
user confirm."* Silently re-keying a session because a file was imported would change what the
generative engine plays, from an action the user took for an unrelated reason. And the repo has
paid for the opposite shape before: #164/#227 — a control that appears to do something. A
displayed estimate that the user acts on is honest; an automatic write is a second author of
the session's key with no way to see who wrote it.

**Consequence registered rather than hidden:** "Apply detected key" is NOT in V1. It is the
obvious next step and it needs `SessionContext` in `WorkstationView`'s environment, which it
does not have today (measured: `@Environment` there is `TimelineStore`, `TimelineRegionPlayer`,
`BeatPlayer`, `PianoRollModel`, `ClipStore`).

## Shape — the `AudioImport` pattern, because it is proven

One impure step, everything else pure, so the blocking bundle can drive the whole thing without
a device or an audio file.

```
Sources/Echoelmusic/Sequencer/AudioKeyAnalysis.swift   (NEW)

  PURE (Foundation only, no AVFoundation):
    windowStarts(frameCount:windowFrames:maxWindows:) -> [Int64]
        evenly spaced, never running past the end, bounded by maxWindows
    summarise(_ DetectedTuning?) -> String?
        the one place the user-facing phrasing is written (#416)

  IMPURE adapter, #if canImport(AVFoundation):
    nonisolated static func analyse(url:) -> DetectedTuning?
        AVAudioFile → seek each window start → read windowFrames → mono Float
        → PitchTracker.detect per window → TuningDetector.analyze
```

**REALTIME LAW.** `analyse` is never called from a render block, an audio tap or the main
actor. It runs in a detached task after the import transaction has already landed. The cost is
bounded twice over — `maxWindows` caps both the frames read and the YIN work, and YIN is
O(n·τ) per window, so an unbounded read is the failure mode to design against, not a
theoretical one.

**WHY NOT INSIDE `AudioImport.perform`.** That function is `@MainActor` and synchronous. Adding
seconds of YIN to it would freeze the door at the exact moment the user is watching it — the
10.76.48 lesson in a new place: the fix there was to stop doing per-item work on the main actor,
and this would re-introduce it in bulk.

**WHY `Sequencer/` AND NOT `DSP/`.** `DSP/` imports Foundation and Accelerate and nothing else,
and the AUv3 extension compiles it in isolation — a DSP file that reaches for AVFoundation is a
build failure in the extension (`.claude/rules/swift-audio.md`). `PitchTracker` stays where it
is; the file-reading adapter sits next to `AudioImport`, which already imports AVFoundation.

## The door

`WorkstationView`'s existing `importNote`. No new surface, no new modal — the presentation
chain is at 13 of a deliberate budget of 14 and this slice must not spend the last slot.

After a successful `AudioImport.perform`, a detached task analyses the managed copy and, back on
the main actor, appends the estimate to the note: *"Imported Kora.wav to Audio 1 · sounds like
A minor, A4 ≈ 441 Hz"*. A nil return (thin evidence) appends NOTHING — an honest silence, not a
guess, which is what `analyze`'s nil return is for.

## Guards

`Tests/CISmoke/TheDetectedTuningHasAProducerTests.swift`, behavioural where it can be:

- `windowStarts` is bounded, ordered, and never seeks past `frameCount` (drive it with values,
  no file needed).
- An empty/short fundamentals list yields nil — the estimator refuses rather than inventing.
- `summarise(nil)` is nil, so a thin result cannot reach the note.
- SOURCE-TEXT SCAN, labelled as such: `analyse(` is not called from `AudioImport.perform` and
  not from any `@MainActor` body in `WorkstationView` without a detached hop.
- COUNTERWEIGHT (#343): `TuningDetector` and `PitchTracker` each still have exactly one
  declaration and no SECOND estimator was minted.

Each claim must fail for its named reason (#367) and must not forbid correct work (#364) — in
particular nothing here may forbid a later "Apply detected key".

## What this slice does NOT do

- No write to `SessionContext`. No new persistence root. No second clock, no second timeline
  truth, no second parameter registry.
- No tempo/BPM estimate from audio. Audio Import V1 decided `nativeBPM = 0`, no estimate, and
  this plan does not quietly reverse a founder decision from the adjacent slice.
- No microphone. Phases H/I/J are FOUNDER HOLD (see `memory/decisions.md`, 2026-09-22) and this
  plan is precisely the demonstration that the detector does not need one.

## Device debt, stated in advance

Everything below is `[NEEDS-FOUNDER-VERIFY]` and cannot be closed by CI: whether the estimate is
RIGHT on real material, whether the analysis finishes fast enough to feel instant, and whether
the wording reads as a suggestion rather than a claim.
