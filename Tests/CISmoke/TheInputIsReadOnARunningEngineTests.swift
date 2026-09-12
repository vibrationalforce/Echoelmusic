// TheInputIsReadOnARunningEngineTests.swift
// Echoel — #1272 (A1 of the founder's 2026-09-11 ask, „Intelligentes absturzsicheres Audio
// Input"). HYPOTHESIS #6 of the `isInputConnToConverter` crash family is BUILT: the master
// engine is STARTED between the record-route claim and the input-format read, so the node's
// format is the hardware's and not the 0 Hz placeholder.
//
// WHY NOW, AND WHY THIS ONE. `AudioEngine.swift` has carried #6 as "recorded, to be tried
// ONLY if a device log shows #5 did not close the family" since #954b. A device log did:
// v10.79.469 (2589) logs `on: prepared before format read (#1251)` and, on the VERY NEXT
// line, `input format from session fallback (node unusable — #823: node 0.0 Hz/2 ch,
// session 48000.0 Hz/1 ch)`. `prepare()` therefore does not build the I/O unit's input
// scope. #823's own reasoning says what does: a `start()` under the record route. The stop
// at rung `on 1/5` and the claim were always the first two thirds of that sentence; this
// slice writes the third.
//
// ⚠️ ONE HYPOTHESIS PER SLICE is the law this family taught (v421–v469, seven labelled
// repairs). This slice changes exactly one thing about WHEN the engine runs and nothing
// about WHICH format is connected — #954's substitution, #1269's bail-out and #958b's rate
// rebuild are all untouched, so the next device log stays decidable.
//
// SOURCE-TEXT SCAN: order and presence inside `setInputMonitoring`. Whether starting the
// engine first makes `inputNode` report the hardware format is the hypothesis itself — a
// DEVICE PROBE, NEEDS-FOUNDER-VERIFY at the call site.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`0610210`) and this tree:
// claims 1, 2 and 3 RED on the parent (the start, its rung and the `|| monitorPreStarted`
// gate do not exist there), claim 5 RED on the parent by its "#6 IS BUILT" needle, claim 4
// GREEN on both (it is the counterweight — it must be green on both or it is not one).
// All five GREEN here. Claims 1–3 and 5 TRAGEND (4 of 5 verdicts flip); claim 4
// PROPHYLAKTISCH.

import Foundation
import XCTest

final class TheInputIsReadOnARunningEngineTests: XCTestCase {

    private static let engine = "Sources/Echoelmusic/Audio/AudioEngine.swift"

    private static let startRung = "on: starting engine before the input read (#1272)"
    private static let readRung = "on: touching the input node + reading its format"

    /// Claim 1 — the start exists once on the ON path, behind its own rung, and sits between
    /// the route claim and the format read. Order is the whole mechanism: a start BEFORE the
    /// claim builds the I/O unit against the playback-only session (the state #823 measured
    /// as producing the 0 Hz placeholder), and a start AFTER the read leaves the read exactly
    /// as stale as #1251 left it.
    func testTheEngineIsStartedBetweenTheClaimAndTheFormatRead() throws {
        let src = SourceText.codeOnly(try text(Self.engine))
        let on = try Self.member("func setInputMonitoring(_ on: Bool) -> Bool", in: src)
        XCTAssertEqual(on.components(separatedBy: Self.startRung).count - 1, 1, """
            the pre-read start rung is gone — a log can no longer say whether the engine was \
            running when the input node was read, which is the ONE thing #1272 changed (#1272)
            """)
        let claim = try XCTUnwrap(on.range(of: "claimRecordRoute(.inputMonitoring)")).lowerBound
        let prepare = try XCTUnwrap(on.range(of: "masterEngine.prepare()")).lowerBound
        let rung = try XCTUnwrap(on.range(of: Self.startRung)).lowerBound
        let start = try XCTUnwrap(on.range(of: "try masterEngine.start()", range: rung..<on.endIndex)).lowerBound
        let read = try XCTUnwrap(on.range(of: "var inFmt = input.inputFormat(forBus: 0)")).lowerBound
        XCTAssertLessThan(claim, rung,
                          "the pre-read start runs BEFORE the record-route claim — it would build the I/O unit against the playback-only session, which is the 0 Hz state itself (#823/#1272)")
        XCTAssertLessThan(prepare, rung,
                          "`prepare()` no longer precedes the pre-read start — #1251's rung then cannot say whether control died inside `prepare()` (#1251/#1272)")
        XCTAssertLessThan(rung, start,
                          "the rung stands AFTER the start it names — a ladder rung must precede its call, or a death inside the call is silent (#859/#860)")
        XCTAssertLessThan(start, read,
                          "the pre-read start runs AFTER the format read — the read is then the pre-start guess #1251 already shipped and v10.79.469 refuted (#1272)")
    }

    /// Claim 2 — a failed pre-read start must FALL THROUGH, not return. Two reasons, and the
    /// second is a guard-on-guard: the stopped-engine path is still complete, and
    /// `TheEngineLifecycleSpeaksInTheDiagLogTests` claim 16 requires `on 4/5` to keep a
    /// reachable SKIPPED emitter. A pre-start that always succeeds or always exits would
    /// redden that guard on a correct tree (#364).
    func testAFailedPreReadStartFallsThroughInsteadOfRefusing() throws {
        let src = SourceText.codeOnly(try text(Self.engine))
        let on = try Self.member("func setInputMonitoring(_ on: Bool) -> Bool", in: src)
        let from = try XCTUnwrap(on.range(of: Self.startRung)).upperBound
        let to = try XCTUnwrap(on.range(of: Self.readRung, range: from..<on.endIndex)).lowerBound
        let window = String(on[from..<to])
        XCTAssertTrue(window.contains("catch"), """
            the pre-read start has no `catch` — `start()` throws on a route iOS will not \
            grant, and an uncaught throw here would take the whole toggle down a path that \
            has worked since #625 (#1272)
            """)
        XCTAssertFalse(window.contains("return"), """
            the pre-read start refuses the toggle when it fails. It must fall through to the \
            stopped-engine path: that path is complete and guarded, and `on 4/5 SKIPPED: \
            engine was not running` has to stay REACHABLE or \
            `TheEngineLifecycleSpeaksInTheDiagLogTests` claim 16 goes red on a correct tree \
            (#364/#882/#1272)
            """)
        XCTAssertFalse(window.contains("try!"), "a force-try on the pre-read start — the throw is the case this window exists for")
    }

    /// Claim 3 — rung 4/5 is taken whenever the engine is running, not only when it was
    /// running BEFORE the toggle. Rung 4/5 is where the connected-vs-node-vs-session
    /// comparison is printed (#959), i.e. the line this crash family is triaged from; leaving
    /// it gated on `wasRunning` alone would make the healthy new path log `4/5 SKIPPED:
    /// engine was not running` while the engine demonstrably ran — a ladder lying about its
    /// own state (#878/#882).
    func testTheRestartRungAlsoCoversTheEngineWeStarted() throws {
        let src = SourceText.codeOnly(try text(Self.engine))
        let on = try Self.member("func setInputMonitoring(_ on: Bool) -> Bool", in: src)
        XCTAssertEqual(on.components(separatedBy: "if wasRunning || monitorPreStarted {").count - 1, 1, """
            rung 4/5's gate no longer reads the pre-read start. Either it is back to \
            `if wasRunning` — and the engine #1272 started gets no 4/5 line, so a healthy run \
            looks like a death at rung 3 — or the flag was renamed without this claim (#1272)
            """)
        let gate = try XCTUnwrap(on.range(of: "if wasRunning || monitorPreStarted {")).lowerBound
        let taken = try XCTUnwrap(on.range(of: "logMonitorOutcome(\"on 4/5: restarting")).lowerBound
        XCTAssertLessThan(gate, taken, "the 4/5 gate no longer precedes its taken rung — re-anchor (§4)")
    }

    /// Claim 4 — COUNTERWEIGHT, green on both trees. #1272 moves WHEN the engine runs and
    /// nothing else: the ladder still announces five rungs on the ON side, `on 4/5` still has
    /// both emitters, #1269's refusal to connect an input node with no hardware format is
    /// untouched, and rung 1/5 still stops before the claim. If one of these went with the
    /// slice, the slice did more than it says.
    func testTheLadderAndTheBailOutSurvive() throws {
        let raw = try text(Self.engine)
        for rung in ["on 1/5", "on 2/5", "on 3/5", "on 4/5", "on 5/5"] {
            XCTAssertTrue(raw.contains("\"\(rung)"),
                          "rung `\(rung)` left the ON ladder — `scripts/diag-ladder.py` audits 1..5 (#854/#882)")
        }
        XCTAssertTrue(raw.contains("on 4/5 SKIPPED: engine was not running"),
                      "`on 4/5`'s SKIPPED emitter is gone — a gated step that does not run must say so (#882)")
        let src = SourceText.codeOnly(raw)
        let on = try Self.member("func setInputMonitoring(_ on: Bool) -> Bool", in: src)
        XCTAssertTrue(on.contains("input format unusable after the session claim"),
                      "#1269's bail-out is gone — an input node with no hardware format would be connected again, which is the founder's v10.79.469 SIGABRT (#1269)")
        XCTAssertTrue(on.contains("if wasRunning { masterEngine.stop() }"),
                      "rung 1/5 no longer stops the engine before the claim. The stop is two thirds of #823's sentence and #1272 is the third: stop releases the I/O unit, the claim changes the route, the start rebuilds the unit WITH an input scope (#823/#1272)")
    }

    /// Claim 5 — the hypothesis list says #6 is built. A triager reading "recorded, to be
    /// tried" after it has shipped would spend a device round proposing the code in front of
    /// them — the #425 shape (a note refuting its own code), and the most expensive kind here
    /// because a device round costs the founder, not a session.
    func testTheHypothesisListSaysSixIsBuilt() throws {
        let raw = try text(Self.engine)
        XCTAssertTrue(raw.contains("HYPOTHESIS #6 — connect the monitor chain on the RUNNING engine"),
                      "hypothesis #6's entry is gone — the history of what was tried is what keeps the next repair from repeating one (#1251)")
        XCTAssertTrue(raw.contains("#6 IS BUILT"),
                      "the hypothesis list still calls #6 unbuilt while the start sits in the code above it (#425/#1272)")
        XCTAssertTrue(raw.contains("v10.79.469"),
                      "the log that refuted #5 is no longer named. #5's `prepare()` call is still in the code, so without the log a reader cannot tell a live mechanism from a kept-for-free one (#1272)")
    }

    private static func member(_ marker: String, in src: String) throws -> String {
        let hits = src.components(separatedBy: marker).count - 1
        guard hits == 1, let start = src.range(of: marker) else {
            throw XCTSkip("anchor `\(marker)` occurs \(hits)× — re-anchor before trusting a zero (#408)")
        }
        guard let open = src[start.upperBound...].firstIndex(of: "{") else { return "" }
        var depth = 0
        var i = open
        while i < src.endIndex {
            let c = src[i]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(src[open...i]) } }
            i = src.index(after: i)
        }
        return String(src[open...])
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
