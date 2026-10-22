# Runde 3 — ux

Workflow `wf_9e31f7a2-0a8` — Bereich `1f763674e..99c4835b7` (Nacharbeit seit `840643342`) mit den 10 `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [7], `founderAssumptions` 0. Gesamtentscheidung: **APPROVE** — all 8 criteria graded, every code criterion met; 1 device request(s) for the next build's device round. `outsideScope`: `docs/dev/TODO_FOUNDER_2026-10-19.md`; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

This is the UX/claims round 3 review of job 006. Every earlier UX finding is fixed or rebutted in code.

Round 1:
- m2: the failure line now goes beside the export line, not over it (`lastError.map { "\($0) \(line)" }`).
- m5: the door is disabled while `packageIsBusy`.
- m6: the caption says "At most 128 characters." in the record colour.
- m7: the move is tried again at every write.
- m8: autocorrection is off, and a 44 pt "Clear name" button was added.

Round 2:
- m3: `moveSettled()` removes exactly the failure line.
- m4: the stranded case now says "its file is called X for now".
- m5 is rebutted with a reason I accept: the media load lasts seconds, and the other three busy states show their own state.

Visible sentences, checked against this build:
- "Rename Song…", "Rename Song", "Name", "Cancel"/"Rename" and "Its file in the Files app is renamed too." are all true. Files exposure: `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace` and the Documents directory.
- Exports name the file through `openSongName` from `currentURL`.
- The header and its accessibility label read `store.project.name`.
- The Open-menu checkmark now matches by path.
- There is no health, wellness or esoteric wording.
- FEATURE_STATUS, CLAIMS and the store text are left alone until the device verdict, as the spec says.

Uncodixfy and accessibility:
- Radius is `Theme.Radius.medium` = 8 with a 1 px border; no glass, glow or scale animation; the label sits above the field.
- Fonts are Dynamic Type text styles.
- The record red is about 5.1:1 on the background (AA). Colour is never the only cue, because the caption text changes too.
- There is no flashing.
- The new `songsOpened` and `packageIsBusy` reads in the menu are low-frequency, not hot state.

The round-3 delta (the byte-bounded stem, `moveSettled`, the reopen of the same song) adds no new visible copy except the two failure sentences, and both are accurate in the normal path. Three minor edge cases remain; none blocks shipping.

changedFiles also contains `docs/dev/TODO_FOUNDER_2026-10-19.md`. It comes from commit dab7568c7 and is outside this job.

## Befunde

1. **minor** · `EchoelStudio/App/Documents/DocumentController.swift`:614
   - Befund: The double-fault case can leave the song under the in-between name with nothing on screen. It starts with a stranded case-only rename: the package sits under e.g. 'beat renaming 1a2b3c4d' and the line says 'its file is called … for now; Echoel tries again'. An Undo then takes the name back to 'beat'. `isDue` is now false, so `moveSettled()` deletes the line and no retry will ever happen, yet the package stays under the in-between name. The Open list (it shows file names) marks 'beat renaming 1a2b3c4d' with a checkmark while the header says 'beat', and nothing explains it. Rename is disabled for the unchanged name, so the musician has to rename to something else and back to repair it.
   - Vorschlag: Count a package whose stem is the in-between form of the followed name as still owed, so it keeps being retried and the line stays. Or at least do not remove the line while `currentURL` is the in-between URL.
2. **minor** · `EchoelStudio/App/Documents/DocumentController.swift`:659
   - Befund: Once a failure line has been said, a later failure never updates it. Case: a case-only rename first fails at step 1 ('keeps the name beat', which is true). A retry then fails at step 2 and the rollback fails too, so the package moves to the in-between name. The guard `failedMoveLine == nil` keeps the old sentence on screen, and 'keeps the name beat' is now untrue. This needs three failures in a row, so it is very unlikely.
   - Vorschlag: On a stranded failure, replace an existing `failedMoveLine` in `lastError` with the stranded wording instead of returning early.
3. **minor** · `EchoelStudio/App/Views/RenameSongView.swift`:38
   - Befund: When the name passes 128 characters, the caption switches to 'At most 128 characters.' and Rename greys out. A VoiceOver user is not told about either change: the caption is a separate static text below the field, and nothing announces it or ties it to the field or the button.
   - Vorschlag: Add `.accessibilityHint(caption)` to the TextField (or the Rename button), or post an announcement when `isTooLong` turns true.
