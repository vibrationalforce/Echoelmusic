# Runde 2 — security-agent

Workflow `wf_864aabbe-500` — Bereich `4c4bd5ad8..2e7f68ca0` (Nacharbeit seit `5942df4fd`) mit den 7 `paths` aus `board.json`, `criteria` 7, `deviceCriteria` [6], `founderAssumptions` 0. Gesamtentscheidung: **APPROVE** — all 7 criteria graded, every code criterion met; 1 device request(s) for the next build's device round. `outsideScope`: leer; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

Security and privacy lens, round 2 of job 007, covering 4c4bd5ad8..2e7f68ca0. The rework since round 1 is 5942df4fd..2e7f68ca0.

Earlier findings: my one round-1 minor is fixed. In ProjectLibraryTests.swift:163-173, only step 2 now fails, with the made-up error at line 170. Step 1 and the way back are the real FileManager.moveItem (line 172), and the way back runs onto the EMPTY folder that step 2 creates at the old name. If the move replaced that folder the way POSIX rename(2) does, rename would throw the plain error rather than RenameStranded. That error would escape `catch let stranded as` and fail the test. So the guard now proves the property the whole protection rests on. Measured, not inferred: the Core job of Echoel Studio run 39824850887 (job 119985321955, macOS) logs `testAStrandedRenameIsFoundByItsPackageNotItsOldName passed`, along with the other three guards (289 tests, 0 failures). Echoel Studio (Linux) run 39824850931 is also success. I could not read the Linux log: the blob download was refused by the proxy. The other eight round-1 minors are all marked as addressed in reviews/round-1/rebuttal.md, and I checked each against the code:
- one sentence that names only where the file is (DocumentController.swift:676)
- capital letters only (ProjectLibrary.swift:209 and :219, with the new lowercase negative case in the test)
- high-priority announcement (RenameSongView.swift:32-35)
- the caption is `accessibilityHidden` (RenameSongView.swift:51)

The spec's A4, A5 and A8 and criteria 1, 2, 4 and 5 were updated to match.

New security checks on the whole job:
1. Rollback race. rename asks the PACKAGE (`files.fileExists(atPath: between.path)`, ProjectLibrary.swift:190) and no longer the old name. An import that reserves the old name off the main thread can therefore no longer make DocumentController write into another song's package.
2. Path confinement is unchanged. The canonical-parent check is still there, every target is the library directory plus a stem cleaned by fileName(for:), and moveItem never overwrites. The internal `moving:` seam is reachable only from @testable tests.
3. The A4 auto-rename trigger is narrower now that only capital hex counts (ProjectLibrary.swift:219). A crafted AirDrop or Files package named `X renaming 1A2B3C4D` is still only renamed to its sanitised inner name, inside the library, onto a free name (renamedURL skips taken names, including case-insensitive matches). An inner name equal to the between stem returns the same URL, and followed() clears the flag, so there is no loop. No package that shipped earlier could carry a lowercase tail: UUID.uuidString is uppercase on Darwin and Linux.
4. Untrusted text in the UI. The new status line still puts the package's file stem in it (DocumentController.swift:676, which was already the case before). StudioView renders it with `Text(document)` from a String variable, so it shows verbatim with no Markdown or format interpretation. The log line still carries only the error's domain and code (public), with no song or file name.
5. VoiceOver. The announcement, the hints and the hidden caption use fixed text with no song name, so nothing private reaches speech beyond what is already on screen.
6. The diff adds no entitlements, Info.plist, network, permission or egress code, so App Store 5.1.x is unaffected. There are no secrets in the added lines, including board.json and the review files. It does not touch .claude/workflows, .claude/agents, any CLAUDE.md or .claude/rules.

No blocker, major or minor finding through this lens. One cosmetic note, which is not a security finding: the stemByteLimit doc comment (ProjectLibrary.swift:244) still spells the between suffix in lower case. The byte count is the same, so the limit still holds.

## Befunde

Keine.
