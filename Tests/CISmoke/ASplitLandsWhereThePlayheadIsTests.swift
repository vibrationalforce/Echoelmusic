// ASplitLandsWhereThePlayheadIsTests.swift
// Echoel — GMMW AE-9 (founder 2026-10-08: "Die klassische DAW Audio Editing View fehlt mir noch.
// Orientiere dich an den Bigplayern"). Every DAW cuts a part where the playhead is; the part bar
// had one Split, and it cut where IT computed (the part's middle). AE-7 gave the piece a
// playhead you can put down (the ruler's line); AE-9 cuts there.
//
// WHAT THIS PINS.
// 1. END-TO-END (`PartSplit.playheadCut`, pure): the cut is the transport step the playhead is
//    on, floored — never a free tick — and only strictly inside the part: nil on either edge,
//    before it, after it, and for a negative tick.
// 2. END-TO-END (pure): `PartSplit.hasLineInside(_:every:)` is true EXACTLY when some playhead
//    on that grid gives a cut — driven by brute force over every tick (the transport step:
//    playing) and every bar line (the ruler's line: stopped) around seven parts. So the label
//    never sends a stopped player to the ruler for a part no bar line falls inside (review MED-1).
// 3. END-TO-END on the real owners (`TimelineRegionPlayer`, `TimelineStore`), through the ONE
//    composition the button and its tap both ask (`PartSplit.playheadTick`, review MED-4):
//    stopped, the ruler's line names the cut — `locate` bar 4 on a part over bars 2–5 cuts it
//    there through the store's split, ONE undo step; the line on the part's own start names no
//    cut, and past the loop end the line folds the way `play` folds it. Playing, the position is
//    the step sounding now.
// 4. SOURCE: the leaf reads `currentTick` only inside its own `TimelineView` (paused while
//    stopped — the `ArrangePlayheadView` pattern, review MED-2: the lit state is the tap's own
//    answer); body and tap ask `playheadTick` and `keepsWhoPlays`; the cut goes through the
//    bar's own `split` (media tempo, one undo step); every layout shows the button once, and the
//    narrowest puts it with the move pair (review MED-3: seven icons do not fit 375 pt).
//
// Grading (§0/§3, no Swift toolchain). First commit `13d8200` (parent `f2c8b5e`): `playheadCut`
// and `PartSplitAtPlayhead` did not exist there — every claim a FORWARD guard, one absence (#486).
// Review repair (parent `4ca57dd`): `hasLineInside` and `playheadTick` do not exist there, so the
// file does not compile against it — again one absence, no verdict there; claims 2–4 are the
// review's findings made checkable. Claims 1–3 transcribed into Python on the cases below;
// claim 4's scans against both trees (the counterweights — the first Split's handler and its
// `keepsWhoPlays` gate — are green on both).
// NOT covered: that the lit state keeps up with the ear (it follows the transport at 8 Hz), that
// the narrow layout fits at every type size, and that a cut while playing is clean — a split is a
// structure edit, and the player's catch-up re-primes the audio tracks (a re-attack of held notes
// and audio can be heard). Device probes, registered below.
// NEEDS-FOUNDER-VERIFY: select a part, tap bar 3 on the ruler, tap "At playhead" → the part is cut
// at bar 3 (one Undo joins it back). Then Play: "At playhead" lights only while the playhead is
// inside the selected part; tap it → the part is cut at the step you heard. Listen across the
// cut on an audio part and on a MIDI part. On a small phone (SE), the part bar's buttons fit.

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
        XCTAssertNil(PartSplit.playheadCut(for: p, atTick: -3 * Self.bar), "a negative tick cuts nothing")
        let top = part(0, 2 * Self.bar)
        XCTAssertNil(PartSplit.playheadCut(for: top, atTick: -1), "a negative tick cuts nothing, even at the top")
        XCTAssertEqual(PartSplit.playheadCut(for: top, atTick: Self.step), Self.step, "one step in is a cut")
    }

    // MARK: 2 — the label never promises a cut that cannot exist (pure)

    func testALineInsideExistsExactlyWhenSomePlayheadCuts() {
        let parts: [TrackParts.Part] = [part(0, 4 * Self.bar), part(Self.bar + 50, 3 * Self.step),
                                        part(Self.step, Self.step), part(Self.step, 2 * Self.step),
                                        part(Self.step + 1, Self.step), part(7, 1), part(Self.bar, Self.bar)]
        for p in parts {
            // Playing: any tick (the transport hands step ticks, the cut floors anything else).
            var anyCut = false
            for tick in Swift.max(0, p.startTick - 2 * Self.step)...(p.startTick + p.lengthTicks + 2 * Self.step) {
                if let cut = PartSplit.playheadCut(for: p, atTick: tick) {
                    anyCut = true
                    XCTAssertEqual(cut % Self.step, 0, "every cut is on a transport step")
                    XCTAssertTrue(cut > p.startTick && cut < p.startTick + p.lengthTicks, "every cut is inside the part")
                }
            }
            XCTAssertEqual(PartSplit.hasLineInside(p, every: Self.step), anyCut,
                           "part at \(p.startTick) for \(p.lengthTicks): playing, some step cuts it iff a step line is inside")
            // Stopped: the ruler's line is always on a bar.
            var anyBarCut = false
            for bar in 0...((p.startTick + p.lengthTicks) / Self.bar + 1) {
                if PartSplit.playheadCut(for: p, atTick: bar * Self.bar) != nil { anyBarCut = true }
            }
            XCTAssertEqual(PartSplit.hasLineInside(p, every: Self.bar), anyBarCut,
                           "part at \(p.startTick) for \(p.lengthTicks): stopped, the ruler can cut it iff a bar line is inside")
        }
        XCTAssertFalse(PartSplit.hasLineInside(part(Self.step, Self.step), every: Self.step), "one step long: no step strictly inside")
        XCTAssertTrue(PartSplit.hasLineInside(part(Self.step, 2 * Self.step), every: Self.step), "two steps long: its middle step")
        XCTAssertFalse(PartSplit.hasLineInside(part(Self.bar, Self.bar), every: Self.bar), """
            a one-bar part on a bar line has no bar line strictly inside it — the ruler can never \
            cut it, so the stopped label must not send the player there (review MED-1)
            """)
        XCTAssertTrue(PartSplit.hasLineInside(part(Self.bar, Self.bar), every: Self.step),
                      "…while a playing cut can still reach it")
        XCTAssertFalse(PartSplit.hasLineInside(part(Self.bar, 2 * Self.bar), every: 0), "no grid, no line")
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

        // The composition the button's lit state and its tap both ask — `playheadTick`, not a copy.
        func cutFromTheLine() -> Int? {
            let document = timeline.document
            guard let p = TrackParts.parts(onLane: lane.id, in: document).first(where: { $0.id == region.id }) else {
                return nil
            }
            let head = PartSplit.playheadTick(playing: false, currentTick: 999_999,
                                              cueTick: player.cueTick, in: document)
            return PartSplit.playheadCut(for: p, atTick: head)
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
            so this fails if `playheadTick` stops asking the fold; that the button and its tap ask \
            `playheadTick` is claim 4's scan
            """)
        XCTAssertEqual(PartSplit.playheadTick(playing: true, currentTick: 3 * Self.bar + Self.step,
                                              cueTick: player.cueTick, in: timeline.document),
                       3 * Self.bar + Self.step, "playing, the playhead is the step sounding now — the line does not matter")
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

    // MARK: 4 — one path, no position outside the leaf's own clock (source)

    func testTheLeafReadsThePositionOnlyOnItsOwnClock() throws {
        let bar = try source(Self.barPath)
        guard let leaf = bracedBody(after: "private struct PartSplitAtPlayhead<Content: View>: View {", in: bar),
              let body = bracedBody(after: "var body: some View {", in: leaf),
              let tap = bracedBody(after: "private func splitAtPlayhead() {", in: leaf),
              let label = bracedBody(after: "private func label(playing: Bool, cut: Int?, enabled: Bool) -> String {", in: leaf) else {
            return XCTFail("ANCHOR MISSING: `PartSplitAtPlayhead`, its body, its tap or its label (#454)")
        }
        let clock = "TimelineView(.animation(minimumInterval: Self.playingRefresh, paused: !playing)) { _ in"
        guard let clockAt = body.range(of: clock), let readAt = body.range(of: "player.currentTick"),
              let playingAt = body.range(of: "let playing = player.isPlaying") else {
            return XCTFail("ANCHOR MISSING: the leaf's clock, its position read or its playing read (#454)")
        }
        XCTAssertLessThan(clockAt.upperBound, readAt.lowerBound, """
            `currentTick` is read OUTSIDE the leaf's own `TimelineView` — it is `@ObservationIgnored` \
            (a body read goes stale) and only a self-driving leaf may follow it (10.76.41/50)
            """)
        XCTAssertLessThan(playingAt.lowerBound, clockAt.lowerBound, "the clock is paused by the cold `isPlaying` read above it")
        XCTAssertEqual(body.components(separatedBy: "player.currentTick").count - 1, 1, "ONE position read in the body")
        XCTAssertEqual(leaf.components(separatedBy: "player.currentTick").count - 1, 2, "…and one in the tap — nowhere else")
        let ask = "PartSplit.playheadTick(playing: "
        XCTAssertTrue(body.contains(ask), "the lit state asks the ONE composition")
        XCTAssertTrue(tap.contains(ask), "…and so does the cut")
        XCTAssertTrue(bar.contains("playing ? currentTick : TimelineRegionPlayer.playStartTick(forCue: cueTick, in: document)"),
                      "stopped, the playhead is the ruler's line through the ONE fold (AE-7)")
        XCTAssertTrue(body.contains("cut.map { PartSplit.keepsWhoPlays(regionID: regionID, atTick: $0, in: document) }"),
                      "a cut that would change who plays is not lit")
        XCTAssertTrue(tap.contains("PartSplit.keepsWhoPlays(regionID: regionID, atTick: cut, in: document)"),
                      "the tap asks again, against the document as it is then")
        XCTAssertTrue(label.contains("let unit = playing ? TimelineTime.ticksPerTransportStep : TimelineTime.ticksPerBar"),
                      "stopped, the label asks for a BAR line — the ruler's line is always on a bar (review MED-1)")
        XCTAssertTrue(label.contains("guard PartSplit.hasLineInside(part, every: unit) else {"))
        XCTAssertTrue(tap.contains("split(regionID, cut)"), "the cut goes through the bar's own Split handler")
        XCTAssertFalse(leaf.contains("timeline.splitRegion("), "never a second write path — the bar's `split` writes")
        for banned in ["DragGesture", "player.play(", "player.stop("] {
            XCTAssertFalse(leaf.contains(banned), "the leaf holds `\(banned)` — it reads the player and cuts on a tap")
        }

        // Every layout shows the button exactly once; the narrowest puts it with the move pair.
        guard let helper = bracedBody(after: "private func playheadSplit(_ part: TrackParts.Part, regionID: UUID, showsTitles: Bool) -> some View {", in: bar),
              let editHead = bar.range(of: "private func editRow("),
              let edit = bracedBody(after: "-> some View {", in: String(bar[editHead.lowerBound...])),
              let actionHead = bar.range(of: "private func actionRow("),
              let action = bracedBody(after: "-> some View {", in: String(bar[actionHead.lowerBound...])),
              let barBody = bracedBody(after: "var body: some View {", in: bar) else {
            return XCTFail("ANCHOR MISSING: `playheadSplit`, `editRow`, `actionRow` or the bar's body (#454)")
        }
        XCTAssertEqual(bar.components(separatedBy: "PartSplitAtPlayhead(").count - 1, 1, "built in one place")
        XCTAssertTrue(helper.contains("split: { split($0, at: $1) }) { enabled, label, action in"),
                      "the leaf is handed the bar's own Split handler")
        XCTAssertTrue(helper.contains("button(\"At playhead\", \"scissors.circle\", enabled: enabled, showsTitle: showsTitles,"),
                      "it wears the bar's own button, title and spoken label")
        XCTAssertTrue(edit.contains("if withPlayheadSplit {\n                playheadSplit(part, regionID: regionID, showsTitles: showsTitles)"),
                      "the edit row shows it beside Split when asked")
        XCTAssertTrue(action.contains("trims: trims, showsTitles: showsTitles, withPlayheadSplit: true)"),
                      "the one-row layouts ask the edit row for it")
        XCTAssertEqual(barBody.components(separatedBy: "playheadSplit(part, regionID: regionID, showsTitles: false)").count - 1, 1,
                       "the narrowest layout shows it once, with the move pair")
        XCTAssertEqual(barBody.components(separatedBy: "withPlayheadSplit: false)").count - 1, 1,
                       "…and asks its edit row NOT to show it a second time")
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
