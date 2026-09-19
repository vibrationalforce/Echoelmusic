// SOURCE-TEXT SCAN (§1). It proves where the calls and the clears SIT, not that a second
// take behaves differently on a device — that is a DEVICE PROBE and stays open.
//
// ── WHAT #1380 FOUND ────────────────────────────────────────────────────────────────
// `CameraRPPGBioPublisher.stop()` tore down the camera, the estimator, the respiration
// window and the coherence history, and left the FINGER-CONTACT decision standing:
// `isFingerDetected`, `fingerDetectionBuffer`, `fingerTrueCount`, `brightness` and
// `redChannel` survive a take. `startPulseDetection()` runs `resetPulseState(keepEstimate:
// false)`, which clears the optical WINDOW and none of those five; the only thing that
// clears them is `CameraAnalyzer.reset()`, and it had ZERO callers in `Sources/`.
//
// The cost is not cosmetic, because both halves of the acquisition hysteresis read the
// stale `true`: `isFingerFrame(… wasDetected:)` drops the red floor from the ACQUIRE
// value to the HOLD value ("acquisition is never loosened", says its own doc), and
// `updateFingerDetection` needs a quarter of the window instead of half — over a buffer
// still full of the previous take's `true`s. A new take could therefore open reporting a
// finger on a lens nothing was touching, which is precisely the state the acquire floor
// exists to refuse.
//
// ── WHY THE CLEAR IS AT THE BOUNDARY AND NOT IN `resetPulseState` ──────────────────
// The one-line version — move the five clears down into `resetPulseState` — also fires on
// all five `resetForRecovery` sites, one of which is the finger-loss flush. Dropping the
// contact lock there is exactly what the hysteresis prevents (a glare flicker would restart
// the trust climb). Claim 3 pins that asymmetry so the cheap version cannot be applied by
// someone reading only claim 1.
//
// ── GRADING AGAINST THE PARENT (§3) ────────────────────────────────────────────────
// Transcribed in Python against `git show HEAD:<path>` and the worktree; no Swift toolchain
// here (§0).
//   · REGRESSIONS: claims 1 and 5 (the call did not exist on the parent) and claim 6
//     (`isTorchAvailable` occurred nowhere in `Sources/` before this slice).
//   · COUNTERWEIGHTS, green on BOTH trees: claims 2, 3, 4, 7 — and they are the point of
//     the file. Claim 4 is the premise that makes claim 1 mean anything; claim 7 keeps a
//     branch that is unreachable on the shipped target but carries the iPad reason.
//   · ANCHOR ABSENCE: none.
//
// ⚠️ #364 — the shapes are pinned, never the values. Claim 4 asks that the two floors stay
// ASYMMETRIC (a ternary on `wasDetected` / on `isFingerDetected`), not that they are 0.28
// and 0.12; retuning either number is ordinary work and must stay green. Moving the clear
// from `stop()` to the START of a take would red claim 1 and is a rewrite of this file, not
// a violation — claim 5 is the half that survives it.

import Foundation
import XCTest

final class TheTakeBoundaryClearsTheContactLockTests: XCTestCase {

    private static let publisher = "Echoelmusic/Bio/CameraRPPGBioPublisher.swift"
    private static let analyzerFile = "Echoelmusic/Video/CameraAnalyzer.swift"
    private static let captureFile = "Echoelmusic/Video/CameraCapture.swift"

    /// The three fields that decide whether a finger is on the lens, plus the two optical
    /// levels that feed the placement cue. Named once (#416).
    private static let contactFields = [
        "isFingerDetected",
        "fingerDetectionBuffer",
        "fingerTrueCount",
    ]

    /// 1 — the take boundary forgets the body. REGRESSION on the parent.
    func testTheTakeBoundaryCallsTheFullReset() throws {
        let code = try Self.codeText(Self.publisher)
        guard let stop = Self.body(of: "public func stop()", in: code) else {
            return XCTFail("`public func stop()` not found in \(Self.publisher) — re-anchor (#454).")
        }
        XCTAssertTrue(stop.contains("analyzer.reset()"), """
            `stop()` does not call `analyzer.reset()`. `stopPulseDetection()` only writes \
            `isPulseDetecting = false`, and the next take's `startPulseDetection()` runs \
            `resetPulseState(keepEstimate: false)`, which clears the optical window and NONE of \
            \(Self.contactFields.joined(separator: " / ")). The new take then opens holding the \
            previous take's contact decision, so the acquire floor is replaced by the hold floor \
            over a detection buffer already full of `true` — a finger reported on a lens nothing \
            is touching. If the clear moved to the START of a take instead, rewrite this claim; \
            claim 5 is the half that does not care which boundary carries it.
            """)
    }

    /// 2 — and the thing it calls really clears them. COUNTERWEIGHT.
    func testTheFullResetClearsEveryContactField() throws {
        let code = try Self.codeText(Self.analyzerFile)
        guard let reset = Self.body(of: "func reset()", in: code) else {
            return XCTFail("`func reset()` not found in \(Self.analyzerFile) — re-anchor (#454).")
        }
        for field in Self.contactFields {
            XCTAssertTrue(reset.contains(field), """
                `CameraAnalyzer.reset()` no longer touches `\(field)`. Claim 1 asks `stop()` to \
                call this method precisely because it is the only one that clears the contact \
                state; a `reset()` that has stopped clearing it makes claim 1 green for a reason \
                that no longer exists (§4).
                """)
        }
        for level in ["brightness", "redChannel"] {
            XCTAssertTrue(reset.contains(level), """
                `CameraAnalyzer.reset()` no longer restores `\(level)`. Both feed the placement \
                cue and the washed-out test, so a new take would read the previous take's light.
                """)
        }
    }

    /// 3 — the asymmetry that makes the cheap fix wrong. COUNTERWEIGHT.
    func testTheRecoveryFlushLeavesTheContactLockStanding() throws {
        let code = try Self.codeText(Self.analyzerFile)
        guard let flush = Self.body(of: "private func resetPulseState", in: code) else {
            return XCTFail("`resetPulseState` not found in \(Self.analyzerFile) — re-anchor (#454).")
        }
        for field in Self.contactFields {
            XCTAssertFalse(flush.contains(field), """
                `resetPulseState` now touches `\(field)`. That method is the MID-TAKE re-settle: \
                it runs from `startPulseDetection()` and from all five `resetForRecovery` sites, \
                one of which is the finger-loss flush. Clearing the contact lock there drops it on \
                a glare flicker and restarts the trust climb — exactly what the acquire/hold \
                hysteresis exists to prevent. A take boundary and a re-settle are different \
                events; only the boundary may forget the body. If the hysteresis itself is being \
                redesigned, rewrite this file rather than deleting the claim (#364).
                """)
        }
    }

    /// 4 — the premise. Without an asymmetric hysteresis, carrying the lock over would cost
    /// nothing and claims 1–3 would be about nothing. COUNTERWEIGHT.
    func testTheContactHysteresisIsStillAsymmetric() throws {
        let code = try Self.codeText(Self.analyzerFile)
        XCTAssertTrue(code.contains("wasDetected ?"), """
            `isFingerFrame` no longer chooses its red floor on `wasDetected`. The whole cost of a \
            carried-over lock is that the ACQUIRE floor is replaced by the easier HOLD floor; \
            without that ternary there is no acquisition gate to disarm. (The VALUES are \
            deliberately not pinned — retuning them is ordinary work, #364.)
            """)
        XCTAssertTrue(code.contains("isFingerDetected ? (fingerDetectionWindow / 4) : (fingerDetectionWindow / 2)"), """
            `updateFingerDetection` no longer needs fewer true frames to HOLD than to ACQUIRE. \
            That second asymmetry is the other half of the carried-over lock: a full buffer of \
            the previous take's `true`s clears the easier bar on the new take's first frame.
            """)
    }

    /// 5 — the orphan half, and the one that survives moving the clear to the other boundary.
    /// REGRESSION on the parent (zero callers there).
    func testTheFullResetHasAProducer() throws {
        let root = try Self.sourcesRoot()
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return XCTFail("cannot walk Sources/ — re-anchor (#454).")
        }
        var scanned = 0
        var callers: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            scanned += 1
            let text = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
            if text.contains("analyzer.reset()") { callers.append(url.lastPathComponent) }
        }
        XCTAssertGreaterThan(scanned, 0, "empty corpus — the walk found no Swift file (#454).")
        XCTAssertFalse(callers.isEmpty, """
            `CameraAnalyzer.reset()` has no caller in `Sources/` again. It is the only method \
            that clears the finger-contact state, so with no caller that state survives every \
            take boundary — the #1380 finding, restored. It does not matter WHICH boundary calls \
            it; it matters that one does.
            """)
    }

    /// 6 — the torch half of the same slice: the refusal reads the RUNTIME property, and it
    /// reads it BEFORE taking a configuration lock. REGRESSION on the parent.
    func testTheTorchRefusalReadsTheRuntimePropertyBeforeLocking() throws {
        let code = try Self.codeText(Self.captureFile)
        guard let apply = Self.body(of: "private func applyTorch()", in: code) else {
            return XCTFail("`applyTorch()` not found in \(Self.captureFile) — re-anchor (#454).")
        }
        guard let check = apply.range(of: "!device.isTorchAvailable") else {
            return XCTFail("""
                `applyTorch()` does not test `device.isTorchAvailable`. That is the ONE torch \
                failure reachable on the shipped target: it goes false under thermal pressure, \
                the condition `thermalTorchLevel()` already fights. Without light there is no \
                red-channel pulse, and a dark torch is indistinguishable from a badly placed \
                finger in every cue the player is shown.
                """)
        }
        guard let lock = apply.range(of: "try device.lockForConfiguration()") else {
            return XCTFail("`try device.lockForConfiguration()` not found in `applyTorch()` — re-anchor (#454).")
        }
        XCTAssertTrue(check.lowerBound < lock.lowerBound, """
            The availability test sits AFTER `try device.lockForConfiguration()`. A hot phone then takes a \
            device configuration lock it cannot use, which is the #1374/#1378 shape one file over: \
            a guard placed behind the side effect it is meant to prevent.
            """)
        XCTAssertTrue(apply.contains("torchUnavailable"), """
            `applyTorch()` no longer latches `torchUnavailable`. The latch is the whole point: \
            before #1380 the failure reached a `.warning` nobody reads on a device, so the next \
            log could not answer "was there light?" and silence read as "the finger was wrong".
            """)
    }

    /// 7 — and the unreachable branch stays. COUNTERWEIGHT against a plausible cleanup.
    func testTheHardwareBranchSurvivesAsTheIPadReason() throws {
        let code = try Self.codeText(Self.captureFile)
        XCTAssertTrue(code.contains("device.hasTorch"), """
            The `hasTorch` branch is gone. It cannot execute on what we ship — every iPhone has \
            an LED and `project.yml` pins `TARGETED_DEVICE_FAMILY: "1"` — but it is the honest \
            branch for a platform that has none, and CLAUDE.md names exactly this coupling as the \
            reason iPad is not a target. Deleting it as dead code removes the record, not the \
            constraint.
            """)
    }

    // MARK: - helpers

    private static func body(of key: String, in text: String) -> String? {
        guard text.components(separatedBy: key).count - 1 == 1,
              let start = text.range(of: key),
              let open = text[start.upperBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var out = ""
        var i = open
        while i < text.endIndex {
            let c = text[i]
            if c == "{" { depth += 1 }
            if c == "}" {
                depth -= 1
                if depth == 0 { return out }
            }
            out.append(c)
            i = text.index(after: i)
        }
        return nil
    }

    private static func sourcesRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path),
                          "Sources/ not present in this checkout")
        return sources
    }

    private static func codeText(_ relative: String) throws -> String {
        let url = try sourcesRoot().appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: url.path) else {
            struct Missing: Error, CustomStringConvertible {
                let p: String
                var description: String { "Sources/\(p) is missing — re-anchor this scan (#454)." }
            }
            throw Missing(p: relative)
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }
}
