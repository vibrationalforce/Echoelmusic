// TheClickAccentPairStaysAdjacentTests.swift
// Echoel — #1375. Blocking bundle. SOURCE-TEXT SCAN (`Tests/CISmoke/CLAUDE.md` §1): it proves
// the order the rows are WRITTEN in, never how they render.
//
// ⭐ THIS FILE EXISTS BECAUSE A REFLOW SLICE WAS STARTED AND CORRECTLY ABANDONED. `CLAUDE.md`
// says the whole remaining #292 adaptivity backlog is ONE slice — `tempoToolsPanel`, "2 Felder
// + 3 Schalter" — and the obvious move is to wrap the two fields in an `AdaptiveCardGrid` the
// way `masterPanel`, `moodPanel`, `soundPanel` and `visualPanel` already are. Measured at the
// source, those two fields are NOT ADJACENT and must not be made adjacent:
//
//   Toggle   "Metronome (click)"   — the gate
//   Field    "Accent every"        — the number
//   Toggle   "Accent downbeat"     — ITS switch, put here on purpose by #930b
//   Field    "Click level"         — a MIX value, deliberately after the pair
//
// A grid needs its members adjacent. Reaching it means either moving "Accent downbeat" away
// from the number it governs — undoing #930b, whose own comment block was corrected three
// times (#930, #930b, and the ⛔ that retracted "the toggle two rows down now sits next to") —
// or sweeping a `Toggle` into a two-column pair with an `EchoelValueField`, which is the
// ragged-height regression `MoodPanelReflowsTests` claim 3 already condemns. So the remaining
// backlog is not one slice; it is ZERO slices and a reason, and the reason had no home in the
// tree that a `grep` would find.
//
// ⚠️ IT DOES NOT FORBID A FUTURE REFLOW (#364), and claim 3's message says so in the failure
// text. It goes red BY DESIGN the day someone adds a grid here — the same shape as
// `TheTempoDestinationHasNoRouteTests` — and what it asks for on that day is that the decision
// be made explicitly: #930b's pairing argument and `CLAUDE.md`'s two "#292" homes move in the
// SAME commit, rather than a tidy-up quietly reversing a three-times-corrected call.
//
// ⛔ NOT GUARDED HERE, AND THAT IS #416 NOT AN OVERSIGHT: that `metronomeRow` must never read
// `metronome.bpm` (the ~20 Hz relay write during a tempo glide, the menu-freeze family).
// `TheMenuHostReadsNoHotStateTests` owns the metronome half of that law across the whole host
// file and states its own reasoning for it. A second scan here would be a second spelling of
// one decision — and a reflow edit is exactly the moment someone would add a BPM readout, so
// the coverage matters; it just already exists.
//
// ⚠️ HONEST GRADING. No local Swift toolchain (§0). **Seven assertions across four claims**,
// stated rather than counted from the file's shape. The row body is taken by BRACE MATCHING
// from the declaration (#408: no fixed window — this member carries ~70 lines of comment, and
// `SourceText.codeOnly` preserves line count, so any line budget is unsound by construction).
// Transcribed into Python, driven against this tree (GREEN) and against five mutants — the two
// fields made adjacent, "Click level" hoisted above the pair, an `AdaptiveCardGrid` added, the
// gate toggle removed, and a field downgraded to a raw `Slider` — each of which turned the
// intended claim RED. **0 regression catches, 7 COUNTERWEIGHTS (#343)**: correct, because this
// slice records a decision NOT to change code.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheClickAccentPairStaysAdjacentTests: XCTestCase {

    private static let hostFile = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let declaration = "private var metronomeRow: some View {"

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    /// The member's body, comments stripped, taken by brace matching from its declaration.
    /// Returns nil when the declaration is gone — a lost anchor FAILS, it does not skip (#454).
    private func rowBody() throws -> String? {
        let code = SourceText.codeOnly(try String(
            contentsOf: try repoRoot().appendingPathComponent(Self.hostFile), encoding: .utf8))
        guard let start = code.range(of: Self.declaration) else { return nil }
        var depth = 0
        var index = code.index(before: start.upperBound)   // the declaration's own `{`
        var out = ""
        while index < code.endIndex {
            let character = code[index]
            if character == "{" { depth += 1 }
            if character == "}" {
                depth -= 1
                if depth == 0 { return out }
            }
            out.append(character)
            index = code.index(after: index)
        }
        return nil   // unbalanced braces — treated as a lost anchor
    }

    private func body() throws -> String {
        guard let body = try rowBody() else {
            XCTFail("""
                `\(Self.declaration)` is gone from `\(Self.hostFile)`, or its braces do not \
                balance, so every claim in this file compared nothing. That FAILS rather than \
                passing vacuously (#454). If the click rows moved, re-anchor here in the same \
                commit and carry #930b's pairing argument with them.
                """)
            return ""
        }
        return body
    }

    // MARK: - Claim 1 — the four rows are written in the order #930b settled on

    func testTheClickAccentPairStaysAdjacent() throws {
        let body = try self.body()
        guard !body.isEmpty else { return }
        let anchors = ["Toggle(isOn: $metronome.enabled)",
                       "EchoelValueField(label: \"Accent every\"",
                       "Toggle(isOn: $metronome.accentDownbeat)",
                       "EchoelValueField(label: \"Click level\""]
        var positions: [String.Index] = []
        for anchor in anchors {
            guard let found = body.range(of: anchor) else {
                return XCTFail("""
                    `metronomeRow` no longer contains `\(anchor)`. The four rows and their \
                    order are the subject of this file; a renamed or removed row needs this \
                    guard re-anchored in the same commit, not deleted.
                    """)
            }
            positions.append(found.lowerBound)
        }
        for pair in 0..<(positions.count - 1) {
            XCTAssertLessThan(positions[pair], positions[pair + 1], """
                `metronomeRow`'s rows are out of order at "\(anchors[pair])" → \
                "\(anchors[pair + 1])". #930b put "Accent downbeat" DIRECTLY below the number \
                it governs, because the accent is what makes "Accent every" audible at all — \
                its own comment says "the remedy is the very next row, not three rows away". \
                "Click level" is a MIX value and sits after the pair it does not join. \
                Reordering is allowed (#364), but it undoes a decision this file's header \
                records as corrected three times — say so explicitly and move those comments.
                """)
        }
    }

    // MARK: - Claim 2 — no adaptive grid here, and that is the finding

    /// The one claim that will one day be red on purpose.
    func testTheRowCarriesNoAdaptiveGrid() throws {
        let body = try self.body()
        guard !body.isEmpty else { return }
        XCTAssertFalse(body.contains("AdaptiveCardGrid"), """
            `metronomeRow` gained an `AdaptiveCardGrid`. This guard does not forbid that — it \
            asks that it be deliberate. Reaching a grid needs the two `EchoelValueField`s \
            ADJACENT, which means moving "Accent downbeat" off the number it governs (#930b), \
            or pairing a `Toggle` with a field in one row, which is the ragged-height \
            regression `MoodPanelReflowsTests` claim 3 condemns. If neither applies any more, \
            correct #930b's comment block AND both `CLAUDE.md` homes of the "#292 backlog is \
            one slice" claim in the SAME commit, then retire this claim.
            """)
    }

    // MARK: - Claim 3 — the parameter law still holds for these rows

    /// Counterweight. Without it, claim 1 stays green on a tree that kept the ORDER and lost
    /// the controls — a raw `Slider` for "Click level" would satisfy every position check above
    /// while breaking the app-wide rule that a numeric parameter is an `EchoelValueField`.
    func testTheNumbersAreFieldsAndTheSwitchesAreToggles() throws {
        let body = try self.body()
        guard !body.isEmpty else { return }
        XCTAssertEqual(body.components(separatedBy: "EchoelValueField(").count - 1, 2, """
            `metronomeRow` no longer holds exactly two `EchoelValueField`s. Both numbers here \
            are numeric parameters, and CLAUDE.md's rule is that every adjustable numeric \
            parameter is an `EchoelValueField` — never a raw `Slider` or `Stepper`.
            """)
        XCTAssertEqual(body.components(separatedBy: "Toggle(isOn:").count - 1, 2, """
            `metronomeRow` no longer holds exactly two `Toggle`s. Both switches here are Bools, \
            and the same rule says to read the word NUMERIC: a Bool is a `Toggle`, which is \
            what the row's own comment states.
            """)
    }

    // MARK: - Claim 4 — the gate still gates

    /// Counterweight for the shape of claim 1: the last three rows live inside
    /// `if metronome.enabled`. If that branch were flattened the order would still read
    /// correctly here while the panel had silently changed what it shows when the click is off.
    func testTheThreeDetailRowsStayBehindTheEnableGate() throws {
        let body = try self.body()
        guard !body.isEmpty else { return }
        XCTAssertTrue(body.contains("if metronome.enabled {"), """
            `metronomeRow` lost its `if metronome.enabled` branch, so the accent interval, its \
            switch and the click level now show while the click is off — three controls with \
            no audible consequence, which is exactly what #135/#164/#227 removed elsewhere.
            """)
    }
}
