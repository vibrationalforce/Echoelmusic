//
//  SessionController.swift
//  Echoelmusic — Restructure A1, step 1 (founder 2026-10-04, wörtlich: „Verbinde anschließend A1
//  SessionController als eindeutigen Besitzer des Ablaufs für Öffnen, Sichern und Abspielen.
//  Verwende die bestehenden kanonischen Zustände. Speicherfehler müssen sichtbar ankommen; ein
//  fehlgeschlagenes Sichern darf keinen stillen Projektverlust verursachen.")
//
//  ⭐ THE ONE RULE OVER EVERY STEP THAT REPLACES THE PIECE IN FRONT. Open and New piece both
//  rescue the live piece first (`autosaveTake`) and then overwrite it — and the overwrite
//  writes THROUGH: `TimelineStore.replaceDocument` flushes `timeline.json` at once and
//  `ClipStore.replaceSlots` persists the grid. Until this type, neither step asked whether the
//  rescue had reached the disk. A failed library write leaves the rescued row only in
//  `ProjectStore`'s memory (`pendingProjects`), so the old song's last copy on disk was
//  replaced by the new one while its only other copy lived in RAM — quit or crash before
//  "Retry save", and the piece was gone without a word.
//
//  The canonical state is `ProjectStore.hasPendingSave` (`saveError != nil`), not a second
//  flag: the store already owns the failure, the banner (`ProjectSaveStatusView`) already shows
//  it, and "Retry save" already clears it. This type only decides what a pending save MEANS for
//  a replacing step: the step is refused, nothing is replaced, and the refusal says why in
//  words — next to the row the player tapped.
//
//  ⚠️ SCOPE, stated so nobody reads more into it: this type owns the OPEN/SAVE half (step 1 the
//  replacement gate, step 2 the song that cannot be saved, step 3 `WorkingCopyStatusView`). The
//  PLAY/STOP half already has one owner and stays there — `ProjectTransport` derives the run state
//  from the canonical flags and routes the ONE Stop and the head's resume. Step 4 FENCED it instead
//  of moving it: `TheClockIsStartedAndStoppedAtNamedPlacesTests` lists every direct start/stop of
//  the clock, so a second play/stop truth cannot appear unannounced. Moving it here would rename
//  seven guarded call sites without changing a behaviour.
//  ⚠️ LIMIT: while a save stays pending (storage full), Open and New piece stay refused. That
//  is deliberate — the alternative is the silent loss this type exists to stop — and the way
//  out is the one the banner already offers: free storage, then "Retry save".
//

import Foundation

enum SessionController {

    /// The steps that put another piece in front of the player.
    enum Replacement: Equatable, Sendable {
        case open
        case newPiece
    }

    /// nil = the step may replace the piece. A sentence = refuse, change nothing, show it.
    /// Ask AFTER the rescue ran: a rescue that failed right now is the case that matters most.
    static func replacementRefusal(_ step: Replacement, hasPendingSave: Bool) -> String? {
        guard hasPendingSave else { return nil }
        switch step {
        case .open:
            return String(localized: "Couldn't open. The piece in front isn't saved yet, so nothing was replaced. Retry save first.")
        case .newPiece:
            return String(localized: "Couldn't start a new piece. The piece in front isn't saved yet, so nothing was replaced. Retry save first.")
        }
    }
}
