# Runde 1 — security-agent

Workflow `wf_f738a9cc-f68` — Bereich `4c4bd5ad8..5942df4fd` mit den 7 `paths` aus `board.json`, `criteria` 7, `deviceCriteria` [6], `founderAssumptions` 0. Gesamtentscheidung: **APPROVE** — all 7 criteria graded, every code criterion met; 1 device request(s) for the next build's device round. `outsideScope`: leer; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

Security and privacy review, round 1 of job 007 (rename hardening), range 4c4bd5ad8..5942df4fd. There are no earlier rounds for this job. The one security finding from job 006 round 3 (minor m1: the failed rollback was judged by whether something existed at the old name) is fixed the way that review suggested. ProjectLibrary.swift:190 now asks whether the package is still under the in-between name (`files.fileExists(atPath: between.path)`). Only then does it throw RenameStranded; otherwise it rethrows the error. An import that reserved the old name in the meantime can no longer make DocumentController keep currentURL on that other package. The guard testAStrandedRenameIsFoundByItsPackageNotItsOldName fails on the old guard and passes on the new one.

Path safety is unchanged and still holds. rename(_:to:moving:) keeps the canonical-parent check (line 171). Every target is still the library directory plus a stem cleaned by fileName(for:): forbidden characters become dashes, leading and trailing dots are stripped so ".." cannot occur, and the stem is capped at 200 bytes. The `moving:` seam is internal, so the App cannot reach it; only the @testable Core tests can, and the public rename(_:to:) still uses FileManager.moveItem.

The new A4 rule sets the stranded flag when a package whose file name matches the in-between pattern opens. A song that arrives from AirDrop or Files keeps its sender's file name through adopt, so a crafted file can trigger this. The result is an automatic rename to the song's inner name at the next write, and that name is untrusted. That is still safe. The name is cleaned the same way, renamedURL skips any name another song holds, and moveItem never overwrites, so the move stays inside the library and never lands on another song's package. isBetweenStem itself (lines 214-219) is a pure string check with no I/O. Quarantine stays consistent, because packageMoved re-notes the opening name.

open(throwing:) now re-reads the open song at currentURL after mayLeaveSong. currentURL is always a library path, so this only closes a case where a stale chosen URL could have read another package.

Logging is unchanged where it matters: moveFailed still logs only the error's domain and code as public, and no new log line carries a song name. The VoiceOver hints and the announcement in RenameSongView use a fixed message with no song name. The diff touches no entitlements, Info.plist, network code or permissions, and nothing leaves the device, so App Store 5.1.x is unaffected. The diff touches no CLAUDE.md, no .claude/rules, no .claude/agents and no review-workflow file.

There is one minor finding about test strength; nothing blocks shipping.

## Befunde

1. **minor** · `EchoelStudio/Core/Tests/EchoelCoreTests/ProjectLibraryTests.swift`:169
   - Befund: The test never checks that the real move refuses an occupied name. In testAStrandedRenameIsFoundByItsPackageNotItsOldName, step 2 creates the other song's folder at the old name (line 167). Step 3, the way back, then fails with a made-up `throw CocoaError(.fileWriteFileExists)` (line 169) instead of calling FileManager.moveItem. The promise that a song never writes into another song's package rests on that real move refusing an existing folder. The import reserves its package as an EMPTY folder (DocumentController.reservePackage, line 1401) and fills it only later (line 1356). POSIX rename(2) silently replaces an empty folder, so only Foundation's own check keeps the package off it. The test passes whatever moveItem does there.
   - Vorschlag: In the closure, let step 3 (the way back) call the real `FileManager.default.moveItem(at: source, to: destination)` after step 2 has created the folder at `url`. Only step 2 should keep a made-up failure. The guard then proves that the real move refuses the occupied empty folder, and the claim no longer depends on a stubbed error.
