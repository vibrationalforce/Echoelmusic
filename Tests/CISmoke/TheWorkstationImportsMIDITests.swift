// TheWorkstationImportsMIDITests.swift
// Echoel — S2 (founder 2026-09-23, "all tasks"): a Standard MIDI File becomes one user-owned
// MIDI part on the Workstation's MIDI track, and Workstation Play plays its whole length.
//
// WHAT KIND OF GUARD THIS IS (§1), per claim:
// · Claims 1–8 are END-TO-END BEHAVIOUR over pure statics: literal SMF bytes through the shipped
//   parser into `MIDIImport.plan`, then the ENGINE's own predicates (`canPlay`,
//   `executableNotes`, `RegionNoteWindow.barSlices`) on the result. No store is constructed on
//   a success path — both persist into the App Group, so a success test would leave clips and
//   tracks in the running app's saved state (`AudioImport.plan`'s header gives the same reason).
// · Claims 9–13 are SOURCE-TEXT SCANS: who calls what, and where the one importer sits.
// · DEVICE PROBE, open: that the picker shows MIDI files, that the part SOUNDS, the one-bar hold
//   and the instrument-running coupling — items (44)–(52) in `WorkstationView`'s header.
//
// HONEST GRADING (§3). This file does NOT compile against the parent: it names `MIDIImport`,
// which this commit creates. No assertion has a verdict there. Transcribed instead:
// · claims 1–8, 11 and 13 are FORWARD guards (they drive or name the new type);
// · claim 9 is a REGRESSION on the parent's `syncPrimaryRollClip` (it called
//   `ensureComposerRegion(` unconditionally) — reported once, as a forward scan, because the
//   anchor `userPartWouldBeShadowed(` is new (#486);
// · claims 10 and 12 are FORWARD (the rows and callers are new), with COUNTERWEIGHT halves —
//   the audio importer's prefix and the parser's other caller stay where they were.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheWorkstationImportsMIDITests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let importer = "Sources/Echoelmusic/Sequencer/MIDIImport.swift"
    private static let door = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let sourcesRoot = "Sources/Echoelmusic"

    // MARK: - Fixtures

    /// A variable-length quantity (SMF), most significant group first.
    private static func vlq(_ value: Int) -> [UInt8] {
        var groups: [UInt8] = [UInt8(value & 0x7F)]
        var rest = value >> 7
        while rest > 0 {
            groups.insert(UInt8(rest & 0x7F) | 0x80, at: 0)
            rest >>= 7
        }
        return groups
    }

    /// One note as absolute ticks at 480 PPQ.
    private struct Event { let channel: Int; let pitch: Int; let start: Int; let length: Int }

    /// A Type-0 file at 480 PPQ (so file ticks and note ticks are the same number).
    private static func smf(_ events: [Event]) -> [UInt8] {
        var timed: [(tick: Int, bytes: [UInt8])] = []
        for e in events {
            let ch = UInt8(e.channel & 0x0F)
            timed.append((e.start, [0x90 | ch, UInt8(e.pitch), 0x64]))
            timed.append((e.start + e.length, [0x80 | ch, UInt8(e.pitch), 0x00]))
        }
        timed.sort { $0.tick < $1.tick }
        var body: [UInt8] = []
        var now = 0
        for t in timed {
            body += vlq(t.tick - now) + t.bytes
            now = t.tick
        }
        body += [0x00, 0xFF, 0x2F, 0x00]
        var bytes: [UInt8] = [0x4D, 0x54, 0x68, 0x64, 0x00, 0x00, 0x00, 0x06,
                              0x00, 0x00, 0x00, 0x01, 0x01, 0xE0,
                              0x4D, 0x54, 0x72, 0x6B]
        let length = UInt32(body.count)
        bytes += [UInt8(truncatingIfNeeded: length >> 24), UInt8(truncatingIfNeeded: length >> 16),
                  UInt8(truncatingIfNeeded: length >> 8), UInt8(truncatingIfNeeded: length)]
        return bytes + body
    }

    /// A song with a bio MIDI lane FIRST, an audio lane, then the one lane the engine plays
    /// through the roll — so a lane rule that is not `rollLaneID` lands somewhere else.
    private static func song() -> (doc: TimelineDocument, roll: UUID) {
        let bio = TimelineLane(name: "Bio", kind: .midi, isBio: true)
        let audio = TimelineLane(name: "Audio 1", kind: .audio)
        let midi = TimelineLane(name: "MIDI 1", kind: .midi)
        return (TimelineDocument(lanes: [bio, audio, midi]), midi.id)
    }

    private static func landing(_ bytes: [UInt8]?, _ doc: TimelineDocument,
                                slot: Int? = 0) -> Result<MIDIImport.Landing, MIDIImport.Failure> {
        MIDIImport.plan(name: "tune", bytes: bytes, document: doc, freeSlotIndex: slot)
    }

    private static func failure(_ r: Result<MIDIImport.Landing, MIDIImport.Failure>) -> MIDIImport.Failure? {
        if case .failure(let f) = r { return f }
        return nil
    }

    /// Two bars: C4 on beat 1, E4 on beat 3, G4 across bar 2 (two beats).
    private static let tune: [Event] = [
        Event(channel: 0, pitch: 60, start: 0, length: 480),
        Event(channel: 0, pitch: 64, start: 960, length: 480),
        Event(channel: 1, pitch: 67, start: bar + 480, length: 960),
    ]

    // MARK: - 1…8 Behaviour

    /// 1. A file becomes ONE user-owned MIDI clip carrying exactly the parsed melodic notes, and
    /// ONE region on the engine's roll lane, at the lane's next free tick, in whole bars.
    func testAMIDIFileBecomesOneUserOwnedPartOnTheRollLane() throws {
        let (doc, roll) = Self.song()
        guard case .success(let l) = Self.landing(Self.smf(Self.tune), doc) else {
            return XCTFail("a two-bar, three-note file was refused")
        }
        XCTAssertEqual(l.clip.kind, .midi)
        XCTAssertFalse(l.clip.composerOwned, "an imported part must be USER-owned — the composer may never rewrite it")
        XCTAssertNil(l.clip.mediaRef, "a MIDI part carries its notes in the clip, not on disk")
        let notes = try XCTUnwrap(l.clip.melody?.notes)
        XCTAssertEqual(notes.map(\.pitch), [60, 64, 67])
        XCTAssertEqual(notes.map(\.startTick), [0, 960, Self.bar + 480])
        XCTAssertEqual(notes.map(\.lengthTicks), [480, 480, 960])
        XCTAssertEqual(l.laneID, roll)
        XCTAssertEqual(doc.rollLaneID, roll, "counterweight: the fixture's roll lane is the engine's")
        XCTAssertEqual(l.region.laneID, roll)
        XCTAssertEqual(l.region.clipID, l.clip.id)
        XCTAssertEqual(l.region.startTick, 0)
        XCTAssertEqual(l.region.lengthTicks, 2 * Self.bar)
        XCTAssertEqual(l.clip.colorIndex, l.slotIndex)
    }

    /// 2. The ENGINE agrees: Play is offered, every note is loaded, one bar slice per bar, and
    /// the last bar holds the last note — the whole file, not a one-bar window.
    func testTheImportedPartPlaysItsWholeLength() throws {
        let (doc0, _) = Self.song()
        guard case .success(let l) = Self.landing(Self.smf(Self.tune), doc0) else {
            return XCTFail("the fixture was refused")
        }
        var doc = doc0
        doc.regions.append(l.region)
        XCTAssertTrue(TimelineRegionPlayer.canPlay(doc, clips: [l.clip],
                                                   bpm: TimelineRegionPlayer.fallbackTempo,
                                                   resolveAudio: { _ in nil }),
                      "the engine refuses the imported part — Play would stay grey")
        let loaded = TimelineRegionPlayer.executableNotes(of: l.clip, in: l.region,
                                                          bpm: TimelineRegionPlayer.fallbackTempo)
        XCTAssertEqual(loaded.count, 3)
        let bars = RegionNoteWindow.barSlices(notes: loaded, regionLengthTicks: l.region.lengthTicks)
        XCTAssertEqual(bars.count, 2)
        XCTAssertEqual(bars.last?.map(\.pitch), [67])
    }

    /// 3. A second import APPENDS after the first on the same lane, never on top of it.
    func testASecondImportAppendsAfterTheFirst() throws {
        let (doc0, roll) = Self.song()
        guard case .success(let first) = Self.landing(Self.smf(Self.tune), doc0) else {
            return XCTFail("the fixture was refused")
        }
        var doc = doc0
        doc.regions.append(first.region)
        guard case .success(let second) = Self.landing(Self.smf(Self.tune), doc, slot: 1) else {
            return XCTFail("the second import was refused")
        }
        XCTAssertEqual(second.laneID, roll)
        XCTAssertEqual(second.region.startTick, first.region.endTick)
    }

    /// 4. The refusals answer in the founder's order: the file first, then the lane, then the
    /// slot — and each has a sentence of its own.
    func testTheFileAnswersBeforeTheLaneAndTheSlot() throws {
        let empty = TimelineDocument()
        XCTAssertEqual(Self.failure(Self.landing(nil, empty, slot: nil)), MIDIImport.Failure.unreadableFile)
        XCTAssertEqual(Self.failure(Self.landing([0x00, 0x01, 0x02], empty, slot: nil)), MIDIImport.Failure.notAMIDIFile)
        XCTAssertEqual(Self.failure(Self.landing(Self.smf(Self.tune), empty, slot: nil)), MIDIImport.Failure.noMIDILane)
        let (doc, _) = Self.song()
        XCTAssertEqual(Self.failure(Self.landing(Self.smf(Self.tune), doc, slot: nil)), MIDIImport.Failure.clipGridFull)

        let audioOnly = TimelineDocument(lanes: [TimelineLane(name: "Audio 1", kind: .audio),
                                                 TimelineLane(name: "Bio", kind: .midi, isBio: true)])
        XCTAssertEqual(Self.failure(Self.landing(Self.smf(Self.tune), audioOnly)), MIDIImport.Failure.noMIDILane,
                       "an audio lane or a bio MIDI lane is not the roll lane")

        let all: [MIDIImport.Failure] = [.pickerFailed, .unreadableFile, .fileTooLarge, .notAMIDIFile,
                                         .noMelodicNotes, .tooLong, .noMIDILane, .clipGridFull]
        XCTAssertEqual(Set(all.map(\.userMessage)).count, all.count, "two failures share one sentence")
    }

    /// 5. Channel 10 is skipped and COUNTED; a file with nothing else is REFUSED, never placed
    /// as an empty part that greys Play for a reason nobody can see.
    func testDrumNotesAreSkippedAndADrumOnlyFileIsRefused() throws {
        let (doc, _) = Self.song()
        let kit = [Event(channel: 9, pitch: 36, start: 0, length: 120),
                   Event(channel: 9, pitch: 38, start: 480, length: 120)]
        XCTAssertEqual(Self.failure(Self.landing(Self.smf(kit), doc)), MIDIImport.Failure.noMelodicNotes)
        XCTAssertTrue(MIDIImport.Failure.noMelodicNotes.userMessage.contains("drum"))

        guard case .success(let l) = Self.landing(Self.smf(kit + Self.tune), doc) else {
            return XCTFail("a mixed file was refused")
        }
        XCTAssertEqual(l.skippedDrumNotes, 2)
        XCTAssertEqual(l.clip.melody?.notes.count, 3)
        XCTAssertTrue(MIDIImport.successNote(l, laneName: "MIDI 1").contains("drum notes skipped"))
    }

    /// 6. The limits refuse rather than truncate: a part past `maxBars`, a file past
    /// `maxFileBytes`. At the bar limit exactly, it lands.
    func testAnOverlongPartOrFileIsRefused() throws {
        let (doc, _) = Self.song()
        let lastBar = (MIDIImport.maxBars - 1) * Self.bar
        let atLimit = [Event(channel: 0, pitch: 60, start: lastBar, length: 480)]
        guard case .success(let l) = Self.landing(Self.smf(atLimit), doc) else {
            return XCTFail("a part exactly \(MIDIImport.maxBars) bars long was refused")
        }
        XCTAssertEqual(l.region.lengthTicks, MIDIImport.maxBars * Self.bar)

        let past = [Event(channel: 0, pitch: 60, start: lastBar + Self.bar, length: 480)]
        XCTAssertEqual(Self.failure(Self.landing(Self.smf(past), doc)), MIDIImport.Failure.tooLong)

        let huge = Self.smf(Self.tune) + [UInt8](repeating: 0, count: MIDIImport.maxFileBytes)
        XCTAssertEqual(Self.failure(Self.landing(huge, doc)), MIDIImport.Failure.fileTooLarge,
                       "the byte cap is checked on what was read, before parsing")
    }

    /// 7. A note longer than a bar is held for EXACTLY one bar — the roll releases on
    /// `endStep % 16`, so a longer note would otherwise sound only its remainder.
    func testANoteLongerThanABarIsHeldForOneBar() throws {
        let (doc, _) = Self.song()
        let pad = [Event(channel: 0, pitch: 48, start: 0, length: Self.bar + 4 * 120)]
        guard case .success(let l) = Self.landing(Self.smf(pad), doc) else {
            return XCTFail("a one-note pad was refused")
        }
        XCTAssertEqual(l.clip.melody?.notes.first?.lengthTicks, Self.bar)
        XCTAssertEqual(l.heldForOneBar, 1)
        XCTAssertEqual(l.region.lengthTicks, Self.bar, "the clamp decides the bar span too")
        XCTAssertTrue(MIDIImport.successNote(l, laneName: "MIDI 1").contains("held for one bar"))
    }

    /// 8. The composer's question: a NEW composer region over `[0, window)` would shadow a
    /// user part inside the window — but not a composer part, not a missing clip, and not a
    /// part that starts after the window.
    func testTheShadowQuestionCountsOnlyExistingUserParts() throws {
        let (doc0, roll) = Self.song()
        let window = 8 * Self.bar
        let user = Clip(name: "user", kind: .midi, melody: MelodyClip(notes: []))
        let composed = Clip(name: "take", kind: .midi, melody: MelodyClip(notes: []), composerOwned: true)
        func ask(_ start: Int, _ clipID: UUID, clips: [Clip]) -> Bool {
            var doc = doc0
            doc.regions = [TimelineRegion(laneID: roll, clipID: clipID, startTick: start, lengthTicks: Self.bar)]
            return MIDIImport.userPartWouldBeShadowed(onLane: roll, in: doc, clips: clips, windowTicks: window)
        }
        XCTAssertTrue(ask(0, user.id, clips: [user, composed]))
        XCTAssertTrue(ask(window - 1, user.id, clips: [user]))
        XCTAssertFalse(ask(window, user.id, clips: [user]), "a part after the window is not shadowed")
        XCTAssertFalse(ask(0, composed.id, clips: [user, composed]), "the composer's own region never blocks it")
        XCTAssertFalse(ask(0, UUID(), clips: [user]), "a region whose clip is missing is inaudible — nothing to shadow")
        XCTAssertFalse(MIDIImport.userPartWouldBeShadowed(onLane: roll, in: doc0, clips: [user], windowTicks: window))
    }

    // MARK: - 9…13 Source-text scans

    /// 9. The instrument ASKS before it adds a composer region, so a user part keeps bar 1.
    func testTheComposerYieldsToAUserPart() throws {
        let code = SourceText.codeOnly(try rawText(Self.studio))
        let body = try body(of: "syncPrimaryRollClip", in: code)
        let ask = try XCTUnwrap(body.range(of: "MIDIImport.userPartWouldBeShadowed("),
                                "`syncPrimaryRollClip` no longer asks whether a user part would be shadowed")
        let add = try XCTUnwrap(body.range(of: "ensureComposerRegion("),
                                "counterweight: `syncPrimaryRollClip` no longer creates the composer region")
        XCTAssertLessThan(ask.lowerBound, add.lowerBound,
                          "the question must come BEFORE the composer region is added, or the import is already shadowed")
        XCTAssertEqual(occurrences(of: "ensureComposerRegion(", in: body), 1)
    }

    /// 10. The door: two labelled rows, the lane creator handed the store, and ONE importer on
    /// this leaf whose prefix the audio guard pins (#W1 — two importers can shadow a picker).
    func testTheDoorHasTwoRowsAndOneImporter() throws {
        let door = SourceText.codeOnly(try rawText(Self.door))
        for label in ["Add MIDI Track", "Import MIDI", "Import Audio", "Add Audio Track"] {
            XCTAssertTrue(door.contains("Text(\"\(label)\")"), "the \"\(label)\" row is no longer labelled")
        }
        XCTAssertTrue(door.contains("MIDIImport.addMIDITrack(timeline: timeline)"))
        XCTAssertEqual(occurrences(of: ".fileImporter(", in: door), 1,
                       "the Workstation must keep ONE importer whose type switches (#W1)")
        XCTAssertTrue(door.contains(".fileImporter(isPresented: $importPresented"),
                      "counterweight: the one importer is still the audio door's")
        XCTAssertTrue(door.contains("UTType.midi") && door.contains("handleMIDIImport(result)"))
        XCTAssertEqual(try filesUnderSources(containing: "MIDIImport.perform("), ["Studio/WorkstationView.swift"])
    }

    /// 11. The transaction writes the clip BEFORE the region, only on success, and touches no
    /// persistence, media library or engine predicate of its own.
    func testTheClipIsWrittenBeforeTheRegionAndNothingElse() throws {
        let code = SourceText.codeOnly(try rawText(Self.importer))
        let commit = try body(of: "commit(", in: code)
        let clip = try XCTUnwrap(commit.range(of: "clipStore.setClip("))
        let region = try XCTUnwrap(commit.range(of: "timeline.addRegion("))
        XCTAssertLessThan(clip.lowerBound, region.lowerBound)
        let refusal = try XCTUnwrap(commit.range(of: "case .failure"))
        XCTAssertLessThan(refusal.lowerBound, clip.lowerBound, "a refusal must return before any write")
        for banned in ["AppGroupStore", "UserDefaults", "JSONEncoder", "MediaLibrary.", "canPlay("] {
            XCTAssertFalse(code.contains(banned), "`MIDIImport` now names `\(banned)`")
        }
    }

    /// 12. The parser's callers are the import and the (buttonless) instrument path — a third
    /// caller is a second opinion about what a MIDI file contains.
    func testTheParserHasTwoCallers() throws {
        XCTAssertEqual(try filesUnderSources(containing: "MIDIFileImporter."),
                       ["Sequencer/MIDIImport.swift", "Studio/EchoelStudioView.swift"])
    }

    /// 13. The no-lane refusal instructs ONLY while a production row can obey it — the
    /// biconditional `TheWorkstationImportsAudioTests` claim 18 holds for the audio twin.
    func testTheNoLaneRefusalOnlyInstructsWhatARowCanDo() throws {
        let doored = try filesUnderSources(containing: "addMIDITrack(")
            .filter { $0 != "Sequencer/MIDIImport.swift" }
        let instructs = MIDIImport.Failure.noMIDILane.userMessage.lowercased().contains("add a midi track")
        XCTAssertEqual(instructs, !doored.isEmpty, """
            The no-MIDI-lane refusal and the app's ability to add a MIDI track disagree \
            (instructs: \(instructs); rows calling `addMIDITrack(`: \(doored.count)).
            """)
    }

    // MARK: - Helpers

    private func occurrences(of needle: String, in text: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var index = text.startIndex
        while let found = text.range(of: needle, range: index..<text.endIndex) {
            count += 1
            index = found.upperBound
        }
        return count
    }

    private struct AnchorMissing: Error { let name: String }

    /// The brace-matched body of `func <name>` (§2, #408 — never a fixed line window).
    private func body(of name: String, in code: String) throws -> String {
        guard let start = code.range(of: "func \(name)"),
              let open = code.range(of: "{", range: start.upperBound..<code.endIndex)
        else {
            XCTFail("`func \(name)` is not where this guard looks — re-anchor it (#1240)")
            throw AnchorMissing(name: name)
        }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let character = code[index]
            if character == "{" { depth += 1 }
            if character == "}" {
                depth -= 1
                if depth == 0 { return String(code[open.upperBound..<index]) }
            }
            index = code.index(after: index)
        }
        throw XCTSkip("unbalanced braces after `func \(name)` — refusing to guess its body")
    }

    private func filesUnderSources(containing needle: String) throws -> [String] {
        let root = try repoRoot().appendingPathComponent(Self.sourcesRoot)
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            throw XCTSkip("cannot enumerate \(Self.sourcesRoot) — refusing to report a green it did not earn")
        }
        var hits: [String] = []
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
            else { continue }
            if SourceText.codeOnly(text).contains(needle) { hits.append(relative) }
        }
        return hits.sorted()
    }

    private func rawText(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("\(relativePath) is not present — this guard inspects source text (#454)")
        }
        return try String(contentsOf: path, encoding: .utf8)
    }

    private func repoRoot() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
