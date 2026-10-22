# Runde 2 — ui-state-reviewer

Workflow `wf_864aabbe-500` — Bereich `4c4bd5ad8..2e7f68ca0` (Nacharbeit seit `5942df4fd`) mit den 7 `paths` aus `board.json`, `criteria` 7, `deviceCriteria` [6], `founderAssumptions` 0. Gesamtentscheidung: **APPROVE** — all 7 criteria graded, every code criterion met; 1 device request(s) for the next build's device round. `outsideScope`: leer; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

UI state review, round 2 of job 007, range 4c4bd5ad8..2e7f68ca0. Since round 1 (5942df4fd..2e7f68ca0) the job changed DocumentController.moveFailed, RenameSongView, ProjectLibrary.betweenStem/isBetweenStem and one guard.

Both round-1 ui-state findings are fixed:
- m1 (default-priority announcement): fixed in EchoelStudio/App/Views/RenameSongView.swift lines 31-35. It now posts `AttributedString(caption)` with `accessibilitySpeechAnnouncementPriority = .high` through `AccessibilityNotification.Announcement(limit).post()`, on the rising edge only (`guard tooLong else { return }`).
- m2 (the line reported a rename nobody made): fixed in EchoelStudio/App/Documents/DocumentController.swift line 676. There is now one sentence that names only where the file is ("In the Files app the song is called <file> for now; …"), and the `moved:` parameter is gone from both call sites (648-654).

The other lenses' round-1 minors are also addressed in the code:
- the said-once check now effectively compares the location, because the sentence depends only on `file`
- `isBetweenStem` accepts capitals only, and `betweenStem` writes `.uppercased()`
- the guard's way back is a real `FileManager.moveItem`
- the caption has `.accessibilityHidden(true)`, at RenameSongView.swift line 51

Files I opened at 2e7f68ca0:
- RenameSongView.swift, the whole file
- DocumentController.swift lines 1-140 and the open/save/rename/moveFailed/moveSettled region (about lines 440-700)
- the presentation site, found by grep: StudioView.swift:41 has `.sheet(item: $router.sheet)`, and line 51 has `case .renameSong: RenameSongView()`; StudioView is not in the diff
- all six round-1 review files and the rebuttal

Ancestor read audit, rooted at RenameSongView with StudioView as its parent:
- The sheet hosts no `.menu` Picker.
- The new `.onChange(of: isTooLong)` reads only `@State name`, through computed properties.
- The body still reads only `documents.songsOpened`, which changes on a song switch, not per tick.
- The new `lastError` writes in moveFailed happen only when a move fails, as before, never at a high rate.
- `failedMoveLine` and `fileName` (including the new `isStranded`) stay `@ObservationIgnored`.

Presentation chain: unchanged. The diff adds no `.sheet`, `.fullScreenCover`, `.alert` or `.fileImporter`, and nothing drives two modals at once.

`@Observable`: DocumentController keeps `@MainActor @Observable`, and nothing new is reached through a global.

Navigation: the existing NavigationStack has no links, and the diff does not change navigation.

Lying-control check: the field hint and the Rename button hint follow `isTooLong`. The hidden caption carries no information that the hint and the announcement do not.

CI on 2e7f68ca0 is green:
- Echoel Studio 39824850887, which includes the App build, so the AttributedString announcement API compiles with `import SwiftUI`
- Echoel Studio (Linux) 39824850931

Criterion 6 (VoiceOver on a device) is still device-only and not verified here. The diff does not touch .claude/agents, the review workflow, any CLAUDE.md or .claude/rules. No new findings through this lens.

## Befunde

Keine.
