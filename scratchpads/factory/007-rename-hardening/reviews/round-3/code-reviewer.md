# Runde 3 — code-reviewer

Workflow `wf_f7e15ccc-83c` — Bereich `4c4bd5ad8..fdef21abd` (Nacharbeit seit `2e7f68ca0`) mit den 7 `paths` aus `board.json`, `criteria` 7, `deviceCriteria` [6], `founderAssumptions` 0. Gesamtentscheidung: **APPROVE** — all 7 criteria graded, every code criterion met; 1 device request(s) for the next build's device round. `outsideScope`: leer; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

Round 3, code lens, job 007 (4c4bd5ad8..fdef21abd; rework since 2e7f68ca0). The round-2 code-reviewer minor is fixed. The `stemByteLimit` doc comment now reads " renaming 1A2B3C4D" (ProjectLibrary.swift:244), which matches `betweenStem` (uppercased, :209) and `isBetweenStem` (0-9A-F only, :219). The other round-2 minors are fixed or rebutted in reviews/round-2/rebuttal.md. ux m1 was reworded: DocumentController.swift:677 now says "Only the file lags behind: … and Echoel tries to rename it when it next saves." ux m2 became a measurement inside device criterion 6. Since round 2, only that one string and two comments changed in code, so nothing in the logic could regress.

Re-check of the whole job at head:
- **ProjectLibrary.rename(_:to:moving:):** The internal seam is non-escaping and the public signature is unchanged. After a failed second step, the code asks the package under the name in between, not the old name (:190), which closes the race with the import. The inner `catch {}` does not shadow the error that goes into `RenameStranded`. The stem budget still holds: 200 bytes + 18 for the in-between suffix + 7 for ".echoel" is under 255.
- **isBetweenStem:** It needs a non-empty prefix (a leading " renaming" is rejected), an 8-character tail, and capitals only. The tests cover the negative cases.
- **SongFileName:** `isStranded` is cleared by `opened` and `followed`. `isDue` cannot be true while `followedName` is nil. `busy` still defers the move.
- **DocumentController.open(throwing:):**
  - `isOpenSong` is computed before `mayLeaveSong`, and the URL is re-read from `currentURL` afterwards.
  - The in-between mark is set only on the `another` path, after `opened(named:)`.
  - `lastError = failedMoveLine` gives nil for another song, because `moveSettled` has already run.
  - `restore()` and `open(_:)` both go through this path. Quarantine now keys on the URL actually read.
- **moveFailed:** One location-only sentence. If the line equals the standing one, it returns early. Otherwise `moveSettled` swaps out the standing line before appending, so a stranded line followed by a failed plain retry from the same URL is not said twice.
- **RenameSongView:** The rising-edge `onChange(of: isTooLong)` posts a high-priority AttributedString announcement. The field carries the hint, the Rename button carries the hint while the name is too long, and the caption is accessibilityHidden.
- **Hygiene:** No force unwraps, no print, logging stays on the existing Logger with only domain and code public, and everything is MainActor-isolated.
- **Tests:** The test closures are non-escaping, so mutating the captured `var step` is legal under Swift 6.

CI on head fdef21abd, from `gh run list --commit`: Echoel Studio 39828730749 succeeded and Echoel Studio (Linux) 39828730750 succeeded. I did not read the logs, so I have not checked that the guards are named in them; that check belongs to criterion 7.

One new cosmetic minor below. Criterion 6 is device-only and not verified here.

## Befunde

1. **minor** · `EchoelStudio/Core/Sources/EchoelCore/SongFileName.swift`:2
   - Befund: The type's doc header still says the package follows a CHANGE of the song's own name 'and nothing else', and that a song whose file was called something else when it opened keeps that file name until it is renamed. This job added `stranded()` (lines 42-48), and its own doc says 'A song that opens from such a package is stranded too'. DocumentController.swift:498 calls it when a song opens from a name in between, with no rename. The package then moves at the next write (spec A4, a deliberate exception to job 006 A3). The header now contradicts the method below it in the same file.
   - Vorschlag: Name the exception in the header: a package left under a name in between, whether by a change of case that failed both ways or by opening from such a name, follows no name and takes the song's own name at the next write.
