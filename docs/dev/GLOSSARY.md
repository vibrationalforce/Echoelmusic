# Glossary — one word per thing (interface audit 2026-09-30, rule 1)

**Rule 1 of the interface audit (COGA objective 3): one word per thing, app-wide.** A
beginner who reads "song" in the head, "project" in the Library and "session" in a hint has
to guess whether those are three things or one. They are one. This file is the ONE
definition of the words the app wears; the founder's table in the audit doc (Tiefenprüfung
und Neustruktur, „Ein Wort pro Sache") is its source, and the guard
`Tests/CISmoke/TheChromeSpeaksOneWordPerThingTests.swift` READS THIS FILE — it does not
carry a second copy of the list (#416). Change the table here and the guard follows.

The app's visible strings are English today (`Resources/Localizable.xcstrings` holds 24
keys in `en` + `de`; the German column below is the word the string catalog will carry
when the chrome is localised — the audit's answer was "Ja, String-Katalog; Chrome zuerst
(~40 Wörter), Panels danach"). Code identifiers are NOT in scope: `TimelineLane`,
`ClipStore`, `SessionContext`, `Song…` types keep their names; only what a person reads
changes.

<!-- ONE-WORD TABLE — read by TheChromeSpeaksOneWordPerThingTests. Keep the shape:
     | word | Wort | struck | meaning |  — the third column is a comma-separated list of the
     words that must NEVER appear in a visible string for this thing; "—" means none. -->

| word | Wort | struck (never in visible text) | meaning |
|---|---|---|---|
| piece | Stück | project, session, song | the saved work — what Library opens, what Save writes, what the head names |
| track | Spur | lane | one row of the piece |
| part | Teil | clip, region, take | one block on a track |
| scene | Szene | section | one row of the Perform grid |
| default | Standard | reset, initial, factory | the value a fresh install has — every value field that knows its default offers it as "Default" (keypad key + VoiceOver action, rule 6) |
| loop | Schleife | — | the repeat range (a length) — never the tempo mode (that is "Locked", below) |
| tempo mode | Tempo-Modus | flow | the ONE tempo truth, the BPM lock, in the lock's own words: **"Follows pulse"** / **"Locked"** (the head-strip picker; `BodyTempoField` says "Tempo, following" / "Tempo locked"). ⛔ "Flow" / "Loop" stood here until 2026-09-30: "Flow" told a beginner nothing, and "Loop" is the word for the repeat range. `ComposerMode`'s cases `flowFree` / `studioLocked` are persisted rawValues and keep their names. "loop" is deliberately NOT struck for this row — it is the word above |

## What the words are NOT

- **"pulse reading"** is the camera / strap measurement (the strip's own word). It is not a
  "session": the head's Stop ends the piece, the instrument and the pulse reading, and its
  hint says exactly those three.
- **"the instrument"** is the generative voice you play by touch and body. Its held music is
  "the instrument's held music", never "your session".
- **"recording"** is a take being written — but the block it produces is a **part**.

## Scope of the guard — chrome first, panels later

The guard scans the visible string literals (comment-stripped, `\( … )` interpolations
removed, log / breadcrumb / `source:` provenance lines excluded) of the CHROME files:

`ProjectHeader` · `ProjectTransport` · `HeaderMonitors` · `WorkspaceView` · `StageShell` ·
`GuideOverlay` · `WorkstationSummary` · `SongHistoryRow` · `ComposeGuide`

and requires ZERO struck words there. Measured before the first slice (2026-09-30):
24 visible literals in five of those files carried a struck word — "song" ×16, "session" ×7,
"lane" ×1 (`scripts`-free measurement: `scratchpad/measure_glossar_chrome2.py`). The
panels (`EchoelStudioView`, the plates, the Workstation views, the Library) carry roughly
170 more (`measure_glossar.py`, literal count — log strings included, so an upper bound).
They are the next ratchet: add a file to the guard's list in the same commit that cleans it.

## Words with a second meaning — why the scan is scoped, not app-wide

`take` is also a verb ("how many breaths you take per minute", `BioMetricInfo`), `session`
is also `AVAudioSession` in log lines, `section` is also a SwiftUI `Section`. A word-boundary
scan over ALL of `Sources/` would flag those; the chrome list keeps the guard honest, and a
file is added only after its own hits are read one by one, never by a bulk rename.
