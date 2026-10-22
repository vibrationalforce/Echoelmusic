# Runde 3 — ux

Workflow `wf_f7e15ccc-83c` — Bereich `4c4bd5ad8..fdef21abd` (Nacharbeit seit `2e7f68ca0`) mit den 7 `paths` aus `board.json`, `criteria` 7, `deviceCriteria` [6], `founderAssumptions` 0. Gesamtentscheidung: **APPROVE** — all 7 criteria graded, every code criterion met; 1 device request(s) for the next build's device round. `outsideScope`: leer; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

UX and claims lens, round 3 of job 007 (range 4c4bd5ad8..fdef21abd, rework since 2e7f68ca0).

Earlier findings, each checked at the head:
- Round 1 (ux m1–m4, ui-state m1/m2, code m1/m2, security m1): all stay fixed. There is one location-only sentence, no "renamed", capital hex only, a real move-back in the guard, a high-priority announcement and a hidden caption.
- Round 2 code m1: fixed. The `stemByteLimit` doc now says " renaming 1A2B3C4D" (ProjectLibrary.swift:244).
- Round 2 ux m1: fixed with the PM's own wording (DocumentController.swift:677): "Only the file lags behind: in the Files app the song is called <file> for now, and Echoel tries to rename it when it next saves." It now names what lags (the file), so the red line no longer reads as a failed save. It is true in every state that reaches `moveFailed`:
  - a plain failure after a rename (the file is still at the old name)
  - a stranded case change (the in-between name)
  - an Undo back to the old name while stranded (`stranded()` keeps the move owed)
  - a song opened from an in-between package
  - "tries … when it next saves" holds, because `saveNow` calls `followRenamedSong` (line 571) and a failed move is never `followed`.
- Round 2 ux m2 (Speak Hints off): rebutted acceptably. It is now a measurement in [DEVICE] criterion 6, with a stated fallback.

Spec A5 matches the code word for word. The status strip (StudioView.swift:211-215) has no lineLimit, so the longer sentence wraps instead of truncating, even with a long stem plus the in-between suffix.

What the diff does not change, so nothing to report through this lens:
- no styling, radius, animation, glass, numeric-parameter control or flash
- no health, wellness or esoteric wording
- ContentPipeline/CLAIMS.md and FEATURE_STATUS.md correctly untouched
- no .claude/agents, review workflow, CLAUDE.md or .claude/rules file

One new minor wording note, below. Criterion 6 still needs the device run.

## Befunde

1. **minor** · `EchoelStudio/App/Documents/DocumentController.swift`:677
   - Befund: The pronoun 'it' in '…the song is called <file> for now, and Echoel tries to rename it when it next saves.' is ambiguous: the noun closest to it is 'the song', not 'the file'. A first-time user may read it as Echoel renaming the SONG, maybe back, right after they named it. The sentence's opening, 'Only the file lags behind', carries the intended meaning, so this is wording, not a false claim.
   - Vorschlag: Name the object, keeping 'tries' for honesty. For example: '…and Echoel tries to rename the file when it next saves.' Update spec A5 in the same commit, because it quotes the sentence verbatim.
