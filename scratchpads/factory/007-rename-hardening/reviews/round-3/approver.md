# Runde 3 — approver

Workflow `wf_f7e15ccc-83c` — Bereich `4c4bd5ad8..fdef21abd` (Nacharbeit seit `2e7f68ca0`) mit den 7 `paths` aus `board.json`, `criteria` 7, `deviceCriteria` [6], `founderAssumptions` 0. Gesamtentscheidung: **APPROVE** — all 7 criteria graded, every code criterion met; 1 device request(s) for the next build's device round. `outsideScope`: leer; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer.

Approver: **APPROVE**. Eigene Zählung der Spec: `specCriteria` 7, `specDevice` [6], `specFounder` 0 — gleich den Zahlen des PM.

## Warum

I counted the spec as committed at fdef21abd before opening board.json or any review. It has 7 numbered acceptance criteria. Criterion 6 is the only one tagged [DEVICE]. No Assumption bullet starts with [FOUNDER] (A1–A8 each start with their own ID), so the founder count is 0.

I read the whole diff from base 4c4bd5ad8 to head fdef21abd.
- **Criteria 1–5** are met in code, and the guards named in criteria 1–3 are in the tree.
- **Criterion 7** is confirmed from the CI logs, not taken from the reviewers. On head fdef21abd:
  - Echoel Studio run 39828730749 succeeded. In its Core + DSP + Engine job (119998870157), all four guards are logged as passed, and the log ends with "Executed 182 tests, with 0 failures". Its App (iPhone + iPad) job (119998869920) reports BUILD SUCCEEDED for the Debug simulator build, the simulator launch smoke test and the Release generic/platform=iOS build.
  - Echoel Studio (Linux) run 39828730750 succeeded. In job 119998869533 all four guards pass, out of 161 tests with 0 failures.

**Locked files.** The locked set comes from the base commit 4c4bd5ad8:
- `.claude/settings.json` and `.mcp.json` (PROTECTED_FILES in the hook; PROTECTED_DIRS is empty)
- `permissions.ask`: settings.json, .mcp.json and .claude/hooks/**
- context.md §3: .github/workflows/**, project.yml and Resources/iOS/Info.plist

The unscoped changed-file list touches none of these. It contains only 6 files under EchoelStudio/Core and EchoelStudio/App, plus scratchpads/factory/007-rename-hardening/**.

**Instruction files.** The diff changes no CLAUDE.md, nothing under .claude/rules and nothing under .claude/agents.

**Founder-owned areas.** The job decides nothing in the founder's areas: no scope, money, legal or licence text, health wording, App Store submission or user-data deletion. Its only user-facing change is an English status sentence about a file name, plus VoiceOver hints.

**Board base.** board.json records base 4c4bd5ad86056afa7044a4bb4e507dbd312d83c7, which matches the range under review.

**Open minors.** Two cosmetic minors remain, neither blocking:
- The doc header of SongFileName.swift still says the package follows a change of name "and nothing else". It does not mention the new stranded() exception.
- In the status sentence at DocumentController.swift:677, "rename it" is ambiguous. The PM can fold both into a later touch, updating spec A5 in the same commit, since A5 quotes the sentence word for word.

## Abnahme-Kriterien

1. **erfüllt** (code) — A case-only rename whose second step and way back both fail, while another package holds the old name, throws RenameStranded with the package under the in-between name (keeping Media/) and leaves the other package untouched. If only the second step fails and the way back works, the error itself is thrown and the package is as before. The first guard uses a real move onto the occupied empty folder.
   - Beleg: ProjectLibrary.swift:169 has the internal `moving:` seam. ProjectLibrary.swift:190 checks `guard !files.fileExists(atPath: between.path) else { throw RenameStranded(url: between, ...) }`, so it asks the package rather than the old name. In ProjectLibraryTests, testAStrandedRenameIsFoundByItsPackageNotItsOldName creates the old-name folder at step 2 and uses a real FileManager.moveItem for the way back. It asserts the in-between stem, the Media/take.wav bytes and that the other folder is empty. testACaseRenameThatGoesBackLeavesThePackageAsItWas asserts the error is not RenameStranded and that the directory holds only ["beat.echoel"]. Both guards are logged as passed in Echoel Studio job 119998870157 and in Linux job 119998869533 on fdef21abd.
2. **erfüllt** (code) — isBetweenStem recognises the in-between name that rename writes, and no ordinary name: not 'renaming' without the 8 characters, and not the 8 characters in lower case.
   - Beleg: ProjectLibrary.swift has betweenStem (uppercased prefix(8)) and, at :215, isBetweenStem, which requires a non-empty prefix, an 8-character tail and only 0-9A-F. testTheNameInBetweenIsKnownAgain covers the negatives, including 'renaming 1A2B3C4D', 'Beat renaming', the 7- and 9-character tails, 'XYZ12345' and lower-case hex. It is logged as passed in both Core logs on the head.
3. **erfüllt** (code) — stranded() makes every name due, the followed one too; busy still defers the move; followed(_:) and opened(named:) clear the mark.
   - Beleg: SongFileName.swift:13 declares isStranded, :26 has `isStranded || $0 != name`, :21 and :39 clear it in opened and followed, and :46 is stranded(). testAStrandedPackageIsOwedEvenUnderItsOldName asserts each of these, including shouldMove with busy:true being false. It is logged as passed in both Core logs on the head.
4. **erfüllt** (code) — DocumentController: the stranded branch calls fileName.stranded(); open(throwing:) marks an in-between package as stranded and reads the open song from currentURL after mayLeaveSong; moveFailed says ONE location-only sentence, replaces a standing line when the location changed, and never says the same one twice. Shown by reading the code and by the App build.
   - Beleg: DocumentController.swift at head:
- :648 `fileName.stranded()` in the RenameStranded catch.
- :480 computes isOpenSong before mayLeaveSong, and :482 re-reads `currentURL ?? chosen` after it.
- :498 calls `isBetweenStem(...) { fileName.stranded() }` only on the `another` path, after opened(named:) and moveSettled.
- :506 sets `lastError = failedMoveLine`.
- :677 is the one sentence.
- :679 has `guard line != failedMoveLine else { return }`, followed by moveSettled() before the append, which swaps out the standing line.
- open(_:) quarantines the URL that was actually read.
The App (iPhone + iPad) job 119998869920 reports BUILD SUCCEEDED for both the simulator and the Release iOS build.
5. **erfüllt** (code) — RenameSongView: hint on the field, high-priority announcement on crossing the length limit, hint on Rename, the caption hidden from VoiceOver. Shown by reading the code and by the App build.
   - Beleg: RenameSongView.swift at head:
- :31-35 use `.onChange(of: isTooLong)` on the rising edge to post AttributedString(caption) with accessibilitySpeechAnnouncementPriority = .high.
- :70 puts `.accessibilityHint(caption)` on the field.
- :94 puts `.accessibilityHint(isTooLong ? caption : "")` on Rename.
- :51 marks the caption `.accessibilityHidden(true)`.
The App build is green in job 119998869920.
6. **offen** (device) — [DEVICE] With VoiceOver, type past 128 characters in Rename Song (for example by pasting). The announcement 'At most 128 characters.' is not talked over, and Rename reads as dimmed with the same sentence. Repeat with Speak Hints off: the announcement still comes, and whether the reason for the dimmed Rename is missing is a measurement.
   - Beleg: Code cannot meet this. To check on the next build:
1. With VoiceOver on, open Song > Rename Song… and paste a text longer than 128 characters.
2. Confirm VoiceOver says 'At most 128 characters.' and that the paste echo does not talk over it.
3. Swipe to Rename and confirm it is read as dimmed with the same sentence.
4. Repeat with VoiceOver > Verbosity > Speak Hints off. Confirm the announcement still comes, and note whether the dimmed Rename still gives its reason. If the reason is missing, the caption goes back to being its own element and the field's duplicate hint is removed.
7. **erfüllt** (code) — Echoel Studio is green on the head: the guards from criteria 1–3 pass by name in the Core log, and the App build (simulator and Release device) is green; Echoel Studio (Linux) likewise.
   - Beleg: `gh run list --commit fdef21abd` shows Echoel Studio 39828730749 success and Echoel Studio (Linux) 39828730750 success. Logs via mcp get_job_logs:
- Core job 119998870157: 'Test Case ... testAStrandedRenameIsFoundByItsPackageNotItsOldName ... passed', likewise for testACaseRenameThatGoesBackLeavesThePackageAsItWas, testTheNameInBetweenIsKnownAgain and SongFileNameTests.testAStrandedPackageIsOwedEvenUnderItsOldName; 'Executed 182 tests, with 0 failures'; 'All tests' passed.
- App job 119998869920: '** BUILD SUCCEEDED **' for the Debug generic/platform=iOS Simulator build and for the Release generic/platform=iOS build, plus 'still running 20 s after launch'.
- Linux job 119998869533: all four guards passed; 'Executed 161 tests, with 0 failures'.

## Für den Menschen

Nichts.

## Geräte-Bitten

- Kriterium 6: Code cannot meet this. To check on the next build:
1. With VoiceOver on, open Song > Rename Song… and paste a text longer than 128 characters.
2. Confirm VoiceOver says 'At most 128 characters.' and that the paste echo does not talk over it.
3. Swipe to Rename and confirm it is read as dimmed with the same sentence.
4. Repeat with VoiceOver > Verbosity > Speak Hints off. Confirm the announcement still comes, and note whether the dimmed Rename still gives its reason. If the reason is missing, the caption goes back to being its own element and the field's duplicate hint is removed.
