# Runde 1 — code-reviewer

Workflow `wf_f738a9cc-f68` — Bereich `4c4bd5ad8..5942df4fd` mit den 7 `paths` aus `board.json`, `criteria` 7, `deviceCriteria` [6], `founderAssumptions` 0. Gesamtentscheidung: **APPROVE** — all 7 criteria graded, every code criterion met; 1 device request(s) for the next build's device round. `outsideScope`: leer; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

Round 1, code lens. There were no earlier reviews to re-check (the reviews/ directory does not exist). Nothing in the diff blocks shipping, and two minor notes follow.

**ProjectLibrary.rename**
- The internal `moving:` seam is non-escaping and keeps the public `rename(_:to:)` signature, so the overloads cannot clash.
- After a failed second step, the code now asks whether the package is still under the name in between, and no longer whether the old name exists. This closes the race where another package takes the old name. A successful way back still throws the plain error.
- `betweenStem` and `isBetweenStem` agree with each other. `isBetweenStem` needs a non-empty prefix and exactly eight hex characters, and the negative cases in `testTheNameInBetweenIsKnownAgain` hold.

**SongFileName**
- `isStranded` makes every name due, but only while a song is open. `opened` and `followed` clear it.
- The busy check still holds back a stranded move.

**DocumentController**
- `isOpenSong` is worked out before `mayLeaveSong`, so a reopen reads at `currentURL` after the save that may have moved the package. `another` stays false in that case.
- A package opened under a name in between is marked stranded only on the `another` path, after `opened(named:)`.
- `lastError = failedMoveLine` gives nil when another song opens, because `moveSettled` has already run.
- `moveFailed` swaps out a standing line through `moveSettled()` and returns early when the line is the same.
- The stranded catch branch calls `stranded()` before `packageMoved`.
- No force unwraps and no `print` were added; logging stays on the existing `Logger`.

**RenameSongView**
- `onChange(of:)` with two parameters and `AccessibilityNotification.Announcement(String).post()` are both available on iOS 18 (Package.swift `.iOS(.v18)`). The same API is already used in `Sources/`.
- The hints on the field and on the Rename button follow `isTooLong` correctly.

**Tests**
- I traced the three ProjectLibrary guards on both case-sensitive (Linux) and case-insensitive volumes, and each lands where its assertions expect.
- The closures are typed correctly for `(URL, URL) throws -> Void`, and `@testable` reaches the internal `rename(_:to:moving:)` and `betweenStem`.

**Not verified here:** whether the tests and the app build actually pass. That is criterion 7, the CI gate. The board says nothing was run before the push.

## Befunde

1. **minor** · `EchoelStudio/App/Documents/DocumentController.swift`:673
   - Befund: The status line can change while the file stays where it is. After a stranded case change, the line says "its file is called <stem> renaming XXXXXXXX" (moved: true). If the next write's normal move from that name in between then fails, the catch-all branch (line 652) calls moveFailed with moved: false. That builds "its file keeps the name <stem> renaming XXXXXXXX", which differs from the standing line, so lines 677-681 replace it even though the file is still in the same place. Criterion 4 asks for a replacement whenever the sentence changes, so this matches it. A5, though, ties the replacement to where the file is now, and here a second, differently worded sentence is said about an unchanged location.
   - Vorschlag: Pick the wording from whether the file is under a name in between (`ProjectLibrary.isBetweenStem(file)`), not from the `moved` flag. Alternatively, compare only the file location before replacing the line.
2. **minor** · `EchoelStudio/Core/Sources/EchoelCore/ProjectLibrary.swift`:218
   - Befund: isBetweenStem also accepts lowercase hex, but betweenStem only ever writes `UUID().uuidString.prefix(8)`, which is uppercase. This makes the A4 false-positive class (a package someone names by hand and that gets moved at the next write) wider than A4's "genau so, wie `rename` ihn schreibt". Criterion 2 also says the check recognises the name `rename` writes and no ordinary name.
   - Vorschlag: Limit the tail check to "0123456789ABCDEF". If lowercase is deliberate, for example to cope with a volume that changes case, say so in the doc comment and add a test case for it.
