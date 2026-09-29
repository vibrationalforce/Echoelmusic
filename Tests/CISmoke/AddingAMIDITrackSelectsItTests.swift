// AddingAMIDITrackSelectsItTests.swift
// Echoel — DMMW Phase 2 · slice 2 (founder 2026-09-29: "'Add a MIDI track' erzeugt eine
// sichtbare Spur").
//
// WHAT IT PINS. "Add MIDI Track" appended a lane and said nothing: the new row appeared at the
// END of the track list, often below the fold, unselected — on a phone the tap looked like
// nothing. Now the door SELECTS the track it made (its row is marked, its details open under
// it) and says which track it made, on the card when the guide ran it.
//
// 1. END-TO-END BEHAVIOUR over the shipped selection owner: `selectTrack` opens and never
//    closes (the toggle's opposite, which a door that just MADE a track must not do); a part on
//    another track is deselected with it.
// 2. END-TO-END BEHAVIOUR over a REAL `TimelineStore`: `MIDIImport.addMIDITrack` appends, so
//    the last lane is the one just made and it is a non-bio MIDI lane — the premise the view's
//    `lanes.last` read stands on (#343). The lane is removed again (it holds no part).
// 3. SOURCE-TEXT SCAN (`private` members of a `View`): the view makes the track through the
//    one helper, THEN selects the last lane, refusing anything but a non-bio MIDI lane; the
//    sentence names the track; the guide's step 1 shows it on the card.
//
// GRADING (§3). Against the parent (`4e6a2cf7c`) this file does NOT COMPILE — `selectTrack` and
// `MIDIImport.addedTrackNote` are new — so no assertion has a verdict there: ONE absence (#486),
// every claim a FORWARD guard. Counterweight: claim 2's append premise is true on both trees.
// Transcribed in Python against THIS tree (no toolchain here): each scan needle found once, in
// the order asserted.
//
// ⛔ HONEST LIMIT: that the selected row is on screen after the tap (the list may be long) is a
// DEVICE PROBE, open. NEEDS-FOUNDER-VERIFY: Workstation → Add MIDI Track → the new track is
// marked and its details open; the sentence names it; VoiceOver reads it as selected.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class AddingAMIDITrackSelectsItTests: XCTestCase {

    private static let view = "Sources/Echoelmusic/Studio/WorkstationView.swift"

    // MARK: - 1. the owner opens, never closes

    func testSelectingATrackOpensItAndNeverClosesIt() {
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let lead = TimelineLane(name: "Lead", kind: .midi)
        let part = TimelineRegion(laneID: keys.id, clipID: UUID(), startTick: 0,
                                  lengthTicks: TimelineTime.ticksPerBar)
        let document = TimelineDocument(lanes: [keys, lead], regions: [part])

        let selection = WorkstationSelection()
        selection.selectTrack(lead.id)
        XCTAssertEqual(selection.trackID, lead.id)
        selection.selectTrack(lead.id)
        XCTAssertEqual(selection.trackID, lead.id, "selecting the open track again keeps it open — no toggle")

        selection.selectRegion(part.id, in: document)
        XCTAssertEqual(selection.trackID, keys.id, "fixture premise: the part selects its own track")
        selection.selectTrack(lead.id)
        XCTAssertEqual(selection.trackID, lead.id)
        XCTAssertNil(selection.regionID, "a part on another track is not left selected")
    }

    // MARK: - 2. the premise: the new MIDI lane is the last lane

    func testTheHelperAppendsSoTheLastLaneIsTheNewMIDITrack() {
        let timeline = TimelineStore()
        let before = timeline.document.lanes.map(\.id)
        MIDIImport.addMIDITrack(timeline: timeline)
        guard let added = timeline.document.lanes.last else {
            return XCTFail("the helper added nothing")
        }
        defer { timeline.removeLaneIfEmpty(id: added.id) }
        XCTAssertFalse(before.contains(added.id), "the last lane must be the NEW one — `addLane` appends")
        XCTAssertEqual(added.kind, .midi)
        XCTAssertFalse(added.isBio)
        XCTAssertEqual(timeline.document.lanes.count, before.count + 1)

        let note = MIDIImport.addedTrackNote(laneName: added.name)
        XCTAssertTrue(note.hasPrefix("Added \(added.name)."), "the sentence names the track it made: \(note)")
        XCTAssertTrue(note.contains("selected"), "and says where it is")
        XCTAssertFalse(note.contains("add a part"), """
            New MIDI Part lands on the ROLL lane (MIDIImport header), which is this track only when \
            it is the first MIDI one — the sentence must not promise the part lands here.
            """)
    }

    // MARK: - 3. the view selects what it made

    func testTheDoorSelectsTheTrackItMadeAndSaysSo() throws {
        let view = try source(Self.view)
        let action = try member("private func addMIDITrack() {", in: view)
        let make = try XCTUnwrap(action.range(of: "MIDIImport.addMIDITrack(timeline: timeline)"))
        let pick = try XCTUnwrap(action.range(of: "if let added = timeline.document.lanes.last, added.kind == .midi, !added.isBio {"),
                                 "the door must select only a non-bio MIDI lane it just made")
        let select = try XCTUnwrap(action.range(of: "selection.selectTrack(added.id)"))
        XCTAssertLessThan(make.lowerBound, pick.lowerBound, "make the track, THEN read which one it is")
        XCTAssertLessThan(pick.lowerBound, select.lowerBound)
        XCTAssertTrue(action.contains("importNote = MIDIImport.addedTrackNote(laneName: added.name)"))
        XCTAssertFalse(action.contains("toggleTrack("), "a door that made the track must not be able to close it")

        let guide = try member("private var composeGuide: some View {", in: view)
        let step = try XCTUnwrap(guide.range(of: "case .track:"))
        let tail = guide[step.upperBound...]
        let end = tail.range(of: "case .part:")?.lowerBound ?? tail.endIndex
        let trackCase = String(tail[..<end])
        XCTAssertTrue(trackCase.contains("addMIDITrack()"))
        XCTAssertTrue(trackCase.contains("guideNote = importNote"), "the card shows which track step 1 made")
    }

    // MARK: - helpers

    private struct AnchorMissing: Error {}

    /// Brace-matched body after `anchor` (§2, #408).
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor),
              let open = code.range(of: "{", range: start.lowerBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: \(anchor) (#454)")
            throw AnchorMissing()
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
        throw AnchorMissing()
    }

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing()
        }
        return SourceText.codeOnly(text)
    }
}
