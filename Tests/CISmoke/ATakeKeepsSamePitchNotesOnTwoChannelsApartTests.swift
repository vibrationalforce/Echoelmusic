// ATakeKeepsSamePitchNotesOnTwoChannelsApartTests.swift
// Ultraplan-MPE1 (2026-10-16, from the external live-set audit §4, measured at `7628d7d`): the take
// recorder named an open note by its PITCH alone, and the record tee dropped the channel the MIDI
// input already carried. An MPE controller plays every note on its own member channel, so two held
// notes of one pitch are ordinary there — and the recorder turned them into ONE short note (the
// second note-on closed the first as a re-trigger, the first note-off closed the second). An open
// note is now named by channel AND pitch, from the CoreMIDI callback to `MIDINoteRecorder`.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–2 are END-TO-END over the pure `MIDINoteRecorder` and `TakeRecorder`.
//   · Claim 3 is a SOURCE-TEXT SCAN: the tee from `MIDIBusPublisher` to `RecordController` hands the
//     channel on at both ends (a closure that drops it compiles, because the API defaults to 0).
//   · NOT CLAIMED: per-note expression (pressure, CC74, bend) is still not recorded, and playback is
//     still the one monophonic performer voice (`TheMPEInputHasNoZonesTests`). This keeps two notes;
//     it does not make MPE input real.
//   · DEVICE PROBE, open: an MPE controller, two fingers on one pitch, record, both notes in the part.
//
// HONEST GRADING against the parent (§3): the file does not COMPILE there — `channel:` is a new label
// — ONE absence (#486), every claim a FORWARD guard. Claim 1's single-channel half is a COUNTERWEIGHT
// (the old behaviour, unchanged). Mutants: the key back to pitch alone (1, two notes become one) · the
// tee closure ignoring its channel (3) · `flushOpen` keyed by pitch (1, the held pair is lost).

import Foundation
import XCTest
@testable import Echoelmusic

final class ATakeKeepsSamePitchNotesOnTwoChannelsApartTests: XCTestCase {

    // MARK: 1 — two channels, one pitch: two notes

    func testTwoHeldNotesOfOnePitchOnTwoChannelsAreTwoNotes() {
        var r = MIDINoteRecorder()
        r.noteOn(pitch: 60, velocity: 0.8, atTick: 0, channel: 1)
        r.noteOn(pitch: 60, velocity: 0.5, atTick: 120, channel: 2)
        XCTAssertEqual(r.openCount, 2, "the second finger is a second note, not a re-trigger")
        r.noteOff(pitch: 60, atTick: 480, channel: 1)
        r.noteOff(pitch: 60, atTick: 960, channel: 2)
        let notes = r.notes()
        XCTAssertEqual(notes.count, 2)
        XCTAssertEqual(notes.map(\.startTick), [0, 120])
        XCTAssertEqual(notes.map(\.lengthTicks), [480, 840], "each note-off closes its own channel's note")
        XCTAssertEqual(notes.map(\.velocity), [0.8, 0.5])

        // A held pair at the end of the take is flushed as two notes.
        var held = MIDINoteRecorder()
        held.noteOn(pitch: 64, velocity: 0.7, atTick: 0, channel: 3)
        held.noteOn(pitch: 64, velocity: 0.7, atTick: 0, channel: 4)
        held.flushOpen(atTick: 240)
        XCTAssertEqual(held.notes().count, 2)

        // A note-off on a channel that holds nothing closes nothing.
        var stray = MIDINoteRecorder()
        stray.noteOn(pitch: 67, velocity: 0.7, atTick: 0, channel: 1)
        stray.noteOff(pitch: 67, atTick: 60, channel: 2)
        XCTAssertEqual(stray.openCount, 1)

        // Counterweight: on ONE channel a second note-on is still a re-trigger.
        var one = MIDINoteRecorder()
        one.noteOn(pitch: 60, velocity: 0.5, atTick: 0)
        one.noteOn(pitch: 60, velocity: 0.9, atTick: 240)
        one.noteOff(pitch: 60, atTick: 480)
        XCTAssertEqual(one.notes().map(\.lengthTicks), [240, 240])
    }

    // MARK: 2 — the take carries the channel to every armed lane

    func testTheTakeRecordsBothChannels() {
        let lane = UUID()
        var take = TakeRecorder()
        take.start(targets: [(lane, .midiInput)], anchorTick: 0)
        take.noteOn(pitch: 60, velocity: 0.8, atTick: 0, channel: 1)
        take.noteOn(pitch: 60, velocity: 0.8, atTick: 0, channel: 2)
        take.noteOff(pitch: 60, atTick: 240, channel: 2)
        take.noteOff(pitch: 60, atTick: 480, channel: 1)
        let takes = take.finish(atTick: 960)
        XCTAssertEqual(takes.first?.clip.melody?.notes.count, 2)
        XCTAssertEqual(takes.first?.clip.melody?.notes.map(\.lengthTicks).sorted(), [240, 480])
    }

    // MARK: 3 — the record tee hands the channel on at both ends

    func testTheRecordTeeCarriesTheChannel() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        func code(_ path: String) throws -> String {
            SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8))
        }
        let publisher = try code("Sources/Echoelmusic/Sync/MIDIBusPublisher.swift")
        XCTAssertTrue(publisher.contains("self.onRecordNoteOn?(note, velocity, channel)"))
        XCTAssertTrue(publisher.contains("self.onRecordNoteOff?(note, channel)"))
        let app = try code("Sources/Echoelmusic/EchoelmusicApp.swift")
        XCTAssertTrue(app.contains("recordController?.recordNoteOn(pitch: note, velocity: velocity, channel: channel)"))
        XCTAssertTrue(app.contains("recordController?.recordNoteOff(pitch: note, channel: channel)"))
        let controller = try code("Sources/Echoelmusic/Core/RecordController.swift")
        XCTAssertTrue(controller.contains("recorder.noteOn(pitch: pitch, velocity: velocity, atTick: currentTick, channel: channel)"))
        XCTAssertTrue(controller.contains("recorder.noteOff(pitch: pitch, atTick: currentTick, channel: channel)"))
    }
}
