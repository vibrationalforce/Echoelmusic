// MediaLookUndo.swift
// Echoel — MS/MV review repair (2026-09-27): the ONE way back from a photo or video look.
//
// ⭐ WHY IT LIVES OUTSIDE THE CARD. The first version kept the undo in the card's own `@State`, and
// the review found two ways to lose it silently: picking a second photo to compare cleared it, and
// switching the Studio chip unmounts the Workstation plate (one panel shows at a time) and took the
// state with it. Applying the second photo then snapshotted the FIRST photo's look as its "before",
// so the look from before any photo could no longer be reached — while the Undo hint still promised
// exactly that. One pending application, held for the app's lifetime and shared by every media card,
// closes both: a card that comes back finds its Undo, and a second Apply is refused until the first
// is undone.
//
// ⚠️ It is read in a card's `body`, and that is safe: it changes only on a tap (Apply / Undo),
// never at a rate — nothing hot (the #10.76.50 law is about 10 Hz readers).

import Foundation
import Observation

@MainActor
@Observable
final class MediaLookUndo {

    /// The shared instance every media card reads.
    static let shared = MediaLookUndo()

    /// The applied look that Undo would take back, if any.
    private(set) var pending: MediaSeedApplication?
    /// The medium that applied it, for plain words on the button ("photo", "video").
    private(set) var medium = ""

    init() {}

    /// Records an application. Refused (returns false) while another is pending — its `before` is
    /// the only way back to the look from before any photo or video.
    @discardableResult
    func record(_ application: MediaSeedApplication, from medium: String) -> Bool {
        guard pending == nil else { return false }
        pending = application
        self.medium = medium
        return true
    }

    /// Takes the pending look back and forgets it.
    func undo(on defaults: UserDefaults) {
        pending?.undo(on: defaults)
        pending = nil
        medium = ""
    }
}
