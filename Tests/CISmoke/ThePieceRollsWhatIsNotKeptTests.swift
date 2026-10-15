// ThePieceRollsWhatIsNotKeptTests.swift
// Echoel — Roll + Lock (founder 2026-10-15, after Synth Palace's Synth Shaper: one dice re-rolls
// every layer that is not locked). "Roll" in the Add menu gives every composing track a fresh
// variation unless "Keep on Roll" holds it; the Echoel track follows the body and is never rolled.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR (`PieceRoll` on a real `TimelineStore`): a roll changes the seed of an
//      unlocked composing track, keeps a locked one byte for byte, and leaves the Echoel track and a
//      track that does not compose alone. The outcome counts both.
//   2. END-TO-END BEHAVIOUR: the lock is written as `true` or nil, survives encode/decode, an old
//      lane without the key reads unlocked, and a lock is not a structural change (no voice
//      re-attack while playing).
//   3. END-TO-END BEHAVIOUR: the sentence after a roll says what happened in each case.
//   4. SOURCE-TEXT SCAN: one Roll item in the Add menu, the studio composes once on "roll", the
//      Device-page lock writes through `PieceRoll.setLocked`, no modal, no accent.
//
// ⚠️ HONEST GRADING (#433). `PieceRoll`, `rollLocked` and `setLaneRollLocked` are created by this
// commit: the file does not compile against the parent, one absence (#486), every claim FORWARD.
//
// ⚠️ THE LIMIT. Whether the rolled lines sound good together is an EAR question, and whether they
// arrive at once while playing is a DEVICE PROBE (NEEDS-FOUNDER-VERIFY: two synth tracks with
// Compose here, keep one, Add ▸ Roll while playing — the other one changes, the kept one does not).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ThePieceRollsWhatIsNotKeptTests: XCTestCase {

    private static let loopBars = 4

    // MARK: 1 — the roll

    func testARollChangesOnlyWhatIsNotKept() {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }

        let echoel = TimelineLane(name: "Roll Echoel", kind: .midi, variationSeed: 7)
        let free = TimelineLane(name: "Roll free", kind: .midi, variationSeed: 11)
        let kept = TimelineLane(name: "Roll kept", kind: .midi, variationSeed: 22, rollLocked: true)
        let silent = TimelineLane(name: "Roll silent", kind: .midi)
        let lanes = [echoel, free, kept, silent]
        let clips = lanes.map { Clip(name: "composer \($0.name)", composerOwned: true) }
        let regions = zip(lanes, clips).map { lane, clip in
            TimelineRegion(laneID: lane.id, clipID: clip.id, startTick: 0, lengthTicks: TimelineTime.ticksPerBar)
        }
        timeline.replaceDocument(TimelineDocument(lanes: lanes, regions: regions))
        XCTAssertEqual(timeline.document.rollLaneID, echoel.id, "fixture premise: the first MIDI track is the Echoel track")

        let split = PieceRoll.split(in: timeline.document, clips: clips, loopBars: Self.loopBars)
        XCTAssertEqual(split.roll, [free.id], "only the composing, unlocked rack track is rolled")
        XCTAssertEqual(split.kept, [kept.id], "the locked one is kept")

        var next: UInt64 = 1000
        let outcome = PieceRoll.roll(timeline: timeline, clips: clips, loopBars: Self.loopBars) {
            next += 1
            return next
        }
        XCTAssertEqual(outcome, PieceRoll.Outcome(rolled: 1, kept: 1))
        let after = Dictionary(uniqueKeysWithValues: timeline.document.lanes.map { ($0.id, $0.variationSeed) })
        XCTAssertEqual(after[free.id] ?? nil, 1001, "the free track got the fresh seed")
        XCTAssertEqual(after[kept.id] ?? nil, 22, "the kept track's variation is untouched")
        XCTAssertEqual(after[echoel.id] ?? nil, 7, "the Echoel track follows the body — never rolled")
        XCTAssertNil(after[silent.id] ?? nil, "a track that does not compose gets no seed")
    }

    // MARK: 2 — the lock as data

    func testTheLockIsWrittenAsTrueOrNothing() throws {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }
        let lane = TimelineLane(name: "Lock", kind: .midi)
        timeline.replaceDocument(TimelineDocument(lanes: [lane]))
        PieceRoll.setLocked(lane.id, locked: true, timeline: timeline)
        XCTAssertEqual(timeline.document.lanes.first?.rollLocked, true)
        PieceRoll.setLocked(lane.id, locked: false, timeline: timeline)
        XCTAssertNil(timeline.document.lanes.first?.rollLocked, "unlocking writes nil — the old bytes")

        let unlocked = try JSONEncoder().encode(TimelineLane(name: "u", kind: .midi))
        XCTAssertFalse(String(decoding: unlocked, as: UTF8.self).contains("rollLocked"),
                       "an unlocked track writes no key at all")
        let locked = TimelineLane(name: "l", kind: .midi, rollLocked: true)
        let round = try JSONDecoder().decode(TimelineLane.self, from: JSONEncoder().encode(locked))
        XCTAssertTrue(round.isRollLocked, "a lock survives the round trip")
        let old = try JSONDecoder().decode(TimelineLane.self, from: unlocked)
        XCTAssertFalse(old.isRollLocked, "a track from before the lock reads unlocked")

        var relocked = TimelineDocument(lanes: [TimelineLane(name: "s", kind: .midi)])
        let before = relocked
        relocked.lanes[0].rollLocked = true
        XCTAssertTrue(TimelineDocument.structurallyEqual(before, relocked),
                      "a lock changes nothing that sounds — no relocate, no voice re-attack")
    }

    // MARK: 3 — the sentence

    func testTheSentenceSaysWhatHappened() {
        XCTAssertTrue(PieceRoll.note(.init(rolled: 0, kept: 0)).hasPrefix("Nothing to roll yet"))
        XCTAssertTrue(PieceRoll.note(.init(rolled: 0, kept: 2)).hasPrefix("Every composing track is kept"))
        let both = PieceRoll.note(.init(rolled: 2, kept: 1))
        XCTAssertTrue(both.contains("2") && both.contains("1"), "both counts are said")
        XCTAssertTrue(both.contains("Echoel track follows your body"), "the unrolled Echoel track is explained")
    }

    // MARK: 4 — the doors

    func testOneRollItemAndOneLockWriter() throws {
        let workstation = try code("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertEqual(workstation.components(separatedBy: "{ rollPiece() } label: { Label(\"Roll\"").count - 1, 1,
                       "one Roll item in the Add menu")
        XCTAssertTrue(workstation.contains("PieceRoll.requestCompose(after: outcome)"), "a roll asks for one compose")
        let studio = try code("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        guard let arm = studio.range(of: "case PieceRoll.rollField:") else {
            return XCTFail("ANCHOR MISSING: the studio's roll arm")
        }
        let tail = studio[arm.upperBound...].prefix(400)
        XCTAssertTrue(tail.contains("recomposeIfRunning()"), "the studio composes once on a roll")
        let rows = try code("Sources/Echoelmusic/Studio/TrackComposeRows.swift")
        XCTAssertTrue(rows.contains("PieceRoll.setLocked(laneID, locked: $0, timeline: timeline)"),
                      "the Device page's lock writes through the one writer")
        XCTAssertFalse(rows.contains("setLaneRollLocked("), "the rows never write the store directly")
        let roll = try code("Sources/Echoelmusic/Studio/PieceRoll.swift")
        for forbidden in ["addLane(", "setLaneGenreOverride(", "setLaneMood(", "ensureComposerRegion("] {
            XCTAssertFalse(roll.contains(forbidden), "a roll makes no track and turns no composer on (`\(forbidden)`)")
        }
        XCTAssertTrue(roll.contains("TrackCompose.setVariation(laneID, seed: seed(), timeline: timeline)"),
                      "the seed goes through New variation's own writer (#416)")
        for modal in [".sheet(", ".fullScreenCover(", ".popover(", ".confirmationDialog("] {
            XCTAssertFalse(roll.contains(modal), "no modal")
        }
        guard let lock = rows.range(of: "Text(\"Keep on Roll\")") else {
            return XCTFail("ANCHOR MISSING: the Keep on Roll toggle")
        }
        XCTAssertTrue(rows[lock.upperBound...].prefix(300).contains(".tint(EchoelTheme.text)"),
                      "the lock is tinted with the text colour — the accent is the body's signal only")
    }

    // MARK: helpers

    private func code(_ relativePath: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 where !FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
            dir = dir.deletingLastPathComponent()
        }
        let url = dir.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relativePath) not on disk — this run has no source tree")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }
}
