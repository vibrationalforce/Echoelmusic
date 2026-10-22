# Runde 2 — approver

Workflow `wf_864aabbe-500` — Bereich `4c4bd5ad8..2e7f68ca0` (Nacharbeit seit `5942df4fd`) mit den 7 `paths` aus `board.json`, `criteria` 7, `deviceCriteria` [6], `founderAssumptions` 0. Gesamtentscheidung: **APPROVE** — all 7 criteria graded, every code criterion met; 1 device request(s) for the next build's device round. `outsideScope`: leer; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer.

Approver: **APPROVE**. Eigene Zählung der Spec: `specCriteria` 7, `specDevice` [6], `specFounder` 0 — gleich den Zahlen des PM.

## Warum

I counted the spec at 2e7f68ca0 myself before opening anything else. It has 7 numbered acceptance criteria. Only criterion 6 is tagged [DEVICE], and none of its Assumptions (A1-A8) starts with [FOUNDER].

I read the whole job diff from its base, 4c4bd5ad8..2e7f68ca0. It covers ProjectLibrary, SongFileName, their tests, DocumentController, RenameSongView, and the spec. Every code criterion is met in code:
- When the way back fails, rename now asks whether the package itself is still under the in-between name, instead of checking the old name.
- `isBetweenStem` matches capital hex only, and the writer always writes capitals.
- `stranded()` makes every name due, and `followed` or `opened` clears that.
- `open(throwing:)` marks a package with an in-between name as stranded, and re-reads the open song from `currentURL` after `mayLeaveSong`.
- `moveFailed` says one sentence that names only where the file is. It replaces a stale line and never says the same line twice.
- The VoiceOver hints, the high-priority announcement and the hidden caption are all present.

CI on the head commit is green:
- `Echoel Studio` 39824850887 succeeded. Its Core + DSP + Engine job 119985321955 logs all four guards by name as passed. Its App job 119985322448 succeeded.
- `Echoel Studio (Linux)` 39824850931 succeeded. I could not read its log: the blob download was refused (403).

No file that is founder-locked at the base was changed:
- context.md §3: workflows, project.yml, Info.plist
- the hook's PROTECTED_FILES: .claude/settings.json, .mcp.json
- permissions.ask: settings.json, .mcp.json, .claude/hooks/**

The unscoped diff touches only EchoelStudio Core/App sources and tests and scratchpads/factory/007. It changes no CLAUDE.md or .claude/rules file.

board.json records base 4c4bd5ad86056afa7044a4bb4e507dbd312d83c7, which matches.

Nothing here is the founder's to decide. This is a hardening repair of the already-approved rename door. It deletes no user data, adds no health wording and does not touch App Store submission. A4 does auto-rename a package that has an in-between name, but only within the library, onto a free name.

Two cosmetic notes remain open, neither of which blocks:
- The `stemByteLimit` doc comment still spells the in-between suffix in lower case.
- The UX lens suggests naming what 'tries again' refers to.

Criterion 6 still needs the device run.

## Abnahme-Kriterien

1. **erfüllt** (code) — A change of case whose second step AND way back both fail, while another package holds the old name, throws RenameStranded with the package under the in-between name (Media kept) and leaves the other package alone. If only step 2 fails and the way back works, the plain error is thrown and the package is as before. The way back in the first guard is a real move.
   - Beleg: ProjectLibrary.swift:190 checks the package (`guard !files.fileExists(atPath: between.path) else { throw RenameStranded(...) }`). ProjectLibraryTests.swift:156: only step 2 is stubbed, and the way back is a real FileManager.moveItem onto the empty folder. ProjectLibraryTests.swift:187 covers the way-back case. Both are logged as passed in job 119985321955 of Echoel Studio run 39824850887 on 2e7f68ca0.
2. **erfüllt** (code) — isBetweenStem recognises the in-between name rename writes and no ordinary name (not 'renaming' without the eight characters, not lowercase hex).
   - Beleg: ProjectLibrary.swift:209 writes `.uppercased()`, and :215 accepts only an 8-character tail of 0-9A-F. The test at ProjectLibraryTests.swift:205 includes the negative cases 'beat renaming 1a2b3c4d' and 'renaming 1A2B3C4D'. It passed in job 119985321955.
3. **erfüllt** (code) — SongFileName.stranded() makes every name due, including the followed one; busy still defers it; followed(_:) and opened(named:) clear it.
   - Beleg: SongFileName.swift:13,21,26,39,46-47. The test at SongFileNameTests.swift:35 passed in job 119985321955.
4. **erfüllt** (code) — DocumentController: the stranded branch calls fileName.stranded(); open(throwing:) marks a package with an in-between name as stranded and reads the open song under currentURL after mayLeaveSong; moveFailed says one location-only sentence, replaces a stale line and never repeats the same one.
   - Beleg: DocumentController.swift:648 calls `fileName.stranded()`. :480-482 compute isOpenSong before mayLeaveSong, then `url = isOpenSong ? (currentURL ?? chosen) : chosen`. :498 marks an in-between stem as stranded. :676 is the single sentence, and :678 (`guard line != failedMoveLine`) followed by moveSettled() replaces a stale line. The App job 119985322448 succeeded.
5. **erfüllt** (code) — RenameSongView: hint on the field, high-priority announcement when the limit is crossed, hint on Rename, caption hidden from VoiceOver.
   - Beleg: RenameSongView.swift:31-35 posts the announcement on the rising edge only, as an AttributedString with `accessibilitySpeechAnnouncementPriority = .high`. :51 sets `.accessibilityHidden(true)`. :70 is the field hint. :94 is the Rename hint while too long. The App build in run 39824850887 succeeded.
6. **offen** (device) — [DEVICE] With VoiceOver, type past 128 characters in Rename Song: VoiceOver says 'At most 128 characters.' and Rename reads as dimmed with the same sentence.
   - Beleg: Needs a device run. With VoiceOver on, paste a text over 128 characters into the Rename Song field. Check that the announcement is spoken and is not talked over by the paste echo, and that Rename reads as dimmed with the hint. The UX lens suggests also trying it with Speak Hints off.
7. **erfüllt** (code) — Echoel Studio green on head with guards 1-3 passed by name in the Core log and the App build (simulator and release device) green; Echoel Studio (Linux) green too.
   - Beleg: `gh run list --commit 2e7f68ca0` lists Echoel Studio 39824850887 as success and Echoel Studio (Linux) 39824850931 as success. In the Core job 119985321955 log, all four guards appear as "passed" (289 tests, 0 failures). App job 119985322448 succeeded. I could not read the Linux log (blob 403), so only that run's conclusion is checked.

## Für den Menschen

Nichts.

## Geräte-Bitten

- Kriterium 6: Needs a device run. With VoiceOver on, paste a text over 128 characters into the Rename Song field. Check that the announcement is spoken and is not talked over by the paste echo, and that Rename reads as dimmed with the hint. The UX lens suggests also trying it with Speak Hints off.
