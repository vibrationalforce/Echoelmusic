# Runde 2 — ux

Workflow `wf_ac2238b4-7c1` — Bereich `1f763674e..840643342` (Nacharbeit seit `963758fb2`) mit den 10 `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [7], `founderAssumptions` 0. Gesamtentscheidung: **REWORK** — . `outsideScope`: `docs/dev/TODO_FOUNDER_2026-10-19.md`; `sensitiveOutside`, `lockChanged`, `judgeChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

UX/claims lens, round 2 of job 006 (rename song). I checked all five round-1 UX findings in 1f763674e..84064334 and all five are fixed. m2: the failure line is added next to an existing lastError instead of replacing it (DocumentController.swift:652). m5: "Rename Song…" is disabled while packageIsBusy (StudioView.swift:415-416), so a rename made through the sheet moves the file at once and its caption "Its file in the Files app is renamed too." is true. That caption holds for this build: project.yml sets UIFileSharingEnabled and LSSupportsOpeningDocumentsInPlace, and the library lives in Documents (DocumentController.swift:153-155). m6: a too-long name gets the caption "At most 128 characters." in the record colour, about 5.1:1 contrast on the 0.07 background. The sheet counts characters the same way as Names.validated. m7: a failed move is now retried at every write. m8: autocorrection is off and the field has a 44 pt clear button labelled "Clear name". The new sheet also follows the house rules: label above the input, radius 8, solid surface with a 1 px border, Dynamic Type text styles only, dark scheme like the other sheets, no animation, no flashes, no health, wellness or esoteric wording. The spec keeps FEATURE_STATUS, CLAIMS and the store text unchanged until the device check, which is correct. I found no blocker or major problem. Three minor points remain, all about wording or explanation.

## Befunde

1. **minor** · `EchoelStudio/App/Documents/DocumentController.swift`:621
   - Befund: When a later write retries the move and succeeds, the success branch only resets failedMoveSaid. It does not remove the failure line it added to lastError at line 652. The status strip therefore keeps saying "…its file keeps the name X for now; Echoel tries again when it next saves." after the file has already been renamed, until Play or another song clears lastError. A sentence on screen becomes untrue.
   - Vorschlag: On a successful move after a failed one, remove the line that moveFailed added (or set lastError to what stood before it), so only the line that was true stays.
2. **minor** · `EchoelStudio/App/Documents/DocumentController.swift`:650
   - Befund: In the RenameStranded path, moveFailed is called with stranded.url, so the line reads "its file keeps the name Beat renaming 1a2b3c4d". The file never had that name; it was just moved there. "keeps" is wrong for that case.
   - Vorschlag: Pass whether the package moved, and for the stranded case say e.g. "…its file is called <between name> for now; Echoel tries again when it next saves."
3. **minor** · `EchoelStudio/App/Views/StudioView.swift`:416
   - Befund: "Rename Song…" is greyed out with no reason while packageIsBusy. Exports, imports and takes show their own state on screen, but the media load after opening a song with audio (isLoadingMedia) shows nothing. A first-time user can open the Song menu right after launch or a song switch and find Rename disabled with no explanation. The same applies to VoiceOver, which only says "dimmed".
   - Vorschlag: Optional: add an accessibilityHint or a short status line while the song's audio loads (e.g. "Loading the song's audio…"), so the disabled door has a visible reason.
