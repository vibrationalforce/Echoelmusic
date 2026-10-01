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
// ⭐ EchoelAI step 2 (founder addendum 2026-09-27): it is ALSO the one WRITER of a media look.
// `apply(photo:on:)` / `apply(video:on:)` refuse while a look is pending, write, and record in one
// call — the cards' Apply and the agent's `media.applyLook` both go through it, so there is no
// second path that could write a look without its way back. And it holds the seed each card has
// READ AND SHOWS (`shownPhoto` / `shownVideo`), which is what "this photo" means to the agent. A
// seed is a handful of numbers — no pixels, no file — and it lives in memory only: nothing here is
// persisted, and a card withdraws its seed when it disappears, starts a new read, or fails one.
//
// ⚠️ It is read in a card's `body`, and that is safe: it changes only on a tap (Apply / Undo) or
// when a read finishes, never at a rate — nothing hot (the #10.76.50 law is about 10 Hz readers).
//
// ⭐ LIFECYCLE OF A MEDIA LOOK (review MED-2, measured 2026-09-27) — three different lifetimes, and
// none of them is the project's:
//   · The LOOK ITSELF is the six `StudioDefaultKeys.visual*` values plus `visual.preset`, written to
//     `UserDefaults.standard` — a GLOBAL app setting. `Project` carries no visual field
//     (`git grep -c visual Sources/Echoelmusic/Core/Project.swift` → 0) and `saveProject` /
//     `openFromLibrary` touch none of these keys: opening another project neither adopts a
//     foreign look nor restores one of its own. The look survives a relaunch.
//   · THIS UNDO (`pending`) lives for the PROCESS. After a relaunch the look is still applied and
//     the way back through Undo is gone; the Visual panel's own fields and presets are then the
//     way back. That is stated, not repaired — a persisted undo is not a requirement.
//   · THE SHOWN SEED (`shownPhoto` / `shownVideo`) lives as long as the card SHOWS it.

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
    /// The two words a medium is named by — one spelling, read by the cards' headers.
    static let photoMedium = "photo"
    static let videoMedium = "video"
    /// The medium as a SPOKEN word (E4-41, moved home in E4-45). `medium` is an identifier, compared
    /// by both cards and never shown — the word a VoiceOver user hears, and the word inside
    /// `applyBlockedReason`, is a catalog key. Lives here, Foundation-only, so the owner can speak it
    /// without the cards' PhotosUI/ImageIO guards.
    var spokenMedium: String {
        medium == Self.videoMedium ? String(localized: "video") : String(localized: "photo")
    }

    /// Why a card's Apply is grey, in ONE sentence (nil while nothing is pending). The cards show
    /// it under the buttons AND speak it as the button's hint (review MED-8: the reason used to be
    /// VoiceOver-only, so a sighted person saw a grey button and no reason).
    var applyBlockedReason: String? {
        guard pending != nil else { return nil }
        // E4-45: seams around the spoken medium; the bundle's English is byte-identical
        // ("A photo look is applied. Undo it first to apply this one.", pinned end-to-end by
        // TheMediaLookHasOneWriterTests). German reads „Ein Foto-Look ist angewendet. …“.
        return String(localized: "A ") + spokenMedium + String(localized: " look is applied. Undo it first to apply this one.")
    }
    /// Counts every recorded application. Two applications of the same seed to the same look are
    /// EQUAL values, so "is the pending look still the one I applied?" is asked with this, not
    /// with the value (EchoelAI review MED-2: undo, then Apply again by hand, read as the agent's).
    private(set) var generation = 0
    /// The photo the photo card has read and holds, if any — "this photo".
    private(set) var shownPhoto: MediaSeed?
    /// The video the video card has read and holds, if any — "this video".
    private(set) var shownVideo: VideoSeed?

    init() {}

    /// Records an application. Refused (returns false) while another is pending — its `before` is
    /// the only way back to the look from before any photo or video.
    @discardableResult
    func record(_ application: MediaSeedApplication, from medium: String) -> Bool {
        guard pending == nil else { return false }
        pending = application
        self.medium = medium
        generation &+= 1
        return true
    }

    /// The card says which photo it holds (nil: none — a new read started, a read failed, or the
    /// card went away).
    func showPhoto(_ seed: MediaSeed?) { shownPhoto = seed }
    func showVideo(_ seed: VideoSeed?) { shownVideo = seed }

    /// Writes a photo's look and records its way back — or writes NOTHING while another look is
    /// pending (its `before` is the only way back to the look from before any photo or video).
    @discardableResult
    func apply(photo seed: MediaSeed, on defaults: UserDefaults) -> MediaSeedApplication? {
        guard pending == nil else { return nil }
        let application = MediaSeedApplication.apply(seed, to: defaults)
        record(application, from: Self.photoMedium)
        return application
    }

    /// The same for a video; an implausible seed writes nothing either.
    @discardableResult
    func apply(video seed: VideoSeed, on defaults: UserDefaults) -> MediaSeedApplication? {
        guard pending == nil, let application = MediaSeedApplication.apply(seed, to: defaults) else { return nil }
        record(application, from: Self.videoMedium)
        return application
    }

    /// Takes the pending look back and forgets it.
    func undo(on defaults: UserDefaults) {
        pending?.undo(on: defaults)
        pending = nil
        medium = ""
    }
}
