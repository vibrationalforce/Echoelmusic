// TheCanvasShowsWhatIsSilentTests.swift
// Echoel — modes census 2026-09-26, design slice 5: the Arrange canvas shows which tracks make
// no sound.
//
// WHAT THIS PINS. A muted track, and every track another track's solo silences, looked exactly
// like a playing one on the canvas. Now a silenced lane's parts dim, its name gutter carries a
// SHAPE (speaker with a slash; headphones for the soloed track), and VoiceOver hears the state
// on the row and on every part. Mute and Solo stay the track header's switches — the canvas
// only shows.
//
// 1. END-TO-END BEHAVIOUR (`ArrangeCanvas.hearing`, pure, over real `TimelineDocument`s): the
//    state follows the mixer's own rule — DRIVEN against `TimelineDocument.effectiveGain` over
//    every mute/solo combination of three tracks at full level, so the picture and the mixer's
//    mute/solo cannot disagree (#416: one rule, checked, not restated by hand). A zero level or
//    a track without a voice is silent too and is NOT dimmed — the scope is mute and solo.
// 2. END-TO-END BEHAVIOUR: each silenced state has a symbol AND a spoken word, so the cue is
//    never colour or opacity alone; a playing track adds nothing.
// 3. SOURCE: the canvas reads the state from that one function, dims the lane (opacity only),
//    puts the symbol in the name gutter, speaks it on the row and on each part, and offers no
//    mute/solo control of its own.
//
// Grading (§0, no Swift toolchain): `hearing`, `symbol`, `spokenState` and `nameGutter` do not
// exist on the parent (`60f1bd2ab`), so this file does not compile there — every claim is a
// FORWARD guard, one absence (#486). Claims 1-2 transcribed into Python and driven over all 64
// combinations; claim 3 transcribed against this tree, with mutants (the opacity removed, a
// part label without the state, a Button in the gutter): each red.
// NOT covered: whether 0.45 reads as "silent" rather than "disabled" on glass, and the symbol's
// legibility at 10 pt — a device look.
// NEEDS-FOUNDER-VERIFY: Workstation with two tracks that hold parts → Mute one: its parts dim and
// a crossed-out speaker leads its name; un-mute, Solo the other: the solo track shows headphones,
// the other dims with an outlined crossed-out speaker; VoiceOver on a dimmed part says "…, muted,
// part at bar …" or "…, silent while another track is soloed, …".

import Foundation
import XCTest
@testable import Echoelmusic

final class TheCanvasShowsWhatIsSilentTests: XCTestCase {

    private static let canvasPath = "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift"

    // MARK: 1 — the mixer's rule, driven

    func testTheCanvasStateIsTheMixersRule() {
        for mask in 0..<64 {
            let lanes = (0..<3).map { i in
                TimelineLane(name: "T\(i)", kind: .midi,
                             isMuted: mask & (1 << (2 * i)) != 0,
                             isSoloed: mask & (1 << (2 * i + 1)) != 0)
            }
            let document = TimelineDocument(lanes: lanes)
            for lane in lanes {
                let hearing = ArrangeCanvas.hearing(of: lane.id, in: document)
                XCTAssertEqual(ArrangeCanvas.isSilenced(hearing), document.effectiveGain(for: lane.id) == 0,
                               "mask \(mask), \(lane.name): the canvas shows \(hearing) but the mixer plays gain \(document.effectiveGain(for: lane.id))")
                if lane.isMuted {
                    XCTAssertEqual(hearing, .muted, "mute wins over the track's own solo, as in the mixer")
                } else if lane.isSoloed {
                    XCTAssertEqual(hearing, .soloed)
                } else if lanes.contains(where: { $0.isSoloed }) {
                    XCTAssertEqual(hearing, .silencedBySolo,
                                   "a solo anywhere silences this track — even when the soloed track is also muted")
                } else {
                    XCTAssertEqual(hearing, .plays)
                }
            }
        }
        XCTAssertEqual(ArrangeCanvas.hearing(of: UUID(), in: TimelineDocument()), .plays,
                       "an unknown track has nothing to dim")
    }

    // MARK: 2 — never colour alone

    func testEverySilentStateHasAShapeAndAWord() {
        XCTAssertNil(ArrangeCanvas.symbol(.plays))
        XCTAssertEqual(ArrangeCanvas.spokenState(.plays), "", "a playing track adds nothing to its name")
        let states: [ArrangeCanvas.Hearing] = [.muted, .soloed, .silencedBySolo]
        for state in states {
            XCTAssertNotNil(ArrangeCanvas.symbol(state), "\(state) must carry a symbol, not only a dimmed colour")
            XCTAssertTrue(ArrangeCanvas.spokenState(state).hasPrefix(", "), "\(state) must be spoken after the name")
        }
        XCTAssertEqual(Set(states.compactMap(ArrangeCanvas.symbol)).count, 3,
                       "muted, soloed and silenced-by-solo are three different shapes")
        XCTAssertTrue(ArrangeCanvas.isSilenced(.muted) && ArrangeCanvas.isSilenced(.silencedBySolo))
        XCTAssertFalse(ArrangeCanvas.isSilenced(.soloed) || ArrangeCanvas.isSilenced(.plays))
    }

    // MARK: 3 — the canvas uses it, and only shows

    func testTheCanvasDimsNamesAndSpeaksTheState() throws {
        let file = try source(Self.canvasPath)
        guard let canvas = file.range(of: "struct ArrangeCanvasView: View {"),
              let canvasEnd = file.range(of: "struct ArrangeBarRuler: View {", range: canvas.upperBound..<file.endIndex),
              let gutter = file.range(of: "private func nameGutter(_ row: WorkstationSummary.LaneRow) -> some View {",
                                      range: canvas.upperBound..<canvasEnd.lowerBound),
              let lane = file.range(of: "private func laneRow(_ row: WorkstationSummary.LaneRow, selected: UUID?) -> some View {",
                                    range: gutter.upperBound..<canvasEnd.lowerBound) else {
            return XCTFail("ANCHOR MISSING: `nameGutter` then `laneRow` inside `ArrangeCanvasView` (#454)")
        }
        let gutterBody = String(file[gutter.upperBound..<lane.lowerBound])
        let laneBody = String(file[lane.upperBound..<canvasEnd.lowerBound])
        XCTAssertTrue(gutterBody.contains("let hearing = ArrangeCanvas.hearing(of: row.id, in: document)"))
        XCTAssertTrue(gutterBody.contains("if let symbol = ArrangeCanvas.symbol(hearing) {"),
                      "the gutter leads with the state's symbol")
        XCTAssertTrue(gutterBody.contains("Image(systemName: symbol)"))
        XCTAssertTrue(laneBody.contains("let hearing = ArrangeCanvas.hearing(of: row.id, in: document)"))
        XCTAssertTrue(laneBody.contains("let spokenName = row.name + ArrangeCanvas.spokenState(hearing)"))
        XCTAssertTrue(laneBody.contains(".opacity(ArrangeCanvas.isSilenced(hearing) ? 0.45 : 1)"),
                      "a silenced lane's parts dim")
        // E4-90 (7ad87b510) moved the connective into the string catalog so it speaks German;
        // this pin stayed on the interpolated English form and could no longer match. The claim
        // is unchanged: the part's label LEADS with the track's spoken name and state.
        XCTAssertTrue(laneBody.contains("label: spokenName + String(localized: \", part at \") + SessionGrid.label(forTick: start),"),
                      "every part says its track's state, not only the row")
        XCTAssertTrue(laneBody.contains(".accessibilityLabel(\"\\(spokenName): \" + ArrangementStrip.spoken(onLane: row.id, in: document))"),
                      "the row says the state after the name")
        let canvasBody = String(file[canvas.upperBound..<canvasEnd.lowerBound])
        for banned in ["toggleMute", "toggleSolo", "isMuted", "isSoloed"] {
            XCTAssertFalse(canvasBody.contains(banned), """
                ArrangeCanvasView names `\(banned)` — the canvas SHOWS mute and solo through \
                `ArrangeCanvas.hearing`; the header's switches are the one control for each
                """)
        }
        XCTAssertFalse(gutterBody.contains("Button("), "the gutter's symbol is not a second mute/solo control")
    }

    // MARK: helpers

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }
}
