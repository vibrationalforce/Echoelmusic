// TheMediaLookHasOneWriterTests.swift
// EchoelAI step 2a (founder addendum 2026-09-27): "Nutze die Farben dieses Fotos" needs the SAME
// path the card's Apply takes. So `MediaLookUndo` became the one writer of a media look — refuse
// while a look is pending, write, record, in ONE call — and it holds the seed each card has read
// and shows ("this photo", "this video"), in memory only.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–2 are END-TO-END on the shipped `MediaLookUndo` (a fresh instance, never `.shared`)
//     against a private `UserDefaults` suite.
//   · Claim 3 is a SOURCE-TEXT SCAN: exactly one file under `Sources/` calls
//     `MediaSeedApplication.apply(`, and both cards route Apply through the owner and hand it the
//     seed they show. The cards are SwiftUI views no test can render.
//   · Claim 4 is END-TO-END on the owner's `applyBlockedReason`, then a SOURCE-TEXT SCAN of where
//     the cards put that sentence (in sight, in the hint, in the header). Whether it READS well on
//     a phone is a device probe.
//   · DEVICE PROBE, open: pick a photo, Apply, Undo; pick a video; leave the Workstation and come
//     back — nothing is offered that the screen does not show. NEEDS-FOUNDER-VERIFY.
//
// HONEST GRADING against the parent (95a3e540a, §3): the file does not COMPILE there — it names
// `apply(photo:on:)`, `showPhoto`, which this commit creates — ONE absence (#486); all claims are
// FORWARD guards. Hand-transcribed in Python; mutants driven, each red for its named reason: the
// owner writing while a look is pending (claim 1), an implausible video recorded (claim 1), a
// card keeping its inline `MediaSeedApplication.apply` (claim 3), a card that never withdraws its
// seed on disappear (claim 3).
// Review repair (MED-1/MED-2): claim 1 pins the `generation` count (mutant: no bump → red), claim 3
// the withdrawal when the card is collapsed (mutant: the header only toggles → red).
// Review repair 2e (2026-09-27): a read that finishes AFTER the card was collapsed used to publish
// its seed anyway (`showPhoto(decoded.seed)` unconditionally) — the agent then saw "A photo is open"
// on a closed card. Claim 3 now pins the `if isOpen` gate at both publish sites, and the two
// cancellation lines that cover the newer-pick and gone-card cases. Mutant: the bare call → red.
// Review repair 3a (MED-8, 2026-09-27): why Apply is grey was VoiceOver-only. Claim 4 drives
// `applyBlockedReason` END-TO-END (nil / one sentence / nil again) and SCANS that both cards render
// it in sight, speak it as the hint, and name their live look in the collapsed header — and that
// the sentence has ONE home (neither card spells "Undo it first"). Mutants: a card keeping its own
// inline sentence → red; the visible `Text(reason)` removed → red.
// Review 4e (Codex, 2026-09-27): "the result must be invalidated; cancellation alone need not be
// enough". Claim 5 pins WHY it is enough here: the cancellation check and the gated publish are one
// main-actor turn (no `await`, no new task between them), and every path that invalidates a read —
// a newer pick, the card going away — runs on that same actor BEFORE the next task starts; collapse
// does not cancel, it flips `isOpen`, which the publish reads. Mutant: an `await` moved between the
// check and the publish → red; the cancel moved after `loadTask = Task {` → red.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheMediaLookHasOneWriterTests: XCTestCase {

    private func freshDefaults() throws -> UserDefaults {
        let name = "echoel.tests.mediaLookWriter.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        return suite
    }

    private let look = VisualLookSnapshot(intensity: 1, detail: 40, motion: 1, spread: 1, hue: 0.1,
                                          saturation: 1.05, presetID: "vapor")

    private func photo(brightness: Double) -> MediaSeed {
        MediaSeed(version: MediaSeed.formatVersion, hue: 0.6, dominantRed: 0.2, dominantGreen: 0.3,
                  dominantBlue: 0.8, brightness: brightness, saturation: 0.7, contrast: 0.5,
                  hasDominantColour: true, sampledPixels: 64)
    }

    private func video(motion: Double) -> VideoSeed {
        VideoSeed(version: VideoSeed.formatVersion, durationSeconds: 4, frameRate: 30, brightness: 0.5,
                  hue: 0.25, saturation: 0.5, hasDominantColour: true, motionEnergy: motion,
                  transientTimes: [1], sampledFrames: 16)
    }

    // MARK: 1 — one call writes and records; a pending look blocks every other write

    func testTheOwnerWritesRecordsAndRefusesInOneCall() throws {
        let defaults = try freshDefaults()
        look.write(to: defaults)
        let owner = MediaLookUndo()

        XCTAssertEqual(owner.generation, 0)
        let applied = try XCTUnwrap(owner.apply(photo: photo(brightness: 0.9), on: defaults))
        XCTAssertEqual(owner.pending, applied, "the write and its way back are one step")
        XCTAssertEqual(owner.generation, 1, "every recorded look is told apart, even an equal one")
        XCTAssertEqual(owner.medium, "photo")
        XCTAssertEqual(applied.before, look)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), applied.after)

        XCTAssertNil(owner.apply(video: video(motion: 1), on: defaults), "a pending look blocks a second")
        XCTAssertNil(owner.apply(photo: photo(brightness: 0.1), on: defaults))
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), applied.after, "the refused writes wrote nothing")
        XCTAssertEqual(owner.generation, 1, "a refused write records nothing")

        owner.undo(on: defaults)
        XCTAssertNil(owner.pending)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), look)

        XCTAssertNil(owner.apply(video: video(motion: 3), on: defaults), "an implausible video writes nothing")
        XCTAssertNil(owner.pending, "and records nothing")
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), look)
        let moved = try XCTUnwrap(owner.apply(video: video(motion: 1), on: defaults))
        XCTAssertEqual(owner.medium, "video")
        XCTAssertEqual(owner.generation, 2)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), moved.after)
    }

    // MARK: 2 — "this photo" is what a card shows, and nothing else

    func testTheOwnerHoldsOnlyWhatACardShows() {
        let owner = MediaLookUndo()
        XCTAssertNil(owner.shownPhoto)
        XCTAssertNil(owner.shownVideo)
        owner.showPhoto(photo(brightness: 0.4))
        owner.showVideo(video(motion: 0.2))
        XCTAssertEqual(owner.shownPhoto, photo(brightness: 0.4))
        XCTAssertEqual(owner.shownVideo, video(motion: 0.2))
        owner.showPhoto(nil)
        XCTAssertNil(owner.shownPhoto, "a card withdraws its photo")
        XCTAssertEqual(owner.shownVideo, video(motion: 0.2), "the other card's video is not touched")
    }

    // MARK: 3 — one writer in Sources/, and both cards use it

    func testBothCardsWriteThroughTheOwner() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let sources = root.appendingPathComponent("Sources")
        var writers: [String] = []
        let files = try XCTUnwrap(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        var read = 0
        for case let url as URL in files where url.pathExtension == "swift" {
            read += 1
            let code = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
            if code.contains("MediaSeedApplication.apply(") { writers.append(url.lastPathComponent) }
        }
        XCTAssertGreaterThan(read, 250, "only \(read) Swift files read — the walk failed")
        XCTAssertEqual(writers, ["MediaLookUndo.swift"],
                       "a media look is written in ONE place, so no path writes one without its way back")

        func code(_ path: String) throws -> String {
            SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8))
        }
        let photoCard = try code("Sources/Echoelmusic/Studio/PhotoSeedCard.swift")
        let videoCard = try code("Sources/Echoelmusic/Studio/VideoSeedCard.swift")
        XCTAssertTrue(photoCard.contains("undo.apply(photo: decoded.seed, on: .standard)"))
        XCTAssertTrue(videoCard.contains("undo.apply(video: read.seed, on: .standard)"))
        XCTAssertTrue(photoCard.contains("if isOpen { MediaLookUndo.shared.showPhoto(decoded.seed) }"),
                      "a read photo is offered — only while the card is open (review repair 2e)")
        XCTAssertTrue(videoCard.contains("if isOpen { MediaLookUndo.shared.showVideo(read.seed) }"),
                      "a read video is offered — only while the card is open (review repair 2e)")
        // The newer-pick and gone-card cases are the cancellation before that line: every read
        // checks `Task.isCancelled` after its awaits, and `onDisappear` cancels.
        for card in [photoCard, videoCard] {
            XCTAssertTrue(card.contains("guard !Task.isCancelled else { return }"), "a cancelled read publishes nothing")
            XCTAssertTrue(card.contains(".onDisappear {\n            loadTask?.cancel()"), "a card that went away cancels its read")
        }
        XCTAssertEqual(photoCard.components(separatedBy: "MediaLookUndo.shared.showPhoto(nil)").count - 1, 2,
                       "withdrawn when a new read starts and when the card goes away")
        XCTAssertEqual(videoCard.components(separatedBy: "MediaLookUndo.shared.showVideo(nil)").count - 1, 2)
        // Review MED-1: a collapsed card does not show its photo, so it withdraws it too.
        XCTAssertTrue(photoCard.contains("MediaLookUndo.shared.showPhoto(isOpen ? shownSeed : nil)"))
        XCTAssertTrue(videoCard.contains("MediaLookUndo.shared.showVideo(isOpen ? shownSeed : nil)"))

        let owner = try code("Sources/Echoelmusic/Studio/MediaLookUndo.swift")
        for persisted in ["UserDefaults.standard", "FileManager", "Codable", ".set("] {
            XCTAssertFalse(owner.contains(persisted), "the shown seed must stay in memory — the owner names `\(persisted)`")
        }
    }

    // MARK: 4 — why Apply is grey is one sentence, in sight and spoken, from one home

    func testTheReasonAGreyApplyGivesIsOneSentenceInSightAndSpoken() throws {
        let defaults = try freshDefaults()
        look.write(to: defaults)
        let owner = MediaLookUndo()
        XCTAssertNil(owner.applyBlockedReason, "nothing pending — nothing blocks")
        _ = try XCTUnwrap(owner.apply(photo: photo(brightness: 0.9), on: defaults))
        XCTAssertEqual(owner.applyBlockedReason, "A photo look is applied. Undo it first to apply this one.")
        owner.undo(on: defaults)
        XCTAssertNil(owner.applyBlockedReason, "taken back — Apply is free again")
        _ = try XCTUnwrap(owner.apply(video: video(motion: 1), on: defaults))
        XCTAssertEqual(owner.applyBlockedReason, "A video look is applied. Undo it first to apply this one.")

        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        func code(_ path: String) throws -> String {
            SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8))
        }
        let ownerCode = try code("Sources/Echoelmusic/Studio/MediaLookUndo.swift")
        XCTAssertTrue(ownerCode.contains("var applyBlockedReason: String?"), "the sentence's one home")
        let cards = [("Sources/Echoelmusic/Studio/PhotoSeedCard.swift", "photoMedium"),
                     ("Sources/Echoelmusic/Studio/VideoSeedCard.swift", "videoMedium")]
        for (path, medium) in cards {
            let card = try code(path)
            XCTAssertTrue(card.contains("if !isLive, let reason = undo.applyBlockedReason {"),
                          "\(path): the reason is shown, and not while the applied look is this card's own")
            XCTAssertTrue(card.contains("Text(reason)"), "\(path): shown in sight, not only spoken")
            XCTAssertTrue(card.contains(".accessibilityHint(undo.applyBlockedReason ??"),
                          "\(path): the same sentence is the button's hint")
            XCTAssertTrue(card.contains("undo.medium == MediaLookUndo.\(medium)"),
                          "\(path): the collapsed header names ITS live look, not the other card's")
            XCTAssertFalse(card.contains("Undo it first"), "\(path): the sentence has one home (#416)")
        }
    }

    // MARK: 5 — a read's RESULT is invalidated, not merely its task cancelled (review 4e)

    func testACompletedReadPublishesInTheSameMainActorTurnAsItsCancellationCheck() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        for (path, publish, withdraw) in [
            ("Sources/Echoelmusic/Studio/PhotoSeedCard.swift",
             "if isOpen { MediaLookUndo.shared.showPhoto(decoded.seed) }", "MediaLookUndo.shared.showPhoto(nil)"),
            ("Sources/Echoelmusic/Studio/VideoSeedCard.swift",
             "if isOpen { MediaLookUndo.shared.showVideo(read.seed) }", "MediaLookUndo.shared.showVideo(nil)"),
        ] {
            let code = SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8))
            // (a) Between the cancellation check and the publish: no suspension, no new task. A
            // newer pick cancels on the main actor, so a read that passes the check publishes before
            // the pick can run, and one the pick cancelled never passes it.
            XCTAssertEqual(code.components(separatedBy: "guard !Task.isCancelled else { return }").count - 1, 1,
                           "\(path): ONE cancellation check — the anchor below relies on it")
            guard let check = code.range(of: "guard !Task.isCancelled else { return }"),
                  let publishAt = code.range(of: publish, range: check.upperBound..<code.endIndex) else {
                return XCTFail("\(path): the cancellation check or the gated publish moved — re-anchor")
            }
            let between = code[check.upperBound..<publishAt.lowerBound]
            XCTAssertFalse(between.contains("await"),
                           "\(path): a suspension between the check and the publish reopens the window Codex named")
            XCTAssertFalse(between.contains("Task {") || between.contains("Task.detached"),
                           "\(path): a hop between the check and the publish reopens it too")
            // (b) The invalidating paths come BEFORE the next task, in the same function on the same
            // actor: the older task is cancelled and its seed withdrawn, then the new task starts.
            XCTAssertEqual(code.components(separatedBy: "private func load(").count - 1, 1, "\(path): one read entry")
            guard let entry = code.range(of: "private func load("),
                  let start = code.range(of: "loadTask = Task {", range: entry.upperBound..<code.endIndex) else {
                return XCTFail("\(path): `load(` or its task start moved — re-anchor")
            }
            let prologue = code[entry.upperBound..<start.lowerBound]
            XCTAssertTrue(prologue.contains("loadTask?.cancel()"), "\(path): the older read is cancelled before the new one starts")
            XCTAssertTrue(prologue.contains(withdraw), "\(path): the older seed is withdrawn before the new read starts")
            XCTAssertFalse(prologue.contains("await"), "\(path): nothing suspends between cancel, withdraw and the new task")
            // (c) Collapse is not a cancel: it withdraws by `isOpen`, which the publish reads.
            XCTAssertTrue(code.contains("isOpen.toggle()"), "\(path): the header toggles the card")
            XCTAssertEqual(code.components(separatedBy: "loadTask?.cancel()").count - 1, 2,
                           "\(path): cancel at a newer pick and at disappear — not at collapse (a collapsed card that is "
                           + "opened again during the read shows the result; the publish reads `isOpen`)")
        }
    }
}
