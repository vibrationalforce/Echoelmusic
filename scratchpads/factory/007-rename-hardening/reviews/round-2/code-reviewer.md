# Runde 2 — code-reviewer

Workflow `wf_864aabbe-500` — Bereich `4c4bd5ad8..2e7f68ca0` (Nacharbeit seit `5942df4fd`) mit den 7 `paths` aus `board.json`, `criteria` 7, `deviceCriteria` [6], `founderAssumptions` 0. Gesamtentscheidung: **APPROVE** — all 7 criteria graded, every code criterion met; 1 device request(s) for the next build's device round. `outsideScope`: leer; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

Round 2, code lens, job 007 (4c4bd5ad8..2e7f68ca0; rework 5942df4fd..2e7f68ca0). All nine round-1 findings are fixed in code. I checked each one at the head commit:
- code m1, ux m1, ux m2, ui-state m2: `moveFailed` now builds one sentence that names only where the file is ("In the Files app the song is called <file> for now; …"; the `moved:` parameter is gone), at DocumentController.swift:676. A stranded line followed by a failed plain retry from the in-between URL now gives the same string, so the guard `line != failedMoveLine` at :678 returns early. No "renamed" wording is left.
- code m2: `betweenStem` writes `.uppercased()` (ProjectLibrary.swift:209) and `isBetweenStem` accepts only 0-9A-F (:219). The negative case "beat renaming 1a2b3c4d" is in `testTheNameInBetweenIsKnownAgain`.
- security m1: in `testAStrandedRenameIsFoundByItsPackageNotItsOldName`, only step 2 is stubbed. Steps 1 and 3 (the way back) are real `FileManager.moveItem` calls. If moveItem replaced the empty folder at the old name, `between` would be gone and `rename` would rethrow the plain CocoaError. That error does not match the typed catch, so it would leave the throwing test and turn it red. The way-back test still covers the plain-error case.
- ui-state m1, ux m3: the announcement is an `AttributedString` with `accessibilitySpeechAnnouncementPriority = .high` (RenameSongView.swift:32-35).
- ux m4: the caption `Text` carries `.accessibilityHidden(true)` (:51).

Whole-job re-check:
- **`rename(_:to:moving:)`:** The closure is non-escaping and internal, and the public signature is unchanged. The inner `catch {}` does not shadow the outer `error` that goes into `RenameStranded`. The stranded check asks the package (`between`), not the old name.
- **`SongFileName`:** `isStranded` is cleared by both `opened` and `followed`, and `isDue` cannot be true with a nil `followedName`.
- **`open(throwing:)`:** `isOpenSong` is computed before `mayLeaveSong`, and the URL is re-read from `currentURL` afterwards, so `another` is false for the reopened song. The between-stem mark is set only on the `another` path, after `opened(named:)`. `restore()` goes through the same path.
- **Hygiene:** no force unwraps, no `print`, logging stays on the existing Logger with only domain and code public, and all of it is MainActor-isolated.
- **CI on head 2e7f68ca0:**
  - Echoel Studio run 39824850887 succeeded: Core tests on the macOS host, App Build for iOS Simulator, Launch smoke and Build for iOS device (Release). So `accessibilitySpeechAnnouncementPriority` compiles with `import SwiftUI`.
  - Echoel Studio (Linux) run 39824850931 succeeded, which runs `swift test` over Core. A green result means Linux Foundation's moveItem also refuses the occupied empty folder. I could not fetch that run's log (the proxy returned 403), so I have not seen the guard named in it.

One new cosmetic minor below. Criterion 6 is device-only and not verified here.

## Befunde

1. **minor** · `EchoelStudio/Core/Sources/EchoelCore/ProjectLibrary.swift`:244
   - Befund: The `stemByteLimit` doc comment still gives the in-between name as " renaming 1a2b3c4d", in lowercase. This rework made the writer uppercase on every platform (line 209), and the reader now rejects lowercase on purpose (line 219, A4). The comment now names a spelling that `isBetweenStem` refuses. The byte budget is unaffected, because hex characters take one byte in either case.
   - Vorschlag: Write the example as " renaming 1A2B3C4D" to match `betweenStem` and A4.
