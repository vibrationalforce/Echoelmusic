# Census #4 — SCALE / KEY / TUNING semantics (2026-09-23, read-only)

Founder law under test: *"Detected facts MUST remain distinguishable from authored facts.
Unknown/ambiguous audio key MUST be representable honestly. Do not force uncertain analysis
into a confident label."* Source enum named in the brief: **authored / detected / imported /
external**.

## The owners, measured

| Fact | Owner | Writers (production) |
|---|---|---|
| **Selected key** (what you dial in) | `StudioDefaultKeys.rootIndex` + `.scale` (`studio.rootIndex` / `studio.scale`), `@AppStorage` in `EchoelStudioView`, `WorkspaceView`, `FloatingVisualWindow` | the Key picker; project open; OSC `/ctrl/key` + `/ctrl/scale` |
| **Composed key** (what the take came out in) | `SessionContext.keyRoot` / `.keyScale` (`echoel.keyRoot` / `echoel.keyScale`) | **only** `SessionContext.adopt(key:)`, from exactly two sites — compose (`EchoelStudioView:10809`) and project open (`:11663`) |
| **Concert pitch** | `SessionContext.a4Hz` | project open + the A4 field; fanned to the voices by `applyConcertPitch` |
| **Detected key/tuning** | `DetectedTuning` (value type, NOT Codable, NOT persisted) | `TuningDetector.analyze`, one production producer (`AudioKeyAnalysis`) |

## Verdict: the founder's law is ALREADY satisfied — by separation, not by a field

- **authored** = `studio.*`. **detected** = `DetectedTuning`, which **never writes** either
  store; pinned by `TheDetectedTuningHasAProducerTests.testTheAnalysisNeverWritesTheSessionKey`.
- **imported** = project open, which writes BOTH stores deliberately (`rootIndex = p.keyRoot`
  for what you continue from, `adopt(key: p.key)` for what the take was).
- **detected uncertainty** = shipped today as #F3: `confidence` + `runnerUpConfidence` →
  `keyMargin`, and `summarise` refuses to name a key below either floor.

⭐ **RECOMMENDATION: do NOT add a provenance enum.** With no surface displaying provenance it
would be a field with no consumer — the #496 shape this repo keeps retracting. The separation
already carries the meaning, and it is enforced by a guard rather than by a convention.

## The ONE genuine gap (founder decision, not a defect to fix unasked)

`OSCReceiver`'s `/echoelmusic/ctrl/key` and `/ctrl/scale` write the **authored** store, and
the result is **indistinguishable from the user's own edit**. That is the `external` case of
the founder's enum, and it is unrepresentable today.
**I judge it NOT a defect:** the input is opt-in, default OFF, sender-allowlisted, and a
remote control is the user acting at a distance — the same reason the BPM path is allowed
under `.remoteControl` only when the lock is on. Recorded so the next session does not
re-derive it. If the founder wants remote edits marked, the honest place is the transport
log, which already names `.remoteControl` for tempo.

---

## ⛔ TWO FINDINGS OF MINE COLLAPSED UNDER TRACING TODAY, AND THE PATTERN IS THE POINT

1. **"Nothing sends the MPE zone RPN."** FALSE — `MIDIOutput.sendMPEConfiguration()` sends
   CC101/CC100/CC6. My needle matched `SHA-RPN-ESS` and missed the bytes.
2. **"`SessionContext.keyRoot` has no production writer, so the export filename spells the
   wrong key."** FALSE — it is written by `adopt(key:)` from two sites. I grepped for
   assignments to the FIELD and the write lives in a METHOD one frame away. I had also
   invented the method name (`setKey`), so my first search for it returned nothing and
   *confirmed* the wrong conclusion — the #1376 trap, self-inflicted.

⭐ **LAW (three instances today, one root): a symbol-level grep cannot answer a
behaviour-level question.** "Who writes X" is not `grep 'X ='` — it is `grep 'X ='` PLUS
every method that assigns X, and the names of those methods are not guessable. Worse, both
failures resolved in the CONFIRMING direction: the absent match read as evidence FOR the
finding. **A search that returns nothing must be treated as "my needle may be wrong" before
it is treated as "the thing is absent"** — and the cheap discriminator is to find ONE known
positive and check the needle catches it.
