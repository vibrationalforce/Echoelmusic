# Technical-debt inventory — 2026-10-02 (measured, parked)

Started on a misreading of "Schuld loswerden" (founder meant healing, not tech debt). Kept
because the numbers are real; nothing here is a decision. Re-measure before acting.

- Sources: 443 files, 164,334 lines, **50 % comment lines** (81,792); `⛔` lines 1,764; `#NNN` refs in comments 5,391.
- `EchoelStudioView.swift`: 13,360 lines, 63.7 % comments (8,507), 4,447 code. 849 comment blocks, 114 ≥ 20 lines.
- Tests/CISmoke: 789 files, 200,523 lines (> Sources). 248 read EchoelStudioView; 13 read it raw, 37 with a private `//` filter — comment removal is NOT free (e.g. TheGenreSuggestsTheToneSystemTests pins a doc comment).
- CLAUDE.md 149,769 B — 231 B under its 150,000 B ceiling.
- Presentation chain: 11 on body, 12 file-wide. **Setterless: `showMeditation` → `MeditationView` (342 lines) unreachable.** Stale counts in comments L747–748 ("13 … 14") and L813 ("14 … 16").
- Dead members in EchoelStudioView: `reduceMotion` env (never read), `currentToneHz`, `entrainmentVisualPulseHz`, `goImmersiveForTake` (→ `preTakeVisual*` state + `restorePreTakeVisual` body unreachable); allowlisted/parked: `moodPadsSection`, `liveNarrationBanner` (+`showLiveNarration`), `importMIDI(_:)`.
- Extractable panels (own observation scope, no hot reads today): metronomeRow, tapTempoRow (0 calls), bioPanel (86 % comment), openSheet, masterPanel, soundPanel (heaviest coupling).
- doctor: 2 CRITICAL in founder-gated CI (`|| true`/no pipefail in ci.yml perf/memory/archive steps; `-only-testing:ComprehensiveTestSuite` names no suite). Unreachable views: BroadcastView, ImmersiveStageView, ProUnlockView, SessionView (+ transitive ADMStreamStatusLine, BreathGuideView, PulseMeasurementView).
- Private strippers in CISmoke: 76; `slice(` helpers: 14.
