# Runde 1 — ui-state-reviewer

Workflow `wf_b6a5d286-f55` — Bereich `1f763674e..963758fb2` mit den 10 `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [7], `founderAssumptions` 0. Gesamtentscheidung: **REWORK** — . `outsideScope`: leer; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

UI-state audit of factory 006 (rename song), round 1. The reviews/ directory is empty, so there were no earlier findings to check. I found no blocker or major issues and two minor ones.

Files opened at head 963758fb2: EchoelStudio/App/Views/StudioView.swift in full (StudioView, TransportBar, RecordButton, TempoField, SongMenu), EchoelStudio/App/Navigation/StudioRouter.swift, EchoelStudio/App/Views/RenameSongView.swift, the root scene body in EchoelStudio/App/EchoelStudioApp.swift, Names in EchoelStudio/Core/Sources/EchoelCore/Command.swift, the DocumentController and RecordController diffs, and the ProjectLibrary and SongFileName diffs. Laws checked: EchoelStudio/CLAUDE.md Law 6 (no hot state in a view body) and Law 7 (one presentation slot).

Ancestor read audit, from RenameSongView up through the StudioView sheet host to the WindowGroup root, plus SongMenu (the Menu with the Key and Scale `.menu` Pickers) and its parent TransportBar:
- The diff adds no new hot read. SongMenu gains one Button that reads nothing. The Open-list checkmark now compares paths, but it reads `documents.currentURL`, which it already read before; that value is cold and changes only on open or rename.
- The three new DocumentController fields (`isLoadingMedia`, `takeInFlight`, `fileName`) are all `@ObservationIgnored`. So the new `followRenamedSong()` call inside `saveNow` (which autosave also runs) adds no observation churn. It touches observed state (`currentURL`, `refresh()`, `lastError`) only when a move actually happens or fails.
- RenameSongView reads `store.project.name` in its toolbar. That re-renders on every project change, but the sheet holds no Picker, and the field text and focus are `@State`, so a re-render costs nothing.

Presentation chain is unchanged, +0 modifiers. Measured with `git grep -nE '\.(sheet|fullScreenCover|alert|fileImporter|fileExporter|confirmationDialog|popover|inspector)\('` over EchoelStudio/App at base and head: both show the one `.sheet(item:)` (StudioView.swift:41) and SoundPanel's one `.fileImporter` (SoundPanel.swift:57). The new case `StudioSheet.renameSong` reuses the one slot. The sheet itself has no presentation modifier, and a failed rename is reported in the status strip (`lastError`), not in a modal.

Lying-control check: `canRename` matches `Names.validated` exactly (same trim set, same `count <= 128`, plus "not unchanged"), so the button is never enabled for a name the command would refuse.

@Observable: no new @Observable type. The environment objects the sheet reads are injected at the root and reach sheet content, as SoundPanel already relies on.

Navigation: the sheet's NavigationStack is used only for the title and toolbar and has no links, the same as AboutView, StoreView and AgentView.

Not proven by reading: the build, and the [DEVICE] criterion 7.

## Befunde

1. **minor** · `EchoelStudio/App/Views/RenameSongView.swift`:21
   - Befund: The sheet copies the song name into `@State name` once, in onAppear (line 21). It renames whatever song is open when Rename is tapped (`documents.renameSong(to:)`, line 68), and nothing closes it when the open song changes. If a song arrives from Files or AirDrop while the sheet is up, `.onOpenURL` (EchoelStudioApp.swift:84) runs `openIncoming` and then `open(local)` (DocumentController.swift:411), and the sheet stays presented. It still shows the old song's name, but it now targets the new song. Because `canRename` compares against the new song's name (line 63), an untouched field turns Rename from disabled to enabled without any input. Tapping it renames song B to A's name, and B's package becomes "A 2". The view shows one song's value and writes it to another. Undo recovers it.
   - Vorschlag: Tie the sheet to the song it opened for. Either carry the song's identity in the case (for example `.renameSong(URL)`), and have `renameSong` refuse or dismiss when `currentURL` no longer matches, or dismiss the sheet when the open song changes, for example on a counter of opened songs that DocumentController exposes.
2. **minor** · `EchoelStudio/App/Views/StudioView.swift`:469
   - Befund: A4 deliberately keeps Rename Song available during an export or share (line 413 is never disabled). But the Export WAV, Export Stems and Share Song tasks set `router.sheet = .share(...)` unconditionally when they finish (lines 469, 482, 494). The flow: start an export, which may wait on media decode, then open Rename Song and type. When the export finishes, the single `.sheet(item:)` swaps the rename sheet for the share sheet. The typed name is thrown away and nothing says the rename did not happen. Only one modal is ever up, because the one-slot enum guarantees that, so this is a slot pre-emption, not a stacked modal. The same pattern already exists for About, Store and Assistant, but this is a new sheet that holds text input, and the spec itself puts it in that window.
   - Vorschlag: In those three tasks, present the share sheet only when the slot is free (`if router.sheet == nil`) or not holding an input sheet. Otherwise keep the URL and present it after the current sheet is dismissed. Alternatively, disable Rename Song while `documents.isExporting` is true. That contradicts nothing, because A4 promises only that the package move waits, not that the door stays open.
