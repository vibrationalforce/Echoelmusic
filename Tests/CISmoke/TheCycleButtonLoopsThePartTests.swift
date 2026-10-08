// TheCycleButtonLoopsThePartTests.swift
// Echoel — GMMW AE-12b (founder 2026-10-08, "Orientiere dich an den Bigplayern"): the door to the
// cycle AE-12a taught the piece and the player. ONE Cycle button in the Workstation's pinned
// transport row, beside Click — Logic's and GarageBand's Cycle.
//
// WHAT IT PINS.
// 1. PURE (`CycleChoice.proposal`): a tap loops the selected part's bars (start floored, end rounded
//    up to a bar line), else four bars from where Play starts — never the whole piece (that already
//    loops), always stored as the window the player plays, nil for a piece of one bar.
// 2. PURE: the words (`CycleChoice.label`, `CycleChoice.hint`) and where the ruler draws the band
//    (`RulerLocate.cycleBand`), on the ruler's own scale.
// 3. END-TO-END over a real `TimelineStore`: `setCycle` is ONE `.cycle` Undo step; a write that
//    changes nothing records nothing; Undo and Redo walk it back and forth.
// 4. SOURCE: the button is the ONE writer of the cycle; it reads nothing hot and is locked while a
//    take records; it is mounted once, a direct child of the transport's control group, between
//    Click and Record; the ruler draws the band from the document through the pure rule, in the
//    neutral fill (never green, the body's signal); the head's Undo hint names the cycle.
//
// Grading (§0, no Swift toolchain): on the parent (`492f22d`) this file does NOT COMPILE — it names
// `CycleChoice`, `RulerLocate.cycleBand` and `TimelineStore.setCycle`, which this commit creates —
// so no assertion has a verdict there; every claim is a FORWARD guard. Claims 1–2 and the store's
// step logic were transcribed into Python and driven; claim 4's scans were driven on the worktree.
// NOT covered: the button's look and width on glass, the band's legibility under the numbers, and
// what VoiceOver speaks — device probes.
// KNOWN LIMIT: setting the cycle by a hold-and-slide on the ruler is not built — the ruler row may
// not drag (`ThePlayStartsWhereTheRulerSaysTests`); that gesture is its own slice.
// NEEDS-FOUNDER-VERIFY: select a part on bars 3–4 → tap the Cycle button beside Click → a band marks
// bars 3–4 on the ruler and Play loops them. Tap Cycle again → the band goes, the whole piece loops.

import Foundation
import XCTest
@testable import Echoelmusic

#if canImport(SwiftUI)
@MainActor
final class TheCycleButtonLoopsThePartTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let togglePath = "Sources/Echoelmusic/Studio/WorkstationCycleToggle.swift"
    private static let viewPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let locatorPath = "Sources/Echoelmusic/Studio/ArrangeRulerLocator.swift"
    private static let storePath = "Sources/Echoelmusic/Core/TimelineStore.swift"
    private static let historyPath = "Sources/Echoelmusic/Studio/SongHistoryRow.swift"

    // MARK: 1 — what a tap loops

    func testATapLoopsThePartsBarsOrFourBarsFromThePlayStart() {
        let b = Self.bar
        let song = 8 * b
        let lane = UUID()
        func part(_ start: Int, _ length: Int) -> TimelineRegion {
            TimelineRegion(laneID: lane, clipID: UUID(), startTick: start, lengthTicks: length)
        }
        func proposal(_ region: TimelineRegion?, cue: Int = 0, loop: Int = 8 * TimelineTime.ticksPerBar) -> Range<Int>? {
            CycleChoice.proposal(part: region, cueTick: cue, loopTicks: loop).map { $0.startTick..<$0.endTick }
        }
        XCTAssertEqual(proposal(part(2 * b, 2 * b)), (2 * b)..<(4 * b), "a part on bars 3–4 loops bars 3–4")
        XCTAssertEqual(proposal(part(2 * b + 100, b)), (2 * b)..<(4 * b),
                       "a part off the grid loops every bar it touches")
        XCTAssertEqual(proposal(part(6 * b, 10 * b)), (6 * b)..<song, "a part past the end loops to the end")
        XCTAssertNil(proposal(part(0, song)), "a part spanning the whole piece — the piece already loops")
        XCTAssertEqual(proposal(nil), 0..<(4 * b), "no part: four bars from where Play starts")
        XCTAssertEqual(proposal(nil, cue: 6 * b + 300), (6 * b)..<song, "…from the cue's bar, clamped to the piece")
        XCTAssertEqual(proposal(nil, loop: 4 * b), 0..<(3 * b), "never the whole piece, even when it is four bars")
        XCTAssertEqual(proposal(nil, loop: 2 * b), 0..<b)
        XCTAssertNil(proposal(nil, loop: b), "a piece of one bar has nothing smaller to loop")
        XCTAssertNil(proposal(part(0, b), loop: 0), "an empty piece has no bars")

        for region in [part(2 * b, 2 * b), part(2 * b + 100, b), part(6 * b, 10 * b)] {
            guard let cycle = CycleChoice.proposal(part: region, cueTick: 0, loopTicks: song) else {
                XCTFail("ANCHOR MISSING: a proposal the cases above expect")
                continue
            }
            XCTAssertEqual(cycle.window(loopTicks: song), cycle.startTick..<cycle.endTick,
                           "what the button stores is exactly what the player loops")
        }
    }

    // MARK: 2 — the words and the band

    func testTheWordsAndTheBandNameTheBarsThatLoop() {
        let b = Self.bar
        let two = CycleChoice.label((2 * b)..<(4 * b))
        XCTAssertTrue(two.hasPrefix(SessionGrid.label(forTick: 2 * b)), "it starts with the bar every part names")
        XCTAssertTrue(two.hasSuffix("4"), "…and names the last bar that loops")
        XCTAssertEqual(CycleChoice.label((2 * b)..<(3 * b)), SessionGrid.label(forTick: 2 * b), "one bar is one bar")

        let hints = [CycleChoice.hint(locked: true, on: false, hasProposal: true, hasPart: true),
                     CycleChoice.hint(locked: false, on: true, hasProposal: true, hasPart: true),
                     CycleChoice.hint(locked: false, on: false, hasProposal: false, hasPart: true),
                     CycleChoice.hint(locked: false, on: false, hasProposal: true, hasPart: true),
                     CycleChoice.hint(locked: false, on: false, hasProposal: true, hasPart: false)]
        XCTAssertEqual(Set(hints).count, hints.count, "each state says what a tap will do, in its own words")

        let cycle = TimelineCycle(startTick: 2 * b, endTick: 4 * b)
        guard let band = RulerLocate.cycleBand(cycle, loopTicks: 8 * b, songTicks: 8 * b),
              let padded = RulerLocate.cycleBand(cycle, loopTicks: 8 * b, songTicks: 16 * b) else {
            return XCTFail("a cycle that plays has a band")
        }
        XCTAssertEqual(band.start, 0.25, accuracy: 1e-9)
        XCTAssertEqual(band.width, 0.25, accuracy: 1e-9)
        XCTAssertEqual(padded.start, 0.125, accuracy: 1e-9, "on the ruler's own scale, not the loop's")
        XCTAssertEqual(padded.width, 0.125, accuracy: 1e-9)
        XCTAssertNil(RulerLocate.cycleBand(nil, loopTicks: 8 * b, songTicks: 8 * b), "no cycle, no band")
        XCTAssertNil(RulerLocate.cycleBand(TimelineCycle(startTick: 0, endTick: 8 * b), loopTicks: 8 * b, songTicks: 8 * b),
                     "a cycle that is the whole piece plays as the song loop — no band claims otherwise")
        XCTAssertNil(RulerLocate.cycleBand(cycle, loopTicks: 8 * b, songTicks: 0), "no scale, no band")
    }

    // MARK: 3 — one tap, one Undo step

    func testSetCycleIsOneUndoStep() {
        let b = Self.bar
        let lane = TimelineLane(name: "Keys", kind: .midi)
        let piece = TimelineDocument(lanes: [lane], regions: [
            TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0, lengthTicks: 8 * b),
        ])
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }
        timeline.replaceDocument(piece)
        XCTAssertFalse(timeline.canUndo)

        let cycle = TimelineCycle(startTick: 2 * b, endTick: 4 * b)
        timeline.setCycle(cycle)
        XCTAssertEqual(timeline.document.cycle, cycle)
        XCTAssertTrue(timeline.canUndo, "a tap is one Undo step")
        timeline.setCycle(cycle)
        timeline.undo()
        XCTAssertNil(timeline.document.cycle, "a write that changed nothing recorded nothing — one Undo is back to none")
        XCTAssertFalse(timeline.canUndo)
        timeline.redo()
        XCTAssertEqual(timeline.document.cycle, cycle, "Redo brings it back")
        timeline.setCycle(nil)
        XCTAssertNil(timeline.document.cycle, "the button turns it off through the same writer")
        timeline.undo()
        XCTAssertEqual(timeline.document.cycle, cycle)
        XCTAssertEqual(timeline.document.regions.count, 1, "COUNTERWEIGHT: a cycle step never touches a part")
    }

    // MARK: 4 — one door, cold, locked while a take records (source)

    func testTheButtonIsTheOneDoorAndReadsNothingHot() throws {
        var writers: [String] = []
        let root = repoRoot().appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            return XCTFail("cannot enumerate Sources/Echoelmusic — a scan that saw nothing is not a pass")
        }
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8) else { continue }
            if SourceText.codeOnly(text).contains(".setCycle(") { writers.append(relative) }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        XCTAssertEqual(writers, ["Studio/WorkstationCycleToggle.swift"], "one door sets the cycle: the transport's Cycle button")

        let store = try source(Self.storePath)
        XCTAssertEqual(store.components(separatedBy: "document.cycle = ").count - 1, 2,
                       "the store writes the cycle in `setCycle` and in its Undo, nowhere else")
        let setter = try member("public func setCycle(_ cycle: TimelineCycle?) {", in: store)
        XCTAssertTrue(setter.contains("guard before != cycle else { return }"), "a write that changes nothing records nothing")
        XCTAssertTrue(setter.contains("pushUndo(.cycle(before: before, after: cycle))"), "one `.cycle` step per call")

        let toggle = try source(Self.togglePath)
        let body = try member("struct WorkstationCycleToggle: View {", in: toggle)
        XCTAssertEqual(body.components(separatedBy: "timeline.setCycle(").count - 1, 1, "one write per tap")
        XCTAssertTrue(body.contains("timeline.setCycle(on ? nil : proposal)"), "on turns it off, off turns the proposal on")
        XCTAssertTrue(body.contains("let locked = recorder.isRecording"), "it knows when a take records")
        XCTAssertTrue(body.contains("let enabled = !locked && (on || proposal != nil)"),
                      "locked while a take records — a cycle set mid-take could end it at once")
        for banned in ["currentTick", "TimelineView(", "masterLevel", "@State", "@GestureState"] {
            XCTAssertFalse(body.contains(banned), "`\(banned)` in the Cycle button — it sits in the transport row, cold (10.76.41/50)")
        }
        XCTAssertTrue(body.contains("EchoelTheme.text : EchoelTheme.fill"), "ON is the inverted monochrome tile Click wears")
        XCTAssertFalse(body.contains("EchoelTheme.accent"), "never green — green is the body's signal")
    }

    func testTheButtonStandsInTheTransportRowAndTheRulerDrawsTheBand() throws {
        let view = try source(Self.viewPath)
        XCTAssertEqual(view.components(separatedBy: "WorkstationCycleToggle()").count - 1, 1, "one Cycle button on the plate")
        let row = try member("private var transportRow: some View {", in: view)
        let group = try member("controls {", in: row)
        guard let click = group.range(of: "WorkstationClickToggle()"),
              let cycle = group.range(of: "WorkstationCycleToggle()", range: click.upperBound..<group.endIndex),
              group.range(of: "RecordTakeButton(", range: cycle.upperBound..<group.endIndex) != nil else {
            return XCTFail("the Cycle button is not mounted after Click and before Record, inside `controls { … }`")
        }
        let lead = group[group.startIndex..<cycle.lowerBound]
        XCTAssertEqual(lead.filter { $0 == "{" }.count - lead.filter { $0 == "}" }.count, 0,
                       "a direct, unconditional child of the row — it stacks with Click at large sizes, never vanishes")

        let locator = try source(Self.locatorPath)
        let ruler = try member("struct ArrangeRulerLocator: View {", in: locator)
        XCTAssertTrue(ruler.contains("RulerLocate.cycleBand(document.cycle,"), "the band is read off the document handed in, through the pure rule")
        XCTAssertTrue(ruler.contains(".fill(EchoelTheme.fill)"), "a neutral band — never green, the body's signal")
        XCTAssertEqual(ruler.components(separatedBy: ".onTapGesture(coordinateSpace: .local)").count - 1, 1,
                       "COUNTERWEIGHT: the ruler still has its one tap, and the band takes none")

        let history = try source(Self.historyPath)
        XCTAssertTrue(history.contains("the piece's light look and cycle"), "the head's Undo hint names the cycle it now takes back")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let reason: String }

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        return dir
    }

    private func source(_ relativePath: String) throws -> String {
        guard let text = try? String(contentsOf: repoRoot().appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(reason: relativePath)
        }
        return SourceText.codeOnly(text)
    }

    /// The text of the braces that open at the first `{` from `head` on (#408 — never a window).
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
        XCTFail("ANCHOR MISSING: unbalanced braces after `\(head)` (#454)")
        throw AnchorMissing(reason: head)
    }
}
#endif
