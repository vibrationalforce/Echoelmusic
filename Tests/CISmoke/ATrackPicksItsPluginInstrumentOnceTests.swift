//
//  ATrackPicksItsPluginInstrumentOnceTests.swift
//  Production level H2a (founder 2026-10-13: „… auv3 Plugins für Effekte und MIDI Instrumente …").
//  A rack track can now STORE which installed Audio Unit instrument it plays instead of its
//  built-in voice: `DeviceInsert.pluginInstrument` in the track's `DeviceChain.instrument`, written
//  by ONE writer, one Undo step per pick, read per slot by `MultiRollFanout.hostedInstrument`.
//  H2a was the model alone; since H2b2 the region player names each slot's choice to the host
//  (`HostedInstrumentHost`). No door writes the choice until H2c.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–4) — the insert, the store and the fan-out are shipped and pure
//    or main-actor. Claim 1: the insert round-trips its component, and a LATER format or another
//    type reads as nil (fails closed — a later build's plugin is never loaded with v1 meaning).
//    Claim 2: a pick is one Undo step and Undo gives the built-in voice back; a re-pick of the same
//    plugin records nothing. Claim 3, COUNTERWEIGHTS: the Echoel track, an audio track and a
//    foreign insert type are refused; an Echoel instance or an unreadable instrument already in
//    the slot is never overwritten; the track's effect insert is kept; clearing leaves no chain.
//    Claim 4: the slot resolver answers for the track the rack plays in that slot, and nil for an
//    out-of-range slot.
//  · SOURCE-TEXT SCAN (claim 5) — the region player is the one reader: its four load sites plus
//    the live mixer merge (H2b2 raised this from "no reader"; H2d added the merge, 4 → 5).
//
//  GRADING against the parent tree (#433/#464): the file does NOT compile there — the insert type,
//  the writer, the step kind and the resolver are created by this commit — so no assertion has a
//  verdict on the parent (ONE absence, #486). Transcribed by reading `setLanePluginInstrument`,
//  `editLanePlugin`, the `.lanePlugin` undo case, `pluginComponent` and `hostedInstrument`; not run.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ATrackPicksItsPluginInstrumentOnceTests: XCTestCase {

    private static let synth = DeviceInsert.PluginComponent(type: 0x6175_6D75, subtype: 0x7379_6E74,
                                                            manufacturer: 0x4163_6D65,
                                                            name: "Synth One", manufacturerName: "Acme")
    private static let other = DeviceInsert.PluginComponent(type: 0x6175_6D75, subtype: 0x7069_616E,
                                                            manufacturer: 0x4163_6D65,
                                                            name: "Piano", manufacturerName: "Acme")

    /// The Echoel track (the first MIDI lane), one rack track, one audio track.
    private static func song() -> (TimelineDocument, echoel: UUID, rack: UUID, audio: UUID) {
        let echoel = TimelineLane(name: "Echoel", kind: .midi)
        let rack = TimelineLane(name: "Keys", kind: .midi, builtinInstrument: .polySynth)
        let audio = TimelineLane(name: "Tape", kind: .audio)
        return (TimelineDocument(lanes: [echoel, rack, audio], regions: []), echoel.id, rack.id, audio.id)
    }

    // MARK: 1 — the insert names its component, and fails closed

    func testTheInsertRoundTripsAndFailsClosed() throws {
        let insert = DeviceInsert.pluginInstrument(Self.synth)
        XCTAssertEqual(insert.typeID, DeviceInsert.pluginInstrumentTypeID)
        XCTAssertEqual(insert.pluginComponent, Self.synth)
        let decoded = try JSONDecoder().decode(DeviceInsert.self, from: JSONEncoder().encode(insert))
        XCTAssertEqual(decoded.pluginComponent, Self.synth, "the choice survives a save")

        var later = insert
        later.typeVersion = DeviceInsert.pluginInstrumentTypeVersion + 1
        XCTAssertNil(later.pluginComponent, "a later format is not read with v1 meaning")
        XCTAssertNil(DeviceInsert.echoel(fxCharacter: .vinyl).pluginComponent, "another type is not a plugin")
    }

    // MARK: 2 — a pick is one Undo step

    func testAPickIsOneUndoStep() {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }
        let (doc, _, rack, _) = Self.song()
        timeline.replaceDocument(doc)

        let pick = DeviceInsert.pluginInstrument(Self.synth)
        timeline.editLanePlugin(id: rack) { timeline.setLanePluginInstrument(rack, pick) }
        XCTAssertEqual(timeline.document.lanes.first { $0.id == rack }?.deviceChain?.instrument?.pluginComponent,
                       Self.synth)
        XCTAssertTrue(timeline.canUndo)

        timeline.undo()
        XCTAssertNil(timeline.document.lanes.first { $0.id == rack }?.deviceChain,
                     "Undo gives the built-in voice back and leaves no empty chain")
        timeline.redo()
        XCTAssertEqual(timeline.document.lanes.first { $0.id == rack }?.deviceChain?.instrument, pick,
                       "Redo puts the same insert back")

        // COUNTERWEIGHT: a re-pick of what the track already plays records nothing — also when the
        // menu builds a FRESH insert (new id) for the same component (review of H2b: comparing
        // inserts recorded an empty step).
        timeline.replaceDocument(timeline.document)
        timeline.editLanePlugin(id: rack) { timeline.setLanePluginInstrument(rack, pick) }
        XCTAssertFalse(timeline.canUndo, "the same plugin again is no step")
        let fresh = DeviceInsert.pluginInstrument(Self.synth)
        XCTAssertNotEqual(fresh.id, pick.id, "premise: a new insert has a new id")
        timeline.editLanePlugin(id: rack) { timeline.setLanePluginInstrument(rack, fresh) }
        XCTAssertFalse(timeline.canUndo, "the same component in a fresh insert is no step either")
        XCTAssertEqual(timeline.document.lanes.first { $0.id == rack }?.deviceChain?.instrument?.id, pick.id,
                       "nothing was rewritten")
    }

    // MARK: 3 — refusals and what is kept

    func testOnlyARackTrackTakesOneAndNothingForeignIsOverwritten() {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }
        let (doc, echoel, rack, audio) = Self.song()
        timeline.replaceDocument(doc)
        let pick = DeviceInsert.pluginInstrument(Self.synth)

        timeline.setLanePluginInstrument(echoel, pick)
        timeline.setLanePluginInstrument(audio, pick)
        XCTAssertNil(timeline.document.lanes.first { $0.id == echoel }?.deviceChain, "never on the Echoel track")
        XCTAssertNil(timeline.document.lanes.first { $0.id == audio }?.deviceChain, "never on an audio track")

        timeline.setLanePluginInstrument(rack, .character(.vinyl))
        XCTAssertNil(timeline.document.lanes.first { $0.id == rack }?.deviceChain?.instrument,
                     "an insert of another type is not an instrument pick")

        // An effect on the track stays; the plugin sits beside it.
        timeline.setLaneEffect(rack, character: .vinyl)
        timeline.setLanePluginInstrument(rack, pick)
        let chain = timeline.document.lanes.first { $0.id == rack }?.deviceChain
        XCTAssertEqual(chain?.instrument, pick)
        XCTAssertEqual(chain?.soundingCharacter, .vinyl, "the track's effect insert is kept")

        timeline.setLanePluginInstrument(rack, nil)
        XCTAssertNil(timeline.document.lanes.first { $0.id == rack }?.deviceChain?.instrument)
        XCTAssertNotNil(timeline.document.lanes.first { $0.id == rack }?.deviceChain, "the effect still needs the chain")

        // An instrument this build did not write is never replaced.
        var foreign = DeviceInsert.pluginInstrument(Self.other)
        foreign.typeID = "com.echoelmusic.device.later"
        var lanes = timeline.document.lanes
        if let i = lanes.firstIndex(where: { $0.id == rack }) { lanes[i].deviceChain?.instrument = foreign }
        timeline.replaceDocument(TimelineDocument(lanes: lanes, regions: []))
        timeline.setLanePluginInstrument(rack, pick)
        timeline.setLanePluginInstrument(rack, nil)
        XCTAssertEqual(timeline.document.lanes.first { $0.id == rack }?.deviceChain?.instrument, foreign,
                       "a foreign instrument keeps its bytes")
    }

    // MARK: 4 — the slot resolver

    func testTheSlotResolverAnswersForTheRackTrack() {
        let song = Self.song()
        var doc = song.0
        let echoel = song.echoel, rack = song.rack
        if let i = doc.lanes.firstIndex(where: { $0.id == rack }) {
            var chain = DeviceChain(inserts: [])
            chain.instrument = .pluginInstrument(Self.synth)
            doc.lanes[i].deviceChain = chain
        }
        let roll = doc.rollLaneID
        XCTAssertEqual(roll, echoel, "premise: the first MIDI lane is the Echoel track")
        XCTAssertEqual(MultiRollFanout.slot(forLaneID: rack, in: doc, rollLane: roll, capacity: 4), 0)
        XCTAssertEqual(MultiRollFanout.hostedInstrument(forSlot: 0, in: doc, rollLane: roll), Self.synth)
        XCTAssertNil(MultiRollFanout.hostedInstrument(forSlot: 1, in: doc, rollLane: roll), "out of range")
    }

    // MARK: 5 — only the region player reads it (H2b2)

    func testOnlyTheRegionPlayerReadsTheResolver() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let sources = root.appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            throw XCTSkip("Sources/ not on disk — this run has no source tree")
        }
        var callers: [String: Int] = [:]
        for case let url as URL in walker where url.pathExtension == "swift" {
            let code = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
            let reads = code.components(separatedBy: "MultiRollFanout.hostedInstrument(forSlot:").count - 1
            if reads > 0 { callers[url.lastPathComponent] = reads }
        }
        XCTAssertEqual(callers, ["TimelineRegionPlayer.swift": 5], """
            The hosted-instrument choice is read somewhere other than the region player's four \
            load sites (fan-out, prime, audition bind, re-bind — right after the slot's kind) and \
            its live mixer merge (H2d: a pick during playback). A second reader is a second \
            decision about what a track plays (#416).
            """)
    }
}
