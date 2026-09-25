// TheSessionLaunchesWhatTheSongPlaysTests.swift
// Echoel — WA4.2: the Session projection of the Workstation's song.
//
// WHAT THIS PINS. `Studio/SessionLaunchView.swift` gives `TimelineRegionPlayer.launchRegion`,
// `stopLaunched`, `launchState` and `launchGeneration` their first production caller. The
// launch engine was done, tested and doorless. The risks in dooring it are a SECOND song (a
// persisted scene list, a second overlap rule) and a control that does nothing (a launch cell
// on a lane the engine refuses, or a tap while the engine no-ops because the song is stopped).
//
// 1. END-TO-END over the real `TimelineDocument`: the tracks are exactly the lanes a launch is
//    HEARD on (MIDI and audio, not bio, not video/visual, not a MIDI lane past the lane rack's
//    capacity), in document order — by `TrackMix.role`, the inspector's rule.
// 2. END-TO-END: scenes are the distinct start ticks of parts on those tracks, ascending; a
//    part on a refused lane opens no scene; each cell is `activeRegion`'s answer — a part that
//    started earlier and still plays belongs to the later scene, and an overlap is won by the
//    region `activeRegion` picks (#1440: one definition of precedence).
// 3. END-TO-END: every `LaneLaunchState` case maps to the cell it lights, and only that one.
// 4. COUNTERWEIGHTS (#343): the premises — `launchRegion` still refuses bio/other lanes and
//    no-ops while stopped; `launchGeneration` stays OBSERVED and `currentTick` IGNORED (the
//    leaf-safety argument of the view's header).
// 5. SOURCE: the view launches and stops through the player's API with the one named quantize,
//    disables launching while stopped, persists nothing, never starts the transport, never
//    reads the playhead; the Workstation constructs it exactly once and still does not launch.
//
// Grading (§0, no Swift toolchain in a web session): claims 1–3 were transcribed into Python
// over a model of `SessionGrid` and `TimelineScheduling.activeRegion`; claims 4–5 were driven
// against this tree. On the parent the subject file does not exist, so the bundle does not
// build there — ONE absence, not N findings (#486). Claim 4 is COUNTERWEIGHTS (green on both).
// NOT covered: whether the grid renders, reads well, or that a launched part is HEARD on the
// bar — a device probe, owned by the marker below.
// NEEDS-FOUNDER-VERIFY: Workstation → Play → Session → tap a part, then Launch scene, then
// Stop: each change lands on the next bar and the track returns to the song after Stop.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheSessionLaunchesWhatTheSongPlaysTests: XCTestCase {

    private static let viewPath = "Sources/Echoelmusic/Studio/SessionLaunchView.swift"
    private static let workstationPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let playerPath = "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"
    private static let sourcesRoot = "Sources/Echoelmusic"

    // One fixture VALUE per lane — never a factory (#1419).
    private static let bioLane = TimelineLane(name: "Body", kind: .midi, isBio: true)
    private static let keysLane = TimelineLane(name: "Keys", kind: .midi)
    private static let lookLane = TimelineLane(name: "Look", kind: .visual)
    private static let drumsLane = TimelineLane(name: "Loop", kind: .audio)

    private static let bar = TimelineTime.ticksPerBar
    /// The lane rack's default capacity, as `TimelineRegionPlayer.laneVoiceCapacity` reports it.
    private static let rack = 4

    // MARK: 1 — the tracks are the lanes the engine launches on

    func testTheTracksAreTheLaunchableLanesInOrder() {
        let doc = TimelineDocument(
            lanes: [Self.bioLane, Self.keysLane, Self.lookLane, Self.drumsLane], regions: [])
        XCTAssertEqual(SessionGrid.tracks(in: doc, voiceCapacity: Self.rack).map(\.id), [Self.keysLane.id, Self.drumsLane.id],
                       "bio and visual lanes are refused by launchRegion — no column for them")
        XCTAssertEqual(SessionGrid.tracks(in: doc, voiceCapacity: Self.rack).map(\.name), ["Keys", "Loop"])
    }

    func testAVoicelessTrackIsNotOffered() {
        // Roll lane + five extra MIDI lanes, one part each: the fifth extra has no rack voice.
        let extras = (1...5).map { TimelineLane(name: "Extra \($0)", kind: .midi) }
        let clip = UUID()
        let parts = extras.map { TimelineRegion(laneID: $0.id, clipID: clip,
                                                startTick: 0, lengthTicks: Self.bar) }
        let doc = TimelineDocument(lanes: [Self.keysLane] + extras, regions: parts)
        let ids = SessionGrid.tracks(in: doc, voiceCapacity: Self.rack).map(\.id)
        XCTAssertEqual(ids, [Self.keysLane.id] + extras.prefix(4).map(\.id),
                       "a launch on a voiceless track would read Playing in silence")
        let cells = SessionGrid.scenes(in: doc, voiceCapacity: Self.rack).first?.cells ?? [:]
        XCTAssertNil(cells[extras[4].id])
        // Multi-roll off: only the Echoel track launches a MIDI part.
        XCTAssertEqual(SessionGrid.tracks(in: doc, voiceCapacity: 0).map(\.id), [Self.keysLane.id])
    }

    // MARK: 2 — scenes are where parts start; cells are what the song plays there

    func testScenesAreTheStartsOfPlayableParts() {
        let clip = UUID()
        let long = TimelineRegion(laneID: Self.keysLane.id, clipID: clip,
                                  startTick: 0, lengthTicks: 8 * Self.bar)
        let loopA = TimelineRegion(laneID: Self.drumsLane.id, clipID: clip,
                                   startTick: 0, lengthTicks: 4 * Self.bar)
        let loopB = TimelineRegion(laneID: Self.drumsLane.id, clipID: clip,
                                   startTick: 4 * Self.bar, lengthTicks: 4 * Self.bar)
        // A part on a refused lane opens no scene.
        let curve = TimelineRegion(laneID: Self.bioLane.id, clipID: clip,
                                   startTick: 2 * Self.bar, lengthTicks: Self.bar)
        let look = TimelineRegion(laneID: Self.lookLane.id, clipID: clip,
                                  startTick: 3 * Self.bar, lengthTicks: Self.bar)
        let doc = TimelineDocument(
            lanes: [Self.bioLane, Self.keysLane, Self.lookLane, Self.drumsLane],
            regions: [long, loopA, loopB, curve, look])

        let scenes = SessionGrid.scenes(in: doc, voiceCapacity: Self.rack)
        XCTAssertEqual(scenes.map(\.startTick), [0, 4 * Self.bar])
        XCTAssertEqual(scenes[0].cells, [Self.keysLane.id: long.id, Self.drumsLane.id: loopA.id])
        // The long part started earlier and still plays at bar 5 — it belongs to that scene.
        XCTAssertEqual(scenes[1].cells, [Self.keysLane.id: long.id, Self.drumsLane.id: loopB.id])
    }

    func testAnOverlapIsWonByTheSchedulersChoice() {
        let clip = UUID()
        let under = TimelineRegion(laneID: Self.keysLane.id, clipID: clip,
                                   startTick: 0, lengthTicks: 8 * Self.bar)
        let over = TimelineRegion(laneID: Self.keysLane.id, clipID: clip,
                                  startTick: 2 * Self.bar, lengthTicks: 2 * Self.bar)
        let doc = TimelineDocument(lanes: [Self.keysLane], regions: [under, over])
        let scenes = SessionGrid.scenes(in: doc, voiceCapacity: Self.rack)
        XCTAssertEqual(scenes.map(\.startTick), [0, 2 * Self.bar])
        for scene in scenes {
            // #416/#1440: the cell IS activeRegion's answer, never a second rule.
            XCTAssertEqual(scene.cells[Self.keysLane.id],
                           TimelineScheduling.activeRegion(in: doc, laneID: Self.keysLane.id,
                                                           at: scene.startTick)?.id)
        }
        XCTAssertEqual(scenes[1].cells[Self.keysLane.id], over.id,
                       "the later-starting overlap is what the song plays at bar 3")
    }

    func testAnEmptySongHasNoScenes() {
        let doc = TimelineDocument(lanes: [Self.keysLane, Self.drumsLane], regions: [])
        XCTAssertTrue(SessionGrid.scenes(in: doc, voiceCapacity: Self.rack).isEmpty)
    }

    func testTheSceneLabelNamesTheBar() {
        XCTAssertEqual(SessionGrid.label(forTick: 0), "Bar 1")
        XCTAssertEqual(SessionGrid.label(forTick: 4 * Self.bar), "Bar 5")
        XCTAssertEqual(SessionGrid.label(forTick: Self.bar + 2 * TimelineTime.ticksPerBeat),
                       "Bar 2 beat 3")
    }

    // MARK: 3 — which cell a launch state lights

    func testEveryLaunchStateLightsOnlyItsRegion() {
        let a = UUID(), b = UUID(), other = UUID()
        let playingA = LaunchedRegion(regionID: a, startedAtTick: 0)

        XCTAssertEqual(SessionGrid.cellState(.idle, regionID: a), .idle)

        XCTAssertEqual(SessionGrid.cellState(.playing(playingA), regionID: a), .playing)
        XCTAssertEqual(SessionGrid.cellState(.playing(playingA), regionID: other), .idle)

        let queuedB = LaneLaunchState.queued(regionID: b, startAtTick: Self.bar, current: playingA)
        XCTAssertEqual(SessionGrid.cellState(queuedB, regionID: b), .queued)
        XCTAssertEqual(SessionGrid.cellState(queuedB, regionID: a), .playing,
                       "the part a queued launch replaces keeps sounding until the bar")
        XCTAssertEqual(SessionGrid.cellState(queuedB, regionID: other), .idle)

        let fresh = LaneLaunchState.queued(regionID: b, startAtTick: Self.bar, current: nil)
        XCTAssertEqual(SessionGrid.cellState(fresh, regionID: a), .idle)

        let stopping = LaneLaunchState.queuedStop(current: playingA, stopAtTick: Self.bar)
        XCTAssertEqual(SessionGrid.cellState(stopping, regionID: a), .stopping)
        XCTAssertEqual(SessionGrid.cellState(stopping, regionID: other), .idle)

        XCTAssertFalse(SessionGrid.isLaunched(.idle))
        XCTAssertTrue(SessionGrid.isLaunched(.playing(playingA)))
        XCTAssertTrue(SessionGrid.isLaunched(stopping))
        XCTAssertNil(SessionGrid.word(.idle))
        for state in [SessionGrid.CellState.queued, .playing, .stopping] {
            XCTAssertNotNil(SessionGrid.word(state), "\(state) has no word")
        }
    }

    // MARK: 4 — counterweights: the engine premises the view relies on

    func testTheEngineStillRefusesWhatTheGridLeavesOut() throws {
        let player = try source(Self.playerPath)
        guard let head = player.range(of: "public func launchRegion("),
              let end = player.range(of: "public func stopLaunched(", range: head.upperBound..<player.endIndex)
        else {
            XCTFail("ANCHOR MISSING: launchRegion / stopLaunched moved (#454)")
            return
        }
        let body = String(player[head.upperBound..<end.lowerBound])
        XCTAssertTrue(body.contains("guard isPlaying else { return }"),
                      "launch no-ops while stopped — the premise of the view's disabled state")
        XCTAssertTrue(body.contains("(lane.kind == .midi || lane.kind == .audio), !lane.isBio"),
                      """
                      launchRegion's lane refusal changed. `SessionGrid.tracks` mirrors it; \
                      update both in the same commit, or the grid offers a cell that does nothing \
                      (or hides one that works).
                      """)
        XCTAssertTrue(player.contains("public private(set) var launchGeneration"),
                      "launchGeneration must stay observed, or the grid never repaints on a bar")
        XCTAssertTrue(player.contains("@ObservationIgnored public private(set) var currentTick"),
                      "the playhead must stay unobserved — the leaf-safety argument depends on it")
    }

    // MARK: 5 — source: the view's calls, gates and absences; the one door

    func testTheViewLaunchesThroughThePlayerAndPersistsNothing() throws {
        let code = try source(Self.viewPath)
        XCTAssertTrue(code.contains("player.launchRegion(regionID, quantize: SessionGrid.quantize)"))
        XCTAssertTrue(code.contains("player.stopLaunched(laneID: track.id, quantize: SessionGrid.quantize)"))
        XCTAssertTrue(code.contains("player.launchState(laneID:"))
        XCTAssertTrue(code.contains("player.launchGeneration"))
        XCTAssertTrue(code.contains("let capacity = player.laneVoiceCapacity"),
                      "the voiced-track rule gets the player's capacity, never a literal")
        XCTAssertTrue(code.contains("TrackMix.role(of: lane.id, in: document,"),
                      "one rule for which tracks sound, shared with the inspector (#416)")
        XCTAssertGreaterThanOrEqual(code.components(separatedBy: ".disabled(!playing)").count - 1, 2,
                                    "a part and a scene cannot be launched while the song is stopped")
        for banned in ["player.play(", "player.stop()", "relocate", "currentTick", "loopEnabled",
                       "UserDefaults", "@AppStorage", "JSONEncoder", "AppGroupStore",
                       "TimelineStore(", "TimelineLane(", "TimelineDocument(", "TimelineRegion(",
                       "Timer", "asyncAfter", "Task.sleep"] {
            XCTAssertFalse(code.contains(banned), """
                SessionLaunchView contains `\(banned)`. It is a projection that launches through \
                the player: it owns no transport, no playhead read, no clock and no persistence.
                """)
        }
        // It reads the song and sends the store nothing else.
        let storeMessages = code.components(separatedBy: "timeline.").dropFirst()
            .map { String($0.prefix(while: { $0.isLetter })) }
        XCTAssertEqual(Set(storeMessages), ["document"])
    }

    func testTheWorkstationIsTheOneDoorAndStillDoesNotLaunch() throws {
        let workstation = try source(Self.workstationPath)
        XCTAssertEqual(workstation.components(separatedBy: "SessionLaunchView()").count - 1, 1)
        for member in ["launchRegion", "stopLaunched", "launchState", "launchGeneration"] {
            XCTAssertFalse(workstation.contains(member),
                           "the Workstation's transport is not authorised to launch (claim B there)")
        }
        let doors = try filesMatching { code, _ in code.contains("SessionLaunchView(") }
        XCTAssertEqual(doors, [Self.workstationPath])
    }

    // MARK: Source helpers

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        return dir
    }

    private func source(_ relativePath: String) throws -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }

    private func filesMatching(_ matches: (String, String) -> Bool) throws -> [String] {
        let root = repoRoot().appendingPathComponent(Self.sourcesRoot)
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            XCTFail("cannot enumerate \(Self.sourcesRoot) — a scan that saw nothing is not a pass")
            return []
        }
        var hits: [String] = []
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            let path = Self.sourcesRoot + "/" + relative
            let url = root.appendingPathComponent(relative)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if matches(SourceText.codeOnly(text), path) { hits.append(path) }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        return hits.sorted()
    }
}
