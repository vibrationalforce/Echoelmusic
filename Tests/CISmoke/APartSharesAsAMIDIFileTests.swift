// APartSharesAsAMIDIFileTests.swift
// Echoel — C2 (ultra master plan slice 4, 2026-10-16): the selected MIDI part shares as its own
// `.mid` — "this part into my DAW". Until now the piece shared only the WHOLE song
// (`SongExportTab`) and the instrument only its take; `MIDIFileExporter.export(clip:)` had no
// caller, and it would have written the whole CLIP, past a shortened part's end.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR (`SongMIDIExport.partTrack`, pure): the track holds the part's
//      WINDOW — a trimmed-in note is out, a note past the part's end is out, a note crossing it
//      is cut — at PART ticks, at the track's transpose, named after the track. An overlapping
//      part that wins the track does not remove this part's notes (the person asked for THIS
//      part). Counterweight: the song export of the same fixture does remove them.
//   2. END-TO-END BEHAVIOUR (`SongMIDIExport.partFile`): a format-1 file with two tracks
//      (conductor + the part), every track ending at the part's own length.
//   3. Only MIDI tracks: a part on an audio or a bio track has no MIDI file.
//   4. SOURCE-TEXT SCAN: the door is a `ShareLink` in its own leaf under the part bar — no
//      presentation modifier in the bar's file — and it hides over an empty part.
//
// ⚠️ HONEST GRADING (#433): claims 1–4 drive `partTrack`/`partFile`/`PartMIDIShareLink`, which
// this commit creates — FORWARD guards, one absence on the parent (#486); the song-export
// counterweight in claim 1 is green on both trees. Transcribed by reading against the windowing
// rule (`RegionNoteWindow.windowed`), no toolchain (§0).
// ⚠️ THE LIMIT: DEVICE PROBE (NEEDS-FOUNDER-VERIFY: select a MIDI part, Share as MIDI, open the
// file in a DAW — one track, the part's length, its notes where they sit in the part).

import Foundation
import XCTest
@testable import Echoelmusic

final class APartSharesAsAMIDIFileTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let q = Note.ticksPerQuarter

    private struct Fixture {
        let document: TimelineDocument
        let clips: [UUID: Clip]
        let part: TimelineRegion
        let over: TimelineRegion
        let audioPart: TimelineRegion
        let bioPart: TimelineRegion
    }

    /// Bass (transposed −12): one part two bars long, trimmed in by a bar of its clip. Its clip
    /// holds a note in the trimmed bar, a note in the part, one crossing the part's end and one
    /// past it. A one-beat part lies over its second bar. Plus an audio and a bio track.
    private func fixture() -> Fixture {
        let bar = Self.bar, q = Self.q
        let bass = TimelineLane(name: "Bass", kind: .midi, transposeSemitones: -12)
        let audio = TimelineLane(name: "Vocal", kind: .audio)
        let bio = TimelineLane(name: "Body", kind: .midi, isBio: true)
        let clip = Clip(name: "C", kind: .midi, melody: MelodyClip(notes: [
            Note(pitch: 40, startTick: 0, lengthTicks: q),                    // trimmed away
            Note(pitch: 43, startTick: bar + q, lengthTicks: q),              // part tick q
            Note(pitch: 45, startTick: 2 * bar + 2 * q, lengthTicks: 4 * q),  // crosses the end (3 bars of clip)
            Note(pitch: 47, startTick: 3 * bar + q, lengthTicks: q),          // past the end
        ]))
        let other = Clip(name: "O", kind: .midi, melody: MelodyClip(notes: [
            Note(pitch: 60, startTick: 0, lengthTicks: q),
        ]))
        let part = TimelineRegion(laneID: bass.id, clipID: clip.id, startTick: 4 * bar,
                                  lengthTicks: 2 * bar, contentOffsetTicks: bar)
        let over = TimelineRegion(laneID: bass.id, clipID: other.id, startTick: 5 * bar, lengthTicks: 2 * bar)
        let audioPart = TimelineRegion(laneID: audio.id, clipID: clip.id, startTick: 0, lengthTicks: bar)
        let bioPart = TimelineRegion(laneID: bio.id, clipID: clip.id, startTick: 0, lengthTicks: bar)
        let document = TimelineDocument(lanes: [bass, audio, bio], regions: [part, over, audioPart, bioPart])
        return Fixture(document: document, clips: [clip.id: clip, other.id: other],
                       part: part, over: over, audioPart: audioPart, bioPart: bioPart)
    }

    // MARK: 1 — the part's own window

    func testThePartTrackHoldsThePartsWindowAtPartTicks() throws {
        let f = fixture()
        let bar = Self.bar, q = Self.q
        let track = try XCTUnwrap(SongMIDIExport.partTrack(f.part, in: f.document, clip: { f.clips[$0] }, bpm: 120))
        XCTAssertEqual(track.name, "Bass")
        XCTAssertEqual(track.channel, 0)
        let notes: [[Int]] = track.notes.map { [$0.pitch, $0.startTick, $0.lengthTicks] }
        let expected: [[Int]] = [[31, q, q], [33, bar + 2 * q, 2 * q]]
        XCTAssertEqual(notes, expected, """
            the trimmed-in note and the note past the end are out, the crossing note is cut at the \
            part's end, every note sits at its PART tick and sounds at the track's transpose
            """)

        // Counterweight: the SONG export of the same track loses the second note to the part laid
        // over bar 2 — the part export keeps it, because the person asked for this part.
        let song = SongMIDIExport.songNotes(of: f.part.laneID, in: f.document, clip: { f.clips[$0] }, bpm: 120)
        XCTAssertFalse(song.contains { $0.pitch == 45 }, "premise: in the song the overlying part wins bar 2")
    }

    // MARK: 2 — the file

    func testThePartFileIsTwoTracksAsLongAsThePart() throws {
        let f = fixture()
        let data = try XCTUnwrap(SongMIDIExport.partFile(f.part, in: f.document, clip: { f.clips[$0] }, bpm: 120,
                                                         keyRootPitchClass: 0, keyIsMinor: false))
        let b = [UInt8](data)
        guard b.count > 14 else { return XCTFail("the file is shorter than its own header") }
        XCTAssertEqual(Array(b[0..<4]), Array("MThd".utf8))
        XCTAssertEqual(UInt16(b[8]) << 8 | UInt16(b[9]), 1, "format 1")
        XCTAssertEqual(UInt16(b[10]) << 8 | UInt16(b[11]), 2, "the conductor track plus the part's one track")
        // Same bytes as the song exporter would write for this one track ending at the part's end.
        let track = try XCTUnwrap(SongMIDIExport.partTrack(f.part, in: f.document, clip: { f.clips[$0] }, bpm: 120))
        XCTAssertEqual(data, MIDIFileExporter.exportSong(tracks: [track], tempo: 120, endTick: f.part.lengthTicks,
                                                         keyRootPitchClass: 0, keyIsMinor: false),
                       "the file ends where the part ends — one byte layout, the song exporter's")
    }

    // MARK: 3 — only MIDI tracks

    func testAnAudioOrBioPartHasNoMIDIFile() {
        let f = fixture()
        XCTAssertNil(SongMIDIExport.partTrack(f.audioPart, in: f.document, clip: { f.clips[$0] }, bpm: 120))
        XCTAssertNil(SongMIDIExport.partTrack(f.bioPart, in: f.document, clip: { f.clips[$0] }, bpm: 120))
        XCTAssertNil(SongMIDIExport.partFile(f.audioPart, in: f.document, clip: { f.clips[$0] }, bpm: 120,
                                             keyRootPitchClass: 0, keyIsMinor: false))
        XCTAssertNotNil(SongMIDIExport.partTrack(f.over, in: f.document, clip: { f.clips[$0] }, bpm: 120),
                        "counterweight: the overlying MIDI part has its own file")
    }

    // MARK: 4 — the door

    func testTheDoorIsAShareLinkLeafThatHidesOverAnEmptyPart() throws {
        let bar = try source("Sources/Echoelmusic/Studio/SelectedPartBar.swift")
        XCTAssertEqual(bar.components(separatedBy: "PartMIDIShareLink(regionID: regionID)").count - 1, 1,
                       "the part bar mounts the share link once")
        XCTAssertEqual(bar.components(separatedBy: "ShareLink(item: file, preview: SharePreview(file.name))").count - 1, 1)
        for modal in [".sheet(", ".fullScreenCover(", ".fileExporter(", ".popover("] {
            XCTAssertFalse(bar.contains(modal), "`\(modal)` in the part bar — the share sheet belongs to ShareLink")
        }
        XCTAssertTrue(bar.contains("!track.notes.isEmpty {"), "the link hides over a part with no note to write")
        XCTAssertTrue(bar.contains("SongMIDIExport.partFile(region, in: document"), "the bytes are the pure exporter's")
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
