// TheHeadCountsThePieceInBarsBeatsAndSixteenthsTests.swift
// Echoel — Workstation redesign A4 (founder 2026-10-01, the tablet mockup's display): the head says
// WHERE the piece is as a transport counter — BAR.BEAT.16th · BPM · 4/4 — beside the key.
//
// WHAT THIS PINS.
// 1. BEHAVIOUR (pure, `WorkstationSummary.counterText`): bar · beat · sixteenth, one-based, from the
//    one bar-number rule; the last tick of each unit still reads that unit; a negative tick folds
//    to the top.
// 2. ONE RULE, TWO SPELLINGS (#416, counterweight): for every tick the counter's bar and beat are the
//    bar and beat `positionText` speaks — the head and the plate's readout cannot disagree.
// 3. THE METRE (`WorkstationSummary.meterText`) is read from `TimelineTime.beatsPerBar`, and its
//    denominator 4 is true only while the timeline's beat IS the quarter — that premise is pinned.
// 4. SOURCE: the counter is its own self-driving leaf in the head (`ProjectPositionReadout`): a
//    15 Hz `TimelineView` paused while stopped, the ONLY `currentTick` in `ProjectHeader.swift`,
//    read inside the clock's closure; it shows and speaks the position and does nothing else.
// 5. SOURCE: the head's summary mounts it ONCE, in the display order position · tempo · metre ·
//    place, and the metre speaks a label.
// 6. COUNTERWEIGHT: the KEY of the display is `CompositionHeaderStrip`'s Key picker — the Project
//    plate's Song section since DAW shell S1a — and the head keeps no second copy of it.
//
// Grading (§3; no Swift toolchain here, §0). Parent c83128651: `counterText`, `meterText` and
// `ProjectPositionReadout` do not exist there, so this file DOES NOT COMPILE against the parent — no
// assertion has a verdict there (one absence, #486). Claims 1, 2, 4 and 5 are FORWARD guards. Claim 3
// holds ONE forward assertion (`meterText`) and two PREMISE counterweights that are true on both
// trees. Claim 6 is a COUNTERWEIGHT, true on both trees. Claims 1–3 were transcribed into Python and driven on the cases
// below plus every 7th tick from −200 over three bars (counter and spoken position agree: all).
// Claims 4–6 were transcribed against the slice's tree with `SourceText.codeOnly` semantics: green;
// then mutation-driven, each red for its named reason only — the read hoisted above the clock
// (claim 4, inside-the-clock), the width template removed (claim 4, width), a `currentTick` read in the header's body (claim 4, one-read and
// not-in-body), the leaf mounted after the tempo (claim 5, order), a second mount (claim 5, once),
// the key's `@AppStorage` copied into the head (claim 6).
// NOT covered: that the number keeps up with the sound on glass, how the head re-flows on a narrow
// phone with the counter in it, and how VoiceOver paces the combined summary — device probes.
// NEEDS-FOUNDER-VERIFY: Piece stage → Play: the head counts "1.1.1, 1.1.2 …" beside "120 BPM 4/4", Stop turns it back to a dim "1.1.1", and the head keeps its shape when Play is tapped and at bar 10.
// The top bar's loop counter shows the same b.b.s form for the instrument loop — say whether two such counters on one screen read as two different things.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheHeadCountsThePieceInBarsBeatsAndSixteenthsTests: XCTestCase {

    private static let header = "Sources/Echoelmusic/Studio/ProjectHeader.swift"
    private static let workspace = "Sources/Echoelmusic/Studio/WorkspaceView.swift"
    private static let leafHead = "private struct ProjectPositionReadout: View {"

    // MARK: 1 — the counter, pure

    func testTheCounterNamesBarBeatAndSixteenth() {
        let bar = TimelineTime.ticksPerBar
        let beat = TimelineTime.ticksPerBeat
        let step = TimelineTime.ticksPerTransportStep
        XCTAssertEqual(WorkstationSummary.counterText(forTick: 0), "1.1.1")
        XCTAssertEqual(WorkstationSummary.counterText(forTick: step - 1), "1.1.1",
                       "the last tick of a sixteenth still reads that sixteenth")
        XCTAssertEqual(WorkstationSummary.counterText(forTick: step), "1.1.2")
        XCTAssertEqual(WorkstationSummary.counterText(forTick: beat), "1.2.1")
        XCTAssertEqual(WorkstationSummary.counterText(forTick: bar - 1), "1.4.4",
                       "the last tick of a bar is its fourth beat's fourth sixteenth")
        XCTAssertEqual(WorkstationSummary.counterText(forTick: bar), "2.1.1")
        XCTAssertEqual(WorkstationSummary.counterText(forTick: 11 * bar + 2 * beat + step), "12.3.2")
        XCTAssertEqual(WorkstationSummary.counterText(forTick: -5), "1.1.1",
                       "a negative tick folds to the top, as the bar-number rule does")
    }

    // MARK: 2 — one rule, two spellings

    func testTheCounterAndTheSpokenPositionAgree() {
        let bar = TimelineTime.ticksPerBar
        var checked = 0
        for tick in stride(from: -200, to: 3 * bar, by: 7) {
            let parts = WorkstationSummary.counterText(forTick: tick).split(separator: ".")
            guard parts.count == 3 else {
                return XCTFail("`counterText(forTick: \(tick))` is not BAR.BEAT.16th")
            }
            XCTAssertEqual(WorkstationSummary.positionText(forTick: tick), "Bar \(parts[0]) · Beat \(parts[1])",
                           "at tick \(tick) the head's counter and the spoken position name different spots — two rules (#416)")
            checked += 1
        }
        XCTAssertGreaterThan(checked, 800, "the sweep visited \(checked) ticks — it would pass on almost nothing")
    }

    // MARK: 3 — the metre

    func testTheMetreIsTheOneTheBarsAreCountedIn() {
        XCTAssertEqual(WorkstationSummary.meterText, "\(TimelineTime.beatsPerBar)/4",
                       "the head's metre is read from the constant the bars are divided by")
        XCTAssertEqual(TimelineTime.ticksPerBeat, TimelineTime.ticksPerQuarter, """
            PREMISE: the denominator 4 is true only while the timeline's beat IS the quarter. A beat \
            unit other than the quarter must change `meterText` in the same commit.
            """)
        XCTAssertEqual(TimelineTime.ticksPerBar, TimelineTime.beatsPerBar * TimelineTime.ticksPerBeat,
                       "PREMISE: a bar is beatsPerBar beats — the counter's beat digit wraps there")
    }

    // MARK: 4 — the leaf self-drives and only shows

    func testTheCounterIsASelfDrivingLeafOfTheHead() throws {
        let code = try source(Self.header)
        guard let start = code.range(of: Self.leafHead) else {
            return XCTFail("ANCHOR MISSING: `\(Self.leafHead)` (#454)")
        }
        let leaf = try braceBody(after: start, in: code)
        XCTAssertTrue(leaf.contains("TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !playing))"),
                      "the counter redraws itself at the playhead's rate and stops while the piece is stopped")
        XCTAssertTrue(leaf.contains("WorkstationSummary.counterText(forTick: tick)"),
                      "the digits come from the one pure rule")
        XCTAssertEqual(code.components(separatedBy: "currentTick").count - 1, 1,
                       "ONE read of the position in the head's file — anything else is a second reader")
        XCTAssertFalse(code[..<start.lowerBound].contains("currentTick"), """
            The head's own body reads the playhead. It sits in the ROOT chrome above every menu host: \
            the position belongs in `ProjectPositionReadout` only (the 10.76.41/50 freeze law).
            """)
        guard let clock = leaf.range(of: "TimelineView("),
              let read = leaf.range(of: "let tick = playing ? player.currentTick : 0") else {
            return XCTFail("ANCHOR MISSING: the leaf's clock or its one read (#454)")
        }
        XCTAssertLessThan(clock.lowerBound, read.lowerBound, """
            The position is read outside the `TimelineView`. `currentTick` is `@ObservationIgnored`, \
            so a read hoisted above the clock is taken once and never again — a frozen counter.
            """)
        XCTAssertTrue(leaf.contains(".hidden()"), """
            The counter lost its hidden width template. Without it, bar 10 and bar 100 widen the \
            summary mid-play and the head's `ViewThatFits` can jump to another shape while the music runs.
            """)
        XCTAssertTrue(leaf.contains(".accessibilityLabel(\"Position in the piece\")"),
                      "the counter speaks the glossary word (piece), the label the plate's readout uses")
        XCTAssertTrue(leaf.contains(".accessibilityValue(WorkstationSummary.positionText(forTick: tick))"),
                      "VoiceOver hears bar and beat as words, never three bare numbers")
        for banned in ["Button(", ".onTapGesture", "player.play(", "player.stop()", "relocate"] {
            XCTAssertFalse(leaf.contains(banned),
                           "`ProjectPositionReadout` contains `\(banned)` — it shows the position and does nothing else")
        }
    }

    // MARK: 5 — the head mounts it once, in display order

    func testTheHeadShowsPositionTempoAndMetreInOneLine() throws {
        let code = try source(Self.header)
        XCTAssertEqual(code.components(separatedBy: "ProjectPositionReadout()").count - 1, 1,
                       "one counter in the head")
        guard let head = code.range(of: "private func summary(") else {
            return XCTFail("ANCHOR MISSING: `private func summary(` (#454)")
        }
        let summary = try braceBody(after: head, in: code)
        let order = ["ProjectPositionReadout()", "ProjectTempoReadout()",
                     "Text(verbatim: WorkstationSummary.meterText)", "Text(place)"]
        let found = order.compactMap { summary.range(of: $0)?.lowerBound }
        XCTAssertEqual(found.count, order.count, """
            The head's summary no longer holds all of \(order). The counter line is position · tempo \
            · metre, then the place — if one moved out of the summary, re-point this claim at its home.
            """)
        XCTAssertEqual(found, found.sorted(), """
            The head's counter line is out of order. It reads position · tempo · metre · place, the \
            order every DAW's transport display uses, so a player finds the bar before the speed.
            """)
        XCTAssertTrue(summary.contains(".accessibilityLabel(\"Time signature\")"),
                      "the metre is spoken with its name, not as a bare fraction")
    }

    // MARK: 6 — the key lives in the composition strip, once

    func testTheKeyStaysInTheCompositionStripOnce() throws {
        let workspace = try source(Self.workspace)
        XCTAssertEqual(workspace.components(separatedBy: "Picker(\"Key\",").count - 1, 1, """
            COUNTERWEIGHT: the KEY half of A4 is served by `CompositionHeaderStrip`'s Key picker — \
            since DAW shell S1a the Song section of the Project plate (its mount is pinned by \
            `ChromeDynamicTypeTests`). If it moved again, the head may now be the right home for \
            the key — move it there, do not drop it.
            """)
        let code = try source(Self.header)
        XCTAssertFalse(code.contains("StudioDefaultKeys.rootIndex"), """
            The head reads the key itself while the strip above still shows it — two statements of \
            one fact on one screen (#416). Move the key INTO the head and out of the strip in one \
            commit, or leave it where it is.
            """)
    }

    // MARK: helpers

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

    /// The brace-matched body that opens at the first `{` at or after `start` — the declaration's own.
    private func braceBody(after start: Range<String.Index>, in code: String) throws -> String {
        guard let open = code.range(of: "{", range: start.lowerBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: no `{` after the anchor (#454)")
            throw AnchorMissing(reason: "brace")
        }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let c = code[index]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(code[open.lowerBound...index]) } }
            index = code.index(after: index)
        }
        XCTFail("ANCHOR MISSING: unbalanced braces after the anchor (#454)")
        throw AnchorMissing(reason: "unbalanced")
    }
}
