// TheCaptureRefusesANonFiniteLengthTests.swift
// Echoel — #1374. Blocking bundle. SOURCE-TEXT SCAN (`Tests/CISmoke/CLAUDE.md` §1): it proves
// what the guard and the conversion say and in which ORDER they sit, never that a capture ran.
//
// ⭐ WHY THIS FILE EXISTS. `Int(someDouble)` TRAPS on NaN, on ±infinity and outside Int's
// range — it does not throw, it does not saturate, the process dies. `RetroCapture
// .captureRecent(seconds:)` took a public `Double` straight into `Int(seconds *
// captureSampleRate)` with `min(max(…, 0), ringCapacity)` around the RESULT. A clamp cannot
// protect its own conversion, and reordering it would not have helped: this repo's own NaN law
// says `min(max(v, lo), hi)` passes NaN straight through, because every comparison with NaN is
// false. That law is why `clamped(to:)` exists, and claim 4 pins it.
//
// ⚠️ LATENT, NOT A DEMONSTRATED CRASH — stated here as plainly as in the source, because the
// flattering direction is to book a hardening guard as a caught bug (#433/#464). The live
// caller's window is `min(seconds + ago, retroRingSeconds)`, NaN-permeable by that same law,
// and the length check above it is too. But no producer is proven to make a NaN: a zero tempo
// yields ±infinity, which `min` DOES catch correctly, and NaN needs a 0/0. This guard buys the
// day a producer starts making one.
//
// ⚠️ WHAT IT DOES NOT SAY (#364). It does not forbid making the CALLER NaN-safe, and it does
// not forbid changing the clamp. Claim 2 goes red if the conversion loses its bounds and
// claim 3 goes red if an Int-typed relative widens to a floating-point parameter — both are
// legitimate edits, and both messages name what has to move with them.
//
// ⛔ AND THE FINDING NARROWED WHILE IT WAS BEING WRITTEN, which is the reason claim 3 exists.
// The first note put the trap at `snapshotPreRoll` too. Re-read: that one and
// `writePreRollToFile` both take `seconds: Int`, so they cannot receive a NaN at all — the
// scan had matched the SHAPE `Int(Double(seconds) * …)` without reading the signature. Their
// safety is structural, not guarded, so the thing worth pinning is the SIGNATURE. A guard
// copied onto them would have been a guard for an unreachable state.
//
// ⛔ ONE MORE FIRST-DRAFT ERROR, KEPT BECAUSE ITS FAILURE MODE IS THE POINT. Claim 5 pointed at
// `Sources/Echoelmusic/Sequencer/LoopExporter.swift`; the file lives under `Audio/`. In Swift
// that is a THROW from `String(contentsOf:)`, so it would have been a hard red in CI naming the
// missing path — loud, not silent. That is why `code(at:)` uses `try` and not `try?`: the
// version of this mistake that costs a cycle is the one where a missed anchor reads as a pass.
//
// ⚠️ HONEST GRADING. No local Swift toolchain (§0). **Seven assertions across five claims**,
// stated rather than counted from the file's shape. Needles re-derived by `grep` on today's
// tree, comment-stripped. Transcribed into Python, driven against this tree (GREEN) and
// against SIX mutants — the guard deleted, the guard moved BELOW the conversion, the clamp
// stripped off the conversion, `snapshotPreRoll` widened to `Double`, `clamped(to:)`'s NaN
// branch removed, and the live caller's argument replaced by a literal — each of which turned
// the intended claim RED. The order mutant is the one that matters: a version of this guard
// that asserted only "an isFinite check exists" would have survived it, and an isFinite check
// below the trap is worth nothing. **1 regression catch (the
// guard this slice adds), 6 COUNTERWEIGHTS (#343).**

import Foundation
import XCTest
@testable import Echoelmusic

final class TheCaptureRefusesANonFiniteLengthTests: XCTestCase {

    private static let captureFile = "Sources/Echoelmusic/Audio/RetroCapture.swift"
    private static let clampFile = "Sources/Echoelmusic/Core/FloatingPointClamp.swift"
    private static let callerFile = "Sources/Echoelmusic/Audio/LoopExporter.swift"

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    /// Comment-stripped: this file argues about its own conversion in a 25-line ⛔ block that
    /// QUOTES the guarded line. A raw scan would read the argument as the code (#453/#1050).
    private func code(at rel: String) throws -> String {
        SourceText.codeOnly(try String(
            contentsOf: try repoRoot().appendingPathComponent(rel), encoding: .utf8))
    }

    // MARK: - Claim 1 — the refusal exists, and it sits BEFORE the conversion

    func testTheCaptureRefusesANonFiniteLength() throws {
        let code = try self.code(at: Self.captureFile)
        guard let guardAt = code.range(of: "guard seconds.isFinite else {") else {
            return XCTFail("""
                `captureRecent(seconds:)` no longer refuses a non-finite length. `Int(seconds \
                * captureSampleRate)` TRAPS on NaN and on ±infinity — it does not throw, the \
                process dies — and the `min(max(…))` around it runs after that conversion, so \
                it guards a step that already crashed.
                """)
        }
        guard let convertAt = code.range(of: "Int(seconds * captureSampleRate)") else {
            return XCTFail("""
                The conversion `Int(seconds * captureSampleRate)` is gone from \
                `\(Self.captureFile)`, so this claim compared nothing — it FAILS rather than \
                passing vacuously (#454). If the frame maths moved, re-anchor here in the \
                same commit.
                """)
        }
        XCTAssertLessThan(guardAt.lowerBound, convertAt.lowerBound, """
            The non-finite refusal sits AFTER `Int(seconds * captureSampleRate)`. Order is the \
            whole point: a check that runs after the trap has already fired protects nothing. \
            This is the same shape as the clamp the guard was added to fix.
            """)
    }

    // MARK: - Claim 2 — the clamp is still there (the guard ADDED to it, did not replace it)

    /// Without this, a "simplification" that deletes the bounds and keeps the new guard reads
    /// as green — and `seconds` would then be free to ask for more frames than the ring holds.
    /// The finite check answers NaN and infinity; the clamp answers "too big". Two questions.
    func testTheFrameCountIsStillBoundedBothWays() throws {
        let code = try self.code(at: Self.captureFile)
        XCTAssertTrue(
            code.contains("min(max(Int(seconds * captureSampleRate), 0), ringCapacity)"), """
            The frame count lost its bounds. The `isFinite` guard above answers NaN and \
            infinity only; the ring still has a capacity, and a finite-but-huge `seconds` \
            would ask past it. Changing the clamp is allowed (#364) — but say what bounds the \
            request instead, in the same commit.
            """)
    }

    // MARK: - Claim 3 — the two relatives are safe by SIGNATURE, not by guard

    /// This is the claim the narrowing produced. `snapshotPreRoll` and `writePreRollToFile`
    /// carry the same `Int(… * captureSampleRate)` shape and need no guard, because an `Int`
    /// parameter cannot be a NaN. That safety lives in the signature, so the signature is what
    /// is pinned — widen either to a floating-point type and this goes red, correctly.
    func testTheIntTypedRelativesCannotReceiveANonFiniteLength() throws {
        let code = try self.code(at: Self.captureFile)
        for signature in ["func snapshotPreRoll(seconds: Int = 30)",
                          "func writePreRollToFile(_ file: AVAudioFile, format: AVAudioFormat, seconds: Int)"] {
            XCTAssertTrue(code.contains(signature), """
                `\(signature)` changed. It carries the same `Int(… * captureSampleRate)` \
                conversion as `captureRecent` and is unguarded ON PURPOSE, because an `Int` \
                argument cannot be NaN or infinite. If this parameter became a floating-point \
                type, that reasoning is void and it needs the same `isFinite` refusal — which \
                is exactly why this reads the signature and not the body.
                """)
        }
    }

    // MARK: - Claim 4 — the NaN law this slice cites is still the law

    /// #416 — the source comment argues from `clamped(to:)`'s behaviour rather than restating
    /// it. That argument is only worth anything while the helper still does what it claims.
    func testTheNaNSafeClampStillTreatsNaNAsTheLowerBound() throws {
        let code = try self.code(at: Self.clampFile)
        XCTAssertTrue(code.contains("guard !isNaN else { return range.lowerBound }"), """
            `clamped(to:)` no longer special-cases NaN, so it is now just `min(max(…))` and \
            passes NaN through like everything else. Several ⛔ blocks — including \
            `\(Self.captureFile)`'s — argue FROM this helper being the NaN-safe one. If the \
            helper changed, those arguments move in the same commit.
            """)
        XCTAssertFalse(try self.code(at: Self.clampFile).isEmpty, """
            `\(Self.clampFile)` stripped to nothing under `SourceText.codeOnly`, so the claim \
            above matched against an empty string. That is a broken read, not a pass (#454).
            """)
    }

    // MARK: - Claim 5 — the live caller still goes through the guarded door

    /// The guard is worth having because something real calls it. If this stops being true the
    /// guard is not wrong, but the ⛔ block's account of the blast radius is — and that account
    /// is what a future reader uses to decide whether the guard still earns its lines.
    func testTheLiveCallerStillAsksForAWindowInSeconds() throws {
        let code = try self.code(at: Self.callerFile)
        XCTAssertTrue(code.contains("captureRecent(seconds: window)"), """
            `\(Self.callerFile)` no longer calls `captureRecent(seconds: window)`. The ⛔ block \
            in `\(Self.captureFile)` names this caller as the live path whose window is \
            NaN-permeable; if the call moved or went away, correct that account rather than \
            deleting this claim — a guard whose stated reason has expired is the kind a later \
            cleanup removes along with the law.
            """)
    }
}
