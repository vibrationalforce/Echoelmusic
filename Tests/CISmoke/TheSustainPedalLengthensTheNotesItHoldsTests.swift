// TheSustainPedalLengthensTheNotesItHoldsTests.swift
// Echoel — workstation redesign B6b-1 (2026-10-01): the MIDI-file import APPLIES the sustain pedal
// (CC 64) to note LENGTHS instead of reading past it — the DAW "apply sustain" fold. B6b-0 said
// "The sustain pedal is not read."; the pedal is the one controller a listener hears as a wrong
// note length, and it needs no new field (`Note.lengthTicks` carries it), which is why it is the one
// piece of B6b that is buildable while CC / bend / pressure lanes stay HOLD (nothing plays them).
//
// THE LAW (header of `MIDIFileImporter.swift`): a note RELEASED while its channel's pedal is down
// (≥ 64; pedal events AT the release tick count) ends at that channel's first pedal-up AT OR AFTER
// the release, or at the next note-on of the SAME pitch on that channel if that comes first
// (re-strike law). A pedal-up on the release tick lets the note go there even when a press follows
// it on that tick (a pedal change). A pedal never lifted lets go at the channel's last note-off or
// pedal event. A length only ever grows.
//
// WHAT KIND OF GUARD (§1):
// 1–8. END-TO-END BEHAVIOUR — `MIDIFileImporter.parse` (public, Foundation-only) on literal SMF
//    bytes at 480 PPQ, so a file tick IS a `Note` tick: held chord to the lift; re-strike cuts and
//    another pitch does not; both tie cases at the release tick, and a pedal CHANGE there in both
//    write orders; channel-local; never lifted → the channel's last event, not a distant End of
//    Track; the 64 threshold on a continuous pedal; the pedal on ANOTHER TRACK of a Type-1 file; a
//    note-off written as note-on velocity 0 under running status; a file without a pedal unchanged.
// 9–10. END-TO-END — `MIDIImport.plan` → `successNote`: `sustainedNotes` counts only channels whose
//    notes land (channel 10 is folded but not counted); a lift after the last release lengthens the
//    PART; a held note still obeys the one-bar hold; the sentence carries the count, singular and
//    plural, and is absent when nothing was held.
// 11. SOURCE-TEXT SCAN: the B6b-0 pedal sentence and the `sustainPresses` count are gone from code,
//    and both new sentences are catalog literals. Proves where text sits, not what runs. (The
//    one-walker needle is NOT repeated here — `TheMIDIImportSaysWhatItLeavesOutTests` claim 4 and
//    `AMalformedMIDIFileCannotHangOrTrapTheParserTests` claim 5 already pin it; a third copy is #416.)
// 12. CATALOG: both new sentences translated, `manual`, commented; the old key is gone (an orphan
//    would fail `StringCatalogIsHonestTests`).
//
// Grading (§0/§3 — no Swift toolchain). This file does NOT compile against the parent (25fe5593c;
// the four touched files are byte-identical at 02a68bcaf): it names `parse(…).sustained` and
// `Landing.sustainedNotes`. NO assertion has a verdict there — ONE absence, not N findings (#486).
// Transcribed instead: a Python port of the proposed `parse` (fold on) and of the parent's (fold
// off), plus `plan`/`successNote`, driven over the exact fixtures below.
// REGRESSIONS (red on the parent's behaviour for their named reason — the pedal is not applied):
// 13 — the held lengths of claims 1, 2, 3a, 3b (both orders: the NEW chord's held E4), 5a, 6a, 7a,
// 7b, the part's held lengths, the tail's two bars, the long note's one-bar hold and its length.
// FORWARD (drive a symbol this commit creates): 29 — every `sustained` / `sustainedNotes` read, the
// two new sentences, the two new literals, the catalog's two new entries (6 checks each).
// CHANGED LAW (red on the parent BY DESIGN — the B6b-0 sentence was that tree's law): 5 — the old
// sentence absent from the chord's note; NO pedal sentence on a press that is never lifted (the
// parent SAID "The sustain pedal is not read." there — this one is NOT a counterweight); the old
// sentence and `sustainPresses` absent from the code; the old key absent from the catalog.
// COUNTERWEIGHTS (green on both): 9 — lift-at-release, other channel, press never lifted (lengths),
// 63 is up, no pedal (lengths), drum-note count, no pedal sentence on the pedal-free file, and the
// tempo sentence on both quiet files.
// FIRST-DRAFT PIN: claim 3b was RED on the reviewed draft (it read only the LAST pedal event of the
// release tick, so a lift-then-press there rang the old chord into the new one: C4 1440, not 480).
// STRIPPER (#453): PROPHYLAKTISCH — 0 of 4 claim-11 needles flip raw vs `codeOnly` (the import
// header splits the retired sentence across a line break).
// NOT covered: how a held chord SOUNDS through the roll (re-attack at a re-strike, voice count on a
// pedalled piano part), the sentence's wrap on the plate, German line length — device probes below.
// NEEDS-FOUNDER-VERIFY: Workstation → Import MIDI → a piano file with sustain pedal: (a) the plate
// says "N notes are lengthened by the sustain pedal." and the note editor shows the held lengths;
// (b) playback rings to the pedal lift, a repeated key re-attacks instead of smearing, and a chord
// change under a pedal change does not ring into the next chord; (c) a file without a pedal sounds
// and reads exactly as before; German reads naturally.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheSustainPedalLengthensTheNotesItHoldsTests: XCTestCase {

    private typealias Event = (tick: Int, bytes: [UInt8])

    private static let parserPath = "Sources/Echoelmusic/Sequencer/MIDIFileImporter.swift"
    private static let importPath = "Sources/Echoelmusic/Sequencer/MIDIImport.swift"
    private static let catalogPath = "Sources/Echoelmusic/Resources/Localizable.xcstrings"
    private static let oneHeld = " note is lengthened by the sustain pedal."
    private static let manyHeld = " notes are lengthened by the sustain pedal."
    private static let retiredSentence = " The sustain pedal is not read."

    // MARK: byte builders — 480 PPQ, so a file tick IS a `Note` tick

    private static func vlq(_ value: Int) -> [UInt8] {
        var groups: [UInt8] = [UInt8(value & 0x7F)]
        var rest = value >> 7
        while rest > 0 {
            groups.insert(UInt8(rest & 0x7F) | 0x80, at: 0)
            rest >>= 7
        }
        return groups
    }

    private static func chunk(_ body: [UInt8]) -> [UInt8] {
        let length = UInt32(body.count)
        let head: [UInt8] = [0x4D, 0x54, 0x72, 0x6B,
                             UInt8(truncatingIfNeeded: length >> 24), UInt8(truncatingIfNeeded: length >> 16),
                             UInt8(truncatingIfNeeded: length >> 8), UInt8(truncatingIfNeeded: length)]
        return head + body
    }

    /// Absolute-tick events → one track chunk with its End of Track. Ties keep their written order.
    private static func track(_ events: [Event]) -> [UInt8] {
        let ordered = events.enumerated().sorted { ($0.element.tick, $0.offset) < ($1.element.tick, $1.offset) }
        var body: [UInt8] = []
        var now = 0
        for (_, event) in ordered {
            body += vlq(event.tick - now) + event.bytes
            now = event.tick
        }
        return chunk(body + [0x00, 0xFF, 0x2F, 0x00])
    }

    /// Type 0 for one track, Type 1 for several.
    private static func smf(tracks: [[Event]]) -> [UInt8] {
        let format: UInt8 = tracks.count > 1 ? 1 : 0
        let count = UInt8(truncatingIfNeeded: tracks.count)
        var bytes: [UInt8] = [0x4D, 0x54, 0x68, 0x64, 0x00, 0x00, 0x00, 0x06,
                              0x00, format, 0x00, count, 0x01, 0xE0]
        for events in tracks { bytes += track(events) }
        return bytes
    }

    private static func smf(_ events: [Event]) -> [UInt8] { smf(tracks: [events]) }

    /// One Type-0 track around a raw body (the body brings its own End of Track).
    private static func smf(body: [UInt8]) -> [UInt8] {
        let header: [UInt8] = [0x4D, 0x54, 0x68, 0x64, 0x00, 0x00, 0x00, 0x06,
                               0x00, 0x00, 0x00, 0x01, 0x01, 0xE0]
        return header + chunk(body)
    }

    private static func on(_ pitch: UInt8, channel: UInt8 = 0) -> [UInt8] {
        let status: UInt8 = 0x90 | channel
        return [status, pitch, 0x64]
    }

    private static func off(_ pitch: UInt8, channel: UInt8 = 0) -> [UInt8] {
        let status: UInt8 = 0x80 | channel
        return [status, pitch, 0x00]
    }

    private static func pedal(_ value: UInt8, channel: UInt8 = 0) -> [UInt8] {
        let status: UInt8 = 0xB0 | channel
        return [status, 0x40, value]
    }

    // MARK: fixtures

    /// C4 + E4 released under the pedal, lifted at 1440; D4 played after the lift.
    private static var heldChord: [Event] {
        [(0, on(60)), (0, on(64)), (240, pedal(127)), (480, off(60)), (480, off(64)),
         (1440, pedal(0)), (1500, on(62)), (1800, off(62))]
    }

    /// C4 released under the pedal and struck again at 480; E4 between them; lift at 1440.
    private static var restrike: [Event] {
        [(0, pedal(127)), (0, on(60)), (240, off(60)), (240, on(64)), (300, off(64)),
         (480, on(60)), (720, off(60)), (1440, pedal(0))]
    }

    /// The press shares the release tick and is written AFTER the note-off.
    private static var pressAtRelease: [Event] {
        [(0, on(60)), (480, off(60)), (480, pedal(127)), (960, pedal(0))]
    }

    /// The lift shares the release tick and is written AFTER the note-off.
    private static var liftAtRelease: [Event] {
        [(0, pedal(127)), (0, on(60)), (480, off(60)), (480, pedal(0))]
    }

    /// A pedal CHANGE on a chord change: C4 ends at 480 where the pedal is lifted and pressed again
    /// on the same tick, E4 starts there and is held to the final lift. `releaseFirst` writes the
    /// note-off before the change (C4 off · up · down), otherwise after it (up · down · C4 off).
    private static func pedalChange(releaseFirst: Bool) -> [Event] {
        let change: [Event] = [(480, pedal(0)), (480, pedal(127))]
        let release: [Event] = [(480, off(60))]
        let atTheChange: [Event] = releaseFirst ? release + change : change + release
        let before: [Event] = [(0, pedal(127)), (0, on(60))]
        let after: [Event] = [(480, on(64)), (960, off(64)), (1440, pedal(0))]
        return before + atTheChange + after
    }

    /// Channel 2's pedal around channel 1's note.
    private static var otherChannel: [Event] {
        [(0, pedal(127, channel: 1)), (0, on(60)), (480, off(60)), (960, pedal(0, channel: 1))]
    }

    /// Never lifted; C4 released at 240, E4 at 960; a text event far later moves the End of Track.
    private static var neverLifted: [Event] {
        [(0, pedal(127)), (0, on(60)), (0, on(64)), (240, off(60)), (960, off(64)),
         (96_000, [0xFF, 0x01, 0x00])]
    }

    /// Pressed after the note began, never lifted, and nothing after the release.
    private static var pressOnly: [Event] {
        [(0, on(60)), (100, pedal(127)), (480, off(60))]
    }

    /// A continuous pedal: 80 and 112 are down, 48 is the lift.
    private static var continuous: [Event] {
        [(0, pedal(0x50)), (0, on(60)), (100, pedal(0x70)), (480, off(60)), (960, pedal(0x30))]
    }

    /// 63 is below the threshold.
    private static var halfway: [Event] {
        [(0, pedal(63)), (0, on(60)), (480, off(60)), (960, pedal(0))]
    }

    /// Notes only, including a repeated pitch.
    private static var noPedal: [Event] {
        [(0, on(60)), (240, on(64)), (480, off(60)), (960, off(64)), (960, on(60)), (1200, off(60))]
    }

    /// A drum hit held by channel 10's pedal beside one melodic note.
    private static var drumsHeld: [Event] {
        [(0, [0x99, 0x24, 0x64]), (0, pedal(127, channel: 9)), (0, on(60)), (480, off(60)),
         (480, [0x89, 0x24, 0x00]), (960, pedal(0, channel: 9))]
    }

    /// A note released at 1680 and lifted at 2400 — past the first barline (1920).
    private static var tailPastTheBar: [Event] {
        [(0, pedal(127)), (1440, on(60)), (1680, off(60)), (2400, pedal(0))]
    }

    /// Held from 0 to 2400 — longer than one bar.
    private static var heldPastABar: [Event] {
        [(0, pedal(127)), (0, on(60)), (480, off(60)), (2400, pedal(0))]
    }

    // MARK: readers

    /// [pitch, start, length] for one channel's notes, by start then pitch.
    private static func spans(_ file: [UInt8], channel: Int = 0) throws -> [[Int]] {
        try MIDIFileImporter.parse(from: file).notes
            .filter { $0.channel == channel }
            .map { [$0.note.pitch, $0.note.startTick, $0.note.lengthTicks] }
            .sorted { $0[1] != $1[1] ? $0[1] < $1[1] : $0[0] < $1[0] }
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

    // MARK: 1 — a released note is held until the pedal lifts

    func testAHeldChordLastsUntilThePedalLifts() throws {
        let file = Self.smf(Self.heldChord)
        XCTAssertEqual(try Self.spans(file), [[60, 0, 1440], [64, 0, 1440], [62, 1500, 300]],
                       "both chord notes released under the pedal end at the lift; D4, played after it, keeps its own length")
        let parsed = try MIDIFileImporter.parse(from: file)
        XCTAssertEqual(parsed.sustained.count, 16, "one count per MIDI channel")
        XCTAssertEqual(parsed.sustained[0], 2, "two notes were lengthened, D4 was not")
        XCTAssertEqual(parsed.sustained.reduce(0, +), 2)
    }

    // MARK: 2 — the re-strike law

    func testAReStruckPitchEndsTheHeldNoteAndAnotherPitchDoesNot() throws {
        let file = Self.smf(Self.restrike)
        XCTAssertEqual(try Self.spans(file), [[60, 0, 480], [64, 240, 1200], [60, 480, 960]],
                       "held C4 stops at its own re-strike (480), never overlapping itself; E4 is not cut by C4 and lasts to the lift; the re-struck C4 is held to the lift too")
        XCTAssertEqual(try MIDIFileImporter.parse(from: file).sustained[0], 3)
    }

    // MARK: 3 — the release tick: a press on it holds, a lift on it lets go

    func testThePedalStateAtTheReleaseIncludesThatTick() throws {
        XCTAssertEqual(try Self.spans(Self.smf(Self.pressAtRelease)), [[60, 0, 960]],
                       "a press AT the release tick holds the note, even written after the note-off")
        XCTAssertEqual(try Self.spans(Self.smf(Self.liftAtRelease)), [[60, 0, 480]],
                       "counterweight: a lift AT the release tick lets go there")
    }

    func testAPedalChangeOnTheReleaseTickLetsTheOldChordGo() throws {
        for releaseFirst in [true, false] {
            let file = Self.smf(Self.pedalChange(releaseFirst: releaseFirst))
            XCTAssertEqual(try Self.spans(file), [[60, 0, 480], [64, 480, 960]], """
                releaseFirst \(releaseFirst): the lift on C4's release tick lets C4 go there even \
                though a press follows it on that tick — reading only the LAST pedal event of the tick \
                would ring C4 into E4's chord until 1440; E4, struck under the new press, is held to the lift
                """)
            XCTAssertEqual(try MIDIFileImporter.parse(from: file).sustained[0], 1, "releaseFirst \(releaseFirst): only E4 grew")
        }
    }

    // MARK: 4 — a pedal holds only its own channel

    func testThePedalHoldsOnlyItsOwnChannel() throws {
        let file = Self.smf(Self.otherChannel)
        XCTAssertEqual(try Self.spans(file), [[60, 0, 480]], "channel 2's pedal does not hold channel 1's note")
        XCTAssertEqual(try MIDIFileImporter.parse(from: file).sustained, [Int](repeating: 0, count: 16))
    }

    // MARK: 5 — a pedal never lifted

    func testAPedalNeverLiftedLetsGoAtTheChannelsLastEvent() throws {
        XCTAssertEqual(try Self.spans(Self.smf(Self.neverLifted)), [[60, 0, 960], [64, 0, 960]],
                       "C4 is held to the channel's last note-off (960) — not to the End of Track after the text event at 96 000")
        XCTAssertEqual(try Self.spans(Self.smf(Self.pressOnly)), [[60, 0, 480]],
                       "counterweight: nothing after the release, so nothing to hold to — and the clamp never shortens")
    }

    // MARK: 6 — a continuous pedal crosses at 64

    func testAContinuousPedalHoldsFromSixtyFour() throws {
        XCTAssertEqual(try Self.spans(Self.smf(Self.continuous)), [[60, 0, 960]], "80 and 112 are down; 48 is the lift")
        XCTAssertEqual(try Self.spans(Self.smf(Self.halfway)), [[60, 0, 480]], "counterweight: 63 is up")
    }

    // MARK: 7 — the fold sees across tracks and through running status

    func testThePedalReachesNotesOnAnotherTrack() throws {
        let file = Self.smf(tracks: [[(0, Self.on(60)), (480, Self.off(60))],
                                     [(0, Self.pedal(127)), (960, Self.pedal(0))]])
        XCTAssertEqual(try Self.spans(file), [[60, 0, 960]],
                       "a Type-1 file keeps the pedal on its own track; the walk visits it AFTER the notes, so the fold must run after the walk")
    }

    func testANoteOffWrittenAsVelocityZeroUnderRunningStatusIsHeldToo() throws {
        // B0 40 7F · 90 3C 64 · (running) 40 64 · +480 (running) 3C 00 · (running) 40 00 · +960 B0 40 00 · end
        let body: [UInt8] = [0x00, 0xB0, 0x40, 0x7F,
                             0x00, 0x90, 0x3C, 0x64,
                             0x00, 0x40, 0x64,
                             0x83, 0x60, 0x3C, 0x00,
                             0x00, 0x40, 0x00,
                             0x87, 0x40, 0xB0, 0x40, 0x00,
                             0x00, 0xFF, 0x2F, 0x00]
        let file = Self.smf(body: body)
        XCTAssertEqual(try Self.spans(file), [[60, 0, 1440], [64, 0, 1440]])
        XCTAssertEqual(try MIDIFileImporter.parse(from: file).sustained[0], 2)
    }

    // MARK: 8 — no pedal, no change

    func testAFileWithoutAPedalReadsExactlyAsBefore() throws {
        let file = Self.smf(Self.noPedal)
        XCTAssertEqual(try Self.spans(file), [[60, 0, 480], [64, 240, 720], [60, 960, 240]])
        XCTAssertEqual(try MIDIFileImporter.parse(from: file).sustained.reduce(0, +), 0)
    }

    // MARK: 9 — the import counts what lands, and the part holds it

    func testTheImportCountsOnlyTheNotesItLands() throws {
        let chord = try Self.landing(Self.smf(Self.heldChord))
        XCTAssertEqual(chord.sustainedNotes, 2)
        XCTAssertEqual(try XCTUnwrap(chord.clip.melody?.notes).map(\.lengthTicks), [1440, 1440, 300],
                       "the part carries the held lengths")

        let drums = try Self.landing(Self.smf(Self.drumsHeld))
        XCTAssertEqual(drums.sustainedNotes, 0, "channel 10 is folded but not in the part, so it is not counted")
        XCTAssertEqual(drums.skippedDrumNotes, 1)
        XCTAssertEqual(try MIDIFileImporter.parse(from: Self.smf(Self.drumsHeld)).sustained[9], 1,
                       "the fold DID run on channel 10 — the import leaves it out, not the parser")

        let tail = try Self.landing(Self.smf(Self.tailPastTheBar))
        XCTAssertEqual(tail.region.lengthTicks, 2 * TimelineTime.ticksPerBar,
                       "a lift after the last release lengthens the PART: 1440 + 960 ends in bar 2")

        let long = try Self.landing(Self.smf(Self.heldPastABar))
        XCTAssertEqual(long.sustainedNotes, 1)
        XCTAssertEqual(long.heldForOneBar, 1, "a held note longer than a bar still obeys the one-bar hold")
        XCTAssertEqual(try XCTUnwrap(long.clip.melody?.notes).map(\.lengthTicks), [TimelineTime.ticksPerBar])
    }

    // MARK: 10 — the sentence

    func testTheNoteSaysHowManyNotesThePedalHeld() throws {
        let chord = try Self.landing(Self.smf(Self.heldChord))
        let many = MIDIImport.successNote(chord, laneName: "MIDI 1")
        XCTAssertTrue(many.contains(" 2" + Self.manyHeld), "the count and the plural")
        XCTAssertFalse(many.contains("is not read"), "the B6b-0 sentence is gone")

        let single = try Self.landing(Self.smf(Self.pressAtRelease))
        let one = MIDIImport.successNote(single, laneName: "MIDI 1")
        XCTAssertTrue(one.contains(" 1" + Self.oneHeld), "the singular")

        let quiet: [(name: String, events: [Event])] = [("no pedal", Self.noPedal),
                                                         ("press never lifted", Self.pressOnly)]
        for (name, events) in quiet {
            let landed = try Self.landing(Self.smf(events))
            let note = MIDIImport.successNote(landed, laneName: "MIDI 1")
            XCTAssertFalse(note.contains("sustain pedal"), "\(name): no pedal sentence when no note was held")
            XCTAssertTrue(note.contains("16th-note grid"), "\(name): counterweight — the tempo sentence stays")
        }
    }

    // MARK: 11 — the read-past pedal is gone from the code

    func testTheReadPastPedalIsGoneFromTheCode() throws {
        let importer = try source(Self.importPath)
        XCTAssertFalse(importer.contains(Self.retiredSentence), "the import no longer says the pedal is not read")
        XCTAssertTrue(importer.contains("String(localized: \"" + Self.oneHeld + "\")"), "the singular is a catalog key")
        XCTAssertTrue(importer.contains("String(localized: \"" + Self.manyHeld + "\")"), "the plural is a catalog key")
        let parser = try source(Self.parserPath)
        XCTAssertFalse(parser.contains("sustainPresses"), "the pedal is no longer a dropped-expression count")
    }

    // MARK: 12 — catalog

    func testTheHeldSentencesSpeakGermanAndTheOldOneIsGone() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let url = root.appendingPathComponent(Self.catalogPath)
        guard let data = try? Data(contentsOf: url),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: Any] else {
            return XCTFail("ANCHOR MISSING: cannot read \(Self.catalogPath) (#454)")
        }
        for key in [Self.oneHeld, Self.manyHeld] {
            guard let entry = strings[key] as? [String: Any] else {
                XCTFail("`\(key)` has no catalog entry — it shows in English on a German phone")
                continue
            }
            XCTAssertEqual(entry["extractionState"] as? String, "manual")
            XCTAssertFalse(((entry["comment"] as? String) ?? "").isEmpty, "a translator needs the context")
            let de = ((entry["localizations"] as? [String: Any])?["de"] as? [String: Any])?["stringUnit"] as? [String: Any]
            XCTAssertEqual(de?["state"] as? String, "translated")
            let value = (de?["value"] as? String) ?? ""
            XCTAssertTrue(value.hasPrefix(" "), "the leading space joins it to the number before")
            XCTAssertNotEqual(value, key, "the German unit is not the English key")
        }
        XCTAssertNil(strings[Self.retiredSentence],
                     "the B6b-0 sentence has no literal in Sources any more — left in the catalog it is an orphan")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

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
