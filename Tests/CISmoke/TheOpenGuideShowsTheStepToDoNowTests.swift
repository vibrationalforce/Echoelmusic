// TheOpenGuideShowsTheStepToDoNowTests.swift
// Echoel — the "Create a piece" card, OPEN, draws the step to do now — not all five — with the
// line "Step n of 5" beside its title (founder 2026-10-01: „Viele Bereiche sind zu groß und füllen
// den Bildschirm aus. Vermeide slop." and „Vermeide das es mehrfache Wege zu einem Bereich gibt").
//
// WHY: open on an empty piece the card drew all five steps as bordered rows — ≈318 pt
// (ESTIMATE) on a 375×667 phone, more than the arrangement viewport below it — while four of the
// five were done, waiting, or a second address of a door the plate already has (Add MIDI Track,
// New MIDI Part, Notes, the bar's Play, Save). Drawn one at a time, every step stays reachable:
// finishing one makes the next the drawn one.
//
// ⚠️ ONE EXCEPTION, AND IT IS THE LAW, NOT A LOOPHOLE: a step BEFORE the next one that is WAITING
// keeps its row. A written part the engine cannot play (#1440) makes Play wait while Save is
// next; without the Play row, "Nothing in the piece can play yet — no part with notes is heard."
// (review of c672c2adf, LOW) would be said nowhere on screen. So the rule is `shownSteps`: every
// step up to the next one that is not done. It never draws a done step and never a later one.
//
// ⚠️ "n of 5" NAMES THE NEXT STEP, IT IS NOT PROGRESS. The review of c672c2adf already paid for a
// done-count in this card: Save is never done and Play only while playing, so the count peaked at
// 4 and fell back on Stop. A position names a step and cannot go backwards on Stop.
//
// THE FIVE CLAIMS:
// 1. RUNTIME (END-TO-END on the shipped value type): `ComposeGuide.stepPosition` reads
//    "Step n of 5" for each step and is the ONE spelling the spoken row label starts with (#416).
// 2. RUNTIME, over the WHOLE fact space (all 64 combinations of the six facts): with no next step
//    `shownSteps` is all five; otherwise it ends at the next step, every row before it is
//    WAITING, none is done — at most two rows. Plus four named fixtures (empty, written,
//    playing, written-but-unplayable) so a failure names a situation, not a bit pattern.
// 3. SCAN: the card's ONE `ForEach` iterates `shown`, which is `ComposeGuide.shownSteps(facts)`.
// 4. SCAN: the header carries the position line behind `if let next {`, and the "Next: …" line
//    shows only while folded (open, the drawn row names the step — it is not said twice).
// 5. COUNTERWEIGHTS (#343): the fold toggle, the 44 pt rows and the per-row spoken label remain;
//    `spokenLabel` reads `stepPosition`, never a second spelling.
//
// DEVICE PROBE, open: the card on an empty piece on a 375 pt phone in German („Schritt 1 von 5"),
// a written piece whose part cannot play (two rows: Play waiting with its reason, Save), and a
// VoiceOver pass over header and row.
//
// HONEST GRADING (§3), against the parent tree (`430b20307`): the file does NOT compile there —
// claims 1 and 2 call `ComposeGuide.stepPosition` / `shownSteps`, which this commit creates — so
// no assertion has a verdict on the parent. By transcription: claims 1 and 2 are FORWARD (two
// absences of new API, one finding each); claims 3 and 4 are REGRESSIONS (the card iterates
// `ComposeGuide.Step.allCases` and shows "Next: …" unconditionally); claim 5 is COUNTERWEIGHTS
// except its `stepPosition(step)` needle, red by claim 1's absence (#486). Claim 2's fact-space
// law was transcribed in Python over all 64 combinations: max two rows, three combinations with
// no next step (all three need `canSave == false` beside a written part, which `ComposeGuide.facts`
// cannot produce — `hasPart` implies a user part, and that is what `canSave` asks).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheOpenGuideShowsTheStepToDoNowTests: XCTestCase {

    private static let view = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let model = "Sources/Echoelmusic/Studio/ComposeGuide.swift"

    private static let empty = ComposeGuide.Facts(hasMIDITrack: false, hasPart: false, hasNotes: false,
                                                  canPlay: false, isPlaying: false, canSave: false)
    private static let written = ComposeGuide.Facts(hasMIDITrack: true, hasPart: true, hasNotes: true,
                                                    canPlay: true, isPlaying: false, canSave: true)

    // MARK: 1 — the position names a step, in one spelling

    func testThePositionNamesTheStepInOneSpelling() {
        let expected: [ComposeGuide.Step: String] = [.track: "Step 1 of 5", .part: "Step 2 of 5", .notes: "Step 3 of 5",
                                                     .play: "Step 4 of 5", .save: "Step 5 of 5"]
        for step in ComposeGuide.Step.allCases {
            XCTAssertEqual(ComposeGuide.stepPosition(step), expected[step], "step \(step.rawValue) names the wrong place")
            for facts in [Self.empty, Self.written] {
                XCTAssertTrue(ComposeGuide.spokenLabel(step, facts).hasPrefix(ComposeGuide.stepPosition(step) + ", "), """
                    the spoken row no longer starts with `stepPosition` — two spellings of one \
                    position (#416), and the line beside the title could say a different step than \
                    VoiceOver does
                    """)
            }
        }
    }

    // MARK: 2 — open, the step to do now (and a waiting step before it, with its reason)

    func testTheOpenCardDrawsTheStepToDoNowAndAWaitingStepBeforeIt() {
        // Named fixtures first, so a failure names a situation.
        XCTAssertEqual(ComposeGuide.shownSteps(Self.empty), [.track], "an empty piece: the first step alone")
        XCTAssertEqual(ComposeGuide.shownSteps(Self.written), [.play], "a written piece at rest: Play alone")
        var playing = Self.written
        playing.isPlaying = true
        XCTAssertEqual(ComposeGuide.shownSteps(playing), [.save], """
            while the piece plays, Save alone — Stop is the transport's (one Stop), and a done Play \
            row is not redrawn
            """)
        var unplayable = Self.written
        unplayable.canPlay = false
        XCTAssertEqual(ComposeGuide.shownSteps(unplayable), [.play, .save], """
            a written part the engine cannot play (#1440): Play is WAITING before the next step, \
            and its row is the only place that says why — it must stay drawn
            """)
        XCTAssertFalse(ComposeGuide.detail(.play, unplayable).isEmpty, "premise: the waiting Play row says its reason")

        // The law over the whole fact space.
        var withoutNext = 0
        for bits in 0..<64 {
            let facts = ComposeGuide.Facts(hasMIDITrack: bits & 1 != 0, hasPart: bits & 2 != 0,
                                           hasNotes: bits & 4 != 0, canPlay: bits & 8 != 0,
                                           isPlaying: bits & 16 != 0, canSave: bits & 32 != 0)
            let shown = ComposeGuide.shownSteps(facts)
            guard let next = ComposeGuide.nextStep(facts) else {
                withoutNext += 1
                XCTAssertEqual(shown, ComposeGuide.Step.allCases, """
                    facts \(bits): no next step, so the header says "Every step is available below." \
                    — all five must be drawn
                    """)
                continue
            }
            XCTAssertEqual(shown.last, next, "facts \(bits): the drawn rows do not end at the next step: \(shown)")
            XCTAssertLessThanOrEqual(shown.count, 2, "facts \(bits): \(shown.count) rows — the open card is the step to do now")
            for step in shown.dropLast() {
                XCTAssertEqual(ComposeGuide.state(of: step, facts), .waiting, """
                    facts \(bits): step \(step.rawValue) is drawn before the next one without waiting — \
                    a done or ready step is a second door to an area the plate already opens
                    """)
            }
        }
        // ANCHOR against a vacuous loop: the fact space is real and mostly has a next step.
        XCTAssertLessThan(withoutNext, 64, "no fact combination has a next step — the loop above proved nothing")
    }

    // MARK: 3 — the card iterates the model's one rule

    func testTheOpenCardIteratesTheModelsRule() throws {
        let card = try member("private struct ComposeGuideCard: View {", in: try code(Self.view))
        XCTAssertTrue(card.contains("let shown = ComposeGuide.shownSteps(facts)"),
                      "the card asks the model's ONE rule for the rows to draw (#416)")
        XCTAssertEqual(card.components(separatedBy: "ForEach(").count - 1, 1, "the card draws its rows from ONE loop")
        XCTAssertTrue(card.contains("ForEach(shown) { step in"), "the one loop iterates `shown`")
        XCTAssertFalse(card.contains("ForEach(ComposeGuide.Step.allCases)"), """
            the card draws all five steps again — ≈318 pt on an empty piece (estimate), four of them \
            done, waiting, or a second door to an area the plate already opens (founder 2026-10-01)
            """)
    }

    // MARK: 4 — the header says which step; the "Next:" line only while folded

    func testTheHeaderNamesTheNextStepAndSaysItOnce() throws {
        let card = try member("private struct ComposeGuideCard: View {", in: try code(Self.view))
        XCTAssertTrue(card.contains("let next = ComposeGuide.nextStep(facts)"),
                      "the position line names the model's next step (#416)")
        guard let gate = card.range(of: "if let next {"),
              let position = card.range(of: "Text(ComposeGuide.stepPosition(next))", range: gate.upperBound..<card.endIndex) else {
            return XCTFail("ANCHOR MISSING: `if let next {` → `Text(ComposeGuide.stepPosition(next))` in the card (#454)")
        }
        XCTAssertFalse(card[gate.upperBound..<position.lowerBound].contains("}"),
                       "the position line is the first thing inside `if let next {`")
        guard let folded = card.range(of: "if !expanded {"),
              let detail = card.range(of: "Text(ComposeGuide.headerDetail(facts))", range: folded.upperBound..<card.endIndex) else {
            return XCTFail("""
                ANCHOR MISSING: `if !expanded {` → `Text(ComposeGuide.headerDetail(facts))` — open, the \
                header would say "Next: …" right above the row that says the same (#454)
                """)
        }
        XCTAssertFalse(card[folded.upperBound..<detail.lowerBound].contains("}"),
                       "the \"Next:\" line is the first thing inside `if !expanded {`")
        XCTAssertEqual(card.components(separatedBy: "Text(ComposeGuide.headerDetail(facts))").count - 1, 1,
                       "the header's next line is drawn once")
    }

    // MARK: 5 — counterweights

    func testTheFoldTheTargetsAndTheSpokenRowRemain() throws {
        let card = try member("private struct ComposeGuideCard: View {", in: try code(Self.view))
        XCTAssertTrue(card.contains("expanded.toggle()"), "the player's own tap still folds and opens the card")
        XCTAssertEqual(card.components(separatedBy: "minHeight: 44").count - 1, 2, "header and row keep a 44 pt target")
        XCTAssertTrue(card.contains(".accessibilityLabel(ComposeGuide.spokenLabel(step, facts))"),
                      "the drawn row still speaks its place, title and state")
        XCTAssertTrue(card.contains(".accessibilityLabel(ComposeGuide.headerLabel(facts))"),
                      "the header still speaks the next step, open or folded")
        let model = try code(Self.model)
        let spoken = try member("static func spokenLabel(_ step: Step, _ facts: Facts) -> String {", in: model)
        XCTAssertTrue(spoken.contains("let position: String = stepPosition(step)"),
                      "`spokenLabel` builds its own position again — one spelling (#416)")
        let position = try member("static func stepPosition(_ step: Step) -> String {", in: model)
        XCTAssertFalse(position.contains("doneCount"), "the position line became a progress count — it goes backwards on Stop")
    }

    // MARK: helpers

    /// A missed anchor FAILS (with `XCTFail` first) and stops the claim — never a skip (#806).
    private struct AnchorMissing: Error { let name: String }

    /// The brace-matched body after `anchor`, which ends in its own `{` (#408); string-literal aware.
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else {
            XCTFail("ANCHOR MISSING: `\(anchor)` (#454)")
            throw AnchorMissing(name: anchor)
        }
        var depth = 1
        var index = start.upperBound
        var inString = false
        while index < code.endIndex {
            let ch = code[index]
            if inString, ch == "\\" {
                index = code.index(after: index)
                if index < code.endIndex { index = code.index(after: index) }
                continue
            }
            if ch == "\"" { inString.toggle() }
            if !inString {
                if ch == "{" { depth += 1 }
                if ch == "}" {
                    depth -= 1
                    if depth == 0 { return String(code[start.upperBound..<index]) }
                }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: `\(anchor)` never closes (#454)")
        throw AnchorMissing(name: anchor)
    }

    private func code(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return SourceText.codeOnly(text)
    }
}
