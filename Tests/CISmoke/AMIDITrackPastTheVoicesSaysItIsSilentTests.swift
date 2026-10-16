// AMIDITrackPastTheVoicesSaysItIsSilentTests.swift
// Echoel — Ultramasterplan D1 RACK-CAP (2026-10-16).
//
// WHAT IT PINS. The rack plays the Echoel track plus the first `laneVoiceCapacity` extra MIDI
// tracks (`MultiRollFanout.slot`); every track past that is SILENT. The Device row and the note
// editor already said so (`TrackMix.deviceName(.noVoice)`, `PartNoteEditor.noVoiceLine`) — but
// "Add MIDI Track" made such a track and said only "Added Track 6. It is selected", so the
// first thing a user learned about it was silence. Now the door appends the SAME sentence,
// from the SAME rule (#416), where the track is made.
//
// 1. END-TO-END BEHAVIOUR over the shipped rule: with capacity 2, the Echoel track and the
//    first two extras get no line; the third extra gets the no-voice sentence.
// 2. SOURCE-TEXT SCAN (`private` member of a `View`): `addMIDITrack` asks `TrackMix.role` with
//    the player's own capacity and appends `PartNoteEditor.noVoiceLine` AFTER the added-track
//    sentence — never a second hand-written wording.
//
// GRADING (§3). Claim 1 is true on the parent too (the rule is older) — a COUNTERWEIGHT, not
// a guard of the change. Claim 2 is RED on the parent (`cd93c14`): the needle is absent there.
// Transcribed in Python against THIS tree (no toolchain here): each needle found once, in order.
//
// ⛔ HONEST LIMIT: NEEDS-FOUNDER-VERIFY: Workstation → add MIDI tracks until one is past the
// rack's voices → the note under the list says it has no voice.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class AMIDITrackPastTheVoicesSaysItIsSilentTests: XCTestCase {

    private static let view = "Sources/Echoelmusic/Studio/WorkstationView.swift"

    // MARK: - 1. the shipped rule names the silent track, and only it

    func testOnlyATrackPastTheCapacityGetsTheSilentLine() {
        let echoel = TimelineLane(name: "Echoel", kind: .midi)
        let first = TimelineLane(name: "Keys", kind: .midi)
        let second = TimelineLane(name: "Lead", kind: .midi)
        let third = TimelineLane(name: "Pad", kind: .midi)
        let document = TimelineDocument(lanes: [echoel, first, second, third], regions: [])
        XCTAssertEqual(document.rollLaneID, echoel.id, "fixture premise: the first MIDI lane is the Echoel track")

        for lane in [echoel, first, second] {
            XCTAssertNil(PartNoteEditor.noVoiceLine(TrackMix.role(of: lane.id, in: document, voiceCapacity: 2)),
                         "\(lane.name) has a voice — no silent line")
        }
        let line = PartNoteEditor.noVoiceLine(TrackMix.role(of: third.id, in: document, voiceCapacity: 2))
        XCTAssertNotNil(line, "the third extra track is past a capacity of 2 and must say so")
        XCTAssertEqual(line, TrackMix.deviceName(.noVoice(capacity: 2)), "the inspector's own sentence (#416)")
    }

    // MARK: - 2. the door says it where the track is made

    func testTheAddDoorAppendsTheSilentLineFromTheOneRule() throws {
        let view = try source(Self.view)
        let action = try member("private func addMIDITrack() {", in: view)
        let said = try XCTUnwrap(action.range(of: "importNote = MIDIImport.addedTrackNote(laneName: added.name)"))
        let asked = try XCTUnwrap(action.range(of: "PartNoteEditor.noVoiceLine(TrackMix.role(of: added.id, in: timeline.document,"),
                                  "the door must ask the inspector's ONE rule, not word its own")
        let capacity = try XCTUnwrap(action.range(of: "voiceCapacity: player.laneVoiceCapacity"),
                                     "the capacity is the player's — asked, never assumed (#431)")
        let appended = try XCTUnwrap(action.range(of: "importNote = (importNote ?? \"\") + \" \" + silent + \".\""))
        XCTAssertLessThan(said.lowerBound, asked.lowerBound, "the added-track sentence comes first")
        XCTAssertLessThan(asked.lowerBound, capacity.lowerBound)
        XCTAssertLessThan(capacity.lowerBound, appended.lowerBound)
        XCTAssertFalse(action.contains("No voice"), "no second hand-written wording in the door")
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
