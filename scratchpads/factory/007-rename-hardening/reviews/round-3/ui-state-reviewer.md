# Runde 3 — ui-state-reviewer

Workflow `wf_f7e15ccc-83c` — Bereich `4c4bd5ad8..fdef21abd` (Nacharbeit seit `2e7f68ca0`) mit den 7 `paths` aus `board.json`, `criteria` 7, `deviceCriteria` [6], `founderAssumptions` 0. Gesamtentscheidung: **APPROVE** — all 7 criteria graded, every code criterion met; 1 device request(s) for the next build's device round. `outsideScope`: leer; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

UI state review, round 3 of job 007. The full range is 4c4bd5ad8..fdef21abd, and the rework since the last review is 2e7f68ca0..fdef21abd.

Earlier findings:
- Round 1 had two ui-state minors. Both are still fixed at head. m1: RenameSongView.swift:31-35 posts an AttributedString with accessibilitySpeechAnnouncementPriority = .high, only when the name first becomes too long. m2: DocumentController.swift moveFailed (head line ~674) now says one sentence that names only where the file is, and it claims no rename.
- Round 2 had no ui-state findings.
- Round 2 had three minors from other lenses. Code m1 (the doc comment spelled the in-between suffix in lower case) is fixed at ProjectLibrary.swift:244, which now reads " renaming 1A2B3C4D". UX m1 (the sentence had no object) is fixed: the line now reads "Only the file lags behind: in the Files app the song is called <file> for now, and Echoel tries to rename it when it next saves." UX m2 (VoiceOver with Speak Hints off) is answered by a measurement added to device criterion 6, and spec A5 and criterion 6 were updated to match.

What the rework changed: one string literal and its comment in DocumentController.moveFailed, one doc comment in ProjectLibrary, and the spec, board and review files. It adds no state, observation, environment or presentation change.

Files I opened at fdef21abd:
- RenameSongView.swift, the whole file
- DocumentController.swift lines 1-80 and the open, open(throwing:), followRenamedSong, packageMoved, moveFailed and moveSettled region (about lines 456-520 and 600-700)
- the status-line reader, found by git grep: StudioView.swift:203-211 reads documents.lastError; StudioView is not in the diff
- the round-1 and round-2 ui-state reviews, the round-2 rebuttal and the round-2 approver

Ancestor read audit, rooted at RenameSongView with StudioView as its parent (the .sheet(item:) host):
- The sheet hosts no .menu Picker.
- .onChange(of: isTooLong) reads only @State name, through computed properties.
- documents.songsOpened changes only when a song switches.
- lastError is written only on open, a failed move or a settled move, never at a per-tick rate. In moveFailed, moveSettled and the append run in the same main-actor call, so one rebuild covers both writes.
- failedMoveLine and fileName (including isStranded) stay @ObservationIgnored.

Presentation chain: unchanged. The diff adds no .sheet, .fullScreenCover, .alert or .fileImporter, and nothing drives two modals at once.

@Observable: DocumentController keeps @MainActor @Observable. Nothing new is reached through a global.

Navigation: unchanged. The NavigationStack has no links.

Lying-control check: the field and Rename hints follow isTooLong. The caption hidden from VoiceOver carries nothing that the hint and the announcement do not.

CI on fdef21abd (from gh run list --commit; job logs not opened): Echoel Studio 39828730749 succeeded, and Echoel Studio (Linux) 39828730750 succeeded.

Criterion 6 (VoiceOver on a device) is still device-only and not verified here. The diff touches no .claude/agents file, no review workflow, no CLAUDE.md and no .claude/rules file. There are no new findings through this lens.

## Befunde

Keine.
