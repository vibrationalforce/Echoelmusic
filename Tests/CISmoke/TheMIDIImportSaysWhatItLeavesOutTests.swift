// TheMIDIImportSaysWhatItLeavesOutTests.swift
// Echoel — workstation redesign B6b-0 (2026-10-01): the MIDI-file import reads past pitch bend,
// pressure and controllers — and now SAYS so instead of leaving the loss for the ear. ⭐ B6b-1
// (2026-10-01) took the sustain pedal OUT of this file: it is applied to note lengths now, and
// its claims live in `TheSustainPedalLengthensTheNotesItHoldsTests`. B6b proper (CC / bend /
// pressure lanes in the note editor, an import that KEEPS them) is HOLD: no type in
// `Note`/`Clip` holds a controller value over time, and no player
// path would send one (the header of `MIDIFileImporter.swift` says why `NoteMPE` is not that
// type). A lane that edited such data would edit something nothing plays.
//
// 1. PURE (`MIDIFileImporter.parse`, END-TO-END on literal SMF bytes): MOVEMENT is counted on its
//    channel — a bend away from centre, channel AND polyphonic pressure above 0, a controller
//    CHANGE (never its first value, never CC 64) — and reading past them moves no note: the pairs
//    equal the same file without them, and `channelNotes` IS `parse(…).notes`. Since B6b-1 the
//    pedal DOES move a note, so "without them" means without the pedal too (`readPast`).
//    Running status across two bends keeps the byte widths right.
// 2. PURE (set-up is not movement): bank select, RPN/NRPN and data entry, a starting volume / pan
//    / send, a repeated value, a centred bend, a pressure of 0, a program change and channel mode
//    count NOTHING — almost every exported file opens with these, and a sentence that fires on
//    every file is the blanket disclaimer the note must not become.
// 3. PURE (`MIDIImport.plan` → `successNote`): only channels WITH NOTES IN THE PART count —
//    channel 10's notes are skipped and a noteless channel has nothing in the part to lose; each
//    sentence appears iff its kind is present; a plain file's note names neither; nothing is
//    smuggled into data that something might play (`mpe` stays nil, no automation).
// 4. SOURCE-TEXT SCAN: ONE walk — the import asks `parse(from:` once and `channelNotes(` never;
//    `channelNotes` is the one-line projection. Proves where text sits, not what runs.
// 5. CATALOG: the bend sentence has a translated English-only unit (German until 2026-10-02), `extractionState: manual`, a
//    comment. (The pedal sentence it shared this claim with is gone — B6b-1.)
//
// Grading (§0/§3 — no Swift toolchain). Claims 1–3 transcribed into a Python port of the
// proposed `parse` + the `plan` summation, driven over the exact fixture bytes below, against
// this tree and the parent (6a9c97718). On the parent `parse`, `DroppedExpression` and
// `droppedExpression` do not exist, so this file does NOT compile there and NO assertion has a
// verdict: ONE absence, not N findings (#486). REGRESSIONS: 0 — the silent loss was a missing
// SENTENCE, not a wrong value. FORWARD: every assertion naming the three new symbols or the two
// new sentences. COUNTERWEIGHTS (green on both trees, transcribed): the notes of the expressive
// and the set-up file equal the plain file's on the parent's parser too (it read the same bytes
// past at the same widths); the drum-note count and the tempo sentence still stand; `mpe` stays
// nil and `automation` empty. Claim 4 on the parent's TEXT: `channelNotes(` is in the import (1)
// and `parse(from:` is not (0) — red there for its named reason, recorded, not graded (the file
// does not compile there). STRIPPER (#453): PROPHYLAKTISCH — the import's header names the walk
// WITHOUT a paren on purpose, so no claim-4 needle flips raw vs `codeOnly`.
// B6b-1 EDIT (2026-10-01), transcribed against 02a68bcaf and the slice: claim 1 loses its
// `sustainPresses` assertion (the member is gone — a compile edit, not a finding) and gains the
// count the pedal now has (`parse(…).sustained`); claim 1's no-move test reads `readPast`, and a
// counterweight pins the EXPRESSIVE file's note at the pedal-up (600) instead; claim 3's pedal
// assertions flip from "not read" to the count sentence and to silence on a never-lifted pedal.
// NOT covered: the sentence on the device plate, its wrap at the largest type size, German line
// length, and what real DAW exports contain — device probes, owned below.
// NEEDS-FOUNDER-VERIFY: Workstation → Import MIDI → (a) a file with pitch bend → the plate's
// import line ends with the bend sentence; (b) a plain melody exported from a DAW (starting
// volume/pan, no automation) → no bend sentence; (c) a GM file whose only pedal is on channel 10
// → no pedal sentence, "N drum notes skipped." still there; German shows the bend sentence.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheMIDIImportSaysWhatItLeavesOutTests: XCTestCase {

    private static let parserPath = "Sources/Echoelmusic/Sequencer/MIDIFileImporter.swift"
    private static let importPath = "Sources/Echoelmusic/Sequencer/MIDIImport.swift"
    private static let catalogPath = "Sources/Echoelmusic/Resources/Localizable.xcstrings"
    private static let bendSentence = " Pitch bend, pressure and controller changes are not imported."

    // MARK: fixtures

    private static func vlq(_ value: Int) -> [UInt8] {
        var groups: [UInt8] = [UInt8(value & 0x7F)]
        var rest = value >> 7
        while rest > 0 {
            groups.insert(UInt8(rest & 0x7F) | 0x80, at: 0)
            rest >>= 7
        }
        return groups
    }

    /// A Type-0 file at 480 PPQ around a raw track body (the body brings its own end-of-track).
    private static func smf(body: [UInt8]) -> [UInt8] {
        var bytes: [UInt8] = [0x4D, 0x54, 0x68, 0x64, 0x00, 0x00, 0x00, 0x06,
                              0x00, 0x00, 0x00, 0x01, 0x01, 0xE0,
                              0x4D, 0x54, 0x72, 0x6B]
        let length = UInt32(body.count)
        bytes += [UInt8(truncatingIfNeeded: length >> 24), UInt8(truncatingIfNeeded: length >> 16),
                  UInt8(truncatingIfNeeded: length >> 8), UInt8(truncatingIfNeeded: length)]
        return bytes + body
    }

    /// Absolute-tick channel messages → a Type-0 file. Ties keep their written order.
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

    /// One C4 (channel 1) under everything the parser reads past.
    private static let expressive: [(tick: Int, bytes: [UInt8])] = [
        (0, [0xB0, 0x07, 0x64]),     // CC 7 first value       → set-up, not counted
        (0, [0xB0, 0x79, 0x00]),     // CC 121 reset all       → channel mode, not counted
        (0, [0xE0, 0x00, 0x40]),     // bend at centre         → set-up, not counted
        (0, [0x90, 0x3C, 0x64]),     // note on C4
        (120, [0xE0, 0x00, 0x50]),   // pitch bend             → pitchBends
        (240, [0xD0, 0x40]),         // channel pressure       → pressures
        (240, [0xA0, 0x3C, 0x30]),   // polyphonic pressure    → pressures
        (300, [0xB0, 0x4A, 0x50]),   // CC 74 first value      → not counted
        (330, [0xB0, 0x4A, 0x60]),   // CC 74 changes          → controllers
        (360, [0xB0, 0x40, 0x7F]),   // pedal down             → applied since B6b-1, not counted
        (480, [0x80, 0x3C, 0x00]),   // note off
        (600, [0xB0, 0x40, 0x00]),   // pedal up               → not counted
    ]

    /// The same file with only its notes.
    private static var plain: [(tick: Int, bytes: [UInt8])] {
        expressive.filter { event in
            let kind = event.bytes[0] & 0xF0
            return kind == 0x80 || kind == 0x90
        }
    }

    /// The expressive file without its pedal — what the parse still READS PAST since B6b-1.
    private static var readPast: [(tick: Int, bytes: [UInt8])] {
        expressive.filter { !($0.bytes[0] & 0xF0 == 0xB0 && $0.bytes[1] == 0x40) }
    }

    /// The plain file under the set-up a DAW or GM export typically opens with.
    private static var setUpOnly: [(tick: Int, bytes: [UInt8])] {
        let setUp: [(tick: Int, bytes: [UInt8])] = [
            (0, [0xB0, 0x00, 0x00]), (0, [0xB0, 0x20, 0x00]),                         // bank select
            (0, [0xB0, 0x65, 0x00]), (0, [0xB0, 0x64, 0x00]), (0, [0xB0, 0x06, 0x02]),
            (0, [0xB0, 0x26, 0x00]), (0, [0xB0, 0x65, 0x7F]), (0, [0xB0, 0x64, 0x7F]), // RPN bend range
            (0, [0xB0, 0x07, 0x64]), (0, [0xB0, 0x0A, 0x40]), (0, [0xB0, 0x5B, 0x28]), // volume, pan, send
            (0, [0xE0, 0x00, 0x40]), (0, [0xD0, 0x00]), (0, [0xC0, 0x05]),            // centre, 0, program
            (0, [0xB0, 0x40, 0x00]), (240, [0xB0, 0x07, 0x64]),                       // pedal up, same volume
            (0, [0xB5, 0x07, 0x64]), (240, [0xB5, 0x07, 0x20]),                       // a noteless channel MOVES
        ]
        return plain + setUp
    }

    private static func song() -> TimelineDocument {
        TimelineDocument(lanes: [TimelineLane(name: "MIDI 1", kind: .midi)])
    }

    private static func landing(_ bytes: [UInt8]) throws -> MIDIImport.Landing {
        guard case .success(let l) = MIDIImport.plan(name: "tune", bytes: bytes, document: song(),
                                                     freeSlotIndex: 0) else {
            XCTFail("the import refused a file with a melodic note")
            throw AnchorMissing(name: "MIDIImport.plan")
        }
        return l
    }

    // MARK: 1 — movement is counted on its channel

    func testEachKindOfMovementIsCountedOnItsChannel() throws {
        let parsed = try MIDIFileImporter.parse(from: Self.smf(Self.expressive))
        XCTAssertEqual(parsed.dropped.count, 16, "one count per MIDI channel")
        let first = parsed.dropped[0]
        XCTAssertEqual(first.pitchBends, 1, "the centred bend is set-up; the moved one counts")
        XCTAssertEqual(first.pressures, 2, "channel AND polyphonic pressure are both pressure")
        XCTAssertEqual(parsed.sustained[0], 1,
                       "B6b-1: the pedal is not read past any more — it held the note, and that is counted")
        XCTAssertEqual(first.controllers, 1, "CC 74's change counts — CC 7 and CC 74's first values and CC 121 do not")
        XCTAssertTrue(first.hasBendPressureOrControllers)
        for channel in 1..<16 {
            XCTAssertEqual(parsed.dropped[channel], MIDIFileImporter.DroppedExpression(),
                           "channel \(channel + 1) moved nothing and must count nothing")
        }
    }

    func testReadingPastExpressionMovesNoNote() throws {
        let rich = try MIDIFileImporter.parse(from: Self.smf(Self.readPast))
        let bare = try MIDIFileImporter.parse(from: Self.smf(Self.plain))
        XCTAssertEqual(rich.notes.count, 1)
        XCTAssertEqual(rich.notes.map { $0.channel }, bare.notes.map { $0.channel })
        XCTAssertEqual(rich.notes.map { $0.note.pitch }, bare.notes.map { $0.note.pitch })
        XCTAssertEqual(rich.notes.map { $0.note.startTick }, bare.notes.map { $0.note.startTick })
        XCTAssertEqual(rich.notes.map { $0.note.lengthTicks }, bare.notes.map { $0.note.lengthTicks })
        XCTAssertEqual(rich.notes.map { $0.note.lengthTicks }, [480])
        XCTAssertTrue(bare.dropped.allSatisfy { !$0.hasBendPressureOrControllers },
                      "a file of notes alone reads past nothing")
        let pedalled = try MIDIFileImporter.parse(from: Self.smf(Self.expressive))
        XCTAssertEqual(pedalled.notes.map { $0.note.lengthTicks }, [600],
                       "counterweight (B6b-1): WITH its pedal the note is held to the pedal-up at 600")
        let projected = try MIDIFileImporter.channelNotes(from: Self.smf(Self.expressive))
        XCTAssertEqual(projected.map { $0.note.pitch }, rich.notes.map { $0.note.pitch },
                       "`channelNotes` is the same walk without the counts")
        XCTAssertEqual(projected.map { $0.note.startTick }, rich.notes.map { $0.note.startTick })
    }

    func testRunningStatusAcrossTwoBendsKeepsTheByteWidths() throws {
        // E0 00 50 · (running) 00 51 after 16 ticks · note on · note off 480 later · end.
        let bytes: [UInt8] = [0x00, 0xE0, 0x00, 0x50,
                              0x10, 0x00, 0x51,
                              0x00, 0x90, 0x3C, 0x64,
                              0x83, 0x60, 0x80, 0x3C, 0x00,
                              0x00, 0xFF, 0x2F, 0x00]
        let parsed = try MIDIFileImporter.parse(from: Self.smf(body: bytes))
        XCTAssertEqual(parsed.dropped[0].pitchBends, 2, "a running-status bend is still a bend")
        XCTAssertEqual(parsed.notes.map { $0.note.pitch }, [60], "the note after them still parses")
        XCTAssertEqual(parsed.notes.map { $0.note.startTick }, [16])
        XCTAssertEqual(parsed.notes.map { $0.note.lengthTicks }, [480])
    }

    // MARK: 2 — set-up is not movement

    func testSetUpMessagesCountNothing() throws {
        let parsed = try MIDIFileImporter.parse(from: Self.smf(Self.setUpOnly))
        XCTAssertEqual(parsed.dropped[0], MIDIFileImporter.DroppedExpression(),
                       "bank select, RPN, starting volume/pan/send, a repeated value, a centred bend, a 0 pressure and a program change are set-up")
        XCTAssertEqual(parsed.dropped[5].controllers, 1,
                       "counterweight: a real change IS counted at the parse, even on a channel without notes")
        let bare = try MIDIFileImporter.parse(from: Self.smf(Self.plain))
        XCTAssertEqual(parsed.notes.map { $0.note.startTick }, bare.notes.map { $0.note.startTick })
        XCTAssertEqual(parsed.notes.map { $0.note.lengthTicks }, bare.notes.map { $0.note.lengthTicks })
    }

    // MARK: 3 — the import and its sentence

    func testOnlyChannelsWithNotesInThePartAreNamed() throws {
        let drumsAndOneNote: [(tick: Int, bytes: [UInt8])] = [
            (0, [0x99, 0x24, 0x64]), (0, [0xB9, 0x40, 0x7F]), (0, [0xE9, 0x00, 0x50]),
            (0, [0x90, 0x3C, 0x64]), (480, [0x80, 0x3C, 0x00]), (480, [0x89, 0x24, 0x00]),
        ]
        let quiet = try Self.landing(Self.smf(drumsAndOneNote))
        XCTAssertEqual(quiet.droppedExpression, MIDIFileImporter.DroppedExpression(),
                       "channel 10's notes are skipped, so its pedal and bend must not be named")
        XCTAssertEqual(quiet.skippedDrumNotes, 1, "counterweight: the drum note itself is still counted")
        let noteless: [(tick: Int, bytes: [UInt8])] = drumsAndOneNote + [(tick: 240, bytes: [0xE1, 0x00, 0x50])]
        XCTAssertEqual(try Self.landing(Self.smf(noteless)).droppedExpression, MIDIFileImporter.DroppedExpression(),
                       "channel 2 has no note in the part, so its bend is no loss of the part")
        let melodic: [(tick: Int, bytes: [UInt8])] = drumsAndOneNote + [(tick: 240, bytes: [0xE0, 0x00, 0x50])]
        XCTAssertEqual(try Self.landing(Self.smf(melodic)).droppedExpression.pitchBends, 1,
                       "counterweight: a bend on the channel whose note landed is named")
        XCTAssertEqual(try Self.landing(Self.smf(Self.setUpOnly)).droppedExpression, MIDIFileImporter.DroppedExpression(),
                       "set-up plus a noteless channel's movement: nothing in the part was lost")
    }

    func testTheNoteNamesEachKindTheFileHasAndNoneItLacks() throws {
        let rich = try Self.landing(Self.smf(Self.expressive))
        let richNote = MIDIImport.successNote(rich, laneName: "MIDI 1")
        XCTAssertTrue(richNote.contains("1 note is lengthened by the sustain pedal"),
                      "B6b-1: the pedal is applied and the note says so")
        XCTAssertFalse(richNote.contains("sustain pedal is not read"))
        XCTAssertTrue(richNote.contains("Pitch bend, pressure and controller changes are not imported"))

        let files: [(name: String, events: [(tick: Int, bytes: [UInt8])])] = [("plain", Self.plain),
                                                                              ("set-up only", Self.setUpOnly)]
        for (name, events) in files {
            let landed = try Self.landing(Self.smf(events))
            let note = MIDIImport.successNote(landed, laneName: "MIDI 1")
            XCTAssertFalse(note.contains("sustain pedal"), "\(name): no blanket disclaimer on a file without a pedal press")
            XCTAssertFalse(note.contains("Pitch bend"), "\(name): no blanket disclaimer on a file without movement")
            XCTAssertTrue(note.contains("16th-note grid"), "\(name): counterweight — the tempo sentence stays")
        }

        let pedalOnly: [(tick: Int, bytes: [UInt8])] = Self.plain + [(tick: 100, bytes: [0xB0, 0x40, 0x7F])]
        let pedalLanding = try Self.landing(Self.smf(pedalOnly))
        let pedalNote = MIDIImport.successNote(pedalLanding, laneName: "MIDI 1")
        XCTAssertFalse(pedalNote.contains("sustain pedal"),
                       "B6b-1: a press never lifted past the channel's last release lengthens nothing, so nothing is said")
        XCTAssertFalse(pedalNote.contains("Pitch bend"), "the pedal alone is not a controller change")
    }

    func testNothingTheFileMovedIsStoredWhereSomethingCouldPlayIt() throws {
        let l = try Self.landing(Self.smf(Self.expressive))
        let notes = try XCTUnwrap(l.clip.melody?.notes)
        XCTAssertEqual(notes.count, 1)
        XCTAssertTrue(notes.allSatisfy { $0.mpe == nil },
                      "a file's bend is not an MPE bend: on the ±48-semitone range it would replay far too wide")
        XCTAssertTrue(l.clip.automation.isEmpty, "a controller is not a parameter curve")
    }

    // MARK: 4 — one walk

    func testTheImportAsksTheOneWalkOnce() throws {
        let importer = try source(Self.importPath)
        XCTAssertEqual(importer.components(separatedBy: "MIDIFileImporter.parse(from:").count - 1, 1,
                       "the import asks the walk once")
        XCTAssertFalse(importer.contains("channelNotes("),
                       "a second call would be a second walk over the same bytes")
        let parser = try source(Self.parserPath)
        let projection = try body(of: "public static func channelNotes(from data: [UInt8])", in: parser)
        XCTAssertTrue(projection.contains("try parse(from: data).notes"),
                      "`channelNotes` is the projection of the one walk, not a second one")
        XCTAssertEqual(parser.components(separatedBy: "absTick = Swift.min(absTick + readVLQ(), Self.maxFileTick)").count - 1, 1,
                       "counterweight: exactly one track walker")
    }

    // MARK: 5 — catalog

    func testTheBendSentenceIsCatalogued() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let url = root.appendingPathComponent(Self.catalogPath)
        guard let data = try? Data(contentsOf: url),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: Any] else {
            return XCTFail("ANCHOR MISSING: cannot read \(Self.catalogPath) (#454)")
        }
        for key in [Self.bendSentence] {
            guard let entry = strings[key] as? [String: Any] else {
                XCTFail("`\(key)` has no catalog entry — the sentence left the catalog it is looked up in")
                continue
            }
            XCTAssertEqual(entry["extractionState"] as? String, "manual")
            XCTAssertFalse(((entry["comment"] as? String) ?? "").isEmpty, "a translator needs the context")
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            let en = (localizations["en"] as? [String: Any])?["stringUnit"] as? [String: Any]
            XCTAssertEqual(en?["state"] as? String, "translated")
            let value = (en?["value"] as? String) ?? ""
            XCTAssertTrue(value.hasPrefix(" "), "the leading space joins it to the sentence before")
            XCTAssertEqual(value, key, "the English unit is the key")
            XCTAssertEqual(Set(localizations.keys), ["en"], "the app speaks one language (founder 2026-10-02) — no second unit")
        }
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    /// The brace-matched body after `anchor` (§2, #408 — never a fixed line window).
    private func body(of anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor),
              let open = code.range(of: "{", range: start.lowerBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: \(anchor)")
            throw AnchorMissing(name: anchor)
        }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let ch = code[index]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return String(code[open.lowerBound...index]) }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: \(anchor)")
        throw AnchorMissing(name: anchor)
    }

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return SourceText.codeOnly(text)
    }
}
