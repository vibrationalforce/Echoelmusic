// TheExportKeepsTheNoteResolutionTests.swift
// Echoel — #1254 (ultraplan row 21, audit 2026-09-10 `sequencer-core-5` (b)). The MIDI export
// writes the notes' OWN tick space, `Note.ticksPerQuarter` = 480, instead of flooring every
// tick into 96 PPQ.
//
// BEFORE: `MIDIFileExporter.ticksPerQuarter` was 96 and `exportTicks` did
// `noteTicks * 96 / 480` — integer floor, so a played-in (`MIDINoteRecorder`, "sub-step
// precise") or microtimed (`TouchQuantizer`) note lost up to 4 ticks ≈ 4 ms at 120 BPM and
// every length floored. On-grid content was exact either way. The App Store text sells the
// MIDI export; a DAW import was quietly coarser than the model it came from.
//
// END-TO-END BEHAVIOUR for claims 1–5 and 7 (`MIDIFileExporter`, `MIDIFileImporter`, `Note`,
// `Humanizer` are shipped Foundation-only value types — the bytes are DRIVEN here, not scanned).
// SOURCE-TEXT SCAN for claim 6 (the ONE definition, #416). No device probe is needed: a
// Standard MIDI File either carries the tick or it does not, and the importer reads it back
// on every platform.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0, the byte algebra re-derived in Python against the
// parent `a8d17dc` and this tree): claims 1, 2, 3, 4, 5 and 6 RED on the parent for their
// NAMED reason (96 ≠ 480; division `00 60`; an off-grid tick comes back rounded to a multiple
// of 5; the step-8 delta is 180 not 900; the preset is ±4; the literal `= 96` is present) —
// these are FORWARD guards of one change, not six regressions (#486); claim 7 (tempo meta,
// velocity byte, End-of-Track present) GREEN on both. Stripper: PROPHYLAKTISCH (0 of 2 scan
// verdicts flip).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheExportKeepsTheNoteResolutionTests: XCTestCase {

    private func contains(_ haystack: Data, _ needle: [UInt8]) -> Bool {
        haystack.range(of: Data(needle)) != nil
    }

    private func oneKickAtStepsZeroAndEight() -> [[Bool]] {
        var g = Array(repeating: Array(repeating: false, count: 16), count: 8)
        g[0][0] = true; g[0][8] = true
        return g
    }

    /// Claim 1 — ONE tick space: the exporter's PPQ IS the note model's PPQ (#416).
    func testTheExporterWritesTheNoteModelsPPQ() {
        XCTAssertEqual(Int(MIDIFileExporter.ticksPerQuarter), Note.ticksPerQuarter,
                       "the exporter rescales again — every off-grid tick is floored on the way to the DAW (#1254)")
        XCTAssertEqual(Note.ticksPerQuarter, 480, "the model's PPQ moved; every fixture below moves with it")
    }

    /// Claim 2 — all three file shapes carry division 0x01E0 (480) in the header.
    func testEveryHeaderSaysFourEighty() {
        let grid = MIDIFileExporter.export(steps: oneKickAtStepsZeroAndEight(), tempo: 120)
        let melody = MIDIFileExporter.export(notes: [Note(pitch: 60, startStep: 0, lengthSteps: 2)], tempo: 120)
        let combined = MIDIFileExporter.exportCombined(notes: [], steps: [], tempo: 120, bars: 1)
        for (name, data) in [("Type-0 grid", grid), ("Type-0 melody", melody), ("Type-1 combined", combined)] {
            XCTAssertEqual(Array(data[12..<14]), [0x01, 0xE0], "\(name): division must be 480 (#1254)")
        }
    }

    /// Claim 3 — an OFF-GRID note round-trips tick-exact. 7 and 123 are deliberately not
    /// multiples of 5: at 96 PPQ they floored to 1 and 24 and came back as 5 and 120.
    func testAnOffGridNoteRoundTripsTickExact() throws {
        let played = Note(pitch: 60, startTick: 7, lengthTicks: 123, velocity: 0.8)
        let data = MIDIFileExporter.export(notes: [played], tempo: 120)
        let back = try MIDIFileImporter.notes(from: data)
        XCTAssertEqual(back.count, 1)
        XCTAssertEqual(back.first?.startTick, 7, "the sub-step start was floored away (#1254)")
        XCTAssertEqual(back.first?.lengthTicks, 123, "the length was floored (#1254)")
        let combined = MIDIFileExporter.exportCombined(notes: [played], steps: [], tempo: 120, bars: 1)
        XCTAssertEqual(try MIDIFileImporter.notes(from: combined).first?.startTick, 7,
                       "the Type-1 path (the one the export door uses) must keep the tick too (#1254)")
    }

    /// Claim 4 — on-grid content lands on the 480-space grid: step 8 = 960 ticks, the gate is
    /// half a step (60), so the delta from the first kick's note-off to the second note-on is
    /// 900 = VLQ `87 04`.
    func testTheGridStepIsOneHundredTwentyTicks() {
        let data = MIDIFileExporter.export(steps: oneKickAtStepsZeroAndEight(), tempo: 120)
        XCTAssertTrue(contains(data, [0x00, 0x99, 36, 100, 0x3C, 0x89, 36, 0]),
                      "first kick: note-on at 0, note-off after a 60-tick gate (#1254)")
        XCTAssertTrue(contains(data, [0x87, 0x04, 0x99, 36, 100]),
                      "second kick at step 8 must sit 960 ticks in — 900 after the first note-off (#1254)")
    }

    /// Claim 5 — the humanized FEEL survives the finer grid: ±20 ticks at 480 PPQ is the
    /// ~21 ms at 120 BPM the preset always promised (±4 was that number in 96-PPQ ticks).
    func testTheHumanizedPresetKeepsItsMilliseconds() {
        let ms = Double(Humanizer.humanized.timingTicks) / Double(Note.ticksPerQuarter) * 500
        XCTAssertEqual(ms, 20.8, accuracy: 0.5,
                       "the humanized preset now means \(ms) ms at 120 BPM, not ~21 (#1254)")
        var seen = Set<Int>()
        for i in 0..<200 {
            let dt = Humanizer.humanized.jitter(index: i, seed: 7).tickDelta
            XCTAssertLessThanOrEqual(abs(dt), 20)
            seen.insert(dt)
        }
        XCTAssertTrue(seen.contains { abs($0) > 4 },
                      "no delta beyond ±4 in 200 draws — the preset is still in the old ticks (#1254)")
    }

    /// Claim 6 — the ONE definition in source: the exporter derives from `Note.ticksPerQuarter`
    /// and carries no `= 96` of its own; the humanizer no longer claims two tick spaces.
    func testTheSourceHasOneDefinition() throws {
        let exporter = SourceText.codeOnly(try text("Sources/Echoelmusic/Sequencer/MIDIFileExporter.swift"))
        XCTAssertTrue(exporter.contains("public static let ticksPerQuarter: UInt16 = UInt16(Note.ticksPerQuarter)"),
                      "the exporter's PPQ must be DERIVED from the model's, never restated (#416/#1254)")
        XCTAssertFalse(exporter.contains("exportTicks("), "a rescale helper is back (#1254)")
        let humanizer = try text("Sources/Echoelmusic/Sequencer/Humanizer.swift")
        XCTAssertFalse(humanizer.contains("TWO tick spaces"),
                       "Humanizer's header claims two tick spaces again — both callers are at 480 (#1254)")
    }

    /// Claim 7 — counterweights: tempo meta, velocity byte and End-of-Track are untouched.
    func testTempoVelocityAndEndOfTrackAreUnchanged() {
        let data = MIDIFileExporter.export(steps: oneKickAtStepsZeroAndEight(), tempo: 120)
        XCTAssertTrue(contains(data, [0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20]), "120 BPM tempo meta")
        XCTAssertTrue(contains(data, [0x99, 36, 100]), "the requested velocity is the emitted byte (#474)")
        XCTAssertTrue(contains(data, [0xFF, 0x2F, 0x00]), "End-of-Track")
        XCTAssertEqual(Array(data.prefix(4)), Array("MThd".utf8))
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
