// APartPlaysFromItsBarTests.swift
// Echoel — Phase 3 / Creation Workflow, MIDI editor slice M10: Play from the selected part.
//
// WHAT IT PINS. The loop OPEN → EDIT → PLAY ended at the Workstation's Play, below every track row
// and far from the note grid, and that Play always starts the song from the top. A part in bar 9
// meant eight bars of waiting after every edit. Since M10 the selected part's bar carries
// "Play from here" (`PartPlayButton` in `SelectedPartBar`), one tap above its notes. It starts
// nothing of its own: it calls the Workstation's one start (`startTimeline`, the one
// `player.play(` caller) with the part's start tick, and it is dimmed by the Workstation's one
// `canPlay` question (`songCanStart`). While the song plays it is the player's own Stop.
//
// 1. END-TO-END BEHAVIOUR over a real `TimelineRegionPlayer`, `ClipStore`, `PatternEngine` and
//    `PianoRollModel`: a song with a part in bar 1 (pitch 60) and a part in bar 3 (pitch 64) on
//    the same track. Started from the second part's start tick, the transport stands on bar 3 and
//    the roll holds that part's first bar; started from 0 it holds the first part.
// 2. SOURCE: the button hands the part's start tick to the handed-in start and never calls the
//    player's `play`; the Workstation's mount hands in `startTimeline` and `songCanStart`, and the
//    Workstation asks the engine's `canPlay` exactly once, so the two Plays cannot disagree.
//
// Grading (§0, no Swift toolchain in a web session): `play(fromTick:)`'s bar floor and the roll's
// first load were transcribed and driven on the rig below. Claim 1 is a COUNTERWEIGHT — green on
// the parent (`play(fromTick:)` has floored to the bar since CLIP-5); it pins the premise that the
// tick the button hands over is heard from the part. On the parent (the M7 review repair) the
// file COMPILES — it names no new symbol outside strings — and claim 2 is red there by ANCHOR
// ABSENCE (one absence, #486).
// NOT covered: that it is seen, reached and heard on a device; a restart while the instrument's
// own loop is running mid-bar (M7 review LOW-3 — the button offers Stop while the song plays, so
// it adds no new way into that case).
// NEEDS-FOUNDER-VERIFY: Workstation → a song with a part in a later bar → tap that part → "Play
// from here" above its notes → the song starts at that part's bar, the button turns to Stop, and
// Stop stops it; a song with nothing to play shows the button dimmed.

import Foundation
import XCTest
@testable import Echoelmusic

#if canImport(SwiftUI)
@MainActor
final class APartPlaysFromItsBarTests: XCTestCase {

    private static let barPath = "Sources/Echoelmusic/Studio/SelectedPartBar.swift"
    private static let workstationPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let bar = TimelineTime.ticksPerBar

    private var rigClips: ClipStore?
    private var rigPlayer: TimelineRegionPlayer?
    private var rigPattern: PatternEngine?

    /// One MIDI track: a one-bar part in bar 1 (pitch 60) and a one-bar part in bar 3 (pitch 64).
    private func makeSong() -> (TimelineDocument, ClipStore, later: TimelineRegion) {
        let clips = ClipStore()
        for i in clips.slots.indices { clips.clear(at: i) }
        let first = Clip(name: "Intro", melody: MelodyClip(notes: [Note(pitch: 60, startStep: 0, lengthSteps: 4)]))
        let second = Clip(name: "Hook", melody: MelodyClip(notes: [Note(pitch: 64, startStep: 0, lengthSteps: 4)]))
        clips.setClip(at: 0, first)
        clips.setClip(at: 1, second)
        let lane = TimelineLane(name: "Keys", kind: .midi)
        let later = TimelineRegion(laneID: lane.id, clipID: second.id, startTick: 2 * Self.bar,
                                   lengthTicks: Self.bar)
        let document = TimelineDocument(lanes: [lane], regions: [
            TimelineRegion(laneID: lane.id, clipID: first.id, startTick: 0, lengthTicks: Self.bar),
            later,
        ])
        rigClips = clips
        return (document, clips, later)
    }

    private func start(_ document: TimelineDocument, _ clips: ClipStore, fromTick: Int) -> (TimelineRegionPlayer, PianoRollModel) {
        let player = TimelineRegionPlayer()
        let pattern = PatternEngine()
        let roll = PianoRollModel()
        rigPlayer = player
        rigPattern = pattern
        player.play(document: document, clips: clips, pattern: pattern, pianoRoll: roll, fromTick: fromTick)
        return (player, roll)
    }

    /// `async` so it runs on the class's main actor (`TheMIDITakeIsRecordedFromTheWorkstationTests`).
    override func tearDown() async throws {
        rigPlayer?.stop()
        rigPattern?.stop()
        if let clips = rigClips { for i in clips.slots.indices { clips.clear(at: i) } }
        rigClips = nil
        rigPlayer = nil
        rigPattern = nil
    }

    // MARK: 1 — END-TO-END

    func testThePartsStartTickIsHeardFromThePart() {
        let (document, clips, later) = makeSong()
        let (player, roll) = start(document, clips, fromTick: later.startTick)
        XCTAssertTrue(player.isPlaying, "ANCHOR MISSING: the song did not start — the rig says nothing")
        XCTAssertEqual(player.currentTick, 2 * Self.bar, "the transport stands on the part's bar")
        XCTAssertEqual(roll.notes.map(\.pitch), [64], """
            started from the part's start tick, the roll holds that part's first bar — the tick the \
            part bar hands over is the one the song is heard from
            """)
    }

    func testTheTopStillStartsWithTheFirstPart() {
        let (document, clips, _) = makeSong()
        let (player, roll) = start(document, clips, fromTick: 0)
        XCTAssertEqual(player.currentTick, 0)
        XCTAssertEqual(roll.notes.map(\.pitch), [60], "counterweight: from the top the first part plays")
    }

    // MARK: 2 — SOURCE

    func testThePartBarStartsTheSongThroughTheWorkstationsOneStart() throws {
        let partBar = try source(Self.barPath)
        XCTAssertTrue(partBar.contains("PartPlayButton(startTick: part.startTick, playFrom: playFrom,"),
                      "the button is handed the selected part's start tick")
        let button = try body(of: "private struct PartPlayButton: View {", in: partBar)
        XCTAssertTrue(button.contains("if playing { player.stop() } else { playFrom(startTick) }"),
                      "Play hands the tick to the Workstation's start; while playing it is the player's own Stop")
        XCTAssertTrue(button.contains("let startable = playing || songCanStart()"))
        XCTAssertTrue(button.contains(".disabled(!startable)"),
                      "dimmed by the same answer as the Workstation's Play — a lit button does something")
        XCTAssertFalse(partBar.contains("player.play("), "the part bar never starts the player itself")
        XCTAssertFalse(partBar.contains("canPlay("), "only the Workstation asks the engine")

        let workstation = try source(Self.workstationPath)
        XCTAssertTrue(workstation.contains("SelectedPartBar(playFrom: { startTimeline(fromTick: $0, launching: []) },"),
                      "the mount hands in the Workstation's one start")
        XCTAssertTrue(workstation.contains("songCanStart: { songCanStart() })"))
        XCTAssertTrue(workstation.contains("let startable = songCanStart()"),
                      "the Workstation's own Play asks the same function")
        XCTAssertEqual(workstation.components(separatedBy: "TimelineRegionPlayer.canPlay(").count - 1, 1,
                       "one canPlay call in the Workstation — two Plays, one answer")
    }

    // MARK: helpers

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }

    private struct AnchorMissing: Error { let name: String }

    /// The brace-matched body after `anchor` — never a fixed window (#408).
    private func body(of anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else {
            XCTFail("ANCHOR MISSING: \(anchor) (#454)")
            throw AnchorMissing(name: anchor)
        }
        guard let open = code[code.index(before: start.upperBound)...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: no body after \(anchor) (#454)")
            throw AnchorMissing(name: anchor)
        }
        var depth = 0
        var index = open
        while index < code.endIndex {
            switch code[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(code[code.index(after: open)..<index]) }
            default: break
            }
            index = code.index(after: index)
        }
        XCTFail("ANCHOR MISSING: unbalanced body after \(anchor) (#454)")
        throw AnchorMissing(name: anchor)
    }
}
#endif
