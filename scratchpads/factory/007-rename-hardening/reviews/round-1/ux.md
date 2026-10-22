# Runde 1 — ux

Workflow `wf_f738a9cc-f68` — Bereich `4c4bd5ad8..5942df4fd` mit den 7 `paths` aus `board.json`, `criteria` 7, `deviceCriteria` [6], `founderAssumptions` 0. Gesamtentscheidung: **APPROVE** — all 7 criteria graded, every code criterion met; 1 device request(s) for the next build's device round. `outsideScope`: leer; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

UX and claims lens, round 1 of job 007. There are no earlier rounds for this job. All three UX minors from job 006 round 3 are fixed in code:
- (1) An Undo after a stranded rename keeps the move owed. `SongFileName.stranded()` is called in the stranded branch, so the line no longer disappears while the package stays under the in-between name.
- (2) `moveFailed` now replaces a line that has changed instead of keeping the first one.
- (3) VoiceOver: the field carries the caption as its hint, an announcement "At most 128 characters." fires when the name crosses the limit, and Rename carries the same hint while it is blocked for length.

Checks on this build:
- `Names.maximumLength` is 128 and counts trimmed characters the same way as the door (`Command.swift:123/131`), so the caption is true.
- `AccessibilityNotification` is available, since the iOS 18 floor applies.
- The diff adds no visible sentence beyond the two failure lines that already existed and the announcement, and it contains no health, wellness or esoteric wording.
- Nothing in it bears on Uncodixfy, Dynamic Type, contrast or flash rate: it has no new styling, radius, animation or numeric parameter control.
- `ContentPipeline/CLAIMS.md` and `FEATURE_STATUS.md` are untouched, which is correct for a hardening slice.

Four minor edge cases remain. None blocks shipping:
- The rule that a line is said only once compares the sentence, not where the file is, so one location can be announced twice in two different wordings.
- The failure line opens with "The song is renamed", which can now stand after the user has undone the rename.
- The announcement uses the default priority, so it may be cut off by VoiceOver's own speech for the keystroke or paste. Criterion 6 is the device check for this.
- The caption is read twice when a VoiceOver user swipes through the sheet.

## Befunde

1. **minor** · `EchoelStudio/App/Documents/DocumentController.swift`:677
   - Befund: The said-once guard compares the SENTENCE (`line != failedMoveLine`), not where the file is. Case: a case-only rename strands, and the status line says 'its file is called beat renaming 1A2B3C4D for now' (line 674). At the next write, `followRenamedSong` retries from the in-between URL. Its lowercase name differs from the target, so the move takes the plain path in `ProjectLibrary.rename`. If that move fails, it lands in the generic catch with `moved: false`, and the line becomes 'its file keeps the name beat renaming 1A2B3C4D for now' (line 675). The file has not moved, but the guard sees a new sentence, so `moveSettled()` and a re-add swap the status text. A5 says a new sentence replaces the old one only when the file's location changes.
   - Vorschlag: Remember the file the line names (for example the `url` passed to `moveFailed`) and return early when it is unchanged. Or use one wording for both cases, e.g. 'its file is called X for now'.
2. **minor** · `EchoelStudio/App/Documents/DocumentController.swift`:674
   - Befund: Both failure sentences (lines 674 and 675) begin 'The song is renamed, but …'. With A3, `stranded()` keeps the move owed after an Undo back to the old name, so this line now stands while the header shows the original name. It stays until the next write, and for good if that retry fails. In that case the line is rewritten as 'The song is renamed, but its file keeps the name beat renaming 1A2B3C4D', which describes a rename the user just undid. The same happens with A4: a song opened from an in-between package whose first move fails gets this line, although nothing was renamed in this session. The edge case needs two or three failures in a row.
   - Vorschlag: Use neutral wording that is true in every state that can reach `moveFailed`, e.g. 'The song's file is called X for now; Echoel tries again when it next saves.'
3. **minor** · `EchoelStudio/App/Views/RenameSongView.swift`:30
   - Befund: `AccessibilityNotification.Announcement(caption).post()` posts at the default priority. It is posted in the same moment that VoiceOver speaks the typed character or the pasted text that pushed the name past 128 characters. A default-priority announcement can be dropped or cut off by that speech. That would fail [DEVICE] criterion 6 while the code criterion 5 passes.
   - Vorschlag: Post an `AttributedString` with `accessibilitySpeechAnnouncementPriority = .high` (iOS 17+, below the iOS 18 floor) so the limit is always spoken. Then confirm it in the criterion 6 device run.
4. **minor** · `EchoelStudio/App/Views/RenameSongView.swift`:42
   - Befund: The caption `Text(caption)` is still its own accessibility element, and the TextField now carries the same sentence as its hint (line 63). A VoiceOver user swiping through the sheet therefore hears 'Its file in the Files app is renamed too.' twice: once as the field's hint, once as static text.
   - Vorschlag: Optional: add `.accessibilityHidden(true)` to the caption `Text`, since the field hint and the announcement now carry it.
