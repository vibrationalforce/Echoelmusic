//
//  TheNoteEditorSoundsWhatItSetsTests.swift
//  Production level N1 (founder 2026-10-13: „… brauchbares Pianoroll …"). Until this slice the note
//  editor was silent: `PianoRollModel.audition(pitch:velocity:role:)` was written for exactly this
//  and had NO caller, and a rack track had no audition path at all. Now a note sounds on the
//  instrument that plays its track as it is set, tapped, or moved to a new pitch.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–2) — `TimelineRegionPlayer` is shipped and constructible
//    without an engine. Claim 1 drives the one route decision: the Echoel track auditions on the
//    roll's voice; a rack track on its slot only while the transport is STOPPED (a playing
//    transport owns every slot's binding); a track past the rack's capacity, a disabled rack and
//    an unknown lane audition nothing. Claim 2 drives `auditionNote` against a recording sink:
//    the note reaches the lane's own slot, a second audition releases the first before it
//    sounds, and a NaN velocity arrives finite.
//  · SOURCE-TEXT SCAN (claim 3) — `PartNoteEditor` is a `View`: it routes every audition through
//    the player's one method, sounds an add, a tap and a pitch move, and a sideways move does not.
//  · DEVICE PROBE, OPEN — that it SOUNDS, at the track's level, without a stuck note: the
//    NEEDS-FOUNDER-VERIFY ask at `TimelineRegionPlayer.auditionNote`.
//
//  GRADING against the parent tree (#433/#464): the file does NOT compile there — `auditionRoute`
//  and `auditionNote` are created by this commit — so no assertion has a verdict on the parent (ONE
//  absence, #486). Claims 1–2 are forward guards transcribed by reading `auditionRoute`,
//  `MultiRollFanout.slot(forLaneID:)` and `releaseAudition`; claim 3's needles were grepped
//  against the worktree. COUNTERWEIGHTS (#343): claim 1's playing transport and capacity 0,
//  claim 2's release-before-attack order.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheNoteEditorSoundsWhatItSetsTests: XCTestCase {

    private static let editorPath = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"

    private static let echoel = TimelineLane(name: "Echoel", kind: .midi)
    private static let keys = TimelineLane(name: "Keys", kind: .midi)
    private static let pad = TimelineLane(name: "Pad", kind: .midi)
    private static var document: TimelineDocument {
        TimelineDocument(lanes: [echoel, keys, pad], regions: [])
    }

    // MARK: 1 — the one route decision

    func testEachTrackAuditionsOnTheVoiceThatPlaysIt() {
        let doc = Self.document
        XCTAssertEqual(doc.rollLaneID, Self.echoel.id, "premise: the first MIDI lane is the Echoel track")
        typealias P = TimelineRegionPlayer
        XCTAssertEqual(P.auditionRoute(laneID: Self.echoel.id, in: doc, capacity: 4, isPlaying: false), .roll)
        XCTAssertEqual(P.auditionRoute(laneID: Self.echoel.id, in: doc, capacity: 4, isPlaying: true), .roll,
                       "the roll's own tap preview is monophonic and safe while playing")
        XCTAssertEqual(P.auditionRoute(laneID: Self.keys.id, in: doc, capacity: 4, isPlaying: false), .slot(0))
        XCTAssertEqual(P.auditionRoute(laneID: Self.pad.id, in: doc, capacity: 4, isPlaying: false), .slot(1))
        // COUNTERWEIGHTS: the transport owns the slots while it plays; no rack, no voice.
        XCTAssertEqual(P.auditionRoute(laneID: Self.keys.id, in: doc, capacity: 4, isPlaying: true), .silent)
        XCTAssertEqual(P.auditionRoute(laneID: Self.pad.id, in: doc, capacity: 1, isPlaying: false), .silent,
                       "a track past the rack's capacity has no voice to sound")
        XCTAssertEqual(P.auditionRoute(laneID: Self.keys.id, in: doc, capacity: 0, isPlaying: false), .silent)
        XCTAssertEqual(P.auditionRoute(laneID: UUID(), in: doc, capacity: 4, isPlaying: false), .silent)
    }

    // MARK: 2 — the note reaches the track's slot, one at a time

    func testAnAuditionSoundsOnItsSlotAndReleasesTheLastOne() {
        var heard: [(slot: Int, event: LaneNotePump.Event)] = []
        var lanes: [(slot: Int, lane: UUID?)] = []
        let player = TimelineRegionPlayer()
        player.enableMultiRoll(capacity: 4, sink: { slot, events in
            for event in events { heard.append((slot: slot, event: event)) }
        })
        player.slotLaneSink = { slot, lane in lanes.append((slot: slot, lane: lane)) }
        let doc = Self.document

        XCTAssertTrue(player.auditionNote(laneID: Self.keys.id, pitch: 60, velocity: 0.7,
                                          role: .harmony, in: doc))
        XCTAssertEqual(heard.map(\.slot), [0])
        XCTAssertEqual(heard.first?.event, LaneNotePump.Event(pitch: 60, velocity: 0.7))
        XCTAssertEqual(lanes.last?.slot, 0)
        XCTAssertEqual(lanes.last?.lane, Self.keys.id, "the slot is bound to the track before it sounds")

        heard.removeAll()
        XCTAssertTrue(player.auditionNote(laneID: Self.pad.id, pitch: 64, velocity: .nan,
                                          role: .harmony, in: doc))
        XCTAssertEqual(heard.count, 2, "the held note is released, then the new one sounds")
        XCTAssertEqual(heard.first?.slot, 0)
        XCTAssertEqual(heard.first?.event, LaneNotePump.Event(pitch: 60, velocity: 0),
                       "release BEFORE the next attack — a fast sketch never strands a note")
        XCTAssertEqual(heard.last?.slot, 1)
        XCTAssertEqual(heard.last?.event.pitch, 64)
        XCTAssertEqual(heard.last?.event.velocity, 0.05, "a NaN velocity arrives at the floor, finite")

        // COUNTERWEIGHT: no roll model attached, so the Echoel track has nothing to sound.
        XCTAssertFalse(player.auditionNote(laneID: Self.echoel.id, pitch: 60, velocity: 0.7,
                                           role: .harmony, in: doc))
    }

    // MARK: 3 — the editor sounds an add, a tap and a pitch move

    func testTheEditorAuditionsThroughThePlayersOneMethod() throws {
        let code = SourceText.codeOnly(try source(Self.editorPath))
        XCTAssertEqual(code.components(separatedBy: "player.auditionNote(").count - 1, 1,
                       "every audition goes through one helper and the player's one method")
        XCTAssertTrue(code.contains("@Environment(TimelineRegionPlayer.self) private var player"))
        XCTAssertEqual(code.components(separatedBy: "audition(added.id, in: added.notes, region: region)").count - 1, 2,
                       "a tap on an empty cell and the VoiceOver add both sound the new note")
        XCTAssertTrue(code.contains("audition(id, in: visible, region: region)"), "a tap on a note sounds it")
        guard let move = code.range(of: "if dPitch != 0, let first = ids.sorted(") else {
            return XCTFail("ANCHOR MISSING: a move sounds only when its pitch changed")
        }
        XCTAssertTrue(code[move.upperBound...].prefix(200).contains("audition(first, in: moved, region: region)"))
    }

    private func source(_ relative: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        let file = url.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("\(relative) not on disk — this run has no source tree")
        }
        return try String(contentsOf: file, encoding: .utf8)
    }
}
