// ATrackComposesInItsOwnStyleTests.swift
// Echoel — GMMW GA-1 ("Compose here"). The per-track composer was built in July (Slice A/A2):
// every take the instrument composes fans out to each rack track that carries its own style or
// variation (`LaneComposerInput.composeLaneOverrides`) and lands in that track's composer part.
// Its lane setters had no caller, so no track could ask for it. `TrackComposeRows` is the door,
// on the Device page of a rack track.
//
// WHAT IT PINS.
// 1. PURE: the rows are offered on a rack track (`.laneSynth`, any voice kind) and nowhere else —
//    not the Echoel track (it IS the instrument's part), not a track without a voice, not audio,
//    bio or video.
// 2. END-TO-END over a real `TimelineStore` + `ClipStore`: on places a composer part in the loop
//    (ONE undo step) and a variation of its own; it shows on. Undo takes the part back and it shows
//    off — the lane fields are not on Undo (their own contract), so the variation stays and the
//    next on reuses it instead of rolling a new one.
// 3. END-TO-END refusals write nothing and record no step: a part of the person's own inside the
//    loop (`.ownPart`, the import's rule), a full part grid (`.gridFull`).
// 4. END-TO-END off: the style and the variation go back to "follow the piece", the mood is not
//    touched, the composer's part stays as it is; the fan-out's own predicate (`hasOverride`) says
//    the track no longer composes.
// 5. SOURCE: the rows are mounted once, on the Device page, behind `TrackCompose.offered`; the
//    inspector body and the Style menu's leaf read no part grid (10.76.41/50: the menu host stays
//    still while a take lands); the rows write only through the store's setters and
//    `ensureComposerRegion`, never `setLaneMood`, and read no player or transport.
// COUNTERWEIGHTS (#343): `ensureComposerRegion` asks the same `hasComposerPart` rule the switch
// shows (#416), and the fan-out still leaves the Echoel track out (`lane.id != rollLane`).
//
// Grading (§0, no Swift toolchain): on the parent (`cd471b8`) this file does NOT COMPILE — it names
// `TrackCompose` and `TimelineStore.hasComposerPart`, which this commit creates — so no assertion has
// a verdict there; claims 1–5 are FORWARD guards and the two counterweights would be green on the
// parent's text where their anchors exist (the roll-lane exclusion; the shared rule is new). Every
// claim was transcribed into Python and driven on this tree.
// NOT covered: whether a sampler or EchoelBass track sounds good composing, how the rows read at
// large type sizes, and that the notes arrive on the next Start/evolve — device probes.
// NEEDS-FOUNDER-VERIFY: add a MIDI track → Device → Compose here → Start the instrument → the track
// plays its own line; Style → another genre → the next take follows it; New variation → a different
// line; Off → the part keeps its last notes.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ATrackComposesInItsOwnStyleTests: XCTestCase {

    private static let loopBars = 4
    private static let bar = TimelineTime.ticksPerBar

    // MARK: 1 — offered on a rack track only

    func testTheRowsAreOfferedOnARackTrackOnly() {
        XCTAssertTrue(TrackCompose.offered(.laneSynth(.poly)), "a rack track composes")
        for kind in LaneVoiceKind.allCases {
            XCTAssertTrue(TrackCompose.offered(.laneSynth(kind)), "any voice kind on the rack: \(kind)")
        }
        let refused: [TrackMix.Role] = [.echoelInstrument, .noVoice(capacity: 3), .audio, .bio, .unplayed]
        for role in refused {
            XCTAssertFalse(TrackCompose.offered(role), "\(role) gets no Compose here")
        }
    }

    // MARK: 2 — on places a part and a variation; Undo takes the part

    func testOnPlacesAComposerPartAndAVariation() throws {
        try withStores { timeline, clips, track in
            XCTAssertFalse(TrackCompose.isComposing(track, in: timeline.document, clips: clips.filledClips,
                                                    loopBars: Self.loopBars), "fixture premise: off")
            XCTAssertNil(TrackCompose.turnOn(track, timeline: timeline, clips: clips,
                                             loopBars: Self.loopBars, seed: 42), "on")
            let lane = try XCTUnwrap(timeline.document.lanes.first { $0.id == track })
            XCTAssertEqual(lane.variationSeed, 42, "a variation of its own, so it composes its own line")
            XCTAssertTrue(LaneComposerInput.hasOverride(lane), "the fan-out composes this track")
            let parts = timeline.document.regions(in: track)
            XCTAssertEqual(parts.count, 1, "one composer part")
            let part = try XCTUnwrap(parts.first)
            XCTAssertEqual(part.startTick, 0)
            XCTAssertEqual(part.lengthTicks, Self.loopBars * Self.bar, "the loop the composer writes into")
            XCTAssertEqual(clips.clip(id: part.clipID)?.composerOwned, true, "the composer's part")
            XCTAssertTrue(TrackCompose.isComposing(track, in: timeline.document, clips: clips.filledClips,
                                                   loopBars: Self.loopBars), "the switch shows on")

            timeline.undo()
            XCTAssertTrue(timeline.document.regions(in: track).isEmpty, "ONE undo step takes the part back")
            XCTAssertFalse(TrackCompose.isComposing(track, in: timeline.document, clips: clips.filledClips,
                                                    loopBars: Self.loopBars), "…and the switch shows off")
            XCTAssertEqual(timeline.document.lanes.first { $0.id == track }?.variationSeed, 42,
                           "lane fields are not on Undo — the variation stays")

            XCTAssertNil(TrackCompose.turnOn(track, timeline: timeline, clips: clips,
                                             loopBars: Self.loopBars, seed: 7))
            XCTAssertEqual(timeline.document.lanes.first { $0.id == track }?.variationSeed, 42,
                           "on again keeps the track's variation — it is not rolled anew")
            XCTAssertEqual(timeline.document.regions(in: track).count, 1, "the part is back")
        }
    }

    // MARK: 3 — refusals write nothing

    func testItWillNotPlayOverThePersonsOwnPart() throws {
        try withStores { timeline, clips, track in
            let own = Clip(name: "GA-1 own", kind: .midi, melody: MelodyClip(notes: [Note(pitch: 60, startStep: 0)]))
            clips.setClip(at: 1, own)
            let ownPart = TimelineRegion(laneID: track, clipID: own.id, startTick: 2 * Self.bar, lengthTicks: Self.bar)
            timeline.replaceDocument(TimelineDocument(lanes: timeline.document.lanes,
                                                      regions: timeline.document.regions + [ownPart]))
            let regions = timeline.document.regions
            XCTAssertTrue(TrackCompose.wouldCoverOwnPart(track, in: timeline.document, clips: clips.filledClips,
                                                         loopBars: Self.loopBars), "the import's rule says so")
            XCTAssertEqual(TrackCompose.turnOn(track, timeline: timeline, clips: clips,
                                               loopBars: Self.loopBars, seed: 42), .ownPart)
            XCTAssertEqual(timeline.document.regions, regions, "no part placed over it")
            XCTAssertNil(timeline.document.lanes.first { $0.id == track }?.variationSeed, "no variation written")
            XCTAssertFalse(timeline.canUndo, "no dead undo step")
        }
    }

    func testAFullGridComposesNothing() throws {
        try withStores { timeline, clips, track in
            let grid: [Clip?] = (0..<ClipStore.slotCount).map { index in
                Clip(name: "GA-1 fill \(index)", kind: .midi, melody: MelodyClip(notes: []))
            }
            XCTAssertTrue(clips.replaceSlots(grid), "fixture premise: a full grid of the person's clips")
            XCTAssertEqual(TrackCompose.turnOn(track, timeline: timeline, clips: clips,
                                               loopBars: Self.loopBars, seed: 42), .gridFull)
            XCTAssertTrue(timeline.document.regions(in: track).isEmpty, "nothing placed")
            XCTAssertNil(timeline.document.lanes.first { $0.id == track }?.variationSeed,
                         "no variation written — nothing composes for a track with nowhere to land")
            XCTAssertEqual(clips.slots, grid, "no clip displaced")
            XCTAssertFalse(timeline.canUndo)
        }
    }

    // MARK: 4 — off

    func testOffFollowsThePieceAndKeepsThePart() throws {
        try withStores { timeline, clips, track in
            XCTAssertNil(TrackCompose.turnOn(track, timeline: timeline, clips: clips,
                                             loopBars: Self.loopBars, seed: 42))
            timeline.setLaneGenreOverride(track, genre: MusicStyle.offered.first)
            let part = try XCTUnwrap(timeline.document.regions(in: track).first)

            TrackCompose.turnOff(track, timeline: timeline)
            let lane = try XCTUnwrap(timeline.document.lanes.first { $0.id == track })
            XCTAssertNil(lane.genreOverride, "the style follows the piece")
            XCTAssertNil(lane.variationSeed, "the variation follows the piece")
            XCTAssertNil(lane.mood, "the mood was never set — and off does not write it")
            XCTAssertFalse(LaneComposerInput.hasOverride(lane), "the fan-out leaves the track alone")
            XCTAssertEqual(timeline.document.regions(in: track), [part], "the composer's part stays as it is")
            XCTAssertFalse(TrackCompose.isComposing(track, in: timeline.document, clips: clips.filledClips,
                                                    loopBars: Self.loopBars), "the switch shows off")
        }
    }

    // MARK: 5 — the door, in source

    func testTheRowsAreMountedOnTheDevicePageAndWriteThroughTheStore() throws {
        let inspector = try source("Sources/Echoelmusic/Studio/TrackInspectorView.swift")
        XCTAssertEqual(inspector.components(separatedBy: "TrackComposeRows(laneID: laneID)").count - 1, 1,
                       "mounted once")
        let device = try member("if page == .device {", in: inspector)
        guard let gate = device.range(of: "if TrackCompose.offered(controls.role) {"),
              let mount = device.range(of: "TrackComposeRows(laneID: laneID)") else {
            return XCTFail("ANCHOR MISSING: the Device page's Compose here gate (#454)")
        }
        XCTAssertLessThan(gate.lowerBound, mount.lowerBound, "behind the rack-track gate, on the Device page")
        XCTAssertFalse(inspector.contains("clipStore"), "the inspector reads no part grid — the rows' leaf does")

        let rows = try source("Sources/Echoelmusic/Studio/TrackComposeRows.swift")
        let picker = try member("private struct TrackComposeStylePicker: View {", in: rows)
        XCTAssertFalse(picker.contains("clipStore"), "the Style menu's host reads no part grid (10.76.41/50)")
        XCTAssertTrue(picker.contains("timeline.setLaneGenreOverride(laneID, genre: $0)"), "the style's one write")
        XCTAssertFalse(rows.contains("setLaneMood("), "no mood row, so no mood write")
        let timelineUses = rows.components(separatedBy: "timeline.").dropFirst()
        XCTAssertFalse(timelineUses.isEmpty, "ANCHOR: the rows use the timeline")
        let allowed = ["document", "ensureComposerRegion(", "setLaneVariationSeed(", "setLaneGenreOverride("]
        for use in timelineUses {
            XCTAssertTrue(allowed.contains { use.hasPrefix($0) },
                          "the rows touch the timeline with `\(use.prefix(30))` — only its document and the store's setters")
        }
        for hot in ["player.", "transport.", "TimelineRegionPlayer", "Transport.self", "cameraRPPG"] {
            XCTAssertFalse(rows.contains(hot), "`\(hot)` in the Compose here rows — they read nothing that moves with the song")
        }
    }

    // MARK: counterweights

    func testTheSwitchAndTheStoreAskOneRuleAndTheEchoelTrackStaysOut() throws {
        let store = try source("Sources/Echoelmusic/Core/TimelineStore.swift")
        let ensure = try member("public func ensureComposerRegion(", in: store)
        XCTAssertTrue(ensure.contains("Self.hasComposerPart(onLane: laneID, in: document, clips: clipStore.filledClips,"),
                      "`ensureComposerRegion` asks the rule the switch shows (#416)")
        let fanOut = try source("Sources/Echoelmusic/Sequencer/LaneComposerInput.swift")
        XCTAssertTrue(fanOut.contains("lane.id != rollLane"), "the fan-out still leaves the Echoel track to the instrument")
    }

    // MARK: rig

    private func withStores(_ body: (TimelineStore, ClipStore, UUID) throws -> Void) throws {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            clips.replaceSlots(originalSlots)
            timeline.replaceDocument(originalDocument)
        }
        XCTAssertTrue(clips.replaceSlots([Clip?](repeating: nil, count: ClipStore.slotCount)),
                      "fixture premise: an empty grid")
        let echoel = TimelineLane(name: "GA-1 Echoel", kind: .midi)
        let track = TimelineLane(name: "GA-1 Track", kind: .midi)
        timeline.replaceDocument(TimelineDocument(lanes: [echoel, track], regions: []))
        XCTAssertEqual(timeline.document.rollLaneID, echoel.id, "fixture premise: the first MIDI track is the Echoel track")
        XCTAssertFalse(timeline.canUndo, "fixture premise: a fresh history")
        try body(timeline, clips, track.id)
    }

    private struct AnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(reason: relativePath)
        }
        return SourceText.codeOnly(text)
    }

    /// The text inside the braces that open at the first `{` from `head` on (#408 — never a window).
    private func member(_ head: String, in text: String) throws -> String {
        guard let start = text.range(of: head),
              let open = text[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: `\(head)` (#454)")
            throw AnchorMissing(reason: head)
        }
        var depth = 1
        var index = text.index(after: open)
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(text[text.index(after: open)..<index]) }
            default: break
            }
            index = text.index(after: index)
        }
        XCTFail("UNBALANCED: `\(head)` never closes (#454)")
        throw AnchorMissing(reason: head)
    }
}
