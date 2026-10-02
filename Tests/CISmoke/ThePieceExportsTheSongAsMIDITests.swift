// ThePieceExportsTheSongAsMIDITests.swift
// Echoel — the piece's "Export" tab hands the whole song to the share sheet as a Standard MIDI
// File: every MIDI track, each note where the song plays it (Workstation redesign B4, founder
// 2026-10-01 — „Gestalte alles so um, dass ich Echoelmusic als Workstation ernsthaft vertreten
// kann").
//
// WHY: until B4 the only MIDI export was the instrument's TAKE — one melody, the composer's loop.
// A workstation hands a DAW the ARRANGEMENT. The decision of WHICH notes that is must not become
// a second rule beside the player's (#416): the file asks the three rules the player owns —
// `document.midiLaneIDs`, `TimelineRegionPlayer.executableNotes`, `TimelineScheduling.activeRegion`.
//
// THE FOUR CLAIMS:
// 1. END-TO-END BEHAVIOUR — `SongMIDIExport.tracks` on a fixture with two MIDI tracks, a bio
//    track and an audio track: only the two MIDI tracks, in order, on channels 1 and 2; a part
//    laid over another wins from its start and CUTS the older part's sustain there; the older
//    part plays again where the newer one ends; a trimmed part writes only its window; the bio
//    and audio tracks write nothing. Channel 10 is never given to a melodic track. Each track is
//    written at the pitch it SOUNDS (its transpose applied); a note shifted out of 0…127 is left out.
// 2. END-TO-END BEHAVIOUR — `SongMIDIExport.file`: format 1, one conductor track plus one track
//    per MIDI track, division `Note.ticksPerQuarter`, the tempo the song plays at, each track
//    named, every note on its own channel at its song tick, and every track ending at the song's
//    last whole bar (`TimelineRegionPlayer.loopTicks`) so the DAW sees the song's length.
// 3. SOURCE-TEXT SCAN — the door: `SongExportTab` is a `ShareLink` (no presentation modifier — the
//    black-screen law), constructed only in `pieceTabs` behind the `showsSongs` gate, dimmed and
//    inert while the song holds no note, and it reads the tempo through the player's
//    `@ObservationIgnored` mirror, never the ~20 Hz gliding transport tempo (hot-state law).
//    `SongMIDIExport` ASKS the player's rules and keeps no overlap rule of its own.
// 4. SOURCE-TEXT SCAN — the door's four strings are in the catalog with their English line (German until 2026-10-02).
//
// GRADING (§0/§3, no Swift toolchain in a web session — transcribed in Python against both
// trees): claims 1–2 are FORWARD guards — they drive `SongMIDIExport` and
// `MIDIFileExporter.exportSong`, which this commit creates, so the file does not compile against
// the parent and no assertion has a verdict there (hand-transcribed instead). Claims 3–4 are red
// on the parent by ABSENCE of `SongExportTab` and the four keys — one absence (#486); their
// counterweights (no modal on the door, no hot tempo read, no own overlap rule) are the content
// (#343). The review repair (transpose applied, `sounding`) is FORWARD as well: its claim-1 and
// claim-2 expectations move from 38 to 26 on a track transposed −12, and claim 3's transpose
// needle is red on the B4 commit for the reason its message gives — the export wrote the part's
// pitch, not the sounding one. DEVICE PROBE, open: the share sheet opens from the tile, and the `.mid` opens in a DAW
// with one track per MIDI track, the right tempo and key — readings, not scans.

import XCTest
@testable import Echoelmusic

final class ThePieceExportsTheSongAsMIDITests: XCTestCase {

    private static let exportFile = "Sources/Echoelmusic/Sequencer/SongMIDIExport.swift"
    private static let tabFile = "Sources/Echoelmusic/Studio/SongExportTab.swift"
    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let catalog = "Sources/Echoelmusic/Resources/Localizable.xcstrings"

    private static let bar = TimelineTime.ticksPerBar          // 1920 — one 4/4 bar
    private static let quarter = Note.ticksPerQuarter          // 480

    // MARK: fixture

    /// Keys: part A (two bars) with part B laid over it from beat 2 for one bar. Bass: one part,
    /// trimmed in by a bar. Plus a bio track and an audio track, each carrying a part, which the
    /// export must not write. Every boundary sits on the transport's 16th grid, where the file
    /// and the transport agree exactly (the export's own header names the one place they differ).
    private struct Fixture {
        let document: TimelineDocument
        let clips: [UUID: Clip]
        let keys: UUID
        let bass: UUID
    }

    private func fixture() -> Fixture {
        let bar = Self.bar, q = Self.quarter
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let bass = TimelineLane(name: "Bass", kind: .midi, transposeSemitones: -12)
        let bio = TimelineLane(name: "Body", kind: .midi, isBio: true)
        let audio = TimelineLane(name: "Vocal", kind: .audio)

        // Part A: a sustained C4 from 0 for a bar, an E4 on beat 3, a G4 in the second bar.
        let partA = Clip(name: "A", kind: .midi, melody: MelodyClip(notes: [
            Note(pitch: 60, startTick: 0, lengthTicks: bar),
            Note(pitch: 64, startTick: 2 * q, lengthTicks: q),
            Note(pitch: 67, startTick: bar + 2 * q, lengthTicks: q),
        ]))
        // Part B: one short C5 on its own downbeat.
        let partB = Clip(name: "B", kind: .midi, melody: MelodyClip(notes: [
            Note(pitch: 72, startTick: 0, lengthTicks: q / 2),
        ]))
        // Part C: a note in its first bar (trimmed away) and a long D2 in its second bar.
        let partC = Clip(name: "C", kind: .midi, melody: MelodyClip(notes: [
            Note(pitch: 36, startTick: 0, lengthTicks: q),
            Note(pitch: 38, startTick: bar, lengthTicks: 3000),
        ]))

        let regions = [
            TimelineRegion(laneID: keys.id, clipID: partA.id, startTick: 0, lengthTicks: 2 * bar),
            TimelineRegion(laneID: keys.id, clipID: partB.id, startTick: q, lengthTicks: bar),
            TimelineRegion(laneID: bass.id, clipID: partC.id, startTick: 2 * bar, lengthTicks: bar,
                           contentOffsetTicks: bar),
            TimelineRegion(laneID: bio.id, clipID: partA.id, startTick: 0, lengthTicks: bar),
            TimelineRegion(laneID: audio.id, clipID: partA.id, startTick: 0, lengthTicks: bar),
        ]
        let document = TimelineDocument(lanes: [keys, bio, bass, audio], regions: regions)
        let clips = Dictionary(uniqueKeysWithValues: [partA, partB, partC].map { ($0.id, $0) })
        return Fixture(document: document, clips: clips, keys: keys.id, bass: bass.id)
    }

    // MARK: 1 — the notes the song plays, track by track

    func testTheExportWritesWhatTheSongPlays() {
        let f = fixture()
        let bar = Self.bar, q = Self.quarter
        let tracks = SongMIDIExport.tracks(of: f.document, clip: { f.clips[$0] }, bpm: 120)

        XCTAssertEqual(tracks.map(\.name), ["Keys", "Bass"], """
            only the MIDI tracks are written, in track order — the bio track and the audio track \
            carry parts and write nothing (`document.midiLaneIDs`, the player's own list)
            """)
        XCTAssertEqual(tracks.map(\.channel), [0, 1], "each MIDI track on its own channel, from channel 1")
        guard tracks.count == 2 else { return XCTFail("ANCHOR MISSING: two tracks expected") }

        let keys: [[Int]] = tracks[0].notes.map { note in [note.startTick, note.pitch, note.lengthTicks] }
        let expectedKeys: [[Int]] = [
            [0, 60, q],                 // A's sustain, CUT where B takes the track over
            [q, 72, q / 2],             // B's note, at B's start
            [bar + 2 * q, 67, q],       // A again after B ends — A's own note, at its song tick
        ]
        XCTAssertEqual(keys, expectedKeys, """
            a part laid over another wins from its start (`activeRegion` — the later-starting part), \
            the older part's sustain ends there, A's E4 under B is not written, and A plays again \
            where B ends
            """)

        let bass: [[Int]] = tracks[1].notes.map { note in [note.startTick, note.pitch, note.lengthTicks] }
        let expectedBass: [[Int]] = [[2 * bar, 26, bar]]
        XCTAssertEqual(bass, expectedBass, """
            a trimmed part writes only its window: the note before the trim is gone, the note starts \
            at the part's start and stops at the part's end (`executableNotes`) — and it is written \
            at the pitch the track SOUNDS: the part's D2 (38) on a track transposed −12 is a D1 (26)
            """)

        XCTAssertTrue(SongMIDIExport.hasNotes(f.document, clip: { f.clips[$0] }, bpm: 120),
                      "the door is lit when the song holds a note")

        let probe = [Note(pitch: 60, startTick: 0, lengthTicks: q),
                     Note(pitch: 120, startTick: q, lengthTicks: q),
                     Note(pitch: 5, startTick: 2 * q, lengthTicks: q)]
        let up: [Int] = SongMIDIExport.sounding(probe, transposeSemitones: 7).map(\.pitch)
        let expectedUp: [Int] = [67, 127, 12]
        XCTAssertEqual(up, expectedUp, "a fifth up: 60 → 67, 120 → 127, 5 → 12 — all inside MIDI's range")
        let octaveUp: [Int] = SongMIDIExport.sounding(probe, transposeSemitones: 12).map(\.pitch)
        let expectedOctaveUp: [Int] = [72, 17]
        XCTAssertEqual(octaveUp, expectedOctaveUp, """
            a note the shift pushes past 127 is left out, never folded onto another pitch
            """)
        let octaveDown: [Int] = SongMIDIExport.sounding(probe, transposeSemitones: -12).map(\.pitch)
        let expectedOctaveDown: [Int] = [48, 108]
        XCTAssertEqual(octaveDown, expectedOctaveDown, "and one pushed below 0 is left out the same way")
        XCTAssertEqual(SongMIDIExport.sounding(probe, transposeSemitones: 0).map(\.pitch), [60, 120, 5],
                       "no transpose, no change")
    }

    func testAnEmptySongLeavesTheDoorDark() {
        let f = fixture()
        // The same song without its MIDI parts: the bio and audio parts are still there.
        let onlyOthers = TimelineDocument(
            lanes: f.document.lanes,
            regions: f.document.regions.filter { $0.laneID != f.keys && $0.laneID != f.bass })
        XCTAssertFalse(SongMIDIExport.hasNotes(onlyOthers, clip: { f.clips[$0] }, bpm: 120), """
            bio and audio parts are not MIDI notes — a share sheet over an empty file would be a \
            button that does nothing (#164/#227)
            """)
        XCTAssertFalse(SongMIDIExport.hasNotes(f.document, clip: { _ in nil }, bpm: 120),
                       "a part that points at no clip holds no note")
        XCTAssertEqual(SongMIDIExport.tracks(of: onlyOthers, clip: { f.clips[$0] }, bpm: 120).map(\.notes.count),
                       [0, 0], "an empty MIDI track is still written, named and empty — the DAW sees the layout")
    }

    func testChannelTenIsNeverAMelodicTrack() {
        XCTAssertEqual(SongMIDIExport.channels.count, 15, "the sixteen MIDI channels minus the drum channel")
        XCTAssertFalse(SongMIDIExport.channels.contains(9), """
            channel 10 (index 9) is General MIDI percussion — a melodic track written there opens \
            as a drum kit in the DAW
            """)
        XCTAssertEqual(Set(SongMIDIExport.channels).count, 15, "no channel is handed out twice before the list wraps")

        let lanes = (0..<11).map { TimelineLane(name: "T\($0)", kind: .midi) }
        let tracks = SongMIDIExport.tracks(of: TimelineDocument(lanes: lanes), clip: { _ in nil }, bpm: 120)
        XCTAssertEqual(tracks.map(\.channel), [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11],
                       "the tenth MIDI track skips to channel 11")
    }

    // MARK: 2 — the bytes a DAW reads

    func testTheFileIsAFormatOneSongADAWCanRead() throws {
        let f = fixture()
        let bar = Self.bar, q = Self.quarter
        let data = SongMIDIExport.file(of: f.document, clip: { f.clips[$0] }, bpm: 120,
                                       keyRootPitchClass: 0, keyIsMinor: false)
        let bytes = [UInt8](data)
        guard bytes.count > 14 else { return XCTFail("the file is shorter than its own header") }

        XCTAssertEqual(Array(bytes[0..<4]), Array("MThd".utf8))
        XCTAssertEqual(be32(bytes, 4), 6, "the header chunk is six bytes long")
        XCTAssertEqual(be16(bytes, 8), 1, "format 1 — one track per MIDI track, not one merged track")
        XCTAssertEqual(be16(bytes, 10), 3, "a conductor track plus the two MIDI tracks")
        XCTAssertEqual(be16(bytes, 12), UInt16(Self.quarter), "the division is the timeline's own tick")

        let chunks = try trackChunks(bytes, from: 14)
        XCTAssertEqual(chunks.count, 3, "as many MTrk chunks as the header says")
        guard chunks.count == 3 else { return }

        let songEnd = TimelineRegionPlayer.loopTicks(for: f.document)
        XCTAssertEqual(songEnd, 3 * bar, "the fixture's song ends on its third barline")

        let conductor = try events(chunks[0])
        XCTAssertTrue(conductor.metas.contains { $0.type == 0x51 && $0.data == [0x07, 0xA1, 0x20] },
                      "the tempo meta carries the song's tempo — 120 BPM is 500 000 µs per quarter")
        XCTAssertTrue(conductor.metas.contains { $0.type == 0x58 && $0.data.first == 4 }, "4/4 time")
        XCTAssertEqual(conductor.endOfTrack, songEnd, "the conductor ends at the song's last whole bar")

        let keys = try events(chunks[1])
        XCTAssertTrue(keys.metas.contains { $0.type == 0x03 && $0.data == Array("Keys".utf8) },
                      "the track carries the track's name")
        let ons: [[Int]] = keys.notes.filter { $0.status == 0x90 }.map { event in [event.tick, Int(event.note)] }
        let expectedOns: [[Int]] = [[0, 60], [q, 72], [bar + 2 * q, 67]]
        XCTAssertEqual(ons, expectedOns, "note-ons on channel 1 at their song ticks")
        let offs: [[Int]] = keys.notes.filter { $0.status == 0x80 }.map { event in [event.tick, Int(event.note)] }
        let expectedOffs: [[Int]] = [[q, 60], [q + q / 2, 72], [bar + 3 * q, 67]]
        XCTAssertEqual(offs, expectedOffs, "note-offs where each note ends — the cut sustain ends at the takeover")
        XCTAssertTrue(keys.notes.allSatisfy { $0.velocity <= 127 }, "velocities are seven-bit")
        XCTAssertEqual(keys.endOfTrack, songEnd, "every track spans the song")

        let bass = try events(chunks[2])
        XCTAssertTrue(bass.metas.contains { $0.type == 0x03 && $0.data == Array("Bass".utf8) })
        let bassEvents: [[Int]] = bass.notes.map { event in [Int(event.status), event.tick, Int(event.note)] }
        let expectedBassEvents: [[Int]] = [[0x91, 2 * bar, 26], [0x81, 3 * bar, 26]]
        XCTAssertEqual(bassEvents, expectedBassEvents, "the second track speaks on channel 2, at its transposed pitch")
        XCTAssertEqual(bass.endOfTrack, songEnd)
    }

    // MARK: 3 — the door: a ShareLink in its own leaf, behind the song gate, no hot read

    func testTheExportDoorIsAShareLinkBehindTheSongGate() throws {
        let tab = SourceText.codeOnly(try text(Self.tabFile))
        XCTAssertTrue(tab.contains("ShareLink(item: file, preview: SharePreview(file.name))"), """
            the door is a `ShareLink` — the share sheet belongs to it, so the piece gains a door \
            without a presentation modifier
            """)
        for modal in [".sheet(", ".fullScreenCover(", ".popover(", ".alert(", ".fileExporter(",
                      ".confirmationDialog("] {
            XCTAssertFalse(tab.contains(modal), "`\(modal)` on the export door — the black-screen law forbids growing a chain")
        }
        XCTAssertTrue(tab.contains("title: \"Export\""), "the tile shows its word")
        XCTAssertTrue(tab.contains(".accessibilityLabel(\"Export\")"), "and says the same word to VoiceOver")
        XCTAssertTrue(tab.contains("enabled: enabled") && tab.contains(".disabled(!enabled)"), """
            the tile is dimmed AND inert while the song holds no note — a lit door to an empty \
            file is a button that does nothing (#164/#227)
            """)
        XCTAssertTrue(tab.contains("SongMIDIExport.hasNotes("), "the enabled state asks the export, not a second rule")
        XCTAssertTrue(tab.contains("player.preflightTempo"), """
            the tempo is read through the player's `@ObservationIgnored` mirror
            """)
        for hot in ["pattern.tempo", "transport.tempo", "PatternEngine", ".tempo)"] {
            XCTAssertFalse(tab.contains(hot), """
                `\(hot)` in the export door — the transport tempo glides at ~20 Hz, and a body read \
                of it rebuilds the piece's tab row on every glide step (hot-state law)
                """)
        }

        let workstation = SourceText.codeOnly(try text(Self.workstation))
        XCTAssertEqual(workstation.components(separatedBy: "SongExportTab()").count - 1, 1,
                       "exactly one export door on the piece")
        let tabs = try member("private var pieceTabs: some View {", in: workstation)
        // Slice B (2026-10-01) removed the Master tile this claim anchored on; Mix is now the tab
        // before Export, so the order and the own-gate needles anchor on Mix — same law.
        guard let door = tabs.range(of: "SongExportTab()"),
              let mix = tabs.range(of: "plate = .mix"),
              let gate = tabs.range(of: "if level.showsSongs {", options: .backwards,
                                    range: tabs.startIndex..<door.lowerBound) else {
            return XCTFail("ANCHOR MISSING: the export door, the Mix tab or a showsSongs gate (#454)")
        }
        XCTAssertLessThan(mix.lowerBound, door.lowerBound, "Export is the last tab, after Mix")
        XCTAssertLessThan(mix.lowerBound, gate.lowerBound, """
            the gate nearest the door is its OWN `showsSongs` gate — not the one Mix sits behind, \
            which would put Export inside another tab's block
            """)
        XCTAssertFalse(tabs[gate.upperBound..<door.lowerBound].contains("}"),
                       "the door sits directly inside its gate")
    }

    func testTheExportAsksThePlayersRules() throws {
        let export = SourceText.codeOnly(try text(Self.exportFile))
        for rule in ["document.midiLaneIDs", "TimelineRegionPlayer.executableNotes(",
                     "TimelineScheduling.activeRegion(", "TimelineRegionPlayer.loopTicks(for: document)",
                     "MIDIFileExporter.exportSong("] {
            XCTAssertTrue(export.contains(rule), "the export asks `\(rule)` — the player's rule, never a copy (#416)")
        }
        for copy in [".max(by:", "contentOffsetTicks", "contentOffsetSeconds", "isBio", ".kind =="] {
            XCTAssertFalse(export.contains(copy), """
                `\(copy)` in the export — a second spelling of a rule the player owns (overlap \
                precedence, the trim window, which tracks are MIDI). Ask it instead (#416, #1440).
                """)
        }
        XCTAssertFalse(export.contains("import SwiftUI"), "the export is Foundation-only — the door is the only view")
        let tracks = try member("bpm: Double) -> [Track] {", in: export)
        XCTAssertTrue(tracks.contains("transposeSemitones: lane.transposeSemitones"), """
            each track is written at the pitch it SOUNDS — the track's transpose changes which note \
            is heard, so a DAW that opens the file without it hears a different piece (review of B4)
            """)
    }

    // MARK: 4 — the door's strings are catalogued, in the app's one language (German until 2026-10-02)

    func testTheExportDoorsStringsAreCatalogued() throws {
        let data = try XCTUnwrap(text(Self.catalog).data(using: .utf8))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])
        let expected = [
            "Export",
            "Echoelmusic Piece",
            "Shares the piece as a MIDI file: every MIDI track with its notes, muted ones included. Level, pan and sound stay here",
            "Nothing to export yet. Write a part on a MIDI track, and the piece can be shared as a MIDI file",
        ]
        let tab = try text(Self.tabFile)
        for key in expected {
            XCTAssertTrue(tab.contains("\"\(key)\""), "the door uses the catalog key `\(key)` verbatim")
            let entry = strings[key] as? [String: Any]
            let localizations = entry?["localizations"] as? [String: Any]
            let en = (localizations?["en"] as? [String: Any])?["stringUnit"] as? [String: Any]
            XCTAssertEqual(en?["value"] as? String, key, "`\(key)` has its English line")
            XCTAssertEqual(Set((localizations ?? [:]).keys), ["en"], "`\(key)`: the app speaks one language (founder 2026-10-02) — no second unit")
        }
    }

    // MARK: helpers — a minimal SMF reader, enough to read back what the exporter writes

    private struct Meta { let type: UInt8; let data: [UInt8] }
    private struct NoteEvent { let tick: Int; let status: UInt8; let note: UInt8; let velocity: UInt8 }
    private struct TrackEvents { var metas: [Meta] = []; var notes: [NoteEvent] = []; var endOfTrack: Int? }

    private func be16(_ b: [UInt8], _ i: Int) -> UInt16 { UInt16(b[i]) << 8 | UInt16(b[i + 1]) }
    private func be32(_ b: [UInt8], _ i: Int) -> UInt32 {
        UInt32(b[i]) << 24 | UInt32(b[i + 1]) << 16 | UInt32(b[i + 2]) << 8 | UInt32(b[i + 3])
    }

    private func trackChunks(_ b: [UInt8], from start: Int) throws -> [[UInt8]] {
        var chunks: [[UInt8]] = []
        var i = start
        while i + 8 <= b.count {
            XCTAssertEqual(Array(b[i..<i + 4]), Array("MTrk".utf8), "a track chunk at byte \(i)")
            let length = Int(be32(b, i + 4))
            guard i + 8 + length <= b.count else { throw ParseError.truncated }
            chunks.append(Array(b[(i + 8)..<(i + 8 + length)]))
            i += 8 + length
        }
        XCTAssertEqual(i, b.count, "no bytes after the last chunk")
        return chunks
    }

    private enum ParseError: Error { case truncated, runningStatus }

    private func events(_ t: [UInt8]) throws -> TrackEvents {
        var out = TrackEvents()
        var i = 0, tick = 0
        func vlq() throws -> Int {
            var value = 0
            while true {
                guard i < t.count else { throw ParseError.truncated }
                let byte = t[i]; i += 1
                value = value << 7 | Int(byte & 0x7F)
                if byte & 0x80 == 0 { return value }
            }
        }
        while i < t.count {
            tick += try vlq()
            guard i < t.count else { throw ParseError.truncated }
            let status = t[i]; i += 1
            if status == 0xFF {
                guard i < t.count else { throw ParseError.truncated }
                let type = t[i]; i += 1
                let length = try vlq()
                guard i + length <= t.count else { throw ParseError.truncated }
                let payload = Array(t[i..<i + length]); i += length
                if type == 0x2F { out.endOfTrack = tick } else { out.metas.append(Meta(type: type, data: payload)) }
            } else {
                // The exporter writes every status byte; a data byte here would be running status.
                guard status & 0x80 != 0, i + 2 <= t.count else { throw ParseError.runningStatus }
                out.notes.append(NoteEvent(tick: tick, status: status, note: t[i], velocity: t[i + 1]))
                i += 2
            }
        }
        return out
    }

    /// The brace-matched body after `anchor` (#408); string-literal aware.
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else {
            XCTFail("ANCHOR MISSING: `\(anchor)` (#454)")
            return ""
        }
        var depth = 1
        var index = start.upperBound
        var inString = false
        while index < code.endIndex {
            let ch = code[index]
            if inString, ch == "\\" {
                index = code.index(after: index)
                if index < code.endIndex { index = code.index(after: index) }
                continue
            }
            if ch == "\"" { inString.toggle() }
            if !inString {
                if ch == "{" { depth += 1 }
                if ch == "}" {
                    depth -= 1
                    if depth == 0 { return String(code[start.upperBound..<index]) }
                }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: `\(anchor)` never closes (#454)")
        return ""
    }

    private func text(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
