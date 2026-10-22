# Runde 1 — code-reviewer

Workflow `wf_b6a5d286-f55` — Bereich `1f763674e..963758fb2` mit den 10 `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [7], `founderAssumptions` 0. Gesamtentscheidung: **REWORK** — . `outsideScope`: leer; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **CHANGES**.

## Zusammenfassung

Round 1, code lens. There were no earlier reviews (reviews/ is empty). The Core side checks out. renamedURL counts the song's own package as free and handles a case-insensitive volume through isSameItem. rename() does a case-only change in two steps, puts the package back if the second step fails, and retries the move when another write (the earlier-songs import's mkdir-first reservation) takes the target name first. SongFileName and its tests match criterion 3. The controller wiring matches criteria 4–6: the move check runs before the unchanged check in saveNow, it re-runs at the end of every import, export, share and media load, and the quarantine name is carried over to the new file name. The view uses Theme tokens that exist, the router case is added to the only switch over StudioSheet, and the checkmark now compares standardized paths.

One major defect. The new busy flag `takeInFlight` is a single Bool, but two take lifecycles can overlap: RecordController.record() only checks `isRecording`, and stopRecording clears that flag before it awaits endTake and commitTake. So one take can clear the flag while another still owns the package. A pending rename then moves the package, and that take is decoded from the old path and lost.

Two minor items:
1. A rename that lands on a held song's freed name does not release the hold. The new-write path does this with releaseHold.
2. A failed move can overwrite the export result line. This is cosmetic.

## Befunde

1. **major** · `EchoelStudio/App/Documents/DocumentController.swift`:1062
   - Befund: `takeInFlight` is a single Bool. It is set by every newTakeTarget (line 1055) and cleared by every takeAbandoned (1062) and every commitTake defer (1071), so one take's lifecycle can clear it while another take still owns the package. RecordController.record() guards only on `isRecording`, which stopRecording sets to false (RecordController.swift:135) before it awaits engine.endTake() and documents.commitTake(). Two scenarios follow.

(a) The user renames during take 1, so the move is deferred, as A4 intends. They then tap Stop and immediately Record. The second record() calls newTakeTarget, and AudioEngine.beginTake throws because `takeEnding` is still true. RecordController.swift:121 calls takeAbandoned(): the flag goes false and followRenamedSong() moves the package while take 1's TakeWriter is still finishing and before commitTake runs. commitTake then decodes `take.url`, the old path, which no longer exists. It reports "The take could not be read." and take 1 is never placed in the song; its .caf is left orphaned in the moved package's Media/.

(b) Take 2 is started while take 1's commit is still decoding off the main thread. Take 1's commitTake defer clears the flag while take 2 is recording. A rename during take 2 then moves the package under the open AVAudioFile, and take 2 is lost the same way.

This is a data-loss path that the busy rule exists to prevent, and it was introduced by this diff.
   - Vorschlag: Track takes that are in flight per take rather than with one Bool. Either keep a counter (increment in newTakeTarget, decrement in takeAbandoned and in commitTake's defer, busy while > 0), or keep a Set<MediaID> keyed by TakeTarget.id, with takeAbandoned(target) and commitTake removing only their own id. RecordController.swift:121 and :142 then pass the target they abandon.
2. **minor** · `EchoelStudio/App/Documents/DocumentController.swift`:613
   - Befund: A successful move can give the open song the file name of a held (quarantined) song that was deleted in Files: renamedURL hands out the freed name, just as newURL does. The new-package write path releases such a hold (`if isNew { releaseHold(on: url) }`, line 567). followRenamedSong does not, so at the next launch restore() skips the renamed song as held and shows a note saying it crashed the app.
   - Vorschlag: After `currentURL = moved`, call `releaseHold(on: moved)`. The hold was for the deleted song, not for the name.
3. **minor** · `EchoelStudio/App/Documents/DocumentController.swift`:632
   - Befund: followRenamedSong() runs in the export and share `defer` blocks after the success branch has set `lastError` (for example "Exported without …"). A move that fails there replaces the export's outcome line with the rename line, so the result of the export the user just made is no longer shown. That is the same class of problem the review-2026-10-21/22 comments guard against elsewhere in this file.
   - Vorschlag: Optional: when lastError is already set, append the rename failure line to it instead of replacing it, or give the rename failure its own status line.
