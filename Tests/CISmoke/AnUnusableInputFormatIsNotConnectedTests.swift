// AnUnusableInputFormatIsNotConnectedTests.swift
// Echoel — #1269. The founder's v10.79.469 (2589) device log ends in SIGABRT, and the
// breadcrumb ladder (#859) names the step: the app connected the input node while that node
// had no hardware format at all.
//
// ⭐ THE LOG, and why it decides rather than suggests:
//     monitor: on: prepared before format read (#1251)
//     monitor: input format from session fallback (node unusable — #823:
//                                  node 0.0 Hz/2 ch, session 48000.0 Hz/1 ch)
//     monitor: on 2/5: attaching monitor nodes
//     monitor: on 3/5: connecting input → notch (edge 48000.0 Hz/1 ch,
//                                  session 48000.0 Hz/1 ch, out 48000.0 Hz/2 ch)
//     CRASH exception: com.apple.coreaudio.avfaudio: Input HW format is invalid
// The edge and the session were IDENTICAL and it aborted anyway. `connect(…)` from an input
// node validates THE NODE'S OWN hardware format, not the format argument — so with the input
// scope unestablished (0 Hz) any connect from that node throws, whatever is passed. #823's
// substitution therefore could never rescue this case: it turned a clean bail-out into a
// guaranteed uncatchable ObjC abort, by walking past the very guard #823 itself built.
//
// ⭐ AND THE SAME LOG REFUTES THE TWO STANDING HYPOTHESES IN `AudioEngine`'s own comment:
// #4 ("if edge and session are IDENTICAL and it still aborts, the mismatch is not in this
// format") fired its own discriminator; #5 (`prepare()` rebuilds the input scope) is IN this
// build — its `#1251` rung printed — and the node still read 0.0 Hz two lines later. The
// comment names what follows from that: hypothesis #6 (connect on the RUNNING engine) is the
// next candidate. This slice does not take it.
//
// ⛔ WHAT THIS FILE DOES NOT CLAIM. It does not claim monitoring WORKS. It cannot: the node's
// placeholder is read 2 ms after `setActive`, a route change is asynchronous, and
// `setInputMonitoring` is synchronous so nothing here may wait. What it pins is that the
// unusable case takes the EXIT — which already logs, hands the record route back and restores
// the engine — instead of the connect. A feature that declines to start and says so beats a
// feature that aborts the app.
//
// ⛔ AND IT DELIBERATELY CARRIES A COUNTERWEIGHT (claim 4). The obvious over-correction is to
// delete the session substitution outright. That would re-open #954 — the v10.79.433 crash,
// where the node had a VALID format whose rate was merely stale. Those two cases are mutually
// exclusive by construction, and only one of them is withdrawn here.

import Foundation
import XCTest

final class AnUnusableInputFormatIsNotConnectedTests: XCTestCase {

    private static let engine = "Sources/Echoelmusic/Audio/AudioEngine.swift"

    private func source() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // Tests/CISmoke
            .deletingLastPathComponent()      // Tests
            .deletingLastPathComponent()      // repo root
            .appendingPathComponent(Self.engine)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(Self.engine) not present — this scan cannot report green")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// claim 1 (THE FIX) — the unusable case must not reach the substitution at all.
    func testTheUnusableCaseDoesNotSubstituteAFormat() throws {
        let code = try source()
        XCTAssertFalse(code.contains("if nodeFormatUnusable || nodeDisagreesWithHardware"), """
            The substitution is reachable again for an unusable node format. That is the exact \
            shape of the v10.79.469 SIGABRT: a 0 Hz input node is handed a session format and \
            connected anyway, and `connect(…)` validates the NODE's hardware format rather than \
            the argument — so it throws an ObjC exception no Swift `catch` can see.
            """)
        XCTAssertTrue(code.contains("if nodeDisagreesWithHardware {"), """
            The substitution branch is no longer guarded by `nodeDisagreesWithHardware` alone. \
            If the condition changed shape, re-check that an unusable node format still falls \
            through to the bail-out below rather than into a connect.
            """)
    }

    /// claim 2 (THE PREMISE) — the two cases stay mutually exclusive, which is what makes
    /// claim 1 a complete statement rather than half of one.
    func testTheTwoFormatCasesStayMutuallyExclusive() throws {
        let code = try source()
        XCTAssertTrue(code.contains("let nodeFormatUnusable = inFmt.sampleRate <= 0 || inFmt.channelCount == 0"), """
            `nodeFormatUnusable` is gone or reworded. It is the test for "the input scope was \
            never established", and both the exclusion in `nodeDisagreesWithHardware` and the \
            bail-out's own log line are stated in terms of it.
            """)
        XCTAssertTrue(code.contains("let nodeDisagreesWithHardware = !nodeFormatUnusable"), """
            `nodeDisagreesWithHardware` no longer excludes the unusable case. Without that \
            exclusion the two branches overlap and an unusable format can reach the \
            substitution through the OTHER condition — claim 1 would still pass while the \
            crash returned.
            """)
    }

    /// claim 3 (THE EXIT) — pin the BRANCH, not the sentence. A log line that says "not
    /// connecting" above code that connects would keep a string scan green; the property is
    /// that this exit hands the route back, un-strands the engine, and returns.
    func testTheUnusableCaseLeavesTheGraphAloneAndSaysSo() throws {
        let code = try source()
        guard let exit = code.range(of: "input format unusable after the session claim") else {
            return XCTFail("""
                The bail-out for an unusable input format is gone from \(Self.engine). It is the \
                only thing standing between a 0 Hz input node and an uncatchable abort.
                """)
        }
        let branch = String(code[exit.lowerBound...].prefix(1600))
        XCTAssertTrue(branch.contains("releaseRecordRoute(.inputMonitoring)"), """
            The exit no longer hands the record route back. The claim is registered before the \
            format read, so leaving by this path without releasing keeps `.playAndRecord` \
            raised for the rest of the session.
            """)
        XCTAssertTrue(branch.contains("restoreEngineIfStranded(wasRunning"), """
            The exit no longer restores the engine. The route claim STOPS the master engine \
            (#628/#823), so returning without this leaves the whole app silent — music \
            included — which is #625b's failure shape on a different exit.
            """)
        XCTAssertTrue(branch.contains("return false"), """
            The exit no longer returns. Falling through from here reaches the attach and the \
            connect, which is the crash this file exists for.
            """)
        XCTAssertTrue(branch.contains("NOT connecting"), """
            The exit does not say that it declined to connect. The ladder's law (#882) is that \
            a step which does not run must SAY it did not; without it the next device log shows \
            a gap between rungs and reads as a death rather than a refusal.
            """)
    }

    /// claim 4 (COUNTERWEIGHT) — #954 survives. The disagreement case is a DIFFERENT crash
    /// (v10.79.433) with a valid node format and a stale rate, and its substitution is the fix
    /// for it. Deleting it here would trade one device abort for the other.
    func testTheHardwareDisagreementSubstitutionSurvives() throws {
        let code = try source()
        XCTAssertTrue(code.contains("inFmt = fallback"), """
            #954's substitution is gone. It is not what crashed in v10.79.469: there the node \
            had NO format. Where the node has a valid format whose rate is stale, the session's \
            rate is a real hardware fact and substituting it is what keeps the connect legal.
            """)
        XCTAssertTrue(code.contains("channels: inFmt.channelCount"), """
            The substitution stopped keeping the node's own channel count. The session's number \
            is clamped to 1...2; forcing it onto a node that reported mono manufactures the \
            converter #954 removed — a fix that can introduce the crash it prevents (#364).
            """)
    }
}
