// TheMIDIImportNamesTimingAndInstrumentChangesTests.swift
// Ultraplan-A6 (2026-10-16): the MIDI-file import already said what it reads past for bend,
// pressure and controllers (B6b-0) and what the pedal did (B6b-1). Three things stayed "unread AND
// unsaid" in `MIDIImport.swift`'s header: program changes, tempo changes and the time signature.
// A part has no field for any of them and no player would follow one, so the import now SAYS so —
// for CHANGES only, the B6b-0 law: nearly every exported file opens with a program, a tempo and a
// 4/4, and a sentence that fires on every file teaches the reader to skip it.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–4 are END-TO-END over the shipped parser and `MIDIImport.plan`/`successNote` on
//     hand-built Standard MIDI Files (bytes written here, at 480 PPQ).
//   · Claim 5 reads the string catalog (each new sentence is a key, so it is localisable).
//   · DEVICE PROBE, open: importing a real DAW export with a tempo map and seeing the note.
//
// HONEST GRADING against the parent (§3): the file does not COMPILE there — it names
// `DroppedExpression.programChanges`, `FileTiming` and `Landing.fileTiming`, which this commit
// creates — ONE absence (#486), every claim a FORWARD guard. Hand-transcribed (the meta and
// program-change branches of the walk) against the fixtures. Mutants and the claim each turns red:
// counting the opening program (1) · counting a program on a channel with no notes in the part (1)
// · counting the opening tempo (2) · reading 4/4 as "other" (3) · reading a tempo whose 3 bytes run
// past the track (4, a read past `bodyEnd` traps).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheMIDIImportNamesTimingAndInstrumentChangesTests: XCTestCase {

    private static let programSentence =
        " The file's instrument changes are not followed; the track's own sound plays every note."
    private static let tempoSentence = " The file's tempo changes are not followed."
    private static let meterSentence = " The file is not in 4/4; its notes are placed on the piece's 4/4 bars."

    // MARK: fixtures (the B6b-0 guard's shape: absolute ticks → a Type-0 file at 480 PPQ)

    private static func vlq(_ value: Int) -> [UInt8] {
        var groups: [UInt8] = [UInt8(value & 0x7F)]
        var rest = value >> 7
        while rest > 0 {
            groups.insert(UInt8(rest & 0x7F) | 0x80, at: 0)
            rest >>= 7
        }
        return groups
    }

    private static func smf(body: [UInt8]) -> [UInt8] {
        var bytes: [UInt8] = [0x4D, 0x54, 0x68, 0x64, 0x00, 0x00, 0x00, 0x06,
                              0x00, 0x00, 0x00, 0x01, 0x01, 0xE0,
                              0x4D, 0x54, 0x72, 0x6B]
        let length = UInt32(body.count)
        bytes += [UInt8(truncatingIfNeeded: length >> 24), UInt8(truncatingIfNeeded: length >> 16),
                  UInt8(truncatingIfNeeded: length >> 8), UInt8(truncatingIfNeeded: length)]
        return bytes + body
    }

    private static func smf(_ events: [(tick: Int, bytes: [UInt8])]) -> [UInt8] {
        let ordered = events.enumerated().sorted { ($0.element.tick, $0.offset) < ($1.element.tick, $1.offset) }
        var body: [UInt8] = []
        var now = 0
        for (_, event) in ordered {
            body += vlq(event.tick - now) + event.bytes
            now = event.tick
        }
        return smf(body: body + [0x00, 0xFF, 0x2F, 0x00])
    }

    /// One C4 on channel 1, a bar long.
    private static let note: [(tick: Int, bytes: [UInt8])] = [(0, [0x90, 0x3C, 0x64]), (1_920, [0x80, 0x3C, 0x00])]
    private static let tempo120: [UInt8] = [0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20]   // 500 000 µs/quarter
    private static let tempo90: [UInt8] = [0xFF, 0x51, 0x03, 0x0A, 0x2C, 0x2B]    // 666 667 µs/quarter
    private static let fourFour: [UInt8] = [0xFF, 0x58, 0x04, 0x04, 0x02, 0x18, 0x08]
    private static let threeFour: [UInt8] = [0xFF, 0x58, 0x04, 0x03, 0x02, 0x18, 0x08]

    private static func landing(_ events: [(tick: Int, bytes: [UInt8])]) throws -> MIDIImport.Landing {
        let song = TimelineDocument(lanes: [TimelineLane(name: "MIDI 1", kind: .midi)])
        guard case .success(let landed) = MIDIImport.plan(name: "tune", bytes: smf(events), document: song,
                                                          freeSlotIndex: 0) else {
            throw XCTSkip("premise: the import refused a file with one melodic note")
        }
        return landed
    }

    private static func sentence(_ events: [(tick: Int, bytes: [UInt8])]) throws -> String {
        MIDIImport.successNote(try landing(events), laneName: "MIDI 1")
    }

    // MARK: 1 — a program CHANGE on a landed channel is named; the opening program is not

    func testAProgramChangeIsNamedAndTheOpeningProgramIsNot() throws {
        let opening = note + [(0, [0xC0, 0x05])]
        XCTAssertEqual(try Self.landing(opening).droppedExpression.programChanges, 0, "the opening program is set-up")
        XCTAssertFalse(try Self.sentence(opening).contains(Self.programSentence))

        let changed = opening + [(960, [0xC0, 0x30])]
        XCTAssertEqual(try Self.landing(changed).droppedExpression.programChanges, 1)
        XCTAssertTrue(try Self.sentence(changed).contains(Self.programSentence))

        let same = opening + [(960, [0xC0, 0x05])]
        XCTAssertEqual(try Self.landing(same).droppedExpression.programChanges, 0, "the same program again is no change")

        let otherChannel = note + [(0, [0xC2, 0x05]), (960, [0xC2, 0x30])]
        XCTAssertEqual(try Self.landing(otherChannel).droppedExpression.programChanges, 0,
                       "channel 3 has no note in the part, so its change is no loss of the part")
        XCTAssertFalse(try Self.landing(changed).droppedExpression.hasBendPressureOrControllers,
                       "counterweight: a program change is not named as a bend or controller")
    }

    // MARK: 2 — a tempo CHANGE is named; the opening tempo, and the same tempo again, are not

    func testATempoChangeIsNamedAndTheOpeningTempoIsNot() throws {
        let opening = note + [(0, Self.tempo120)]
        XCTAssertEqual(try Self.landing(opening).fileTiming.tempoChanges, 0)
        XCTAssertFalse(try Self.sentence(opening).contains(Self.tempoSentence))
        XCTAssertEqual(try Self.landing(opening + [(960, Self.tempo120)]).fileTiming.tempoChanges, 0)

        let changed = opening + [(960, Self.tempo90)]
        XCTAssertEqual(try Self.landing(changed).fileTiming.tempoChanges, 1)
        XCTAssertTrue(try Self.sentence(changed).contains(Self.tempoSentence))
        XCTAssertTrue(try Self.sentence(changed).contains("16th-note grid"), "counterweight: the tempo line stays")
    }

    // MARK: 3 — a time signature other than 4/4 is named; 4/4 is not

    func testATimeSignatureOtherThanFourFourIsNamed() throws {
        let common = note + [(0, Self.fourFour)]
        XCTAssertFalse(try Self.landing(common).fileTiming.hasTimeSignatureOtherThanFourFour)
        XCTAssertFalse(try Self.sentence(common).contains(Self.meterSentence))
        let waltz = note + [(0, Self.threeFour)]
        XCTAssertTrue(try Self.landing(waltz).fileTiming.hasTimeSignatureOtherThanFourFour)
        XCTAssertTrue(try Self.sentence(waltz).contains(Self.meterSentence))
        let plain = try Self.sentence(Self.note)
        for unsaid in [Self.programSentence, Self.tempoSentence, Self.meterSentence] {
            XCTAssertFalse(plain.contains(unsaid), "a file of notes alone gets no disclaimer: \(unsaid)")
        }
    }

    // MARK: 4 — a meta whose payload runs past the track is read past, never read

    func testAMetaRunningPastTheTrackIsNotRead() throws {
        // note on · note off · FF 51 03 with only two payload bytes before the track ends.
        let body: [UInt8] = [0x00, 0x90, 0x3C, 0x64, 0x8F, 0x00, 0x80, 0x3C, 0x00, 0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1]
        let parsed = try MIDIFileImporter.parse(from: Self.smf(body: body))
        XCTAssertEqual(parsed.notes.map { $0.note.pitch }, [60], "the note before it still parses")
        XCTAssertEqual(parsed.timing, MIDIFileImporter.FileTiming(), "a cut-off tempo is not a tempo")
    }

    // MARK: 5 — each sentence is a catalog key

    func testTheSentencesAreCatalogued() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let data = try Data(contentsOf: root.appendingPathComponent("Sources/Echoelmusic/Resources/Localizable.xcstrings"))
        let catalog = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        for key in [Self.programSentence, Self.tempoSentence, Self.meterSentence] {
            XCTAssertNotNil(strings[key], "`\(key)` is not in the catalog")
        }
    }
}
