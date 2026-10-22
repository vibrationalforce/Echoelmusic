# Runde 3 — approver

Workflow `wf_9e31f7a2-0a8` — Bereich `1f763674e..99c4835b7` (Nacharbeit seit `840643342`) mit den 10 `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [7], `founderAssumptions` 0. Gesamtentscheidung: **APPROVE** — all 8 criteria graded, every code criterion met; 1 device request(s) for the next build's device round. `outsideScope`: `docs/dev/TODO_FOUNDER_2026-10-19.md`; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer.

Approver: **APPROVE**. Eigene Zählung der Spec: `specCriteria` 8, `specDevice` [7], `specFounder` 0 — gleich den Zahlen des PM.

## Warum

I counted the spec at 99c4835b7 before opening board.json or any reviews. It has 8 numbered acceptance criteria. Only criterion 7 starts with [DEVICE]. None of the Assumption bullets starts with [FOUNDER] (A10 mentions FOUNDER_INBOX inside its text, but it is a WIP-limit note, not a founder decision). board.json records base 1f763674e89b703bf8e988165d326490695ae05e, so the range under review is the whole job.

Locked files: none of the 14 files in the unscoped diff is founder-locked. At the base, the locked set is: .github/workflows/**, project.yml and Resources/iOS/Info.plist (context.md §3), .claude/settings.json and .mcp.json (protect-founder-gated.py PROTECTED_FILES; PROTECTED_DIRS is empty), and .claude/hooks/** (permissions.ask). No CLAUDE.md or .claude/rules file changed. The one file outside the job, docs/dev/TODO_FOUNDER_2026-10-19.md (commit dab7568c7), is a TODO bookkeeping update. Its F-28 change is worded as a session recommendation, not a decision taken.

Founder-owned decisions: the change decides none. No scope, money, legal or health wording, and no store or claims text (the spec explicitly holds back FEATURE_STATUS, CLAIMS and the store text until the device verdict).

Code: the diff matches the spec.
- SongFileName is a pure Core value type.
- ProjectLibrary has renamedURL and rename, with the two-step case-only path and RenameStranded.
- File-name stems are cut to at most 200 bytes of UTF-8.
- DocumentController.saveNow calls followRenamedSong before its unchanged-check. packageIsBusy covers import, export, the media load and takes in flight. Every end of that work calls followRenamedSong again.
- RecordController reports an abandoned take, with its own target.
- The door reuses the single .sheet(item:) slot and is disabled while packageIsBusy.

CI on head 99c4835b7: the Echoel Studio run 39816358103 succeeded. In the Core + DSP + Engine job, every guard named in criteria 1–3 shows as passed by name, and the log ends with 182 tests and 0 failures. In the App job, Build for iOS Simulator, the launch smoke and Build for iOS device (Release) all succeeded. Echoel Studio (Linux) is green too.

The remaining reviewer findings are all minor double-fault edge cases. One more is a wording point in criterion 1: it says the stem stays under 200 bytes in every spelling, but the code holds the base stem to at most 200 bytes, and numbered or in-between spellings can reach up to about 231 bytes. That is still within the 255-byte file-name limit, so the property the criterion protects holds. None of these blocks shipping.

## Abnahme-Kriterien

1. **erfüllt** (code) — ProjectLibrary.renamedURL(for:from:) returns the package itself when its file name already spells the name; otherwise it returns a free spelling that passes other songs and counts its own package as free. The stem stays within the byte budget. Guards: testARenameTakesAFreeNameAndKeepsItsOwn and testAFileNameStaysWithinTheFileSystemLimit.
   - Beleg: EchoelStudio/Core/Sources/EchoelCore/ProjectLibrary.swift (renamedURL, head ~l.145): returns current when lastPathComponent matches, and counts isSameItem as free. fileName(for:) cuts the stem with `while stem.utf8.count > stemByteLimit` (stemByteLimit = 200). Both guards passed by name in Echoel Studio run 39816358103, job Core + DSP + Engine. Wording note: the code holds the BASE stem to at most 200 bytes. A numbered spelling ('base 10000') can be up to 206 bytes and the in-between name up to about 231 bytes. Both stay under the 255-byte file-name limit that A7 names, so the criterion's 'unter 200 in jeder Schreibweise' is slightly stronger than what is built.
2. **erfüllt** (code) — ProjectLibrary.rename(_:to:) moves the whole package (document and Media/), leaves no old folder behind, and a case-only rename leaves exactly one package. Guards: testARenameMovesThePackageWithItsMedia and testACaseOnlyRenameKeepsOnePackage.
   - Beleg: ProjectLibrary.swift rename(_:to:): moveItem of the whole package directory, and a two-step move through '<stem> renaming xxxxxxxx' for a case-only change. Both guards passed by name in run 39816358103. The case-only test asserts that the directory contents are exactly ['Beat.echoel'].
3. **erfüllt** (code) — A pure Core value type decides: a changed name makes the move due; busy defers it; a later quiet write runs it exactly once; another song clears it; a difference that existed at open makes nothing due. Guards in SongFileNameTests.swift.
   - Beleg: EchoelStudio/Core/Sources/EchoelCore/SongFileName.swift is a struct, Equatable and Sendable, with no I/O. All four SongFileNameTests methods passed in run 39816358103 (testAChangedNameIsDueAndMovesOnceAtAQuietWrite, testAMoveWaitsWhileThePackageIsBusy, testAnUndoBackToTheFollowedNameLeavesNothingToDo, testAnotherSongDropsTheMoveAndNothingIsDueBeforeASong).
4. **erfüllt** (code) — DocumentController.saveNow asks the value type BEFORE its unchanged-check, then updates currentURL, the list (refresh) and the launch guard. Import, export/share, the media load and a take count as busy.
   - Beleg: DocumentController.swift:560 calls followRenamedSong() ahead of the `guard currentURL != nil, store.project != savedProject` check. packageMoved sets currentURL, calls noteOpening when quarantine.opening matches, and calls refresh(). packageIsBusy at :606 = isImporting || isExporting || isLoadingMedia || !takesInFlight.isEmpty. followRenamedSong is called again at :688, :770 and :978 (exports and share), :1068 (import), :1119 and :1128 (take abandoned or committed) and :1210 (media load). The App build is green in run 39816358103 (job 'App (iPhone + iPad)').
5. **erfüllt** (code) — The Song menu has 'Rename Song…', which opens StudioSheet.renameSong and is disabled while the package is busy. 'Rename' is disabled for an empty, too long or unchanged name (too long is said), runs .renameProject as one undo step 'Rename Song', and writes at once.
   - Beleg: StudioView.swift:415 has `Button("Rename Song…") { router.sheet = .renameSong }.disabled(documents.packageIsBusy)`, and :51 has `case .renameSong: RenameSongView()` in the single .sheet(item:). StudioRouter.swift adds `case renameSong`. RenameSongView.swift: canRename = !trimmed.isEmpty && !isTooLong && trimmed != store.project.name, and the caption 'At most 128 characters.' appears when too long. DocumentController.swift:595 runs `store.perform([.renameProject(name:)], title: "Rename Song")` followed by saveNow(). The App build is green on the head.
6. **erfüllt** (code) — RecordController reports an abandoned take with ITS target (start failed, no take came back), so a failed take never holds the move forever and never frees another take that is still running.
   - Beleg: RecordController.swift:121 calls documents.takeAbandoned(file) in the beginTake catch. :143 calls takeAbandoned(pending.file) when endTake returns nil. DocumentController keeps takesInFlight as a Set<MediaID>: newTakeTarget inserts the id, takeAbandoned (:1117) and commitTake's defer (:1128) remove only that id.
7. **offen** (device) — [DEVICE] On an iPhone: rename the open song. The header shows the new name at once, Open lists it, the Files app shows the package under it, and the song reopens with its audio after a relaunch. Undo restores the old name in all three places.
   - Beleg: Code cannot meet a device criterion. To check on device: rename via Song menu → 'Rename Song…'; confirm the header, the Open list (with checkmark) and the Files app show the new name; relaunch and confirm the song opens with its audio; then Undo and confirm the header, the Open list and the Files package name revert after the next save.
8. **erfüllt** (code) — The Echoel Studio workflow is green on the head: the guards from 1–3 pass by name in the Core log, and the App build (Simulator and Release device) is green.
   - Beleg: `gh run list --commit 99c4835b7...` shows Echoel Studio run 39816358103 = success (an earlier run 39815611610 was cancelled and superseded) and Echoel Studio (Linux) 39815611487 = success. In the Core + DSP + Engine job log, all 8 guards from criteria 1–3 have 'passed' lines, and the log ends with 'Executed 182 tests, with 0 failures'. In the App (iPhone + iPad) job, head_sha is 99c4835b7, and 'Build for iOS Simulator', 'Launch smoke (iOS Simulator)' and 'Build for iOS device (Release)' are all success.

## Für den Menschen

Nichts.

## Geräte-Bitten

- Kriterium 7: Code cannot meet a device criterion. To check on device: rename via Song menu → 'Rename Song…'; confirm the header, the Open list (with checkmark) and the Files app show the new name; relaunch and confirm the song opens with its audio; then Undo and confirm the header, the Open list and the Files package name revert after the next save.
