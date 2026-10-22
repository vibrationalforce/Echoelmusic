# Runde 3 — ui-state-reviewer

Workflow `wf_9e31f7a2-0a8` — Bereich `1f763674e..99c4835b7` (Nacharbeit seit `840643342`) mit den 10 `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [7], `founderAssumptions` 0. Gesamtentscheidung: **APPROVE** — all 8 criteria graded, every code criterion met; 1 device request(s) for the next build's device round. `outsideScope`: `docs/dev/TODO_FOUNDER_2026-10-19.md`; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

UI-state lens, round 3 of job 006, on 1f763674e..99c4835b7 (rework since 840643342). No blocker or major findings.

Round-1 findings from this lens:
- m9 is fixed. `songsOpened` is now observed: DocumentController.swift:93 dropped `@ObservationIgnored`. RenameSongView records the count in onAppear (line 24), dismisses when it changes (line 27), and `rename()` refuses a mismatch (line 97). Re-reading the same song does not change `songsOpened` (`another` guard, DocumentController.swift:482-492), so the sheet correctly stays open for it, as spec A9 says.
- m10 is fixed. The door is `.disabled(documents.packageIsBusy)` (StudioView.swift:416), and `packageIsBusy` includes `isExporting` (DocumentController.swift:606). All export and share starts are in the Song menu, which the sheet covers, so a finished export can no longer take the slot from a typed name.
- The round-2 rework (`failedMoveLine` / `moveSettled`, the same-song reopen, byte-limited stems) only touches non-observed state and `lastError`. `lastError` is written only when a failure line exists, so it adds no new render churn.

Freeze-law audit: I opened these files at the head: StudioView.swift (StudioView, TransportBar, SongMenu, keyAndScale), RenameSongView.swift, StudioRouter.swift, the relevant parts of DocumentController.swift, RecordController.swift, and the environment injection in EchoelStudioApp.swift.
- The menu host is SongMenu: its Key and Scale pickers use `.pickerStyle(.menu)`. Its ancestors are TransportBar, StudioView and the app root.
- The diff adds exactly one new read to SongMenu's body: `packageIsBusy`, which reads `isImporting`, `isExporting`, `isLoadingMedia` and `takesInFlight`. All four change only once per import, export, take or song open, and each change coincides with a rebuild that already happens, because SongMenu already reads `store.project` and StudioView already watches `mediaRevision` with `.onChange`.
- The diff adds no read to the TransportBar or StudioView bodies. The pre-existing `exportProgress` read in TransportBar is not touched by this diff.
- RenameSongView hosts no `.menu` Picker.

Other checks:
- Presentation: unchanged. There is still exactly one `.sheet(item:)` in StudioView (count 1 before, 1 after), and the new `StudioSheet.renameSong` case reuses that one slot (StudioRouter.swift:29, StudioView.swift:51). RenameSongView has no presentation modifiers.
- Two modals at once: not possible. Every presenter writes the single `router.sheet` item. The only asynchronous presenters (export and share completions) cannot run while the rename sheet is up, because of the door gate.
- `@Observable`: no new class. DocumentController and StudioRouter are both `@MainActor @Observable`.
- Environment: DocumentController and ProjectStore are injected at EchoelStudioApp.swift:62-64, and the sheet inherits them.
- Navigation: RenameSongView has a NavigationStack with no links, and `dismiss` is read at the sheet root.
- Lying-control check: the field limit and the store agree. Both trim with `.whitespacesAndNewlines` and count characters against 128 (`Names.validated`, Command.swift:126-134), so what the sheet shows is what the store keeps. The Open-list checkmark now compares standardized paths (StudioView.swift:506), which fixes a missing checkmark on a renamed or new song.
- Busy state cannot stick: `isLoadingMedia` is reset in `loadMedia` before any cancel takes effect, and every take id is removed on abandon or in `commitTake`'s defer, so the Rename door cannot stay disabled for good.

Not device-verified: this is a code read only.

## Befunde

Keine.
