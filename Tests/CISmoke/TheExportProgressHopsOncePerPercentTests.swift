// TheExportProgressHopsOncePerPercentTests.swift
// Echoel — #1335. `SingleExport.renderWithGain` submitted one `Task { @MainActor }` per
// decoded sample buffer to move a progress bar. That is the 10.76.48 shape CLAUDE.md names
// by its symptom: "Sobald Biofeedback läuft kann ich nicht mehr auswählen" — a flood of tiny
// main-actor task submissions starves the SwiftUI executor and an open `.menu` Picker stops
// responding.
//
// ⭐ WHY IT IS A FLOOD AND NOT A TRICKLE, which is the half a reader has to check before
// believing the finding: the pull loop sets `expectsMediaDataInRealTime = false` and drains
// `copyNextSampleBuffer()` in a `while writerInput.isReadyForMoreMediaData` loop. It is an
// OFFLINE export — it runs as fast as the encoder accepts data, not at 1× playback. A few
// minutes of 44.1 kHz audio is thousands of buffers, delivered within seconds. The 10.76.48
// precedent was ~30 submissions/second from a camera; this is faster.
//
// ⭐ AND THE INFORMATION ARGUMENT IS WHY THE REPAIR COSTS NOTHING. A progress bar has at most
// 100 visible steps. Every submission past the hundredth carried no information — it was pure
// executor load. The throttle is an integer compare on a serial queue.
//
// ⚠️ THE REPAIR INTRODUCED A TRAP RISK AND HAD TO CLOSE IT IN THE SAME LINE (#1174). The old
// spelling `Swift.min(Swift.max(progress, 0), 0.99)` lets NaN through — CLAUDE.md's own
// argument-order law says `max(NaN, 0)` returns NaN, and an invalid PTS produces one. NaN in a
// progress bar is cosmetic; `Int(NaN * 100)`, which the throttle needs, is a Swift TRAP that
// kills the test host with no assertion message and reads exactly like #396 from outside.
// `clamped(to:)` (`Core/FloatingPointClamp.swift`) maps NaN to the lower bound. Claim 3 drives
// that, and it is the one END-TO-END claim here.
//
// ⚠️ THIS GUARD DOES NOT FORBID A SECOND MAIN-ACTOR HOP (#364). It forbids an UNTHROTTLED one.
// If a second hop is genuinely needed, claim 2's count moves WITH a sentence saying why that
// hop is not per-buffer — the pin exists to make the trade conscious, not to freeze the file.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — **9 assertions across three claims**
// (claim 1 = 3, claim 2 = 3, claim 3 = 3), transcribed in Python and driven against BOTH trees.
// On the parent (`854793c`): **exactly 1 red** — the `guard`'s `XCTFail`, which is the
// anchor-absence form (#486: one absence, reported once). **2 are UNREACHED there, which is
// NOT the same as green**: the `guard` RETURNS, so `c1.order` and `c1.hop` never execute on a
// tree without the throttle, and booking them as regressions would be the flattering direction
// (#433/#464). The other **6 are COUNTERWEIGHTS** (#343), green on both trees, and they carry
// the file: the offline premise that makes this a flood, the drain loop, and the NaN behaviour
// of the clamp the throttle now depends on. Without them a tree that simply DELETED the
// progress update would pass claim 1 — an absent hop is trivially "inside the gate".
// ⛔ The first draft of this paragraph said "**2 red … the slice anchor and the needle inside
// it fail together**". They cannot fail together: one is in the `else` branch that returns
// past the other. The transcription said 3 not-PASS and two of those were marked
// skipped-by-return; reading that as "2 red" would have over-credited the slice by one, in a
// guard whose own subject is a count that nobody re-derived.
// LIMITS (§1): claims 1 and 2 are a SOURCE-TEXT SCAN — `renderWithGain` is a private `async`
// AVFoundation method no test bundle can drive. Claim 3 is END-TO-END on a Foundation-only
// value type. That the export still shows smooth progress on a phone is a DEVICE PROBE and is
// NOT claimed here.

import Foundation
import XCTest
// `@testable` IS LOAD-BEARING HERE, unlike in the pure source-text guards next door: claim 3
// calls `clamped(to:)`, an INTERNAL extension in `Core/FloatingPointClamp.swift`. Without this
// line it is `cannot find member` → `** TEST BUILD FAILED **` → the whole blocking bundle stops
// running, which is the `f489a6e` defect recorded in `Tests/CISmoke/CLAUDE.md` §5b. Caught by
// reading the file's imports against the symbols it uses, NOT by any of the seven checkers —
// they all read needles as DATA and are blind to Swift that will not compile (#1280).
@testable import Echoelmusic

final class TheExportProgressHopsOncePerPercentTests: XCTestCase {

    private static let export = "Sources/Echoelmusic/Audio/SingleExport.swift"

    /// Claim 1 — the one main-actor hop sits INSIDE the per-percent gate.
    /// Anchored on a brace-free relationship rather than a line window (#408): the slice runs
    /// from the gate to the `append` that ends the per-buffer work, so inserting prose between
    /// them cannot break it.
    func testTheHopIsInsideTheThrottle() throws {
        let code = SourceText.codeOnly(try Self.text(Self.export))
        guard let gate = code.range(of: "if percent != lastProgressPercent {"),
              let end = code.range(of: "writerInput.append(sampleBuffer)") else {
            return XCTFail(
                "ANCHOR MISSING (#454): `SingleExport` has no per-percent gate around its "
                + "progress update. On the parent this is the finding itself — the hop ran "
                + "once per decoded sample buffer. If the throttle was removed on purpose, "
                + "say in the same commit what now keeps thousands of main-actor submissions "
                + "off the SwiftUI executor during an offline export.")
        }
        XCTAssertLessThan(gate.lowerBound, end.lowerBound,
                          "the gate no longer precedes the end of the per-buffer block — the "
                          + "slice below would read the wrong region.")
        let throttled = String(code[gate.lowerBound..<end.lowerBound])
        XCTAssertTrue(throttled.contains("Task { @MainActor"),
                      "the main-actor hop has moved OUT of the per-percent gate. That restores "
                      + "the 10.76.48 flood: one submission per decoded buffer, thousands "
                      + "within seconds, on a loop that is explicitly NOT real time.")
    }

    /// Claim 2 — counterweight: there is no SECOND, ungated hop, and the premises hold.
    func testNoOtherMainActorHopAndThePremisesHold() throws {
        let code = SourceText.codeOnly(try Self.text(Self.export))
        // COUNT PIN — legal to move (#364), but not silently.
        XCTAssertEqual(
            Self.occurrences(of: "Task { @MainActor", in: code), 1,
            "`SingleExport` has gained a main-actor hop. That is legal — but claim 1 only "
            + "proves the PROGRESS hop is throttled, so a second one is unguarded by this "
            + "file. Move this number together with a sentence saying why the new hop cannot "
            + "fire per sample buffer.")
        XCTAssertTrue(code.contains("writerInput.expectsMediaDataInRealTime = false"),
                      "the export is no longer declared offline. That is the premise the whole "
                      + "finding rests on: at 1× playback a per-buffer hop would be a trickle, "
                      + "and the throttle would be over-engineering rather than a fix.")
        XCTAssertTrue(code.contains("while writerInput.isReadyForMoreMediaData"),
                      "the drain loop is gone — the other half of the same premise.")
    }

    /// Claim 3 — END-TO-END: the clamp the throttle depends on is NaN-safe, so the `Int(…)`
    /// conversion the gate performs cannot trap (#1174). Foundation-only, no AVFoundation.
    func testTheClampCannotHandANaNToTheIntConversion() {
        XCTAssertEqual(Float.nan.clamped(to: 0...0.99), 0,
                       "`clamped(to:)` stopped mapping NaN to the lower bound. The export "
                       + "throttle does `Int(shown * 100)` — with NaN that is a Swift trap "
                       + "that kills the test host with no assertion message, indistinguishable "
                       + "from #396 in a job log.")
        // The counterweight that names WHY the old spelling was not good enough.
        XCTAssertTrue(Swift.max(Float.nan, 0).isNaN,
                      "`max(NaN, 0)` no longer returns NaN — CLAUDE.md's argument-order law "
                      + "would then be wrong, and the reason this line was changed disappears.")
        XCTAssertEqual(Float(1.5).clamped(to: 0...0.99), 0.99,
                       "the clamp stopped bounding above; progress could report past 100 %.")
    }

    private static func occurrences(of needle: String, in text: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var i = text.startIndex
        while let r = text.range(of: needle, range: i..<text.endIndex) {
            count += 1
            i = r.upperBound
        }
        return count
    }

    private static func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
