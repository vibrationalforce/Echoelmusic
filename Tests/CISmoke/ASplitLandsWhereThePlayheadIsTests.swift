// ASplitLandsWhereThePlayheadIsTests.swift
// Echoel — GMMW AE-9 (founder 2026-10-08: "Die klassische DAW Audio Editing View fehlt mir noch.
// Orientiere dich an den Bigplayern"). Every DAW cuts a part where the playhead is; the part bar
// had one Split, and it cut where IT computed (the part's middle). AE-7 gave the piece a
// playhead you can put down (the ruler's line); AE-9 cuts there.
//
// WHAT THIS PINS.
// 1. END-TO-END (`PartSplit.playheadCut`, pure): the cut is the transport step the playhead is
//    on, floored — never a free tick — and only strictly inside the part: nil on either edge,
//    before it, after it; a negative tick floors to the top.
// 2. END-TO-END (pure): `PartSplit.hasStepInside` is true EXACTLY when some playhead gives a cut —
//    driven by brute force over every tick around six parts (on grid, off grid, one step, two
//    steps, one tick), so the lit button while playing never promises a cut that cannot exist.
// 3. END-TO-END on the real owners (`TimelineRegionPlayer`, `TimelineStore`): stopped, the ruler's
//    line names the cut — `locate` bar 3 on a part over bars 2–5 cuts it at bar 3 through the
//    store's split, ONE undo step; a line on the part's own start, or past the piece's loop end
//    (the fold `play` uses), names no cut.
// 4. SOURCE: the leaf's body reads no position (`currentTick` only inside the tap); stopped and
//    tap both ask the ONE fold (AE-7) and `keepsWhoPlays`; the cut goes through the bar's own
//    `split` (media tempo, one undo step); the bar mounts the leaf once per edit row.
//
// Grading (§0/§3, no Swift toolchain, parent `558abd9`): `playheadCut`, `hasStepInside` and
// `PartSplitAtPlayhead` do not exist there, so this file does not compile against the parent —
// every claim is a FORWARD guard, one absence (#486), no assertion has a verdict there. Claims 1–3
// were transcribed into Python and driven on the cases below against this tree; claim 4's scans
// were transcribed against both trees (the counterweights — the first Split's handler and its
// `keepsWhoPlays` gate — are green on both).
// NOT covered: that the tap lands while the step the ear heard is still sounding (a ~120-ms step at
// 120 BPM) and that the cut is inaudible on a device — a device probe, registered below.
// NEEDS-FOUNDER-VERIFY: select a part, tap bar 3 on the ruler, tap "At playhead" → the part is cut
// at bar 3 (one Undo joins it back). Then Play, tap "At playhead" while the part sounds → it is cut
// at the step you heard, and the sound runs on across the cut with no jump.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ASplitLandsWhereThePlayheadIsTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let step = TimelineTime.ticksPerTransportStep
    private static let barPath = "Sources/Echoelmusic/Studio/SelectedPartBar.swift"

    private func part(_ start: Int, _ length: Int) -> TrackParts.Part {
        TrackParts.Part(id: UUID(), startTick: start, lengthTicks: length)
    }

    // MARK: 1 — where the cut falls (pure)

    func testTheCutIsTheStepThePlayheadIsOn() {
        let p = part(Self.bar, 4 * Self.bar)          // bars 2–5
        XCTAssertEqual(PartSplit.playheadCut(for: p, atTick: 3 * Self.bar), 3 * Self.bar,
                       "a playhead on a bar line cuts on that line")
        XCTAssertEqual(PartSplit.playheadCut(for: p, atTick: 3 * Self.bar + Self.step + 7),
                       3 * Self.bar + Self.step, "a playhead between steps cuts on the step it is on — floored")
        XCTAssertNil(PartSplit.playheadCut(for: p, atTick: Self.bar), "the part's own start cuts nothing")
        XCTAssertNil(PartSplit.playheadCut(for: p, atTick: Self.bar + 50),
                     "floored onto the start — still nothing")
        XCTAssertNil(PartSplit.playheadCut(for: p, atTick: 5 * Self.bar), "the part's own end cuts nothing")
        XCTAssertNil(PartSplit.playheadCut(for: p, atTick: 0), "before the part")
        XCTAssertNil(PartSplit.playheadCut(for: p, atTick: 9 * Self.bar), "after the part")
        XCTAssertNil(PartSplit.playheadCut(for: p, atTick: -3 * Self.bar), "a negative tick floors to the top")
        let top = part(0, 2 * Self.bar)
        XCTAssertNil(PartSplit.playheadCut(for: top, atTick: -1), "…which is the part's own start here")
        XCTAssertEqual(PartSplit.playheadCut(for: top, atTick: Self.step), Self.step, "one step in is a cut")
    }

    // MARK: 2 — the lit button never promises a cut that cannot exist (pure)

    func testAStepInsideExistsExactlyWhenSomePlayheadCuts() {
        let parts: [TrackParts.Part] = [part(0, 4 * Self.bar), part(Self.bar + 50, 3 * Self.step),
                                        part(Self.step, Self.step), part(Self.step, 2 * Self.step),
                                        part(Self.step + 1, Self.step), part(7, 1)]
        for p in parts {
            var anyCut = false
            for tick in Swift.max(0, p.startTick - 2 * Self.step)...(p.startTick + p.lengthTicks + 2 * Self.step) {
                if let cut = PartSplit.playheadCut(for: p, atTick: tick) {
                    anyCut = true
                    XCTAssertEqual(cut % Self.step, 0, "every cut is on a transport step")
                    XCTAssertTrue(cut > p.startTick && cut < p.startTick + p.lengthTicks, "every cut is inside the part")
                }
            }
            XCTAssertEqual(PartSplit.hasStepInside(p), anyCut,
                           "part at \(p.startTick) for \(p.lengthTicks): lit while playing iff some playhead cuts it")
        }
        XCTAssertFalse(PartSplit.hasStepInside(part(Self.step, Self.step)), "one step long: no step strictly inside")
        XCTAssertTrue(PartSplit.hasStepInside(part(Self.step, 2 * Self.step)), "two steps long: its middle step")
        XCTAssertTrue(PartSplit.hasStepInside(part(Self.step + 1, Self.step)),
                      "off grid, one step long: a grid step falls inside it")
    }

    // MARK: 3 — stopped, the ruler's line is where the part is cut (real owners)

    func testTheRulersLineCutsThePartThroughOneUndoStep() throws {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }
        let lane = TimelineLane(name: "Keys", kind: .midi)
        let region = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: Self.bar, lengthTicks: 4 * Self.bar)
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: [region]))
        let player = TimelineRegionPlayer()

        func cutFromTheLine() -> Int? {
            let document = timeline.document
            guard let p = TrackParts.parts(onLane: lane.id, in: document).first(where: { $0.id == region.id }) else {
                return nil
            }
            return PartSplit.playheadCut(for: p, atTick: TimelineRegionPlayer.playStartTick(forCue: player.cueTick,
                                                                                           in: document))
        }

        XCTAssertNil(cutFromTheLine(), "the line at the top is before the part")
        player.locate(toTick: Self.bar)
        XCTAssertNil(cutFromTheLine(), "the line on the part's own start cuts nothing")
        player.locate(toTick: 7 * Self.bar)
        XCTAssertEqual(TimelineRegionPlayer.playStartTick(forCue: player.cueTick, in: timeline.document), 2 * Self.bar,
                       "ANCHOR: the fold puts bar 8 of a five-bar piece on bar 3's line")
        XCTAssertEqual(cutFromTheLine(), 2 * Self.bar, """
            past the loop end the line is drawn where `play` folds it (bar 8 of a five-bar piece is \
            bar 3), and the cut lands THERE — the raw cue is past the part and would cut nothing, \
            so this fails if the cut stops asking the fold
            """)
        player.locate(toTick: 3 * Self.bar + 999)
        let cut = try XCTUnwrap(cutFromTheLine(), "the line on bar 4 is inside the part")
        XCTAssertEqual(cut, 3 * Self.bar, "the cut is the bar the line is drawn on")
        XCTAssertTrue(PartSplit.keepsWhoPlays(regionID: region.id, atTick: cut, in: timeline.document),
                      "ANCHOR: a lone part keeps who plays")

        timeline.splitRegion(id: region.id, atTick: cut, bpm: 120)
        let starts = timeline.document.regions.map(\.startTick).sorted()
        XCTAssertEqual(starts, [Self.bar, 3 * Self.bar], "two parts, the second starting on the line")
        timeline.undo()
        XCTAssertEqual(timeline.document.regions.count, 1, "ONE undo step joins it back")
        XCTAssertEqual(timeline.document.regions.first?.lengthTicks, 4 * Self.bar)
    }

    // MARK: 4 — one path, no position in a body (source)

    func testTheLeafReadsThePositionOnlyInsideTheTap() throws {
        let bar = try source(Self.barPath)
        guard let leaf = bracedBody(after: "private struct PartSplitAtPlayhead<Content: View>: View {", in: bar),
              let body = bracedBody(after: "var body: some View {", in: leaf),
              let tap = bracedBody(after: "private func splitAtPlayhead() {", in: leaf) else {
            return XCTFail("ANCHOR MISSING: `PartSplitAtPlayhead`, its body or its tap (#454)")
        }
        XCTAssertFalse(body.contains("currentTick"), """
            the leaf's body reads `currentTick` — it is `@ObservationIgnored` (a body read goes stale) \
            and a position read in a body is the freeze law's churn (10.76.41/50)
            """)
        XCTAssertEqual(leaf.components(separatedBy: "currentTick").count - 1, 1, "ONE position read")
        XCTAssertTrue(tap.contains("? player.currentTick"), "…and it is inside the tap, for a playing piece")
        let fold = "TimelineRegionPlayer.playStartTick(forCue: player.cueTick, in: document)"
        XCTAssertTrue(body.contains(fold), "stopped, the lit state asks the ONE fold the ruler's line is drawn by")
        XCTAssertTrue(tap.contains(fold), "…and so does the cut")
        XCTAssertTrue(body.contains("PartSplit.keepsWhoPlays(regionID: regionID, atTick: $0, in: document)"),
                      "stopped, a cut that would change who plays is not lit")
        XCTAssertTrue(body.contains("? PartSplit.hasStepInside(part)"), "playing, lit only when some cut can exist")
        XCTAssertTrue(tap.contains("PartSplit.keepsWhoPlays(regionID: regionID, atTick: cut, in: document)"),
                      "the tap asks again, against the document as it is then")
        XCTAssertTrue(tap.contains("split(regionID, cut)"), "the cut goes through the bar's own Split handler")
        XCTAssertFalse(leaf.contains("timeline.splitRegion("), "never a second write path — the bar's `split` writes")
        for banned in ["@State", "DragGesture", "TimelineView(", "player.play(", "player.stop("] {
            XCTAssertFalse(leaf.contains(banned), "the leaf holds `\(banned)` — it reads cold state and cuts on a tap")
        }

        // `actionRow` ends its signature the same way, so the edit row is found by its NAME first (#408).
        guard let editHead = bar.range(of: "private func editRow("),
              let edit = bracedBody(after: "-> some View {", in: String(bar[editHead.lowerBound...])) else {
            return XCTFail("ANCHOR MISSING: the bar's edit row (#454)")
        }
        XCTAssertEqual(edit.components(separatedBy: "PartSplitAtPlayhead(").count - 1, 1, "one second Split per edit row")
        XCTAssertTrue(edit.contains("split: { split($0, at: $1) }) { enabled, label, action in"),
                      "the leaf is handed the bar's own Split handler")
        XCTAssertTrue(edit.contains("button(\"At playhead\", \"scissors.circle\", enabled: enabled, showsTitle: showsTitles,"),
                      "it wears the bar's own button, title and spoken label")
        XCTAssertEqual(bar.components(separatedBy: "PartSplitAtPlayhead(").count - 1, 1, "and is built nowhere else")
        // Counterweights (#343): the first Split keeps its own cut, gate and handler.
        XCTAssertTrue(edit.contains("if splittable, let cut { split(regionID, at: cut) }"))
        XCTAssertTrue(bar.contains("timeline.splitRegion(id: regionID, atTick: tick, bpm: bpm)"),
                      "the ONE split write: media tempo, one undo step")
    }

    // MARK: helpers

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            throw XCTSkip("source tree not present")
        }
        return SourceText.codeOnly(text)
    }

    /// The text between `head` (which ends in `{`) and its matching `}`.
    private func bracedBody(after head: String, in text: String) -> String? {
        guard head.hasSuffix("{"), let start = text.range(of: head) else { return nil }
        var depth = 1
        var index = start.upperBound
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(text[start.upperBound..<index]) }
            default: break
            }
            index = text.index(after: index)
        }
        return nil
    }
}
