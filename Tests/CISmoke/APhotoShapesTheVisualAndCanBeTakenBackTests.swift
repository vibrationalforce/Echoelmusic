// APhotoShapesTheVisualAndCanBeTakenBackTests.swift
// MS2 (founder order 2026-09-27): a picture's `MediaSeed` is applied to the EXISTING visual
// parameter path — the six `visual.*` keys and the preset chip — and the look from before the
// photo can be put back.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–4 are END-TO-END on shipped, Foundation-only types (`MediaSeedLook`,
//     `VisualLookSnapshot`, `MediaSeedApplication`) against a private `UserDefaults` suite — the
//     same keys the surfaces read, but never the app's own defaults.
//   · Claim 5 is a SOURCE-TEXT SCAN: the keys this writes are the keys the mounted surfaces read.
//   · DEVICE PROBE, open: that the floating visual visibly changes on Apply and returns on Undo.
//
// HONEST GRADING against the parent (2b2e2d1d7, §3): the file does not COMPILE there — claims
// 1–4 name types this commit creates — so no assertion has a verdict on the parent. Claims 1–4
// are FORWARD guards (one absence, #486); claim 5 is a COUNTERWEIGHT, green on both trees.
// Hand-transcribed in Python; mutants driven, each red for its named reason: a grey picture
// rotating the hue (claim 2), motion taken from the photo (claim 2), undo writing "" for an unset
// chip (claim 3), a NaN stored value copied into the snapshot (claim 4).
//
// REVIEW REPAIR (MS1–MS3 review, 2026-09-27): claim 6 is new — undo restores per value and leaves a
// value moved since; one `MediaLookUndo` refuses a second pending look. FORWARD guards (they name
// `MediaLookUndo`, created in the same commit). Transcribed; mutants red: undo writing all seven
// keys (claim 6a), a holder that accepts a second look (claim 6b).

import Foundation
import XCTest
@testable import Echoelmusic

final class APhotoShapesTheVisualAndCanBeTakenBackTests: XCTestCase {

    /// A private defaults suite per test — never the app's own — removed when the test ends.
    private func freshDefaults() throws -> UserDefaults {
        let name = "echoel.tests.mediaSeedLook.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        return suite
    }

    private func seed(hue: Double = 0.5, brightness: Double = 0.5, saturation: Double = 0.5,
                      contrast: Double = 0.5, coloured: Bool = true) -> MediaSeed {
        MediaSeed(version: MediaSeed.formatVersion, hue: hue, dominantRed: 0.5, dominantGreen: 0.5,
                  dominantBlue: 0.5, brightness: brightness, saturation: saturation, contrast: contrast,
                  hasDominantColour: coloured, sampledPixels: 64)
    }

    // MARK: 1 — the mapping lands inside the preset's own ranges, and moves the right way

    func testTheSeedMapsIntoThePresetRanges() {
        let dark = MediaSeedLook.preset(for: seed(brightness: 0, saturation: 0, contrast: 0), keepingMotion: 1, spread: 1)
        let bright = MediaSeedLook.preset(for: seed(brightness: 1, saturation: 1, contrast: 1), keepingMotion: 1, spread: 1)
        XCTAssertLessThan(dark.intensity, bright.intensity, "a brighter photo gives a brighter visual")
        XCTAssertLessThan(dark.detail, bright.detail, "more contrast gives more detail")
        XCTAssertLessThan(dark.saturation ?? 0, bright.saturation ?? 0, "a more saturated photo, a more saturated visual")
        for p in [dark, bright] {
            XCTAssertTrue((0...1.5).contains(p.intensity) && (8...90).contains(p.detail))
            XCTAssertTrue((0...2).contains(p.saturation ?? -1))
        }
        XCTAssertGreaterThan(dark.intensity, 0, "a black photo dims the visual, it does not switch it off")
        let broken = MediaSeedLook.preset(for: seed(hue: .nan, brightness: .nan, saturation: .infinity, contrast: -.infinity),
                                          keepingMotion: .nan, spread: .nan)
        for v in [broken.intensity, broken.detail, broken.motion, broken.spread, broken.saturation ?? 0] {
            XCTAssertTrue(v.isFinite, "a non-finite seed never reaches the renderer")
        }
        XCTAssertNil(broken.hue, "a NaN hue is no colour")
    }

    // MARK: 2 — what a photo changes and what it leaves

    func testAGreyPhotoKeepsTheColourAndNoPhotoTakesTheMotion() throws {
        let defaults = try freshDefaults()
        var before = VisualLookSnapshot.read(from: defaults)
        before.hue = 0.3
        before.motion = 0.4
        before.spread = 1.3
        let grey = before.applying(seed(hue: 0.9, coloured: false))
        XCTAssertEqual(grey.hue, 0.3, "no dominant colour → the hue stays where the player left it")
        let red = before.applying(seed(hue: 0.02, coloured: true))
        XCTAssertEqual(red.hue, 0.02, accuracy: 1e-6, "a coloured photo sets the hue rotation")
        for after in [grey, red] {
            XCTAssertEqual(after.motion, 0.4, accuracy: 1e-6, "a still has no motion to give")
            XCTAssertEqual(after.spread, 1.3, accuracy: 1e-6)
            XCTAssertEqual(after.presetID, "", "the result is no factory preset — no chip may light")
        }
    }

    // MARK: 3 — apply writes the live keys; undo puts the exact look back

    func testApplyThenUndoRestoresTheLookExactly() throws {
        let defaults = try freshDefaults()
        defaults.set(1.2, forKey: StudioDefaultKeys.visualIntensity.key)
        defaults.set(55.0, forKey: StudioDefaultKeys.visualDetail.key)
        defaults.set(0.7, forKey: StudioDefaultKeys.visualMotion.key)
        defaults.set(0.9, forKey: StudioDefaultKeys.visualSpread.key)
        defaults.set(0.25, forKey: StudioDefaultKeys.visualHue.key)
        defaults.set(1.5, forKey: StudioDefaultKeys.visualSaturation.key)
        defaults.set("bloom", forKey: VisualLookSnapshot.presetKey)
        let original = VisualLookSnapshot.read(from: defaults)

        let application = MediaSeedApplication.apply(seed(hue: 0.6, brightness: 0.1, contrast: 0.9), to: defaults)
        XCTAssertEqual(application.before, original)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), application.after, "apply writes what it returns")
        XCTAssertNotEqual(application.after, original, "the photo visibly changed something")

        application.undo(on: defaults)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), original, "undo is exact, the chip included")
    }

    func testUndoOnAFreshInstallKeepsTheChipThePlayerSaw() throws {
        let defaults = try freshDefaults()
        let fresh = VisualLookSnapshot.read(from: defaults)
        XCTAssertEqual(fresh.presetID, VisualLookSnapshot.presetDefault,
                       "an unset chip reads as the default the studio view shows lit")
        XCTAssertEqual(fresh.saturation, StudioDefaultKeys.visualSaturation.value)
        let application = MediaSeedApplication.apply(seed(), to: defaults)
        application.undo(on: defaults)
        XCTAssertEqual(defaults.string(forKey: VisualLookSnapshot.presetKey), VisualLookSnapshot.presetDefault)
    }

    // MARK: 4 — a broken stored value cannot poison the snapshot

    func testANonFiniteStoredValueReadsAsTheDefault() throws {
        let defaults = try freshDefaults()
        defaults.set(Double.nan, forKey: StudioDefaultKeys.visualHue.key)
        defaults.set(Double.infinity, forKey: StudioDefaultKeys.visualIntensity.key)
        let snapshot = VisualLookSnapshot.read(from: defaults)
        XCTAssertEqual(snapshot.hue, StudioDefaultKeys.visualHue.value)
        XCTAssertEqual(snapshot.intensity, StudioDefaultKeys.visualIntensity.value)
    }

    // MARK: 6 — undo takes back only what still shows the photo; one way back app-wide (review)

    func testUndoLeavesAValueThePlayerMovedSince() throws {
        let defaults = try freshDefaults()
        let original = VisualLookSnapshot.read(from: defaults)
        let application = MediaSeedApplication.apply(seed(hue: 0.6, brightness: 0.9, contrast: 0.9), to: defaults)
        defaults.set(0.33, forKey: StudioDefaultKeys.visualIntensity.key)   // moved by hand after Apply
        application.undo(on: defaults)
        let back = VisualLookSnapshot.read(from: defaults)
        XCTAssertEqual(back.intensity, 0.33, "a value moved since belongs to the player — undo leaves it")
        XCTAssertEqual(back.detail, original.detail, "the rest goes back")
        XCTAssertEqual(back.hue, original.hue)
        XCTAssertEqual(back.presetID, original.presetID)
    }

    @MainActor
    func testThereIsOneWayBackAndASecondApplyIsRefused() throws {
        let defaults = try freshDefaults()
        let original = VisualLookSnapshot.read(from: defaults)
        let undo = MediaLookUndo()
        XCTAssertTrue(undo.record(MediaSeedApplication.apply(seed(brightness: 0.1), to: defaults), from: "photo"))
        let second = MediaSeedApplication.apply(seed(brightness: 0.9), to: defaults)
        XCTAssertFalse(undo.record(second, from: "photo"),
                       "a second look while one is pending would make the first `before` unreachable")
        second.undo(on: defaults)
        undo.undo(on: defaults)
        XCTAssertNil(undo.pending)
        XCTAssertEqual(VisualLookSnapshot.read(from: defaults), original, "the look from before any photo is back")
    }

    // MARK: 5 — the keys written are the keys the surfaces read

    func testTheWrittenKeysAreTheOnesTheSurfacesRead() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        func code(_ path: String) throws -> String {
            SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8))
        }
        let studio = try code("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        XCTAssertTrue(studio.contains("@AppStorage(\"\(VisualLookSnapshot.presetKey)\") private var visualPresetID = \"\(VisualLookSnapshot.presetDefault)\""),
                      "the preset chip's key and default are the twins `VisualLookSnapshot` names")
        let window = try code("Sources/Echoelmusic/Studio/FloatingVisualWindow.swift")
        for key in ["visualIntensity", "visualDetail", "visualHue", "visualSaturation"] {
            XCTAssertTrue(window.contains("@AppStorage(StudioDefaultKeys.\(key).key)"),
                          "the floating visual reads `\(key)` — the seed would otherwise change nothing on screen")
        }
    }
}
