// AMovedSoundingNoteIsReleasedTests.swift
// Echoel — Phase 3 / Creation Workflow, MIDI editor slice M5b: a note moved while it sounds.
//
// WHAT IT PINS. Since M5 a note edit reaches playback on the next step. Both note schedulers keep
// what sounds in a table keyed by the note's ID — `LaneNotePump.active` on the rack tracks,
// `PianoRollModel.active` on the roll. The editor keeps a note's ID when it moves it. So a note
// dragged, WHILE IT SOUNDS, to a later start inside its own span and onto another pitch reached
// its new onset with its old entry still in the table: the onset overwrote the entry, and the
// old pitch was never released — a hung note, until Stop.
//
// 1. END-TO-END BEHAVIOUR over `LaneNotePump` (pure, public): the old pitch is released at the
//    new onset, ahead of the attack, and nothing is left sounding after the moved note ends.
//    The same-pitch move (a retrigger) stays exactly one attack.
// 2. SOURCE-TEXT SCAN over `PianoRollModel.trigger`: the roll releases a displaced note ahead of
//    its attacks, with the same voice and MIDI de-dup as its ordinary releases. The roll's trigger
//    is private and needs live voices, so this half is a scan, not a drive.
//
// Grading (§0, no Swift toolchain in a web session): `LaneNotePump.step`/`load` were transcribed
// into Python and driven against both trees. On the parent (`65ed99950`) this file COMPILES; claim
// 1a (no release of 60 at the new onset) and 1b (60 attacked and never released) are
// REGRESSIONS, red for the reason their messages give (1b counts the EVENTS the voice hears —
// the pump's own table cannot show the hang, the overwrite erased it); claim 1c (a same-pitch move is one attack)
// is a COUNTERWEIGHT, green on both; claim 2 is red on the parent by ANCHOR ABSENCE (one absence,
// #486).
// NOT covered: that the roll's release is HEARD on a device.
// NEEDS-FOUNDER-VERIFY: Workstation → Notes on a playing MIDI part → while a long note sounds,
// drag it later and up or down → the old pitch stops; nothing hangs after Stop.

import Foundation
import XCTest
@testable import Echoelmusic

final class AMovedSoundingNoteIsReleasedTests: XCTestCase {

    private static let rollPath = "Sources/Echoelmusic/Studio/PianoRollView.swift"

    private func ons(_ events: [LaneNotePump.Event]) -> [Int] { events.filter(\.isOn).map(\.pitch) }
    private func offs(_ events: [LaneNotePump.Event]) -> [Int] { events.filter { !$0.isOn }.map(\.pitch) }

    /// A one-bar loop holding ONE note of `id`, sounding from step 0; steps 0…3 played.
    private func pumpSounding(_ id: UUID) -> (LaneNotePump, [LaneNotePump.Event]) {
        var pump = LaneNotePump()
        pump.load(bars: [[Note(id: id, pitch: 60, startStep: 0, lengthSteps: 8)]], startBar: 0)
        var heard = pump.step(0)
        XCTAssertEqual(ons(heard), [60], "ANCHOR MISSING: the note did not start")
        for s in 1..<4 { heard += pump.step(s) }
        return (pump, heard)
    }

    // MARK: 1 — END-TO-END (LaneNotePump)

    func testANoteMovedWhileSoundingReleasesItsOldPitch() {
        let id = UUID()
        var (pump, heard) = pumpSounding(id)
        // The edit: same note, later start inside its own span, a new pitch.
        pump.load(bars: [[Note(id: id, pitch: 64, startStep: 4, lengthSteps: 4)]], startBar: 0)
        let atTheNewOnset = pump.step(4)
        heard += atTheNewOnset
        XCTAssertEqual(offs(atTheNewOnset), [60], """
            1a: the moved note starts again under its OLD id — the old pitch 60 must be released \
            there, or the new entry overwrites the only record that it is sounding
            """)
        XCTAssertEqual(ons(atTheNewOnset), [64])
        XCTAssertEqual(atTheNewOnset.first, LaneNotePump.Event(pitch: 60, velocity: 0),
                       "1a: the release comes ahead of the attack — the pump's own order law")
        for s in 5..<8 { heard += pump.step(s) }
        let atTheEnd = pump.step(8)
        heard += atTheEnd
        XCTAssertEqual(offs(atTheEnd), [64], "the moved note ends where it now ends")
        // The pump's own table cannot show a hung note — the overwrite erased the only record of
        // it. The VOICE hears the events, so the balance is counted there.
        XCTAssertEqual(ons(heard).sorted(), offs(heard).sorted(), """
            1b: attacked \(ons(heard).sorted()) but released \(offs(heard).sorted()) — a pitch \
            attacked and never released is a hung note that only Stop ends
            """)
    }

    func testANoteMovedInTimeOnlyIsOneAttack() {
        let id = UUID()
        var (pump, _) = pumpSounding(id)
        pump.load(bars: [[Note(id: id, pitch: 60, startStep: 4, lengthSteps: 4)]], startBar: 0)
        let atTheNewOnset = pump.step(4)
        XCTAssertEqual(atTheNewOnset, [LaneNotePump.Event(pitch: 60, velocity: 0.8)],
                       "1c: same pitch, same voice — a retrigger, not a release plus an attack")
    }

    // MARK: 2 — SOURCE-TEXT SCAN (PianoRollModel.trigger)

    func testTheRollReleasesADisplacedNoteBeforeItsAttacks() throws {
        let roll = try source(Self.rollPath)
        guard let head = roll.range(of: "private func trigger(_ step: Int) {"),
              let displaced = roll.range(of: "old.pitch != note.pitch || !sameVoice(old.role, note.role) else { continue }",
                                         range: head.upperBound..<roll.endIndex),
              let attacks = roll.range(of: "let exp = Self.noteExpression(note, loopPass: operatorLoopPass",
                                       range: head.upperBound..<roll.endIndex)
        else {
            return XCTFail("ANCHOR MISSING: the roll's displaced release (#454)")
        }
        XCTAssertLessThan(displaced.lowerBound, attacks.lowerBound, "released ahead of every attack")
        let block = String(roll[displaced.upperBound..<attacks.lowerBound])
        XCTAssertTrue(block.contains("outputVoice(for: old.role)?.noteOff(pitch: old.pitch)"))
        XCTAssertTrue(block.contains("midiOut?.noteOff(pitch: old.pitch)"),
                      "the MIDI mirror is released too, or an external synth hangs")
    }

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }
}
