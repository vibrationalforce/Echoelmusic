// ALongNoteSoundsItsWholeLengthTests.swift
// Echoel — EP-9 (end-to-end audit of the MIDI flow, 2026-10-15). A note longer than one bar —
// a pad stretched in the note editor, typed into the inspector's Length, or imported — sounded
// only its REMAINDER: both players release on `endStep % 16 == step`, so a 20-step note starting
// on step 0 matched step 4 of its own bar and stopped after four steps. `RegionNoteWindow` named
// it ("per-bar tied segments are a later refinement"); `MIDIImport` clamps imported notes to one
// bar because of it.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR (`RegionNoteWindow` + `LaneNotePump`, pure — the rack's real
//      scheduler): a 20-step note in a two-bar part attacks ONCE and releases on step 20.
//      Counterweight: the old one-slice shape through the same pump releases on step 4 — the
//      defect, reproduced, so the fixture can tell.
//      A loop WRAP still attacks again (one-bar loop of a whole-bar note, a note filling its part).
//   2. THE SEGMENTS: `barSlices` cuts only a note LONGER than a bar, at the bar line, keeping its
//      id; a sustain of up to one bar crosses the line uncut (the old contract, unchanged).
//   3. THE PRIMARY ROLL ties them: `PianoRollModel.wrapTies` pairs the ending head with its own
//      continuation by id — the existing "a full-bar note meets itself at the wrap" rule.
//
// ⚠️ HONEST GRADING (#433): on the parent this file compiles; claims 1 and 2 are REGRESSIONS
// there (the pump releases on step 4; `barSlices` returns one uncut note), the counterweights and
// claim 3 are green on both trees. Transcribed in Python on this geometry, no toolchain (§0).
// NOT covered: the roll's own step loop (`PianoRollModel.trigger`) is not run here; a chance
// operator on a long note can gate a continuation off and end the sound at the bar line.
// ⚠️ THE LIMIT: DEVICE PROBE (NEEDS-FOUNDER-VERIFY: in a two-bar part stretch one note to a bar
// and a quarter, play — it holds through the bar line without a new attack and stops on beat 2).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ALongNoteSoundsItsWholeLengthTests: XCTestCase {

    private let bar = TimelineTime.ticksPerBar

    /// Drive a pump over `steps` global steps from step 0: the step of every attack and release.
    private func events(_ bars: [[Note]], steps: Int) -> (on: [Int], off: [Int]) {
        var pump = LaneNotePump()
        pump.load(bars: bars, startBar: 0)
        var on: [Int] = []
        var off: [Int] = []
        for global in 0..<steps {
            for event in pump.step(global % 16) {
                if event.isOn { on.append(global) } else { off.append(global) }
            }
        }
        return (on, off)
    }

    // MARK: 1 — END-TO-END

    func testANoteOfABarAndAQuarterHoldsItsWholeLength() {
        let pad = Note(pitch: 48, startStep: 0, lengthSteps: 20)
        let slices = RegionNoteWindow.barSlices(
            notes: RegionNoteWindow.windowed(notes: [pad], offsetTicks: 0, lengthTicks: 2 * bar),
            regionLengthTicks: 2 * bar)
        let played = events(slices, steps: 32)
        XCTAssertEqual(played.on, [0], "one attack — the bar line is not a new note")
        XCTAssertEqual(played.off, [20], "released after its own twenty steps")

        let old = events([[pad], []], steps: 32)     // the pre-EP-9 slice: one uncut note
        XCTAssertEqual(old.off.first, 4, "premise: the old shape released after the remainder")
    }

    /// Counterweight: a whole-bar note in a ONE-bar loop is a new pass every bar — it attacks
    /// again (`LaneNotePumpTests.testFullBarNoteLoopsSeamlessly`); so does a note filling a
    /// two-bar part at the part's own wrap. Only a segment INSIDE the loop is carried.
    func testALoopWrapStillAttacksAgain() {
        let bar1 = Note(pitch: 36, startStep: 0, lengthSteps: 16)
        XCTAssertEqual(events([[bar1]], steps: 33).on, [0, 16, 32])
        let full = Note(pitch: 40, startStep: 0, lengthSteps: 32)
        let slices = RegionNoteWindow.barSlices(notes: [full], regionLengthTicks: 2 * bar)
        let played = events(slices, steps: 65)
        XCTAssertEqual(played.on, [0, 32, 64], "carried across bar 2, attacked at each loop pass")
    }

    // MARK: 2 — THE SEGMENTS

    func testOnlyANoteLongerThanABarIsCutAndItKeepsItsID() {
        let pad = Note(pitch: 48, startStep: 4, lengthSteps: 30)          // to step 34 = bar 3, step 2
        let slices = RegionNoteWindow.barSlices(notes: [pad], regionLengthTicks: 3 * bar)
        XCTAssertEqual(slices.map { $0.map(\.id) }, [[pad.id], [pad.id], [pad.id]])
        XCTAssertEqual(slices.map { $0.map(\.startStep) }, [[4], [0], [0]])
        XCTAssertEqual(slices.map { $0.map(\.lengthSteps) }, [[12], [16], [2]],
                       "the head ends ON the bar line, then a whole bar, then the remainder")

        let sustain = Note(pitch: 50, startStep: 15, lengthSteps: 4)       // crosses, but ≤ one bar
        let kept = RegionNoteWindow.barSlices(notes: [sustain], regionLengthTicks: 2 * bar)
        XCTAssertEqual(kept[0].map(\.lengthSteps), [4], "counterweight: a short sustain stays uncut")
        XCTAssertTrue(kept[1].isEmpty)
    }

    // MARK: 3 — THE PRIMARY ROLL

    func testTheRollTiesTheHeadToItsOwnContinuation() {
        let id = UUID()
        let ties = PianoRollModel.wrapTies(ending: [(id: id, pitch: 48, voiceKey: 1)],
                                           starting: [(id: id, pitch: 48, voiceKey: 1)])
        XCTAssertEqual(ties, [PianoRollModel.TiePair(endID: id, startID: id)])
    }
}
