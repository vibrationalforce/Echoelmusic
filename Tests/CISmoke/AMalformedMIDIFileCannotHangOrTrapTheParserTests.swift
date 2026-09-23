// AMalformedMIDIFileCannotHangOrTrapTheParserTests.swift
// Echoel — S2 prerequisite (founder 2026-09-23, "all tasks"): the Workstation's "Import MIDI"
// hands `MIDIFileImporter` whatever file a user picks, so a malformed file must end in a
// result or a thrown error — never an endless loop on the main actor, never a trap.
//
// WHAT KIND OF GUARD THIS IS (§1). Claims 1–4 are END-TO-END BEHAVIOUR: literal byte fixtures
// through the shipped, public, Foundation-only parser. Claim 5 is a SOURCE-TEXT SCAN of the two
// lines that make the termination argument.
//
// HONEST GRADING (§3). This file compiles against the parent — it names only symbols that
// already existed. Graded by TRANSCRIPTION (a Python port of `channelNotes`, both trees, Swift's
// discarding `<<` and trapping `+`/`*` modelled explicitly):
// · claim 2 is a REGRESSION: on the parent the ten-byte meta length wraps to −13 and walks the
//   read index back to the same event — an ENDLESS LOOP (the port hit its step ceiling);
// · claim 3 is a REGRESSION: on the parent an eight-byte delta reaches ~3.5·10^19 and
//   `fileTick * 480` TRAPS;
// · claim 4 is a FORWARD guard (the parent returns 5000·(2^28−1) ticks without a trap; the
//   clamp to 2^40 is new);
// · claims 1 and 5's counterweight half are COUNTERWEIGHTS, green on both trees.
// ⚠️ On the parent, claims 2 and 3 would not report red — they would hang or kill the clone
// (§5, #1174). That is the defect, not a flaw in the guard.

import Foundation
import XCTest
@testable import Echoelmusic

final class AMalformedMIDIFileCannotHangOrTrapTheParserTests: XCTestCase {

    /// A Type-0 file at 480 PPQ wrapping one track body.
    private static func smf(_ body: [UInt8]) -> [UInt8] {
        var bytes: [UInt8] = [0x4D, 0x54, 0x68, 0x64, 0x00, 0x00, 0x00, 0x06,
                              0x00, 0x00, 0x00, 0x01, 0x01, 0xE0]
        bytes += [0x4D, 0x54, 0x72, 0x6B]
        let length = UInt32(body.count)
        bytes += [UInt8(truncatingIfNeeded: length >> 24), UInt8(truncatingIfNeeded: length >> 16),
                  UInt8(truncatingIfNeeded: length >> 8), UInt8(truncatingIfNeeded: length)]
        return bytes + body
    }

    /// 1. COUNTERWEIGHT — a well-formed file still reads exactly: middle C, one quarter.
    func testAWellFormedFileStillReadsExactly() throws {
        let body: [UInt8] = [0x00, 0x90, 0x3C, 0x64, 0x83, 0x60, 0x80, 0x3C, 0x00,
                             0x00, 0xFF, 0x2F, 0x00]
        let notes = try MIDIFileImporter.channelNotes(from: Self.smf(body))
        XCTAssertEqual(notes.count, 1)
        let note = try XCTUnwrap(notes.first)
        XCTAssertEqual(note.channel, 0)
        XCTAssertEqual(note.note.pitch, 60)
        XCTAssertEqual(note.note.startTick, 0)
        XCTAssertEqual(note.note.lengthTicks, Note.ticksPerQuarter)
    }

    /// 2. A ten-byte meta length that wraps to a NEGATIVE number used to walk the read index
    /// back onto the same event forever. Now it must end.
    func testANegativeMetaLengthCannotLoopForever() throws {
        let body: [UInt8] = [0x00, 0xFF, 0x01,
                             0x81, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x73,
                             0x00, 0x90, 0x3C, 0x64, 0x60, 0x80, 0x3C, 0x00]
        let result = try? MIDIFileImporter.channelNotes(from: Self.smf(body))
        XCTAssertLessThanOrEqual(result?.count ?? 0, 1, "the parser returned — it did not hang")
    }

    /// 3. An eight-byte delta used to make `fileTick * 480` overflow and trap.
    func testAnOverlongDeltaCannotTrap() throws {
        let body: [UInt8] = [0x00, 0x90, 0x3C, 0x64,
                             0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F,
                             0x80, 0x3C, 0x00]
        let result = try? MIDIFileImporter.channelNotes(from: Self.smf(body))
        XCTAssertLessThanOrEqual(result?.count ?? 0, 1, "the parser returned — it did not trap")
    }

    /// 4. Legal four-byte deltas that add up past the ceiling are clamped at it: the note's
    /// end sits at `maxFileTick`, mapped (480 PPQ in, 480 out → the same number).
    func testTheRunningTickIsClampedAtItsCeiling() throws {
        var body: [UInt8] = [0x00, 0x90, 0x3C, 0x64]
        for _ in 0..<5000 {
            body += [0xFF, 0xFF, 0xFF, 0x7F, 0xFF, 0x01, 0x00]   // max delta, empty text event
        }
        body += [0x00, 0x80, 0x3C, 0x00]
        let notes = try MIDIFileImporter.channelNotes(from: Self.smf(body))
        let note = try XCTUnwrap(notes.first)
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(note.note.startTick, 0)
        XCTAssertEqual(note.note.lengthTicks, MIDIFileImporter.maxFileTick,
                       "5000 × (2^28 − 1) ticks exceeds 2^40 and must stop there")
    }

    /// 5. SOURCE-TEXT SCAN — the two lines the termination argument rests on.
    func testTheVariableLengthReadIsCappedAndTheTickClamped() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Echoelmusic/Sequencer/MIDIFileImporter.swift")
        // #1240: only a missing TREE may skip; an unreadable file that exists is a red.
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("MIDIFileImporter.swift is not present — this guard inspects source text (#454)")
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        let code = SourceText.codeOnly(text)
        XCTAssertTrue(code.contains("for _ in 0..<4 {"),
                      "a variable-length quantity must stop after four bytes (SMF)")
        XCTAssertTrue(code.contains("absTick = Swift.min(absTick + readVLQ(), Self.maxFileTick)"),
                      "the running tick must be clamped, or `mapTicks` can overflow")
        XCTAssertTrue(code.contains("func mapTicks("), "counterweight: the tick map still exists")
    }
}
