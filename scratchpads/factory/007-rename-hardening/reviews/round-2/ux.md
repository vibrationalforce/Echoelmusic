# Runde 2 — ux

Workflow `wf_864aabbe-500` — Bereich `4c4bd5ad8..2e7f68ca0` (Nacharbeit seit `5942df4fd`) mit den 7 `paths` aus `board.json`, `criteria` 7, `deviceCriteria` [6], `founderAssumptions` 0. Gesamtentscheidung: **APPROVE** — all 7 criteria graded, every code criterion met; 1 device request(s) for the next build's device round. `outsideScope`: leer; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

UX and claims lens, round 2 of job 007. Every round-1 finding in reviews/round-1 is fixed at 2e7f68ca0, and rebuttal.md answers all nine.

**Round-1 findings, each checked in code**
- ux m1, ux m2, code m1 and ui-state m2 are fixed. `moveFailed` lost its `moved` flag and now builds one sentence (DocumentController.swift:676): "In the Files app the song is called <file> for now; Echoel tries again when it next saves." The sentence names only where the file is, so the said-once guard (line 678) compares the location. The word "renamed" is gone, so the line is true after an Undo and for a song that opened from a name in between.
- ux m3 and ui-state m1 are fixed. The announcement is posted as an `AttributedString` with `accessibilitySpeechAnnouncementPriority = .high` (RenameSongView.swift:33-35). This is Apple's WWDC23 form, and the `Echoel Studio` run 39824850887 on the head is green, so it compiles with `import SwiftUI`.
- ux m4 is fixed. The caption has `.accessibilityHidden(true)` (RenameSongView.swift:51).
- code m2 is fixed. `isBetweenStem` accepts capitals only, `betweenStem` writes with `.uppercased()`, and the test has a new lowercase negative case.
- security m1 is fixed. In the test, step 1 and the way back are real `FileManager.moveItem` calls; only step 2 is a made-up failure.

**Claims and visible text checked on this build**
- The "Files app" wording is true: project.yml:85-86 sets UIFileSharingEnabled and LSSupportsOpeningDocumentsInPlace.
- "tries again when it next saves" is true on both failure branches. The generic catch leaves the name due, and the stranded branch calls `stranded()`. Both are retried in `followRenamedSong` at the next write.
- The sentence in spec A5 matches the code word for word.

**Rest of the lens**
- No health, wellness or esoteric wording.
- No styling, radius, animation, numeric-parameter control or flash change, so Uncodixfy, Dynamic Type, contrast and reduce motion are unaffected.
- ContentPipeline/CLAIMS.md and FEATURE_STATUS.md are correctly left untouched for a hardening slice.

**New this round:** two minor wording and accessibility notes. Neither blocks shipping, and criterion 6 remains the device check.

## Befunde

1. **minor** · `EchoelStudio/App/Documents/DocumentController.swift`:676
   - Befund: The new neutral sentence is true in every state, but it no longer says what did not happen. It appears in the red document line of the status strip (StudioView.swift:211-214, `Theme.Color.record`) and reads: 'In the Files app the song is called beat for now; Echoel tries again when it next saves.' 'Tries again' has no object, so a first-time user can read it as a failed SAVE and worry that their work is lost. In fact the song was written; only its file name lags behind.
   - Vorschlag: Name the object, in wording that stays true after an Undo and for a song opened from a name in between. For example: 'In the Files app the song is still called <file>; its file takes the song's name when Echoel next saves.'
2. **minor** · `EchoelStudio/App/Views/RenameSongView.swift`:51
   - Befund: With the caption hidden, its content reaches VoiceOver only as hints: the field hint at line 70 and the Rename hint at line 94. The one-time announcement is the only other carrier. A VoiceOver user who has turned off Speak Hints (VoiceOver > Verbosity) never hears 'Its file in the Files app is renamed too.'. Once the announcement has passed, they also hear no reason why Rename reads as dimmed. Spec A8 and criterion 5 ask for this trade-off; it is a likely loss, not a measured one.
   - Vorschlag: In the criterion 6 device run, also try it with Speak Hints off. If the limit is lost, keep the caption as an element and drop the duplicate field hint instead of hiding the caption.
