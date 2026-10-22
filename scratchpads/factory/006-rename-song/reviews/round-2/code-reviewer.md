# Runde 2 — code-reviewer

Workflow `wf_ac2238b4-7c1` — Bereich `1f763674e..840643342` (Nacharbeit seit `963758fb2`) mit den 10 `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [7], `founderAssumptions` 0. Gesamtentscheidung: **REWORK** — . `outsideScope`: `docs/dev/TODO_FOUNDER_2026-10-19.md`; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

Round 2, code lens. Every round-1 finding in reviews/round-1/rebuttal.md is fixed in the code, and I checked each one against the head file:
- M1: `takesInFlight` is now a `Set<MediaID>`. `newTakeTarget` (DocumentController:1087) inserts its id, and `takeAbandoned` (:1094) and `commitTake`'s defer (:1103) each remove only their own. `RecordController` calls `takeAbandoned` at :121 (beginTake failed) and :143 (no take came back), and `newTakeTarget` has no other callers.
- m1: `releaseHold(on: moved)` (:640).
- m2: the failure line is added after an existing `lastError` (:652).
- m3: `ProjectLibrary.RenameStranded` is thrown at ProjectLibrary:184, and DocumentController:623-628 follows the package to the in-between name.
- m4: the log line carries only domain and code (:647).
- m5 and m10: the door is disabled by `packageIsBusy` (StudioView:416).
- m6, m8 and m9: RenameSongView:89, :55, :59-68, :27 and :97.

Other checks:
- `renamedURL` and `rename` are correct on case-sensitive and case-insensitive volumes, including a numbered own package and a case-only change.
- The retry loop does not race the earlier-songs import: `reservePackage` takes a name by creating its folder, and `moveItem` refuses an existing target.
- Every package reader and writer is covered by `packageIsBusy`. The engine plays from in-memory buffers and stores media paths relative to the package, so a move after an import, take or load breaks nothing.
- `isLoadingMedia` is cleared on every path, because only `loadMedia` cancels the load task and it clears the flag first.
- Swift 6: `RenameStranded`'s stored properties are Sendable, all new state is MainActor, and the mediaLoad Task inherits MainActor.
- No force unwraps, no print. The Theme tokens and APIs the new view uses exist (iOS 18 target).

CI: Echoel Studio (Linux) is green on 840643342; Echoel Studio is still running there (it was green on 963758fb2).

Two minor edge cases are left in the failed-move bookkeeping. Both need a move to fail first, and neither blocks shipping.

## Befunde

1. **minor** · `EchoelStudio/App/Documents/DocumentController.swift`:648
   - Befund: `failedMoveSaid` is only reset by a successful move (:621) or a song open (:437, :486). Suppose a move fails (the line is said), and then an Undo brings the name back to the followed one. `followRenamedSong` now returns early at :609, so nothing is due, but the flag stays true. If the musician later renames again through the door and that move also fails, `moveFailed` returns at :648 without a word, while the sheet's caption promised the Files name changes too.
   - Vorschlag: Reset `failedMoveSaid` whenever nothing is owed any more: in `followRenamedSong`, when `!fileName.isDue(for: name)`. Alternatively reset it in `renameSong(to:)` before `store.perform`, so each door rename can report its own failure once.
2. **minor** · `EchoelStudio/App/Documents/DocumentController.swift`:485
   - Befund: Reopening the SAME song (from the Open list, or from Files through `adopt`, which keeps it in place) runs `fileName.opened(named: project.name)`. The document already carries the new name, so a move still owed after a failed attempt is dropped: `mayLeaveSong` retries once at :510 before this, and if that retry fails too, no later write ever tries again. The package then keeps its old name silently (`failedMoveSaid` is reset at :486). Spec A7 says every further write retries, and A9 limits the drop to ANOTHER song.
   - Vorschlag: Keep the owed move when the reopened song is the open one: skip `fileName.opened` when `another` is false. Otherwise, add this case to A9 next to the app-end limitation.
