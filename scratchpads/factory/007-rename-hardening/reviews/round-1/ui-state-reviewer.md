# Runde 1 — ui-state-reviewer

Workflow `wf_f738a9cc-f68` — Bereich `4c4bd5ad8..5942df4fd` mit den 7 `paths` aus `board.json`, `criteria` 7, `deviceCriteria` [6], `founderAssumptions` 0. Gesamtentscheidung: **APPROVE** — all 7 criteria graded, every code criterion met; 1 device request(s) for the next build's device round. `outsideScope`: leer; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

UI State Audit, round 1 of job 007. No earlier reviews exist for this job (the reviews/ directory is absent), so this is round 1. Files I opened at 5942df4fd: RenameSongView.swift (whole file), DocumentController.swift (lines 1-130 and 400-700, plus restore() at line 202 calling open(throwing:)), StudioView.swift (the presentation site, unchanged), and the Core diff for SongFileName and ProjectLibrary.

Hot reads in a menu host or its parents: none added. RenameSongView's new .onChange(of: isTooLong) reads only @State `name` through a computed property. The new DocumentController paths write `lastError` only on open, move or failure, never at a per-tick rate. The sheet hosts no menu Picker. Its parent StudioView is untouched.

Presentation chain: unchanged. StudioView still has one .sheet(item: $router.sheet), and RenameSongView is one case of it. The diff adds no .sheet, .fullScreenCover, .alert or .fileImporter. The new .onChange sits on the form inside the NavigationStack and is not a presentation modifier. No two modals are driven at once.

@Observable: DocumentController keeps @MainActor @Observable. The new state (fileName.isStranded) lives inside an @ObservationIgnored struct. failedMoveLine stays @ObservationIgnored, and the visible effect still goes through the observed `lastError`. Environment: RenameSongView still reads the injected DocumentController and ProjectStore; nothing new is reached through a global. Navigation: the existing NavigationStack has no links, and the diff does not change navigation.

State flow I checked:
- open(throwing:) decides isOpenSong before mayLeaveSong and reads currentURL after it, so a move done by the save just before is respected. The re-opened open song keeps `another == false` and so keeps its owed move and its line (`lastError = failedMoveLine`). For another song, moveSettled() runs first, so lastError is still cleared as before.
- restore() also goes through open(throwing:), so a package left under the in-between name by a crash is marked stranded at launch, as A4 asks.
- moveFailed now replaces a standing line whose text changed (moveSettled, then append) and still says an identical line only once.
- AccessibilityNotification needs iOS 17; the Studio floor is iOS 18 (Core/Package.swift `.iOS(.v18)`).

No blocker or major finding through this lens. Two minor findings follow; none is device-verified, and criterion 6 still needs the device.

## Befunde

1. **minor** · `EchoelStudio/App/Views/RenameSongView.swift`:30
   - Befund: The length announcement is posted at default priority, in the same update that the 129th character (or the paste) lands. VoiceOver's own key echo or paste feedback comes right after it and can interrupt a default-priority announcement, so the [DEVICE] check in criterion 6 may hear nothing. This is plausible, not measured; only a device run can settle it.
   - Vorschlag: If the device run in criterion 6 does not hear the sentence, post it with high priority: `var s = AttributedString(caption); s.accessibilitySpeechAnnouncementPriority = .high; AccessibilityNotification.Announcement(s).post()`. If the run hears it as written, leave it.
2. **minor** · `EchoelStudio/App/Documents/DocumentController.swift`:675
   - Befund: A new path reaches the move-failure line. A song opened from a package left under the in-between name is marked stranded (line 498, A4). If its next move then fails, moveFailed says "The song is renamed, but its file keeps the name <stem> renaming 1A2B3C4D for now…". In this session the musician renamed nothing: the name was left behind by an earlier crash or failed move. The line stays roughly true (the song's name and its file differ), but it reports a rename the musician did not make here.
   - Vorschlag: Optional: when the move owed came from an open (not a rename in this session), use wording that does not claim a rename, e.g. "The song's file is called <file> for now; Echoel tries again when it next saves." Or note in the spec that the existing line covers this case.
