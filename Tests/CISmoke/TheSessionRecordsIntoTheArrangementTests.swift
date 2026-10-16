// TheSessionRecordsIntoTheArrangementTests.swift
// P4b (founder 2026-10-16, gap list item 6 "Szenen ins Arrangement aufnehmen"), the wiring half:
// the player logs every launch that LANDS while "Record to arrangement" is on, ends the take
// wherever the launches die (Stop, the external stop, a locate or the cycle's jump, a restart) and
// at the song's wrap, and hands the parts to the app, which writes them through the store's paste
// writer — one Undo step. The pure half is `TheLaunchesBecomePartsOnTheArrangementTests`.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claim 1 is END-TO-END on the real player with nothing playing: the switch is off by default,
//     and turning it off with nothing recorded writes nothing.
//   · Claims 2–3 are SOURCE-TEXT SCANS: every place a launch dies ends the take first, the landing
//     function logs both kinds, the wrap ends it before the fold, the app wires the one sink to the
//     paste writer, and the door is a leaf that writes only the player's switch.
//   · NOT CLAIMED (DEVICE PROBE): that a recorded take plays back as it was launched.
//     NEEDS-FOUNDER-VERIFY (P4b) — the probe is at `SessionRecordToggle.swift`'s head.
//
// HONEST GRADING against the parent (§3): the file does not compile there (`recordsLaunches`,
// `launchTakeSink`, `SessionRecordToggle` are new), so no assertion has a verdict on the parent.
// Hand-transcribed: claims 1–3 are FORWARD guards plus COUNTERWEIGHTS (the switch defaults off; the
// view still persists nothing). Mutants: a `launch.removeAll()` without the take ending first (2) ·
// the wrap ending the take AFTER the fold (2) · a stop logged at the boundary (2) · the sink writing
// through `addRegion` per part (3) · the door touching the store (3).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheSessionRecordsIntoTheArrangementTests: XCTestCase {

    // MARK: 1 — off by default; nothing recorded writes nothing

    func testTheSwitchIsOffAndAnEmptyTakeWritesNothing() {
        let player = TimelineRegionPlayer()
        XCTAssertFalse(player.recordsLaunches, "Session → Arrangement recording is off until switched on")
        var written: [[TimelineRegion]] = []
        player.launchTakeSink = { written.append($0) }
        player.recordsLaunches = true
        player.recordsLaunches = false
        XCTAssertTrue(written.isEmpty, "a take with nothing launched writes nothing")
    }

    // MARK: 2 — the player: log what lands, end the take wherever the launches die

    func testThePlayerEndsTheTakeWhereverTheLaunchesDie() throws {
        let player = try source("Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift")
        let removes = player.components(separatedBy: "launch.removeAll()").count - 1
        XCTAssertGreaterThan(removes, 0, "ANCHOR: the player still clears its launches somewhere")
        var searchFrom = player.startIndex
        var checked = 0
        while let hit = player.range(of: "launch.removeAll()", range: searchFrom..<player.endIndex) {
            let lead = player[player.startIndex..<hit.lowerBound]
            guard let lastEnd = lead.range(of: "endLaunchTake()", options: .backwards),
                  let lastFunc = lead.range(of: "func ", options: .backwards) else {
                XCTFail("a `launch.removeAll()` with no `endLaunchTake()` before it")
                break
            }
            XCTAssertTrue(lastEnd.lowerBound > lastFunc.lowerBound,
                          "every place a launch dies ends the take first, in the same function")
            checked += 1
            searchFrom = hit.upperBound
        }
        XCTAssertEqual(checked, removes)
        let wrap = try XCTUnwrap(player.range(of: "if wrapped, launchTake.isOpen { endLaunchTake() }"))
        let fold = try XCTUnwrap(player.range(of: "if wrapped, !launch.isIdle { launch.shift(by: -loopTicks) }"))
        XCTAssertTrue(wrap.upperBound <= fold.lowerBound, "the take ends at the wrap BEFORE the launch timebase folds")
        XCTAssertTrue(player.contains("launchTake.started(laneID: t.laneID, regionID: regionID, atTick: t.atTick)"),
                      "a start is logged from its boundary")
        XCTAssertTrue(player.contains("launchTake.stopped(laneID: t.laneID, atTick: tick)"),
                      "a stop is logged where the arrangement resumes")
        XCTAssertTrue(player.contains("didSet { if !recordsLaunches { endLaunchTake() } }"),
                      "switching off ends the take there")
        XCTAssertTrue(player.contains("let parts = LaunchTake.regions(for: spans, in: doc)"))
    }

    // MARK: 3 — the one sink, and a door that touches no store

    func testTheAppWritesTheTakeThroughThePasteWriter() throws {
        let app = try source("Sources/Echoelmusic/EchoelmusicApp.swift")
        XCTAssertEqual(app.components(separatedBy: "timelinePlayer.launchTakeSink = {").count - 1, 1, "one sink")
        XCTAssertTrue(app.contains("Task { @MainActor in _ = store.pasteRegions(parts, atTick: start) }"),
                      "one paste = one Undo step, every part at its own tick, never inside the player's stop")
        let view = try source("Sources/Echoelmusic/Studio/SessionLaunchView.swift")
        XCTAssertEqual(view.components(separatedBy: "SessionRecordToggle()").count - 1, 1, "one door, in the Session grid")
        let door = try source("Sources/Echoelmusic/Studio/SessionRecordToggle.swift")
        XCTAssertTrue(door.contains("set: { player.recordsLaunches = $0 }"))
        XCTAssertFalse(door.contains("TimelineStore"), "the door writes the player's switch, never the store")
        XCTAssertFalse(door.contains("@AppStorage"), "a performance switch, not a stored preference")
    }

    // MARK: helpers

    private struct Unreadable: Error {}

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw Unreadable()
        }
        return SourceText.codeOnly(text)
    }
}
