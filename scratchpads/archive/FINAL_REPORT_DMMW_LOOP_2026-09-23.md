# FINAL REPORT — autonomous DMMW loop, 2026-09-23

Written when the loop reached its end condition: **no further dependency-ready slice exists
that is not founder-held.** That is measured (five censuses, closed below), not assumed.

---

## 1. VERIFICATION LEGEND — what each claim in this report is worth

| Grade | Meaning here |
|---|---|
| **COMPILE VERIFIED** | `Xcode Compile Check` conclusion = success. Builds `Sources/` ALONE — says nothing about a test file. |
| **BUILD-FOR-TESTING VERIFIED** | CI/CD job STEP `Build for Testing` = success. The blocking bundle compiles, guards included. (The run's own conclusion is `failure` on every push, #396 — the step is the signal.) |
| **TEST-EXECUTED** | ⚠️ **NOT CLAIMED ANYWHERE IN THIS REPORT.** No Swift toolchain in a web session. Guards were graded by §0 transcription in Python against both trees, or by mutation where red-on-parent is degenerate. |
| **DEVICE-VERIFIED** | ⚠️ **NOTHING HERE.** Every device item is listed in §9. |
| **FOUNDER HOLD** | Needs a decision that is not a session's to make. |
| **FUTURE HAZARD** | Latent; named so it is not re-derived. |

---

## 2. WHAT SHIPPED — five commits, all gate-green

| # | sha | What | Grade |
|---|---|---|---|
| #F3 | `74668c389` | A detected key carries its own uncertainty | COMPILE + BUILD-FOR-TESTING, merged to `main` |
| #F4 | `2d3420cab` | The concert pitch carries its own evidence | COMPILE + BUILD-FOR-TESTING, merged to `main` |
| — | `cbf0ce60d` | The key floors' error rates, measured and published | COMPILE + BUILD-FOR-TESTING, merged to `main` |
| #F5 | `8116b3663` | `SignalTransport.midi2` was `.roadmap` while it shipped | COMPILE + BUILD-FOR-TESTING |
| — | `d53131fd4`, `7d70e005b`, ledger commits | Censuses, video roadmap record, ledgers | docs only |

### 2.1 #F3 — a detected fact must carry its own uncertainty
`DetectedTuning.confidence` had ZERO readers in `Sources/`, and `analyze` returns non-nil on
eight valid pitches with **no floor on the correlation**. `correlation` returns 0 for a flat
histogram, `bestCorr` starts at −2.0, and the first candidate tried is root 0 major — so
atonal material was reported as *"Sounds like C major"*, a key name produced by iteration
order. Added `runnerUpConfidence` → `keyMargin`; `summarise` refuses below either floor.

**The design decision that mattered:** gating on `confidence` alone would have MOVED the
defect. Twelve copies of one pitch score **0.684** — above any sane floor — with margin
**0.000**, because one tall bar fits a major and a minor profile on the same tonic equally.

### 2.2 #F4 — the concert pitch too
`analyze` summed unit vectors of each pitch's cents-deviation and took `atan2`. **`atan2`
discards the magnitude, and the magnitude over the count IS the evidence.** Two lines.
A deterministic fixture with no tuning reference produced **a4 = 440.4 Hz → snapped to 440**:
the plausible wrong answer, which is the dangerous one. (A random draw landed on 432.55 →
the 432 preset — the esoteric claim `CLAUDE.md` bans, invented by the analyser.)

### 2.3 The correction to #F3 — published, not tuned
My #F3 commit message said "fixed". Measuring against a stated null (N notes drawn uniformly
from twelve pitch classes, 40 000 draws/cell): **~50 % of atonal material is still named a
key** (53.6 % at n=8 → 48.3 % at n=64); 29–42 % of profile-drawn tonal material is refused.
#F3 removed the DEGENERATE case, not the weakness. Numbers now sit at the constants **with
the null model's limits**, and **no floor was moved** — raising them trades one error for the
other, and only a listener decides.

### 2.4 #F5 — the protocol register disagreed with the machine
`.midi2` returned `.roadmap` ("typed, not wired") while MIDI 2.0 ships on five legs; the case
comment claimed "(+ MIDI-CI capability inquiry)" with one occurrence in all of `Sources/` —
the claim. A no-op today (no port carries `.midi2`) fixed because `defaultInventory()` filters
roadmap transports out, so the first such port would vanish silently.

---

## 3. CENSUS 1 — MUSICAL CONTEXT. **No second truth found.**

| Fact | Owner | Writers |
|---|---|---|
| Tempo | `Transport` / `PatternEngine` | five enumerated T1 sources |
| Musical position | `Transport.position` (`bar`, `step`, `absoluteStep`) | `tick`; `seek` has **zero** production callers |
| Selected key/scale | `studio.rootIndex` / `studio.scale` | Key picker, project open, OSC `/ctrl/*` |
| Composed key | `SessionContext` | `adopt(key:)` only — compose + project open |
| Concert pitch | `SessionContext.a4Hz` | A4 field, project open |
| Native clip BPM | `Clip.nativeBPM` | `AudioClipFactory` (geometric guess); **import deliberately passes none** |

**No slice.** Nothing to unify; no second clock, no second timeline, no fifth persistence root.

---

## 4. CENSUS 2 — STRETCH / PITCH. **Architecture is real; the producer is founder-held.**

Three of four quality classes are wired: `.clean` + `.tape` (Apple `AVAudioUnitTimePitch`,
pitch-compensated on the same node) and `.beats` (`WSOLAStretcher`, live at
`TimelineAudioSink`, reached from `AudioLanePlayer` with `capabilities: .timelineCapabilities`).
`.studio` (Signalsmith, C++) is `isImplemented == false` — correct, the dependency is absent.
`StretchPlan.resolve(mode:warpEnabled:nativeBPM:projectBPM:capabilities:)` **is** the
"select a stretch mode without a second playback engine" facade the brief asks for.

**What is missing is a PRODUCER of warp-enabled data, and it is a decision, not a gap:**
Audio Import V1 decision 7 passes no `nativeBPM`, so `resolve` returns rate 1.0 for every
imported clip. **FOUNDER HOLD.** Per the brief — *"Do NOT implement several weak algorithms
merely for feature count"* — nothing was added.

---

## 5. CENSUS 3 — MIDI / MPE. Full table in `scratchpads/CENSUS_MIDI_MPE_2026-09-23.md`.

**IMPLEMENTED + doored:** MIDI 1.0 note/CC/pressure/bend in and out · **MIDI 2.0 UMP in and
out** (parse case 0x4, `._2_0` input port, second virtual source, `UMPEncoder` mirror, a
switch, default off) · **MPE OUT** (zone RPN on port open and re-arm; per-note Glide/Slide/
Press on the member channel, emitted BEFORE the note-on) · MIDI clock out 24 PPQN + Start/Stop
· MIDI file export (doored) and import (doorless) · RTP-MIDI · Bluetooth MIDI pairing.

**PARTIAL:** MPE IN — all three dimensions SOUND, but there are no ZONES (RPN 6,6 has no
inbound consumer; the single `controllerEvents` consumer is monophonic). Clock out drifts
against the 4 PPQ step grid with nothing to re-sync.

**MISSING:** Song Position Pointer · Continue · MTC · Program Change / Bank Select on the live
port · poly aftertouch · note-off velocity · NRPN · MIDI Thru · JR timestamps · a virtual
**destination** (Echoel publishes a source, so it can be heard but not addressed by name).

**⭐ THE FINDING IS THE PATTERN, NOT THE LIST: almost every missing row is blocked on a missing
PRODUCER, not a missing encoder** — the #527 shape in a fourth domain. A MIDI feature list is
the wrong planning instrument; the question is always *"what would SEND this?"*

**My first recommendation here was WRONG and is retracted in the census file.** I proposed
SPP + Continue; `UMPEncoder.RealTime`'s own doc already explains why it has three cases:
`Transport.play()` resets position to zero unconditionally, `Transport.seek` has zero
production callers, so SPP would transmit a constant 0 and Continue would have no producer.

---

## 6. CENSUS 4 — SCALE / KEY / TUNING. **The founder's law already holds.**

authored = `studio.*` · detected = `DetectedTuning`, which **never writes** either store
(guarded) · imported = project open, writing both deliberately · **external = OSC `/ctrl/key`,
indistinguishable from a user edit.**

⭐ **RECOMMENDATION: do NOT add a provenance enum.** With no surface to display it, it is the
#496 shape. The separation already carries the meaning and a guard enforces it.
The OSC case is judged acceptable (opt-in, default off, sender-allowlisted — the user acting
at a distance); recorded so it is not re-derived. **FOUNDER DECISION if you disagree.**

---

## 7. CENSUS 5 — AUDIO ANALYSIS. **Both halves of the law hold, both guarded.**

*"No analysis in realtime callbacks"* — pinned. ⚠️ FUTURE HAZARD: the isolation is a fact
about the TYPE (a plain `enum` runs wherever its caller runs), so nothing in the signature
stops someone calling it from a view `body`. The guard is the only thing holding it.

*"Analysis proposes, the owner decides"* — pinned; `SessionContext` stays sole writer.

Remaining unwired: `AudioFeatureExtractor`/`AudioFeatureChannel`. `MetalBioView` reads the
channel per frame and gets `.silent` — that read is a MOUNTING POINT, not dead code.

---

## 8. VIDEO — recorded, not started (`scratchpads/ROADMAP_VIDEO_AWB_AI_2026-09-23.md`)

AWB pipeline and provider-neutral AI video recorded verbatim in substance.
⚠️ **They presuppose a pipeline that does not exist:** #1304 removed video capture entirely
eleven days ago; the only `AVAssetWriter` in `Sources/` is the audio master export.
⛔ **`Sources/Echoelmusic/Video/` holds FOUR files and all four are the rPPG PULSE path.**
Anyone acting on "video roadmap" by directory name deletes the flagship bio source.

---

## 9. DEVICE VERIFICATION OWED — nothing in this report is device-verified

New this loop, all in `WorkstationView`'s header and collected by `founder-verify.py`:
(14)–(18) the Add Audio Track chain · **(19)–(22) the key/tuning sentence** — does a tonal
import get the right key; does a drum loop get NO key; does off-pitch material say "concert
pitch unclear"; **and if real music keeps coming back "unclear", the floors are too HIGH —
say which way it errs.**
Carried: #34, #40, #58, #87, #91, #94, #95, #113, #115, #118, #152.
Print the list: `python3 scripts/founder-verify.py`.

---

## 10. FOUNDER HOLDS — open

1. **CONTENT UNKNOWN / UNRESOLVED.** The second hold in the truncated message never arrived.
   **Not inferred, not used as permission for anything.**
2. **Warp / native BPM detection** (census 4 above) — decision 7 stands.
3. **Audio input** (#1302) — blocks `AudioFeatureExtractor` and any microphone-shaped work.
4. **Video capture** (#1304) — blocks the entire §8 roadmap.
5. **The three analysis floors** — judgements; an ear decides, not a test.

---

## 11. EXACTLY WHAT TO IMPLEMENT NEXT

**Nothing, without a founder decision.** That is the honest answer and the loop's end
condition. Ranked, if a decision arrives:

1. **If warp is approved** — a `nativeBPM` producer on import. The engine, the facade and
   three quality classes are already built; this is the missing centimetre, and it is the
   highest-value single decision on the board.
2. **If the key floors are wrong on device** — move them with the founder's direction, and
   re-run the simulation at the new values before shipping.
3. **If the analysis should improve rather than gate** — that is research, not a slice, and
   the brief's *"do NOT implement several weak algorithms"* applies.
4. **Virtual MIDI destination** — the one MIDI row that is encoder-side and producer-free.
   Council-sized: a third CoreMIDI object with its own lifecycle.

---

## 12. METHOD FAILURES THIS LOOP — the most transferable output

**Four invented or colliding needles, all resolving in the CONFIRMING direction.**
`mpe` ⊂ `tempo` · `RPN` ⊂ `SHARPNESS` · `SPP` ⊂ `DDSPParameterCatalog` · and twice I searched
for a symbol I had invented (`setKey`, `SourceText.codeOnly(atSourcePath:)`), where the empty
result read as evidence FOR my finding.

Two findings of mine collapsed under tracing: "nothing sends the MPE zone RPN" (it is sent,
one `sed` away) and "`SessionContext.keyRoot` has no production writer" (`adopt(key:)` writes
it from two sites — I was one step from "repairing" a filename that is correct).

⭐ **LAWS, now in `HARNESS_LEDGER.md`:**
1. A symbol-level `grep` cannot answer a behaviour-level question. "Who writes X" includes
   every method that assigns X, and those names are not guessable.
2. **A search returning nothing is first a suspicion against the NEEDLE.** Cheap
   discriminator: find one known positive and check the needle catches it.
3. If the hit list names files unrelated to the question, the needle is broken — read the
   hits, not the count.
4. Before recommending a slice from a census, **read the doc comment on the type you would
   edit.** Twice the answer was already written there.
5. `atan2` throws away the magnitude; `max` throws away the runner-up. **A producer that
   returns only a decision has already destroyed the evidence for it.**
6. A threshold without a measured error rate is an opinion with a number in front of it —
   and when the null is writable, the measurement is cheap.
7. A correction sweep that checks the prose and not the model leaves the model as the last
   false witness.
