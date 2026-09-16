// TheWireCannotTrapTheAppTests.swift
// Echoel — #1321. Blocking bundle. Claims 1–3 are END-TO-END BEHAVIOUR on shipped, `public`,
// Foundation-only value types (`Tests/CISmoke/CLAUDE.md` §1) — the strong kind, and said so
// deliberately, because most of this bundle can only scan text. Claims 4–5 are SOURCE-TEXT.
// Nothing here proves a real console or a real peer behaves; that is a DEVICE PROBE and stays
// open.
//
// ⭐ WHY THIS FILE EXISTS. Three separate places converted an EXTERNALLY SUPPLIED floating
// point number to `Int` without bounding it first, and `Int(_:)` TRAPS in Swift for anything
// past `Int.max` — it is not a clamp and not an optional. All three took their input from
// outside the device:
//
//   · `OSCControlCommand.parse`, `key` and `visualStyle`: the range test sat ONE LINE AFTER
//     the conversion, so it never ran on the value that killed the process. The doc block
//     above it said bounds were checked there — a description of the intent, not of the code.
//   · `OSCControlCommand.parse`, `bpm`: no upper bound at all, and `summary` converted the
//     result on EVERY accepted cue, before the consumer's clamp could ever be reached.
//   · `LiveColaboView`'s peer row: the accessibility label converted a peer-supplied `Float`
//     while the VISIBLE cell eleven lines above already used the safe formatter for the same
//     value. `BioPeek`'s sanitizer answers finiteness only and says so; its own header calls
//     the magnitude gap a live hole.
//
// With OSC control input on and the allowlist empty — the documented default — one UDP
// datagram carrying a finite `1e30` was a remote kill mid-performance. The Colabo half needs
// an accepted peer, but fires during BODY EVALUATION, so it did not need VoiceOver to be on.
//
// ⭐ THE LAW, and it is wider than these three sites: **bound in the DOUBLE, then convert.** A
// range test placed after a lossy conversion is not a range test — the conversion is where the
// program dies. `.claude/rules/swift-audio.md` bans force-unwraps and unguarded division for
// exactly this reason and does not name `Int(someFloatingPoint)`; it belongs in that family.
//
// ⚠️ HOW THESE ASSERTIONS FAIL. A Swift trap is not catchable: if a bound is removed again, the
// test process DIES rather than reporting a failure. So claims 1 and 3 are green, or the bundle
// crashes — there is no third outcome, and no message of mine would be printed. That is worth
// stating rather than implying a tidy red.
//
// ⚠️ ONE DELIBERATE BEHAVIOUR CHANGE IS PINNED HERE, NOT SMUGGLED. `bpm` now has an upper bound
// and its lower bound is `Transport.minTempo`, so 10 and 500 are IGNORED where they used to be
// accepted and silently clamped downstream. Claim 2 asserts both edges against the transport's
// own constants rather than a second spelling of them (#416).
//
// ⚠️ HONEST GRADING. No local Swift toolchain (§0). **18 assertions across five claims**
// (claim 1 = 3, claim 2 = 10, claim 3 = 2, claim 4 = 2, claim 5 = 1). All were transcribed in
// Python — `parse` and `summary` reimplemented from each tree's own source, including Swift's
// trapping `Int(_:)`, and the scans driven directly. On the PARENT tree (`eac9a3b`) **10 of 18
// are red**, covering **three defects**: the parse-order trap (claim 1's `key` and
// `visualStyle`, which on the parent do not fail but TRAP), the unbounded tempo (claim 1's
// `bpm`, claim 2's two new bound cases, and claim 3's pair — the summary traps there too), and
// the peer-row label (claim 4's pair). Claim 5's red is not a fourth defect: it is the newly
// published bound that follows from the second. On today's tree all 18 are green.
//
// The other 8 are COUNTERWEIGHTS (#343) and are green on BOTH trees: every legal value and
// every just-outside value behaves exactly as before, so a "repair" that bounded the parser
// into refusing real cues — the #364 way to make this file green — goes red instead.
import Foundation
import XCTest
@testable import Echoelmusic

final class TheWireCannotTrapTheAppTests: XCTestCase {

    private static let prefix = "/echoelmusic/ctrl/"

    private func parse(_ leaf: String, _ value: Float) -> OSCControlCommand? {
        OSCControlCommand.parse(.init(address: Self.prefix + leaf, arguments: [.float(value)]))
    }

    // MARK: - claim 1 (BEHAVIOUR) — a huge finite float off the wire is ignored, not fatal

    /// `1e30` is finite, so it passes every `isFinite` gate, and it is far past `Int.max`.
    /// This is the exact value a console or a byte-swapped sender can put on the wire.
    func testAHugeFiniteFloatIsIgnoredOnEveryNumericAddress() {
        XCTAssertNil(parse("key", 1e30), """
            `/echoelmusic/ctrl/key` accepted a value the app cannot hold. Before #1321 this line \
            did not fail — it TRAPPED, because the range test ran after `Int(v.rounded())`. \
            Bound the Double first, then convert.
            """)
        XCTAssertNil(parse("visualStyle", 1e30), """
            `/echoelmusic/ctrl/visualStyle` accepted a value the app cannot hold — same shape as \
            `key` above, same repair: the bound belongs in front of the conversion.
            """)
        XCTAssertNil(parse("bpm", 1e30), """
            `/echoelmusic/ctrl/bpm` accepted an unbounded tempo. The consumer's clamp cannot \
            save this one: `summary` converts on every accepted cue, one line before the \
            consumer is reached, and even when the BPM lock is off.
            """)
    }

    // MARK: - claim 2 (BEHAVIOUR, counterweights) — every legal cue still lands

    func testTheLegalRangesStillParseAndTheirEdgesStillDont() {
        XCTAssertEqual(parse("key", 0), .key(0))
        XCTAssertEqual(parse("key", 11), .key(11), "B must still be reachable — 11 is in range.")
        XCTAssertNil(parse("key", 12), "12 is not a pitch class; it was refused before #1321 too.")
        XCTAssertEqual(parse("visualStyle", 0), .visualStyle(0))
        XCTAssertEqual(parse("visualStyle", 9), .visualStyle(9), "look 9 is the last index.")
        XCTAssertNil(parse("visualStyle", 10), "10 is past the look index space.")
        XCTAssertEqual(parse("bpm", Float(Transport.minTempo)), .tempo(Transport.minTempo), """
            The slowest tempo the transport can hold must still arrive over the wire. This \
            asserts against `Transport.minTempo`, not a second spelling of it (#416).
            """)
        XCTAssertEqual(parse("bpm", Float(Transport.maxTempo)), .tempo(Transport.maxTempo),
                       "The fastest tempo the transport can hold must still arrive.")
        XCTAssertNil(parse("bpm", Float(Transport.minTempo) - 1), """
            A tempo below the transport's floor is now IGNORED rather than accepted and \
            silently clamped downstream (#1321, deliberate). If that was reverted on purpose, \
            move this assertion and the doc block on `parse` in the SAME commit.
            """)
        XCTAssertNil(parse("bpm", Float(Transport.maxTempo) + 1),
                     "A tempo above the transport's ceiling is ignored — the half that was "
                     + "missing entirely and made the trap reachable.")
    }

    // MARK: - claim 3 (BEHAVIOUR) — the diagnostic line cannot be the thing that kills the app

    /// `OSCControlCommand` is `public`, so `parse` is not the only way a case is built. A
    /// summary string is the last place that may take a performance down.
    func testTheSummaryOfAnAbsurdTempoIsBoundedRatherThanFatal() {
        let line = OSCControlCommand.tempo(1e30).summary
        XCTAssertTrue(line.hasPrefix("bpm "), "The summary's shape is part of the diag format.")
        XCTAssertEqual(line, "bpm \(Int(Transport.maxTempo.rounded()))", """
            A hand-constructed absurd tempo no longer reports as the transport's ceiling. \
            Before #1321 this line did not fail — it trapped. The clamp is defence in depth: \
            `parse` bounds the wire path, this bounds every other caller.
            """)
    }

    // MARK: - claim 4 (SOURCE-TEXT, counterweight) — spoken and drawn come from one formatter

    func testThePeerRowSpeaksTheNumberItDraws() throws {
        let view = try source("Sources/Echoelmusic/Studio/LiveColaboView.swift")
        XCTAssertFalse(view.contains("\"\\(Int(bpm)) beats per minute\""), """
            The Live Colabo peer row converts a peer-supplied Float with `Int(_:)` again. \
            `BioPeek` sanitizes finiteness ONLY — deliberately, because narrowing a finite \
            reading would invent a number the body never produced — so magnitude arrives \
            unchecked. This label is built during body evaluation, so it fires for every user, \
            not only with VoiceOver on.
            """)
        XCTAssertTrue(view.contains("EchoelDecimalText.string(bpm, decimals: 0)) beats per minute"),
                      """
                      The accessibility label no longer speaks the number through the same \
                      formatter the visible cell draws it with. Spoken and drawn must agree — \
                      that is this file's "legible numbers first" law, and it is also what \
                      removes the `Int(_:)`.
                      """)
    }

    // MARK: - claim 5 (SOURCE-TEXT, counterweight) — the published contract names the bound

    func testTheIntegrationsTablePublishesTheTempoBound() throws {
        XCTAssertTrue(try source("docs/integrations.html").contains("float or int, 30&ndash;300"),
                      """
                      `docs/integrations.html` no longer states the tempo range a cue must sit \
                      in. #1321 made the parser REJECT what it used to clamp; an integrator \
                      reading the table needs to know that, or their console will look broken.
                      """)
    }

    // MARK: - file access (§0 — FAIL on a missing anchor, never skip it away)

    private func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        guard let body = try? String(contentsOf: root.appendingPathComponent(relative),
                                     encoding: .utf8), !body.isEmpty else {
            XCTFail("ANCHOR MISSING: \(relative) could not be read while the tree is present "
                    + "— a missing anchor is a finding, not a pass (#454).")
            return ""
        }
        return body
    }
}
