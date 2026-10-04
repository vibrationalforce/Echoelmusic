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
//  ⚠️ SCOPE, stated so nobody reads more into it: this is step 1 of A1 — the save gate. Play and
//  stop still run through `ProjectTransport` and the Studio's own functions; moving their
//  ownership here is the next step (`scratchpads/PLAN_RESTRUCTURE_2026-10-04.md` §3 A1).
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
