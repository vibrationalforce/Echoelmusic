// TheNoteEditorSaysWhenATrackHasNoVoiceTests.swift
// Echoel — Phase 3 / Creation Workflow, MIDI editor slice M8: a track that cannot sound says so
// where its notes are edited.
//
// WHAT IT PINS. The rack plays the Echoel track plus the first `capacity` other MIDI tracks
// (`MultiRollFanout.slot`); every MIDI track after that has no voice. The track inspector has said
// so since WA4.1 (`TrackMix.role` → `.noVoice`). The note editor did not: a part on such a track
// opened, took every edit, and was never heard — the loop OPEN → EDIT → PLAY failed at PLAY with
// no word on screen. Since M8 the editor shows the inspector's line, from the inspector's rule.
//
// 1. END-TO-END BEHAVIOUR (`PartNoteEditor.noVoiceLine` over `TrackMix.role`, both pure): the
//    sixth MIDI track of a song with a four-voice rack gets the inspector's no-voice line; the
//    Echoel track and a track inside the capacity get none; with no rack at all, an extra track
//    gets the "off in this build" line.
// 2. SOURCE: the editor asks `TrackMix.role` (no second rule, #416) with the capacity the
//    Workstation hands in, and reads no player itself — M1 bans `player.` in the editor, because
//    the player is the transport and the editor must stay a cold leaf.
//
// Grading (§0, no Swift toolchain in a web session): `TrackMix.role`, `MultiRollFanout.slot` and
// `deviceName` were transcribed into Python and driven on the four documents below. On the parent
// (`c3f72e956`) this file does NOT compile — `PartNoteEditor.noVoiceLine` is new — so no assertion
// has a verdict there: claim 1 is a FORWARD guard (one absence, #486), and its counterweights (the
// Echoel track and a voiced track get nil) are there so a helper that always returns the line
// cannot pass. Claim 2 is a scan of the same new call.
// NOT covered: that the line is seen and read well on a device.
// NEEDS-FOUNDER-VERIFY: Workstation → add MIDI tracks until there are six → select a part on the
// sixth → under "Notes" it says the track has no voice; a part on the second track says nothing.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheNoteEditorSaysWhenATrackHasNoVoiceTests: XCTestCase {

    private static let editorPath = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"
    private static let workstationPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"

    /// Six MIDI tracks: the first is the Echoel track, the other five want rack voices.
    private func song() -> (TimelineDocument, [UUID]) {
        let lanes = (0..<6).map { TimelineLane(name: "Track \($0 + 1)", kind: .midi) }
        return (TimelineDocument(lanes: lanes, regions: []), lanes.map(\.id))
    }

    private func line(_ laneID: UUID, _ document: TimelineDocument, capacity: Int) -> String? {
        PartNoteEditor.noVoiceLine(TrackMix.role(of: laneID, in: document, voiceCapacity: capacity))
    }

    // MARK: 1 — END-TO-END

    func testATrackPastTheRackSaysItHasNoVoice() {
        let (document, ids) = song()
        XCTAssertEqual(document.rollLaneID, ids[0], "ANCHOR MISSING: the first MIDI track is not the Echoel track")
        let sixth = line(ids[5], document, capacity: 4)
        XCTAssertEqual(sixth, TrackMix.deviceName(.noVoice(capacity: 4)),
                       "the sixth track is the fifth extra one — past a four-voice rack, and it must say so")
        XCTAssertEqual(line(ids[5], document, capacity: 0),
                       TrackMix.deviceName(.noVoice(capacity: 0)), "no rack at all: the 'off in this build' line")
    }

    func testATrackThatSoundsSaysNothing() {
        let (document, ids) = song()
        XCTAssertNil(line(ids[0], document, capacity: 4), "the Echoel track always sounds")
        XCTAssertNil(line(ids[1], document, capacity: 4), "the first extra track has rack voice 0")
        XCTAssertNil(line(ids[4], document, capacity: 4), "the fourth extra track has the last rack voice")
        XCTAssertNil(PartNoteEditor.noVoiceLine(nil), "a track the song does not hold is not described")
    }

    // MARK: 2 — SOURCE

    func testTheEditorAsksTheInspectorsRuleWithTheCapacityItIsHanded() throws {
        let editor = try source(Self.editorPath)
        XCTAssertTrue(editor.contains("Self.noVoiceLine(TrackMix.role(of: lane.id, in: document,"),
                      "the editor asks the inspector's one rule — never a second capacity check")
        XCTAssertTrue(editor.contains("voiceCapacity: voiceCapacity))"))
        XCTAssertTrue(editor.contains("let voiceCapacity: Int"), "a number handed in, required (#431)")
        XCTAssertFalse(editor.contains("player."), "the editor reads no transport (M1's ban, kept)")
        let workstation = try source(Self.workstationPath)
        XCTAssertTrue(workstation.contains("PartNoteEditor(voiceCapacity: player.laneVoiceCapacity)"),
                      "the Workstation hands in the capacity the rack was enabled with")
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
