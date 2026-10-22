# Runde 1 — approver

Workflow `wf_f738a9cc-f68` — Bereich `4c4bd5ad8..5942df4fd` mit den 7 `paths` aus `board.json`, `criteria` 7, `deviceCriteria` [6], `founderAssumptions` 0. Gesamtentscheidung: **APPROVE** — all 7 criteria graded, every code criterion met; 1 device request(s) for the next build's device round. `outsideScope`: leer; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer.

Approver: **APPROVE**. Eigene Zählung der Spec: `specCriteria` 7, `specDevice` [6], `specFounder` 0 — gleich den Zahlen des PM.

## Warum

I counted the committed spec before opening board.json. It has 7 numbered criteria, criterion 6 is the only [DEVICE] one, and no Assumption bullet starts with [FOUNDER]. board.json records base 4c4bd5ad86056afa7044a4bb4e507dbd312d83c7, so the range covers the whole job (one commit, 5942df4fd).

The unscoped changed-file list holds 6 source and test files under EchoelStudio/ plus spec.md and board.json. The job touches no founder-locked file as defined at the base: none of .claude/settings.json, .mcp.json, .claude/hooks/**, .github/workflows/**, project.yml or Resources/iOS/Info.plist, and no CLAUDE.md or .claude/rules file.

Nothing the founder owns is decided here. There is no scope, money, legal, health wording, App Store step or user-data deletion. A4's automatic move of a package left under a name in between is a rename that the spec records and justifies, not a deletion. The new spoken text reuses the existing caption.

CI on head 5942df4fd is green, both jobs of `Echoel Studio` (run 39822259909) and `Echoel Studio (Linux)` (run 39822259249), and all four named guards pass in the Core log. Criterion 6 stays open for the device round. I agree with the reviewers that their minor findings do not block shipping:
- the said-once rule compares the sentence, not the file location
- `isBetweenStem` also accepts lowercase hex
- the step-3 move in the stranded test is stubbed
- the announcement uses default priority
- the failure line says "The song is renamed" even after an Undo or on open

## Abnahme-Kriterien

1. **erfüllt** (code) — When a case-only rename fails at step 2 and on the way back while another package holds the old name, it throws RenameStranded with the package under the name in between, Media/ intact and the other package untouched; when the way back succeeds, the plain error comes back and the package is as before.
   - Beleg: ProjectLibrary.swift (5942df4fd) rename(_:to:moving:): after a failed step 2 it tries `move(between, url)`, then `guard !files.fileExists(atPath: between.path) else { throw RenameStranded(url: between, ...) }`, else `throw error`. Both guards pass in the Echoel Studio run 39822259909, job 119976300434 'Core + DSP + Engine': 'ProjectLibraryTests testAStrandedRenameIsFoundByItsPackageNotItsOldName passed' and 'testACaseRenameThatGoesBackLeavesThePackageAsItWas passed'.
2. **erfüllt** (code) — ProjectLibrary.isBetweenStem recognises the name in between that rename writes and no ordinary name.
   - Beleg: ProjectLibrary.swift: betweenStem(for:) and isBetweenStem(_:) need a non-empty prefix, ' renaming ' and exactly 8 hex characters. The test's negative cases are 'beat', 'Beat renaming', 'renaming 1A2B3C4D', 7 and 9 characters, and non-hex. 'ProjectLibraryTests testTheNameInBetweenIsKnownAgain passed' in run 39822259909.
3. **erfüllt** (code) — SongFileName.stranded() makes every name due, the followed one too; busy still holds it back; followed(_:) and opened(named:) clear it.
   - Beleg: SongFileName.swift: `isStranded` is set by stranded() and cleared in opened(named:) and followed(_:); isDue is `followedName.map { isStranded || $0 != name } ?? false`. 'SongFileNameTests testAStrandedPackageIsOwedEvenUnderItsOldName passed' in run 39822259909.
4. **erfüllt** (code) — DocumentController: the stranded branch calls fileName.stranded(); open(throwing:) marks an in-between package as stranded and reads the open song at currentURL after mayLeaveSong; moveFailed replaces a changed line and never says the same line twice.
   - Beleg: DocumentController.swift (5942df4fd):
- The `catch let stranded as ProjectLibrary.RenameStranded` branch calls `fileName.stranded()` before packageMoved.
- open(throwing:) computes `isOpenSong` before `mayLeaveSong`, then reads `isOpenSong ? (currentURL ?? chosen) : chosen`. In the `another` path it calls `if ProjectLibrary.isBetweenStem(...) { fileName.stranded() }`.
- moveFailed: `guard line != failedMoveLine else { return }; moveSettled(); failedMoveLine = line`.
The App job 'App (iPhone + iPad)' in run 39822259909 passed Build for iOS Simulator, Launch smoke and Build for iOS device (Release).
5. **erfüllt** (code) — RenameSongView: hint on the field, an announcement when the name gets too long, hint on Rename.
   - Beleg: RenameSongView.swift (5942df4fd):
- TextField `.accessibilityHint(caption)`.
- `.onChange(of: isTooLong) { _, tooLong in if tooLong { AccessibilityNotification.Announcement(caption).post() } }`, where caption is 'At most \(Names.maximumLength) characters.' while the name is too long.
- Rename button `.accessibilityHint(isTooLong ? caption : "")`.
The App build is green in run 39822259909.
6. **offen** (device) — [DEVICE] With VoiceOver, type past 128 characters in the Rename Song sheet: VoiceOver says 'At most 128 characters.' and reads Rename as dimmed with the same sentence.
   - Beleg: Needs a device run. Turn VoiceOver on, open Song menu > Rename Song…, paste a text longer than 128 characters, and confirm the announcement is spoken. The announcement is posted at default priority, so check that VoiceOver's own speech for the keystroke or paste does not cut it off. Then focus Rename and confirm it reads as dimmed with the hint 'At most 128 characters.'
7. **erfüllt** (code) — Echoel Studio is green on head with the guards from 1–3 named as passed in the Core log, the App build (Simulator and Release device) is green, and Echoel Studio (Linux) is green too.
   - Beleg: `gh run list --commit 5942df4fd...`:
- Echoel Studio run 39822259909: completed success. Core + DSP + Engine: Test (macOS host) success, 289 tests with 0 failures, all four guards named as passed. App (iPhone + iPad): Build for iOS Simulator, Launch smoke (iOS Simulator) and Build for iOS device (Release) all success.
- Echoel Studio (Linux) run 39822259249: completed success, Test Core (Linux) success.

## Für den Menschen

Nichts.

## Geräte-Bitten

- Kriterium 6: Needs a device run. Turn VoiceOver on, open Song menu > Rename Song…, paste a text longer than 128 characters, and confirm the announcement is spoken. The announcement is posted at default priority, so check that VoiceOver's own speech for the keystroke or paste does not cut it off. Then focus Rename and confirm it reads as dimmed with the hint 'At most 128 characters.'
