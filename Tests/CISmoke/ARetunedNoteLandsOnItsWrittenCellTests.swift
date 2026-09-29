// ARetunedNoteLandsOnItsWrittenCellTests.swift
// Echoel — DMMW Phase 6 · review repair of 24297e7d7 (founder 2026-09-29, "Klang-zu-Licht": a
// note's colour AND its place must follow it consistently).
//
// THE DEFECT. 24297e7d7 made every generated note publish the frequency the engine sounds —
// A4 plus the tone system's cents. The renderer places each cloud with
// `TouchPitchMap.fieldPosition(forHz:)`, which inverted that Hz as if it were 12-TET and
// rounded. Under Maqām Bayātī on C the written E, A and B sound 100 cents low, i.e. at E♭, A♭
// and B♭; the inversion answered E♭/A♭/B♭, none of which is in C major, so those clouds lost
// their cell and fell back to pitch space — off the grid. The colour had been fixed and the
// place broken (independent review, MED-1). Touch notes carried the same defect already.
//
// THE REPAIR, on the existing owner (no new store, clock or modal):
//   · `fieldPosition(forHz:a4Hz:pitchClassCents:key:)` takes the voices' table, with NO
//     default (#431), and lands on the WRITTEN pitch (`TouchPitchMap.writtenPitch`): the pitch
//     whose tuned position is nearest the sounding one. Two written pitches that sound the same
//     cannot be told apart by Hz; on that exact tie the pitch in the key wins, then the lower.
//   · `MetalBioView` reads the voice's observed table mirror once per frame, in the draw
//     callback (not a SwiftUI body, so no observer), and hands it to every slot.
//
// Claims, labelled per `Tests/CISmoke/CLAUDE.md` §1:
//   1. END-TO-END — Bayātī on C, key C major, A4 432: every in-key written pitch 48…83, as the
//      frame publishes it, lands on its OWN cell; with the table ignored E/A/B land on no cell.
//   2. END-TO-END — over the whole shipped library, every root, four scales: a written in-key
//      pitch lands on its own cell, or — only when a lower in-key pitch sounds at exactly the
//      same place — on that one. Nothing else.
//   3. END-TO-END — a 12-TET, empty, short or non-finite table inverts exactly as the old
//      12-TET rounding did.
//   4. SOURCE-TEXT SCAN — the table is a required parameter; the renderer reads it once before
//      the slot loop and passes it at the one call.
// GRADING against the parent: the parent's `fieldPosition(forHz:)` has no `pitchClassCents:`
// label and no `writtenPitch`, so this file does NOT compile against it — no assertion has a
// verdict there; transcribed in Python instead (the library sweep: 833,931 own-cell and
// 180,621 same-sound cases at three concert pitches, 0 violations). Claims 1 and 2 are the
// REGRESSION this repair fixes (the parent's inversion puts Bayātī's E on E♭'s nil cell);
// claim 3 is a COUNTERWEIGHT (12-TET behaviour unchanged); claim 4 is red there by ANCHOR
// ABSENCE (one absence).
// ⛔ HONEST LIMITS. Where the cloud actually draws is a DEVICE PROBE. When two written pitches
// of the key sound identically (Sléndro on C folds E and F onto one pitch), the cloud of the
// upper one shows on the lower one's cell — the frame carries Hz only, and a written-pitch
// field on `MusicalNote` would be the repair; recorded, not built. NEEDS-FOUNDER-VERIFY: Visual
// window, note grid on, key C major, tone system Maqām Bayātī — let the take play: every cloud
// sits on a lit cell of the grid, none floats between cells.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ARetunedNoteLandsOnItsWrittenCellTests: XCTestCase {

    private static let metal = "Sources/Echoelmusic/Views/MetalBioView.swift"
    private static let touch = "Sources/Echoelmusic/Studio/TouchInstrumentView.swift"

    /// The table the voices install for `system` at `root`, as `applyTuning` builds it
    /// (Double → Float), and the Double view of it the frame receives.
    private func tables(_ system: TuningSystem, root: Int) -> (voices: [Float], frame: [Double]) {
        let voices = system.pitchClassCents(root: root).map { Float($0) }
        return (voices, voices.map { Double($0) })
    }

    private func publishedHz(pitch: Int, a4: Double, cents: [Double]) throws -> Double {
        let frame = PianoRollModel.musicalFrame(
            forActive: [Note(pitch: pitch, startStep: 0, velocity: 0.8)], a4Hz: a4,
            pitchClassCents: cents, rootPitchClass: 0, scaleName: "major", tempoBPM: 120, beatPhase: 0)
        return try XCTUnwrap(frame.notes.first?.frequencyHz, "ANCHOR: the frame dropped an audible note")
    }

    // MARK: 1 — Bayātī on C, C major: every degree on its own cell

    func testBayatiDegreesLandOnTheirOwnCells() throws {
        let system = TuningSystem.named("maqam-bayati")
        let (voices, frame) = tables(system, root: 0)
        guard system.id == "maqam-bayati", voices[4] == -100, voices[9] == -100, voices[11] == -100 else {
            return XCTFail("ANCHOR MISSING: Bayātī on C no longer lowers E, A and B by 100 cents (#454)")
        }
        let key = MusicalKey(root: 0, scale: .major)
        let flat = [Float](repeating: 0, count: 12)
        var lostWithoutTable = 0
        for pitch in 48..<84 where key.contains(pitch) {
            let hz = try publishedHz(pitch: pitch, a4: 432, cents: frame)
            let own = try XCTUnwrap(TouchPitchMap.fieldPosition(forPitch: pitch, key: key))
            let landed = try XCTUnwrap(
                TouchPitchMap.fieldPosition(forHz: hz, a4Hz: 432, pitchClassCents: voices, key: key),
                "pitch \(pitch) sounds at \(hz) Hz under Bayātī and landed on NO cell")
            XCTAssertEqual(landed.x, own.x, accuracy: 1e-9, "pitch \(pitch): wrong column")
            XCTAssertEqual(landed.y, own.y, accuracy: 1e-9, "pitch \(pitch): wrong row")
            if TouchPitchMap.fieldPosition(forHz: hz, a4Hz: 432, pitchClassCents: flat, key: key) == nil {
                lostWithoutTable += 1
            }
        }
        // E, A and B in three octaves: the defect the table repairs (the parent's inversion).
        XCTAssertEqual(lostWithoutTable, 9, "with the table ignored, E/A/B lose their cell — the regression")
    }

    // MARK: 2 — the whole library: own cell, or the identical-sounding lower pitch

    func testEveryLibrarySystemLandsOnTheWrittenCell() throws {
        let scales: [Scale] = [.major, .minor, .phrygian, .chromatic]
        var checked = 0
        for system in TuningSystem.library {
            for root in 0..<12 {
                let (voices, frame) = tables(system, root: root)
                for scale in scales {
                    let key = MusicalKey(root: root, scale: scale)
                    for pitch in 48..<84 where key.contains(pitch) {
                        let hz = try publishedHz(pitch: pitch, a4: 440, cents: frame)
                        let semitones = 69.0 + 12.0 * Foundation.log2(hz / 440)
                        let written = TouchPitchMap.writtenPitch(forSemitones: semitones,
                                                                 pitchClassCents: voices, key: key)
                        checked += 1
                        guard written != pitch else { continue }
                        let tuned: (Int) -> Double = { p in
                            Double(p) + Double(voices[((p % 12) + 12) % 12]) / 100.0
                        }
                        XCTAssertTrue(written < pitch && key.contains(written)
                                      && abs(tuned(written) - tuned(pitch)) <= 1e-6, """
                            \(system.id) on \(root), \(scale): written \(pitch) landed on \(written), \
                            which neither is it nor sounds at the same place
                            """)
                    }
                }
            }
        }
        XCTAssertGreaterThan(checked, 1_000, "ANCHOR: the sweep visited almost nothing")
    }

    // MARK: 3 — 12-TET and refused tables invert as before

    func testATwelveToneOrRefusedTableInvertsAsBefore() throws {
        let key = MusicalKey(root: 9, scale: .minor)
        var poisoned = [Float](repeating: 0, count: 12)
        poisoned[4] = .nan
        let tables: [[Float]] = [[Float](repeating: 0, count: 12), [], [Float](repeating: 30, count: 11),
                                 poisoned, [Float](repeating: .infinity, count: 12)]
        for table in tables {
            for pitch in 36...96 {
                let hz = 440 * pow(2.0, Double(pitch - 69) / 12.0)
                let landed = TouchPitchMap.fieldPosition(forHz: hz, a4Hz: 440, pitchClassCents: table, key: key)
                let before = TouchPitchMap.fieldPosition(forPitch: pitch, key: key)
                XCTAssertEqual(landed?.x, before?.x, "table \(table): pitch \(pitch) moved column")
                XCTAssertEqual(landed?.y, before?.y, "table \(table): pitch \(pitch) moved row")
            }
        }
    }

    // MARK: 4 — SOURCE: the wiring

    func testTheRendererHandsTheVoicesTableToTheInversion() throws {
        let touch = try source(Self.touch)
        XCTAssertTrue(touch.contains(
            "public static func fieldPosition(forHz hz: Double, a4Hz: Double, pitchClassCents: [Float],"),
            "the table is a required parameter — a defaulted one appears in no diff (#431)")

        let metal = try source(Self.metal)
        guard let read = metal.range(of: "let cloudCents = synth?.uiTuningCents ?? []"),
              let loop = metal.range(of: "for k in 0..<5 {", range: read.upperBound..<metal.endIndex),
              let call = metal.range(of: "pitchClassCents: cloudCents,", range: loop.upperBound..<metal.endIndex) else {
            return XCTFail("ANCHOR MISSING: the renderer's table read, slot loop and call (#454)")
        }
        XCTAssertLessThan(read.lowerBound, call.lowerBound, "read once, before the slots")
        XCTAssertEqual(metal.components(separatedBy: "pitchClassCents: cloudCents,").count - 1, 1,
                       "ONE call site places the clouds")
        XCTAssertTrue(metal.contains("TouchPitchMap.fieldPosition(forHz: cloudHzSlot[k]"),
                      "ANCHOR: the grid-aware placement is still the renderer's")
    }

    // MARK: - Helpers

    private struct AnchorMissing: Error {}

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing()
        }
        return SourceText.codeOnly(text)
    }
}
