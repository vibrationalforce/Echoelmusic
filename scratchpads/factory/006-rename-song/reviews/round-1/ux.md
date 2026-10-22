# Runde 1 — ux

Workflow `wf_b6a5d286-f55` — Bereich `1f763674e..963758fb2` mit den 10 `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [7], `founderAssumptions` 0. Gesamtentscheidung: **REWORK** — . `outsideScope`: leer; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

UX/claims lens, round 1. There were no earlier reviews to check: scratchpads/factory/006-rename-song/reviews/ is empty and is not in the tree at 963758fb2.

Every new visible sentence was checked against the code:
- "Rename Song…", "Rename Song" (title and undo step, which shows as "Undo Rename Song"), "Name", "Song name", "Cancel", "Rename".
- "Its file in the Files app is renamed too." The Files app shows the app's Documents folder: project.yml sets UIFileSharingEnabled and LSSupportsOpeningDocumentsInPlace, and DocumentController.defaultDirectory is the Documents directory.
- "Could not rename the song." and "The song is renamed, but its file keeps the name X." Both appear in the StudioView status line through documents.lastError.

No health, wellness or esoteric wording.

Uncodixfy is followed: Theme.Radius.medium is 8, the border is 1 px, the fill is solid and there is no blur or glassmorphism. The field copies the existing AgentView input style, and the sheet follows the house NavigationStack, inline title and .preferredColorScheme(.dark) pattern. EchoelValueField does not apply (text, not a number).

Dynamic Type works because Theme.Font uses system text styles and the sheet has no fixed frames. Contrast of textSecondary (0.60) on the 0.07 background is above AA. Nothing animates or flashes.

The header (SongMenu label) and its VoiceOver label read store.project.name, so they update at once. The Open-menu checkmark fix (comparing standardized paths) is a real improvement for the musician.

ProjectLibrary.fileName removes leading dots, so a name like ".x" cannot create a hidden package that would vanish from Open and from the Files app.

The findings are all minor:
- The caption is stated without a condition, and in two corners it silently stops being true.
- A name that is too long, or a move that failed, leaves the button greyed out with no next step.
- The field does not turn off autocorrection or select the old name.

## Befunde

1. **minor** · `EchoelStudio/App/Views/RenameSongView.swift`:42
   - Befund: The caption "Its file in the Files app is renamed too." is stated with no condition, but in two corners the file silently keeps its old name and no message appears. In both, the header shows the new name while the Open list, the Files app and every export (openSongName is the file stem) keep the old one.

(a) Spec A9: a move that waits on busy work is dropped when another song opens. Busy work means an export, a whole audio take (takeInFlight runs from newTakeTarget until the commit) or a media load. "Rename Song…" is not disabled during any of these.

(b) Not stated in the spec: the app ends before that busy work finishes. SongFileName lives only in memory. On relaunch, opened(named:) adopts the new inner name, and under A3 the difference never becomes due again.
   - Vorschlag: Make the sentence conditional, or close the gap. Option one: when SongFileName is still due while a song is being replaced (DocumentController open/newSong), set lastError to the same "keeps the name X" line. Option two: add one clause to A9 and to the caption, e.g. "…is renamed too once nothing is recording or exporting."
2. **minor** · `EchoelStudio/App/Views/RenameSongView.swift`:63
   - Befund: The field accepts any length, and canRename quietly fails once the trimmed name passes Names.maximumLength (128). A musician who pastes a long title sees a greyed-out "Rename" and is not told why.
   - Vorschlag: Show a short caption when trimmed.count > Names.maximumLength (e.g. "At most 128 characters."), or clip the binding to the limit.
3. **minor** · `EchoelStudio/App/Documents/DocumentController.swift`:619
   - Befund: After a failed move, the message "The song is renamed, but its file keeps the name X." offers no way to retry. The sheet greys out Rename for the unchanged name (RenameSongView.swift:64), and renameSong returns early for it (DocumentController.swift:582). The only retry is to rename to some other name and then back. Separately, this assignment runs inside the export, import and take defers, so it can overwrite that work's own message (e.g. "Exported without …").
   - Vorschlag: Add the next step to the sentence (e.g. "…keeps the name X. Rename it again to retry."). Make the sheet's Rename allow the current name while the package name differs from it.
4. **minor** · `EchoelStudio/App/Views/RenameSongView.swift`:33
   - Befund: Typing in the name field is awkward. Autocorrection is on, and the Done key both accepts a pending correction and submits (onSubmit renames and dismisses at once). A made-up song name can therefore be committed, and moved on disk, as the corrected word before the user sees it. Also, the old name is prefilled but not selected and there is no clear button, so a full rename means deleting it character by character.
   - Vorschlag: Add .autocorrectionDisabled() to the TextField and select all of the prefilled text on focus (or add a clear button), as the iOS Files rename does.
