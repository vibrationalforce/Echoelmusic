# Runde 2 — ui-state-reviewer

Workflow `wf_ac2238b4-7c1` — Bereich `1f763674e..840643342` (Nacharbeit seit `963758fb2`) mit den 10 `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [7], `founderAssumptions` 0. Gesamtentscheidung: **REWORK** — . `outsideScope`: `docs/dev/TODO_FOUNDER_2026-10-19.md`; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

UI-state review, round 2, of job 006 (1f763674e..84064334). I found no blocker and no major. Both round-1 findings from this lens are fixed in code.

Round 1 findings:
- m9 (a song arriving from Files got the open sheet's name) is FIXED. `songsOpened` is no longer `@ObservationIgnored`: it is `private(set) var` at DocumentController.swift:93. RenameSongView records the count in `onAppear` (line 24), dismisses through `.onChange(of: documents.songsOpened)` (line 27), and `rename()` refuses a mismatch (line 97). The onChange can fire only because the property is now observed. `songsOpened` changes only in `anotherSongOpened()` (line 929), so the rename itself never closes its own sheet.
- m10 (a finished export took the sheet slot from the rename sheet) is FIXED. The door is `.disabled(documents.packageIsBusy)` at StudioView.swift:416, and `packageIsBusy` (DocumentController.swift:602) includes `isExporting`. The only callers that start an export, import or take are in SongMenu, the sheet-hosted pickers and RecordButton (StudioView.swift:294). The modal sheet covers all of them.

Audits I ran:
- Ancestors of the menu host. I traced StudioView.body, then TransportBar.body/controls/status/messages, then SongMenu.body including keyAndScale (the `.menu` Key/Scale pickers). The diff adds no read to StudioView or TransportBar. SongMenu now also reads `packageIsBusy`, so it observes `isImporting`, `isExporting`, `isLoadingMedia` and `takesInFlight`. All four are cold: they flip only at the start and end of an import, export, take or media load (write sites at lines 661/663, 742/744, 949/952, 1041/1043, 1087/1094/1103, 1158/1163/1180). That is the same class as the existing `isExporting` read. No 10 Hz source and no per-frame main-actor hop was added.
- Busy flags cannot stick, so the door cannot stay disabled. `isLoadingMedia` is reset on every reload (line 1158) and on completion (line 1180), and the only cancel is the reload at line 1155. `takesInFlight` is emptied by `takeAbandoned` (line 1094) and by the `commitTake` defer (line 1103). RecordController calls `takeAbandoned` on both give-up paths (RecordController.swift:121 and 143).
- The stored busy properties are observed (not ignored), so the door's disabled state is live and does not show a stale value. `fileName` and `failedMoveSaid` are `@ObservationIgnored`, and `followRenamedSong` writes no observed state when nothing moves, so autosaves cause no extra rebuilds.
- Values shown and kept agree. The sheet's length and empty checks use the same trimmed `.count` and 128 limit as `Names.validated` (Command.swift:126-134). The Open-menu checkmark compares paths, which fixes a checkmark that pointed at the wrong song.

Report lines:
- Presentation chain: unchanged. StudioView has 1 presentation modifier (`.sheet(item:)`) at both base and head, and the new modal is a `StudioSheet.renameSong` case (StudioRouter.swift:29, StudioView.swift:51). No `.alert`/`.sheet`/`.fullScreenCover`/`.popover` was added anywhere under App. A single enum slot cannot drive two modals at once.
- @Observable: DocumentController and RecordController stay `@MainActor @Observable`. RenameSongView reads them through `@Environment`, injected the same way as the other sheets (SoundPanel, StudioView).
- Navigation: consistent. RenameSongView uses a NavigationStack only for its title and toolbar; there is no NavigationLink.

Files opened: the spec, board.json and round-1 rebuttal.md at head; the full job diff and the round-2 diff of RenameSongView.swift and StudioView.swift; StudioView.swift lines 1-240 and 360-560, DocumentController.swift lines 1-140, 236-262 and 1070-1110 plus grep of all busy-flag sites, RecordController.swift in full, and Command.swift lines 118-150, all at head.

Not verified: compile or device behaviour (no toolchain here), and whether a one-off cold rebuild of SongMenu closes an open Key/Scale submenu on iOS. That last one is the same exposure the existing `isExporting`/`store.project` reads already have, so I did not raise it as a finding.

## Befunde

Keine.
