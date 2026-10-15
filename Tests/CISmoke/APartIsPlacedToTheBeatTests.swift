// APartIsPlacedToTheBeatTests.swift
// Echoel — EP-4 (founder 2026-10-15: MIDI clips "zu ungenau", not "entspannt" to edit). The part
// bar offered only "Starts at bar" — whole bars. It now offers the beat within the bar, and a MIDI
// part's length in beats, as numbers.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR (`TrackParts`, pure): the beat field keeps the bar and the place within
//      the beat; it refuses a non-finite value, a beat outside the bar and the beat already held
//      (nothing to undo). The length field sets whole beats, at least one, and refuses no change.
//   2. SOURCE-TEXT SCAN: both fields are mounted under "Starts at bar"; the length field only for a
//      MIDI part (an audio part's length is its media window, trimmed at its edges); each writes once
//      on commit through the store (`TrackParts.move` / `resizeRegion`).
//
// ⚠️ HONEST GRADING (#433): every claim is FORWARD — the helpers and fields are created here (one
// absence, #486). Transcribed, no local toolchain (§0).
// ⚠️ THE LIMIT: DEVICE PROBE (NEEDS-FOUNDER-VERIFY: select a MIDI part, type beat 3 — it moves half a
// bar; type length 6 — it is a bar and a half long; one Undo each).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class APartIsPlacedToTheBeatTests: XCTestCase {

    private let bar = TimelineTime.ticksPerBar
    private let beat = TimelineTime.ticksPerBeat

    func testTheBeatFieldKeepsTheBarAndTheRest() {
        let start = 4 * bar + 2 * beat + 60                       // bar 5, beat 3, 60 ticks in
        let part = TrackParts.Part(id: UUID(), startTick: start, lengthTicks: bar)
        XCTAssertEqual(TrackParts.beatInBar(forTick: start), 3)
        XCTAssertEqual(TrackParts.startTick(forBeat: 1, keeping: part), 4 * bar + 60,
                       "beat 1 of the same bar, the 60 ticks within the beat kept")
        XCTAssertNil(TrackParts.startTick(forBeat: 3, keeping: part), "the beat it holds — nothing to undo")
        XCTAssertNil(TrackParts.startTick(forBeat: Double(bar / beat + 1), keeping: part), "past the bar's last beat")
        XCTAssertNil(TrackParts.startTick(forBeat: .nan, keeping: part))
        XCTAssertNil(TrackParts.startTick(forBeat: 0, keeping: part))
    }

    func testTheLengthFieldSetsWholeBeats() {
        let part = TrackParts.Part(id: UUID(), startTick: 0, lengthTicks: bar)
        XCTAssertEqual(TrackParts.lengthBeats(part), Double(bar) / Double(beat))
        XCTAssertEqual(TrackParts.lengthTicks(forBeats: 6, keeping: part), 6 * beat)
        XCTAssertNil(TrackParts.lengthTicks(forBeats: Double(bar / beat), keeping: part), "no change, no Undo step")
        XCTAssertEqual(TrackParts.lengthTicks(forBeats: 0.2, keeping: part), beat, "never shorter than one beat")
        XCTAssertNil(TrackParts.lengthTicks(forBeats: .infinity, keeping: part))
    }

    func testBothFieldsAreMountedAndTheLengthOnlyForMIDI() throws {
        let code = try source("Sources/Echoelmusic/Studio/SelectedPartBar.swift")
        guard let start = code.range(of: "PartStartField(part: part, songBars:"),
              let beatField = code.range(of: "PartBeatField(part: part)", range: start.upperBound..<code.endIndex),
              let midi = code.range(of: "if PartLength.isMIDI(regionID, in: document) {", range: beatField.upperBound..<code.endIndex),
              let length = code.range(of: "PartLengthField(part: part, songBars:", range: midi.upperBound..<code.endIndex) else {
            return XCTFail("ANCHOR MISSING: the start, beat and length fields in this order")
        }
        XCTAssertLessThan(beatField.lowerBound, length.lowerBound)
        XCTAssertTrue(code.contains("return lane.kind == .midi && !lane.isBio"), "the length field is MIDI-only")
        XCTAssertTrue(code.contains("TrackParts.move(part, toStartTick: tick, timeline: timeline)"), "the beat writes through the one mover")
        XCTAssertTrue(code.contains("timeline.resizeRegion(id: part.id, lengthTicks: ticks)"), "the length writes through the store")
    }

    // MARK: helpers

    private func source(_ relativePath: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 where !FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
            dir = dir.deletingLastPathComponent()
        }
        let url = dir.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relativePath) not on disk — this run has no source tree")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }
}
