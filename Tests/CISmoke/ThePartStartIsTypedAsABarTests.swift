// ThePartStartIsTypedAsABarTests.swift
// Echoel — modes census 2026-09-26, design slice 7: the selected part's start is a bar number
// the musician can type.
//
// WHAT THIS PINS. Earlier/Later moved a part one bar per tap, so a part that belonged twelve
// bars away cost twelve taps and twelve undo steps. The part bar now carries "Starts at bar", an
// `EchoelValueField` that moves the part to the named bar in ONE write, keeping its place within
// the bar — where the buttons would have landed.
//
// 1. END-TO-END BEHAVIOUR (`TrackParts.startTick(forBar:keeping:)`, pure, over real `Part`s): the
//    result starts in the named bar by the Workstation's own bar rule (`barNumber`, #416), at the
//    same offset within the bar, and equals what repeated `laterStart`/`earlierStart` reach; it
//    rounds a fractional draft to the nearest bar; it answers nil for the bar the part is already
//    in (no move, no undo step), for a non-finite draft, below bar 1 and past `maxStartBar`.
// 2. SOURCE: the field is a private LEAF mounted once in the part bar's body; it states its grid
//    (`decimals: 0`), takes its range from `maxStartBar` (#416), writes a DRAFT while dragging and
//    moves the part only in `commitDraft` — through `TrackParts.move`, the one writer the buttons
//    and the canvas use — and drops the draft whenever the part's start moves.
//
// Grading (§0, no Swift toolchain): `startTick(forBar:keeping:)`, `maxStartBar` and
// `PartStartField` do not exist on the parent (`f0d2b55fe`), so this file does not compile there
// — every claim is a FORWARD guard, one absence (#486). Claim 1 transcribed into Python and
// driven over targets 1…40 from twelve start bars at eight offsets; claim 2 transcribed against this tree, with mutants
// (the move written in the Binding's setter, the reset dropped, `decimals: 0` removed, a literal
// range, `onChange` routed to the commit, the mount put inside a condition): each red. Review of
// 6c69dacad added the range claim: the field's reach follows the song, so one swipe is one bar.
// NOT covered: how the field reads under the title on glass, and whether a drag across many bars
// feels right — a device look.
// NEEDS-FOUNDER-VERIFY: Workstation → select a part that starts on beat 3 of bar 2 → "Starts at
// bar" shows 2 → drag or type 9 → on release the part jumps to beat 3 of bar 9 and the heading
// says "Bar 9 · Beat 3"; one Undo puts it back on bar 2; tap Later once and the field shows 3.

import Foundation
import XCTest
@testable import Echoelmusic

final class ThePartStartIsTypedAsABarTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let barPath = "Sources/Echoelmusic/Studio/SelectedPartBar.swift"

    // MARK: 1 — where a typed bar lands, pure

    func testATypedBarKeepsThePlaceWithinTheBar() throws {
        let offsets: [Int] = [0, 1, 120, 480, 959, 960, 1_440, Self.bar - 1]   // annotated (#E2)
        for offset in offsets {
            for startBar in 1...12 {
                let part = TrackParts.Part(id: UUID(), startTick: (startBar - 1) * Self.bar + offset,
                                           lengthTicks: Self.bar)
                for target in 1...40 where target != startBar {
                    let tick = try XCTUnwrap(TrackParts.startTick(forBar: Double(target), keeping: part),
                                             "bar \(startBar) → \(target), offset \(offset)")
                    XCTAssertEqual(WorkstationSummary.barNumber(forTick: tick), target,
                                   "the part starts in the bar the field names — by the heading's own bar rule")
                    XCTAssertEqual(tick % Self.bar, offset, "its place within the bar is kept")
                    var stepped = part.startTick
                    for _ in 0..<abs(target - startBar) {
                        let moved = TrackParts.Part(id: part.id, startTick: stepped, lengthTicks: part.lengthTicks)
                        stepped = target > startBar ? TrackParts.laterStart(moved)
                                                    : (TrackParts.earlierStart(moved) ?? stepped)
                    }
                    XCTAssertEqual(tick, stepped, "the field lands where Earlier/Later would have")
                }
            }
        }
    }

    func testAFractionalDraftRoundsAndTheEdgesMoveNothing() {
        let part = TrackParts.Part(id: UUID(), startTick: 4 * Self.bar + 480, lengthTicks: Self.bar)   // bar 5, beat 2
        XCTAssertEqual(TrackParts.startTick(forBar: 7.4, keeping: part), 6 * Self.bar + 480, "7.4 → bar 7")
        XCTAssertEqual(TrackParts.startTick(forBar: 7.6, keeping: part), 7 * Self.bar + 480, "7.6 → bar 8")
        XCTAssertEqual(TrackParts.startTick(forBar: 1, keeping: part), 480, "bar 1 keeps the beat too")
        XCTAssertNil(TrackParts.startTick(forBar: 5, keeping: part), "the bar it is in — nothing to move or undo")
        XCTAssertNil(TrackParts.startTick(forBar: 5.3, keeping: part), "rounds to the bar it is in")
        let bads: [Double] = [.nan, .infinity, -.infinity, 0, 0.9, -3, Double(TrackParts.maxStartBar) + 1]
        for bad in bads {
            XCTAssertNil(TrackParts.startTick(forBar: bad, keeping: part), "\(bad) moves nothing")
        }
        XCTAssertEqual(TrackParts.startTick(forBar: Double(TrackParts.maxStartBar), keeping: part),
                       (TrackParts.maxStartBar - 1) * Self.bar + 480, "the last bar the field offers is reachable")
    }

    func testTheFieldReachesTheSongAndSwipesOneBar() {
        // Review of 6c69dacad, MED-1/2: on a fixed 1…999 range one VoiceOver swipe moved ~20 bars.
        let part = TrackParts.Part(id: UUID(), startTick: 2 * Self.bar, lengthTicks: Self.bar)   // bar 3
        let songs: [Int] = [0, 1, 4, 16, 32, 42]
        for songBars in songs {
            let range = TrackParts.startBarRange(for: part, songBars: songBars)
            XCTAssertEqual(range.lowerBound, 1)
            XCTAssertEqual(range.upperBound, Double(Swift.max(1, songBars) + TrackParts.startBarRoom),
                           "a \(songBars)-bar song: the field reaches its last bar and a little past it")
            XCTAssertEqual(ScrubPrecision.adjustmentStep(span: range.upperBound - range.lowerBound, decimals: 0), 1,
                           "one swipe is one bar on a \(songBars)-bar song — the step the field itself uses")
        }
        let late = TrackParts.Part(id: UUID(), startTick: 59 * Self.bar, lengthTicks: Self.bar)   // bar 60
        XCTAssertEqual(TrackParts.startBarRange(for: late, songBars: 16).upperBound, 60,
                       "never below the bar the part is on — the field's value stays inside its range")
        XCTAssertEqual(TrackParts.startBarRange(for: part, songBars: .max).upperBound, Double(TrackParts.maxStartBar),
                       "and never past the overflow clamp")
    }

    // MARK: 2 — the leaf, its draft and its one write

    func testTheFieldIsALeafThatMovesOnceOnCommit() throws {
        let code = try source(Self.barPath)
        guard let bar = code.range(of: "struct SelectedPartBar: View {"),
              let body = code.range(of: "var body: some View {", range: bar.upperBound..<code.endIndex),
              let bodyEnd = code.range(of: "private struct Trims {", range: body.upperBound..<code.endIndex),
              let leaf = code.range(of: "private struct PartStartField: View {") else {
            return XCTFail("ANCHOR MISSING: the part bar's body, or `PartStartField` (#454)")
        }
        let barBody = String(code[body.upperBound..<bodyEnd.lowerBound])
        XCTAssertEqual(barBody.components(separatedBy: "PartStartField(part: part,").count - 1, 1,
                       "the field is mounted once, in the part bar")
        // Review of 6c69dacad, LOW-5: directly under the title row — not inside a condition.
        XCTAssertNotNil(barBody.range(of: #"songCanStart:\s*songCanStart\)\s*\}\s*PartStartField\(part: part,"#,
                                      options: .regularExpression),
                        "the field sits unconditionally under the title row")
        XCTAssertEqual(code.components(separatedBy: "PartStartField(").count - 1, 1, "and nowhere else")
        XCTAssertLessThan(bodyEnd.lowerBound, leaf.lowerBound, "the leaf is its own struct, outside the bar")

        let field = String(code[leaf.upperBound...])
        guard let call = field.range(of: "EchoelValueField(label: \"Starts at bar\","),
              let commit = field.range(of: "private func commitDraft() {") else {
            return XCTFail("the leaf no longer offers \"Starts at bar\" or no longer commits through `commitDraft`")
        }
        let fieldCall = String(field[call.upperBound..<commit.lowerBound])
        for needle in ["value: Binding(get: { shownBar }, set: { draft = $0 }),",
                       "range: TrackParts.startBarRange(for: part, songBars: songBars),",
                       "decimals: 0,",
                       "onCommit: { commitDraft() })",
                       ".onChange(of: part.startTick) { _, _ in draft = nil }"] {
            XCTAssertTrue(fieldCall.contains(needle), "the field lost `\(needle)`")
        }
        XCTAssertFalse(fieldCall.contains("TrackParts.move("),
                       "the drag writes a DRAFT — a move per step would stack an undo step per bar crossed")
        // Review of 6c69dacad, MED-3: the per-event `onChange` must not reach the commit either.
        XCTAssertFalse(fieldCall.contains("onChange:"),
                       "`onChange` fires per drag event — routed to the commit, every bar crossed is a move")
        XCTAssertEqual(fieldCall.components(separatedBy: "commitDraft()").count - 1, 1, "committed from `onCommit` only")
        let commitBody = String(field[commit.upperBound...])
        XCTAssertTrue(commitBody.contains("if let tick = TrackParts.startTick(forBar: bar, keeping: part) {"))
        XCTAssertTrue(commitBody.contains("TrackParts.move(part, toStartTick: tick, timeline: timeline)"),
                      "the release writes through the one move the buttons and the canvas use")
        XCTAssertEqual(field.components(separatedBy: "TrackParts.move(").count - 1, 1, "one write, on release")
        for banned in ["Slider(", "Stepper(", "moveRegion("] {
            XCTAssertFalse(field.contains(banned), "the leaf contains `\(banned)` — one control, one writer")
        }
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
