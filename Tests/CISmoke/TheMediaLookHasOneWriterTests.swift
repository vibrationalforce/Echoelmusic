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
//   · DEVICE PROBE, open: pick a photo, Apply, Undo; pick a video; leave the Workstation and come
//     back — nothing is offered that the screen does not show. NEEDS-FOUNDER-VERIFY.
//
// HONEST GRADING against the parent (95a3e540a, §3): the file does not COMPILE there — it names
// `apply(photo:on:)`, `showPhoto`, which this commit creates — ONE absence (#486); all claims are
// FORWARD guards. Hand-transcribed in Python; mutants driven, each red for its named reason: the
// owner writing while a look is pending (claim 1), an implausible video recorded (claim 1), a
// card keeping its inline `MediaSeedApplication.apply` (claim 3), a card that never withdraws its
// seed on disappear (claim 3).

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

        let applied = try XCTUnwrap(owner.apply(photo: photo(brightness: 0.9), on: defaults))
        XCTAssertEqual(owner.pending, applied, "the write and its way back are one step")
        XCTAssertEqual(owner.medium, "photo")
        XCTAssertEqual(applied.before, look)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), applied.after)

        XCTAssertNil(owner.apply(video: video(motion: 1), on: defaults), "a pending look blocks a second")
        XCTAssertNil(owner.apply(photo: photo(brightness: 0.1), on: defaults))
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), applied.after, "the refused writes wrote nothing")

        owner.undo(on: defaults)
        XCTAssertNil(owner.pending)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), look)

        XCTAssertNil(owner.apply(video: video(motion: 3), on: defaults), "an implausible video writes nothing")
        XCTAssertNil(owner.pending, "and records nothing")
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), look)
        let moved = try XCTUnwrap(owner.apply(video: video(motion: 1), on: defaults))
        XCTAssertEqual(owner.medium, "video")
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
        XCTAssertTrue(photoCard.contains("MediaLookUndo.shared.showPhoto(decoded.seed)"), "a read photo is offered")
        XCTAssertTrue(videoCard.contains("MediaLookUndo.shared.showVideo(read.seed)"), "a read video is offered")
        XCTAssertEqual(photoCard.components(separatedBy: "MediaLookUndo.shared.showPhoto(nil)").count - 1, 2,
                       "withdrawn when a new read starts and when the card goes away")
        XCTAssertEqual(videoCard.components(separatedBy: "MediaLookUndo.shared.showVideo(nil)").count - 1, 2)

        let owner = try code("Sources/Echoelmusic/Studio/MediaLookUndo.swift")
        for persisted in ["UserDefaults.standard", "FileManager", "Codable", ".set("] {
            XCTAssertFalse(owner.contains(persisted), "the shown seed must stay in memory — the owner names `\(persisted)`")
        }
    }
}
