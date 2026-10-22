# Job 006, round 2 — what the rework does with each finding

Round 2: `wf_ac2238b4-7c1` on `1f763674e..840643342` (since `963758fb2`) — REWORK, one major
(security-agent), five minors. code-reviewer, ux and ui-state-reviewer PASS. All round-1 findings
were confirmed fixed by the lenses that raised them.

`outsideScope` listed `docs/dev/TODO_FOUNDER_2026-10-19.md`: that is commit `dab7568c7` (the
external review rounds renumbered), which landed on the same branch inside the job's range. It is
not part of this job and is not changed by it.

| # | Lens | Finding | Outcome |
|---|---|---|---|
| M1 | security-agent (major) | The door counts characters (≤128) and `fileName(for:)` cut at 100 characters, but one character can carry many scalars, so a valid name could make a stem far over the 255 bytes a file name may have. The unwritten starter then could never be written, and every write failed. | FIXED. `ProjectLibrary.fileName(for:)` cuts whole characters from the end until the stem is at most `stemByteLimit` = 200 bytes of UTF-8 (room for " 10000", " renaming 1a2b3c4d" and ".echoel"), then trims a trailing space or dot. A single character too big for any file name gives "Untitled". New Core test `testAFileNameStaysWithinTheFileSystemLimit` (a letter with four marks ×100 = 900 bytes, a waving hand with a skin tone ×100 = 800 bytes, one character of 601 bytes): stems ≤200 bytes, the package is written and renamed, one song in the list. |
| m1 | code-reviewer | `failedMoveSaid` stayed true after an Undo took the name back, so a later failed rename said nothing. | FIXED. When nothing is owed (`isDue` false), `moveSettled()` clears the failure. |
| m2 | code-reviewer | Reopening the SAME song ran `opened(named:)` with the new name from its document, dropping an owed move. | FIXED. `open(throwing:)` calls `opened`/`moveSettled` only for another song; the same song read again keeps what it owes. Spec A9 says so. |
| m3 | ux | After a retry succeeded, the failure line stayed on screen, now untrue. | FIXED. The line is kept in `failedMoveLine`; `moveSettled()` removes exactly that line from `lastError` and leaves the rest. |
| m4 | ux | In the stranded case the line said "keeps the name <in-between name>", which the file never had. | FIXED. `moveFailed(_:fileNow:moved:)` says "its file is called X for now" when the package moved to the in-between name. |
| m5 | ux (optional) | "Rename Song…" is greyed out during the media load with no visible reason. | NOT CHANGED. The load takes seconds after a song opens; a status line for it would be a new surface, and the other three busy states (import, export, take) already show their own state. Kept as a known small cost of the door gate. |
