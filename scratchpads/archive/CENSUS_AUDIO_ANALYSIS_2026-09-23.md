# Census #5 — AUDIO ANALYSIS FOUNDATION (2026-09-23)

Founder law under test, verbatim: *"No analysis in realtime callbacks. No automatic mutation
of the musical session context merely because analysis returned a candidate. Analysis
proposes facts. The canonical creative owner decides whether they become authored state."*

## What analysis exists

| Component | State | Realtime? | Writes session state? |
|---|---|---|---|
| `Sequencer/AudioKeyAnalysis` | LIVE, one producer | No — plain `enum`, no global actor, called off the main actor; opens a file, so it could never be on the audio thread | **No** — pinned |
| `DSP/PitchTracker` (YIN) | LIVE via the above | No | No |
| `Core/TuningDetector` | LIVE, pure value math | No | No |
| `Core/AudioFeatureExtractor` + `AudioFeatureChannel` | built, NO producer | — | No |
| `Sequencer/WaveformReducer` | test-only core | — | No |

## Verdict: both halves of the law are satisfied, and BOTH are pinned rather than asserted

- **"No analysis in realtime callbacks"** — `TheDetectedTuningHasAProducerTests`
  `testTheExpensiveAnalysisIsWrittenOffTheMainActor`. ⚠️ The isolation is a fact about the
  TYPE (a plain `enum` runs wherever its caller runs), so the discipline genuinely lives at
  the CALL SITE — nothing in the signature can stop someone calling it from `body`. The
  guard is the only thing holding it.
- **"Analysis proposes, the owner decides"** — `testTheAnalysisNeverWritesTheSessionKey`.
  `SessionContext` stays the sole writer of `echoel.keyRoot`/`keyScale`/`a4Hz`, and the
  detector never touches it. Census #4 has the full ownership table.

## What this session added to the foundation

**#F3 and #F4 — a proposed fact now carries its own evidence, on BOTH axes.**
`DetectedTuning` reports `confidence` + `runnerUpConfidence` → `keyMargin` (is the key
alone?) and `a4Confidence` (is there a tuning reference at all?), and
`AudioKeyAnalysis.summarise` gates the key clause and the concert-pitch clause
independently. Before this, the same sentence was printed at correlation 0.9 and 0.0, and a
concert pitch was asserted for material with no tuning reference.

⭐ **THE GENERAL LAW, and it is the reusable part: `atan2` throws away the magnitude,
`max` throws away the runner-up. A producer that returns only a decision has already
discarded the evidence for it, and no consumer can recover it.** Both fixes were two lines
in the producer and impossible anywhere else. **Whenever a derived value crosses a boundary,
ask what the producer knew and dropped.**

## The remaining gap, named honestly

`AudioFeatureExtractor`/`AudioFeatureChannel` are built with no producer, and
`MetalBioView` reads the channel **per frame**, receiving `.silent` every time. That read is
the mounting point for a future audio-feature source — it is NOT dead code to tidy, and
"tidying" it would move the expensive half into the churn-sensitive body. Already recorded
in `CLAUDE.md`'s orphan register (#1325); repeated here only because a census of analysis
that omitted it would read as "analysis is complete".

**No slice recommended.** The law holds, both halves are guarded, and the one unwired core
is blocked on an audio input that is a FOUNDER HOLD (#1302).
