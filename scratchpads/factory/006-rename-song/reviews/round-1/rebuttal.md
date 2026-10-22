# Job 006, round 1 — what the rework does with each finding

Round 1: `wf_b6a5d286-f55` on `1f763674e..963758fb2` — REWORK, one major (code-reviewer), eight
minors across four lenses. The first call (`wf_65a4a4d0-efb`) was INVALID because `job` carried
the folder path instead of the id; no reviewer ran then.

| # | Lens | Finding | Outcome |
|---|---|---|---|
| M1 | code-reviewer (major) | `takeInFlight` was one Bool, so one take's end (an abandoned second start while the first is still ending, or a commit while the next take records) freed the package under the other take. | FIXED. `takesInFlight: Set<MediaID>`: `newTakeTarget` inserts its id, `takeAbandoned(_ target:)` and `commitTake`'s `defer` remove only their own. `RecordController` passes the target it gives up (`record()` catch, `stopRecording` when no take came back). |
| m1 | code-reviewer | A move onto a held song's freed name kept the hold, so the next launch would skip the renamed song as held. | FIXED. `packageMoved` calls `releaseHold(on: moved)`, as the new-package write path does. |
| m2 | code-reviewer, ux | A failed move in an export or share `defer` replaced that work's own line. | FIXED. The failure line is added beside an existing `lastError`, never over it. |
| m3 | security-agent | A case-only rename whose rollback also fails left the package under the in-between name while `currentURL` stayed on the old path, so the next write made a second package without the audio. | FIXED. `ProjectLibrary.rename` throws `RenameStranded(url:underlying:)` when the package is not back under its old name; `followRenamedSong` follows it there, says so once, and the next write tries the move again. Not testable without forcing two consecutive move failures; read in code. |
| m4 | security-agent | The new log line wrote the move error's description (both song names) as public. | FIXED for the new line: domain and code public, no description. The sibling lines (open, save, import) are older and stay as they are; not this job's. |
| m5 | ux | The caption "Its file in the Files app is renamed too." was unconditional, but a move that waits could be dropped by a song switch, or by the app ending. | FIXED by closing the gap rather than qualifying the sentence: the door is disabled while `packageIsBusy`, so a rename through the door moves at once. Only an Undo or Redo during busy work can still wait (spec A4, A9 now say so). |
| m6 | ux | A name over 128 characters greyed Rename out without a reason. | FIXED. The caption says "At most 128 characters." in the record colour while the name is too long. |
| m7 | ux | A failed move offered no way to retry (Rename is disabled for the unchanged name). | FIXED differently: the move is no longer given up. It is said once and tried again at every write (spec A7). |
| m8 | ux | Autocorrection on, and Done both accepts a correction and submits; no quick way to clear the prefilled name. | FIXED. `.autocorrectionDisabled()` and a clear button (44 pt, "Clear name"). Select-all on focus is not done: it needs `TextField(text:selection:)`, and without a compiler here one more unproven API in a fresh view is the wrong trade; the clear button gives the same quick start. |
| m9 | ui-state-reviewer | The sheet renamed whichever song was open when Rename was tapped; a song arriving from Files while it was up got the other song's name. | FIXED. `songsOpened` is observed now; the sheet keeps the count it opened with, closes when it changes, and `rename()` refuses a mismatch. |
| m10 | ui-state-reviewer | A finished export took the one sheet slot from the rename sheet and dropped the typed name. | FIXED by the same door gate as m5: the rename sheet cannot open while an export or share runs, and nothing can start one while the sheet is up. |

Not changed: Core tests. `SongFileName`'s rules are unchanged (it only stops being told "followed"
after a failure), so its four tests still describe it. The per-take set and the door gate live in
the app, which has no test target; they are read in code and built by `Echoel Studio`.
