# Runde 2 — security-agent

Workflow `wf_ac2238b4-7c1` — Bereich `1f763674e..840643342` (Nacharbeit seit `963758fb2`) mit den 10 `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [7], `founderAssumptions` 0. Gesamtentscheidung: **REWORK** — . `outsideScope`: `docs/dev/TODO_FOUNDER_2026-10-19.md`; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **CHANGES**.

## Zusammenfassung

Security and privacy review, round 2 of job 006 (rename song), 1f763674e..84064334. Both round-1 security findings are fixed. m3 is fixed: ProjectLibrary.rename throws RenameStranded(url:underlying:) when the rollback of a case-only rename also fails (ProjectLibrary.swift:178-186), and followRenamedSong follows the package to the in-between name instead of writing a second package (DocumentController.swift ~624-629). m4 is fixed for the new line: moveFailed logs only the NSError domain and code as public (DocumentController.swift:646). The older save-failed line at :578 still logs localizedDescription, which includes the path, as public. The rebuttal says that line predates the job, and I accept that; it is not re-raised.

Other security checks came out clean:
- **Paths:** paths cannot escape the library folder. rename checks the canonical parent folder (:165-168), and every target is built from `directory` plus a fileName(for:) stem with / \ : and control or format characters replaced and outer dots trimmed. No hidden files or `..` can result.
- **No overwrites:** moveItem never overwrites, and renamedURL skips spellings that are taken.
- **Crash guard:** a rename cannot release the hold on a quarantined (crash-on-open) song, because holds() matches exactly and a taken name is never chosen.
- **Assistant:** the on-device model cannot rename the song. AgentAction has no project-rename case; only renameTrack.
- **Nothing new leaves the device:** no entitlement, Info.plist, network, OSC or MIDI change.

One new major finding: the door validates by character count, but the file system limits each name component by bytes or code units, so a valid name can trap the unwritten starter song in a state where it can't be saved.

## Befunde

1. **major** · `EchoelStudio/App/Documents/DocumentController.swift`:614
   - Befund: Typed text now becomes the package's path component, and nothing bounds it to the file-system limit. Names.validated (Command.swift:131) and RenameSongView.canRename count Characters (≤128). ProjectLibrary.fileName(for:) (ProjectLibrary.swift:223) cuts at prefix(100) Characters. One Character can carry any number of scalars (ZWJ emoji, flags, skin tones, combining marks, a pasted Zalgo string), so a name that passes the door can produce a stem far over NAME_MAX (255). For the unwritten launch starter (first launch, or after a crash, before any edit), followRenamedSong's unwritten branch sets currentURL = library.newURL(for: name) to that too-long path (:614). Every library.write then fails in createDirectory. saveNow returns false at every autosave ('Could not save. Your changes are still open.'), and mayLeaveSong (:508-519) refuses to open any other song. The user is stuck in a song that can neither be saved nor left until they guess Undo or a shorter name; the app ending loses all the work. For a written song the move fails at every save instead (harmless, but permanent). The case-only in-between name (ProjectLibrary.swift:175) adds ' renaming XXXXXXXX' to a stem that may already be near the limit. Before this diff a package name came only from starter names and already-valid adopted file names, so this exposure is new.
   - Vorschlag: Bound ProjectLibrary.fileName(for:) by a file-system budget rather than Characters: drop whole Characters from the end until the stem's utf8.count is at most about 200 bytes, which leaves room for ' 10000', ' renaming XXXXXXXX' and '.echoel' under 255 in any counting unit. Add a Core test: a name of 100 multi-scalar Characters (for example a family emoji or a letter with combining marks, repeated) gives fileName(for:).utf8.count ≤ 200, and newURL and rename on it succeed.
