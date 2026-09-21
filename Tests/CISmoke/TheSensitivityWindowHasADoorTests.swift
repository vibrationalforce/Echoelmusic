// TheSensitivityWindowHasADoorTests.swift
// Echoel — the range expansion built for "Bio löst zu neutral" had no writer. #1408.
//
// WHAT WAS WRONG, measured rather than assumed. `ModRoute.inputLow`/`inputHigh` remap a
// source's normalized value `[low…high] → [0…1]` BEFORE invert/curve/depth. The primitive
// shipped with board row AU2, is applied by `windowed(_:)`, is persisted and is decoded —
// and `git grep -n "inputLow\|inputHigh" -- Sources` returned matches in exactly ONE file,
// `Core/ModulationMatrix.swift` itself. No surface, no producer, nothing outside the type
// could write either edge. The door added by #1250 (`PatchbayView.modulationSection`)
// creates routes with the defaults 0 and 1, i.e. the IDENTITY window.
//
// ⭐ SO THE FOUNDER'S COMPLAINT WAS A REACHABILITY FACT, NOT A TUNING ONE. Coherence
// typically lives in ~[0,3…0,6]; a full-range destination driven by the raw channel moves
// about a third of its travel and feels flat. The fix for that was already in the codebase,
// already tested, already saved to disk — and could not be reached by a finger. That is the
// register defect this repo names repeatedly: built, wired, doorless.
//
// THE PAIRING RULE IS ON THE TYPE, NOT IN THE VIEW (#416). `windowed(_:)` answers a closed
// or inverted window with IDENTITY — a deliberate divide-by-zero guard. Two raw bindings on
// the stored properties would therefore let a player drag one edge past the other and leave
// two numbers on screen beside a route that has quietly stopped shaping anything: the lying
// dial #164/#227 bans. `setInputLow(_:)`/`setInputHigh(_:)` push the other edge ahead
// instead of blocking the drag, and pin as a pair at 0 and 1.
//
// ⚠️ THE RULE DELIBERATELY DOES NOT REACH `init` OR `Decodable`, and claim 4 is what keeps
// it that way. A persisted route may carry `inputLow == inputHigh`; `windowed`'s own doc
// calls that identity, and a build that wrote such a route is entitled to keep behaving as
// it did (#527 — a stored document is not a bug to correct on load). Enforcing the gap at
// construction would silently re-tune every one of them on the next launch, with no way for
// anyone to notice.
//
// GRADING (§3). Claims 1-4 are END-TO-END BEHAVIOUR on a `public` Foundation-only value
// type — the strong kind. They do not compile against the parent (they call two methods this
// commit creates), so per §3 no assertion has a verdict there and the logic was transcribed
// in Python instead: an EXHAUSTIVE sweep of 1 250 edit sequences over a 25-point grid that
// includes out-of-range and near-boundary inputs, both orders, zero violations. Claim 5 is a
// SOURCE-TEXT SCAN and is a REGRESSION on the parent — four needles, but ONE finding
// reported four times (#486): the door does not exist there.
//
// ⛔ CLAIMS 6 AND 7 WERE BOOKED AS PURE COUNTERWEIGHTS IN THE FIRST DRAFT AND NEITHER IS.
// Driving the scans said so. Each SPLITS: claim 6's two `EchoelValueField` needles are red
// on the parent (same one absence again), while its `Slider`/`Stepper` ban is green on both;
// claim 7's `minInputWindow` needle is red on the parent by anchor absence (a symbol this
// commit creates), while its two `clamp01` needles are the real counterweights, green on
// both. Booking a split claim by its more flattering half is the direction §3 warns about,
// so it is written out per needle rather than per method.
//
// ⚠️ WHAT NO TEST HERE CAN SHOW: that a window of [0,3…0,6] FEELS right on coherence. That
// is the founder's ear on a device (board AU2 says so: "UI-Knopf + Founder-Feel-Tuning").
// What is checkable is that the control exists, cannot lie, and does what its label says.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheSensitivityWindowHasADoorTests: XCTestCase {

    private static let matrix = "Sources/Echoelmusic/Core/ModulationMatrix.swift"
    private static let patchbay = "Sources/Echoelmusic/Studio/PatchbayView.swift"

    private func makeRoute(low: Float = 0, high: Float = 1) -> ModRoute {
        ModRoute(source: .coherence,
                 destination: ModDestination(ModDestinationKey.tempo),
                 inputLow: low, inputHigh: high)
    }

    // MARK: - Claim 1 — no edit can close the window (END-TO-END BEHAVIOUR)

    /// Exhaustive over a grid that includes both boundaries, both out-of-range directions
    /// and both edit orders. A property, not a sample: the whole point of putting the rule
    /// on the type is that no sequence of finger movements can reach a degenerate window.
    func testNoEditSequenceLeavesADegenerateWindow() {
        var probes: [Float] = (0...20).map { Float($0) / 20 }
        probes.append(contentsOf: [-0.5, 1.5, 0.001, 0.999])

        for a in probes {
            for b in probes {
                var lowFirst = makeRoute()
                lowFirst.setInputLow(a)
                lowFirst.setInputHigh(b)

                var highFirst = makeRoute()
                highFirst.setInputHigh(b)
                highFirst.setInputLow(a)

                for (order, r) in [("low then high", lowFirst), ("high then low", highFirst)] {
                    XCTAssertGreaterThanOrEqual(r.inputHigh - r.inputLow,
                                                ModRoute.minInputWindow - 1e-6, """
                        Editing \(order) with (\(a), \(b)) left a window of \
                        \(r.inputHigh - r.inputLow). `windowed(_:)` answers a window this \
                        narrow with IDENTITY, so the route would show two numbers and shape \
                        nothing — the exact lying dial the setters exist to prevent.
                        """)
                    XCTAssertTrue(r.inputLow >= 0 && r.inputHigh <= 1, """
                        Editing \(order) with (\(a), \(b)) left an edge outside [0,1]: \
                        [\(r.inputLow), \(r.inputHigh)]. Both setters clamp before pairing.
                        """)
                }
            }
        }
    }

    // MARK: - Claim 2 — the pair pins at the ends (END-TO-END BEHAVIOUR)

    /// At the extremes there is no room to push the other edge, so the pair moves as a unit.
    /// Without this the setters would have to REFUSE the drag, which leaves a player pressed
    /// against an invisible wall with no way to move the window as a whole.
    func testThePairPinsAtBothEnds() {
        var top = makeRoute()
        top.setInputLow(1.0)
        XCTAssertEqual(top.inputHigh, 1.0, accuracy: 1e-6, "Dragging the low edge to the top must leave the high edge at 1.")
        XCTAssertEqual(top.inputLow, 1.0 - ModRoute.minInputWindow, accuracy: 1e-6, """
            Dragging the low edge to 1 must pin the pair at the top of the range, not \
            produce an impossible window.
            """)

        var bottom = makeRoute()
        bottom.setInputHigh(0.0)
        XCTAssertEqual(bottom.inputLow, 0.0, accuracy: 1e-6, "Dragging the high edge to the bottom must leave the low edge at 0.")
        XCTAssertEqual(bottom.inputHigh, ModRoute.minInputWindow, accuracy: 1e-6, "Mirror of the pin at the top.")
    }

    // MARK: - Claim 3 — the window actually expands (END-TO-END BEHAVIOUR)

    /// The whole point: a value in the middle of the body's real operating range must reach
    /// the middle of the destination's travel, not a third of it.
    func testTheWindowExpandsTheBodysOperatingRange() {
        var narrow = makeRoute()
        narrow.setInputLow(0.3)
        narrow.setInputHigh(0.6)

        XCTAssertEqual(narrow.windowed(0.45), 0.5, accuracy: 1e-5, """
            A coherence of 0.45 sits halfway through the typical ~[0,3…0,6] operating range \
            and must reach halfway through the destination. It did not, so the remap is not \
            being applied and the route is as flat as it was before the door.
            """)
        XCTAssertEqual(narrow.windowed(0.2), 0, accuracy: 1e-6, "Below the window is none of the travel.")
        XCTAssertEqual(narrow.windowed(0.9), 1, accuracy: 1e-6, "Above the window is all of the travel.")

        XCTAssertEqual(makeRoute().windowed(0.45), 0.45, accuracy: 1e-6, """
            The DEFAULT window must still be identity. If this moved, every route created \
            before this commit changed its sound on the next launch — which is the one thing \
            AU2's primitive was designed not to do.
            """)
    }

    // MARK: - Claim 4 — construction is NOT repaired (COUNTERWEIGHT, END-TO-END)

    /// The #527 protection, and the reason it is a claim rather than a comment: the obvious
    /// "tidy-up" is to move the pairing rule into `init` so the invariant holds everywhere.
    /// That would rewrite every persisted degenerate route on load, silently.
    func testConstructionKeepsADegenerateWindowAsItWasSaved() {
        let stored = makeRoute(low: 0.5, high: 0.5)
        XCTAssertEqual(stored.inputLow, 0.5, accuracy: 1e-6)
        XCTAssertEqual(stored.inputHigh, 0.5, accuracy: 1e-6, """
            `init` widened a window that a previous build saved closed. A stored document is \
            not a bug to correct on load — `windowed(_:)` answers a closed window with \
            identity on purpose, and that is the behaviour that route already had.
            """)
        XCTAssertEqual(stored.windowed(0.45), 0.45, accuracy: 1e-6, "A closed window is identity, as its own doc says.")

        var edited = stored
        edited.setInputLow(0.3)
        XCTAssertGreaterThanOrEqual(edited.inputHigh - edited.inputLow,
                                    ModRoute.minInputWindow - 1e-6, """
            The FIRST edit of a saved degenerate window must repair it. Otherwise the only \
            routes a player cannot fix are the ones already broken.
            """)
    }

    // MARK: - Claim 5 — the door exists and goes through the setters (SOURCE-TEXT SCAN)

    func testTheRoutingRowMountsBothEdgesThroughTheSetters() throws {
        let code = SourceText.codeOnly(try rawText(Self.patchbay))
        let row = try Self.bodyOfMember(startingWith: "private struct ModulationRouteRow: View {", in: code)

        XCTAssertTrue(row.contains("value: inputLowBinding"), """
            The routing row no longer mounts the window's lower edge. Without it \
            `ModRoute.inputLow` has no writer again and every route runs the identity \
            window — the #1408 defect returning.
            """)
        XCTAssertTrue(row.contains("value: inputHighBinding"), "The upper edge is no longer mounted.")
        XCTAssertTrue(row.contains("setInputLow("), "The lower edge's binding no longer routes through the pairing setter.")
        XCTAssertTrue(row.contains("setInputHigh("), "The upper edge's binding no longer routes through the pairing setter.")

        for raw in ["$route.inputLow", "$route.inputHigh"] {
            XCTAssertFalse(row.contains(raw), """
                The row writes \(raw) directly. A raw binding on the stored property skips \
                the pairing rule, so a player can drag one edge past the other and \
                `windowed(_:)` falls back to identity — two numbers beside a route that has \
                stopped doing anything (#164/#227).
                """)
        }
    }

    // MARK: - Claim 6 — one control everywhere (SPLIT: two REGRESSIONS + a COUNTERWEIGHT)

    /// The two `EchoelValueField` needles are red on the parent by the same one absence as
    /// claim 5; the `Slider`/`Stepper` ban is the counterweight, green on both. It is here
    /// because a "range" is exactly the kind of parameter a raw `Slider` attracts, and the
    /// app-wide law is a number field.
    func testTheRowUsesTheOneParameterControl() throws {
        let code = SourceText.codeOnly(try rawText(Self.patchbay))
        let row = try Self.bodyOfMember(startingWith: "private struct ModulationRouteRow: View {", in: code)

        // ⚠️ NAMED, NOT COUNTED. The first draft asserted `EchoelValueField(` occurs at least
        // four times, and a count pin is the shape #903 documents rotting silently: a future
        // slice that legitimately removes `Smooth` would red a guard about a rule it did not
        // break. These two needles pin the LAW at the two rows this commit adds.
        XCTAssertTrue(row.contains("EchoelValueField(label: \"Bio min\""), """
            The lower edge is no longer an `EchoelValueField`. Every adjustable NUMERIC \
            parameter in this app uses that one control so reading and interaction are \
            identical everywhere.
            """)
        XCTAssertTrue(row.contains("EchoelValueField(label: \"Bio max\""), "The upper edge is no longer an `EchoelValueField`.")
        for banned in ["Slider(", "Stepper("] {
            XCTAssertFalse(row.contains(banned), """
                The routing row introduced a raw SwiftUI \(banned.dropLast()). The app-wide \
                rule is `EchoelValueField` for every adjustable NUMERIC parameter; a named \
                choice stays a `Picker`, which is why `curve` and the two menus are untouched.
                """)
        }
    }

    // MARK: - Claim 7 — the rule stays off the decode path (SPLIT, SOURCE-TEXT SCAN)

    /// Pins claim 4's decision in the source as well as in behaviour, because the behavioural
    /// claim only covers `init` — the `Decodable` path is a second door into the same state
    /// and a guard that drove only one of them would read as covering both.
    func testTheGapRuleNeverReachesConstructionOrDecoding() throws {
        let code = SourceText.codeOnly(try rawText(Self.matrix))

        XCTAssertTrue(code.contains("self.inputLow = ModulationMatrix.clamp01(inputLow)"), """
            `init` no longer stores the lower edge as a plain clamp. If the pairing rule \
            moved here, every persisted closed window is silently widened on the next launch.
            """)
        XCTAssertTrue(code.contains("inputLow = ModulationMatrix.clamp01(try c.decodeIfPresent(Float.self, forKey: .inputLow) ?? 0)"), """
            The decoder no longer stores the lower edge as a plain clamp with an identity \
            default. Both halves matter: the clamp keeps a corrupt file in range, and the \
            `?? 0` is what makes a pre-AU2 route decode to the identity window.
            """)
        XCTAssertTrue(code.contains("public static let minInputWindow"), "The pairing floor is gone; the two setters have nothing to enforce.")
    }

    // MARK: - Helpers

    /// Brace-matched extraction, not a fixed line window — this repo writes 30-40 line
    /// comment blocks and `SourceText.codeOnly` preserves line count (#408).
    private static func bodyOfMember(startingWith anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else {
            throw XCTSkip("""
                the declaration `\(anchor)` is not present — this guard reads a member body, \
                so it SKIPS rather than reporting a green it did not earn. If it was renamed, \
                re-anchor it here in the same commit (#456).
                """)
        }
        var depth = 0
        var body = ""
        for ch in code[start.lowerBound...] {
            if ch == "{" { depth += 1 }
            if depth > 0 { body.append(ch) }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return body }
            }
        }
        throw XCTSkip("unbalanced braces after `\(anchor)` — extraction cannot be trusted")
    }

    private func rawText(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("""
                \(relativePath) is not present — this guard inspects source text, so it SKIPS \
                rather than reporting a green it did not earn (#454)
                """)
        }
        return try String(contentsOf: path, encoding: .utf8)
    }

    private func repoRoot() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
