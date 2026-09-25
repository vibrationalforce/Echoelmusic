// TheAUv3ReverbMixGlidesAcrossABlockTests.swift
// Echoel — #202 (post-RC, 2026-09-25): the AUv3's reverb blend (host address 6) glides across a
// render block instead of stepping at its edge. Blocking bundle.
//
// THE DEFECT (reviewed at RC, #201). `EchoelBodyVibeDevice.renderSpace` wrote `reverb.mix = next`
// once per block, so every sample of a block played the new blend and the block boundary carried
// the whole change: a zipper on a slow host sweep, a click on a jump. The RC review filed it as
// post-RC because the stage was new and the step was bounded by the host's own block size.
//
// THE REPAIR. Each sample plays `EchoelBodyVibeDevice.mixRamp(from:to:sample:of:)` — linear from
// the mix the previous block ENDED on to this block's target, exactly the target at the last
// sample. `EchoelReverb.mixGlidePrimed` keeps the FIRST block from gliding: before any block has
// played, `mix` is the type's default (0.25), not something a listener heard.
//
// WHAT KIND OF GREEN (§1), PER CLAIM:
// · claim 1 is the arithmetic of the one function the render calls, including its edges.
// · claims 2–3 are RENDERED AUDIO through the real `EchoelReverb` and the same `renderSpace` the
//   AUv3 render block calls. Claim 2 reads the blend each sample PLAYED from the output itself:
//   on a silent input `processStereo` returns `wet * m` (the dry term is `0 * (1 - m)`, exactly
//   zero), and a twin stage at mix 1 returns `wet` from an identical tank — the tank's input does
//   not depend on the mix while the mix is above 0 — so the ratio of the two IS the blend.
// · claim 4 is END-TO-END on the same types: a zero-length call changes no state (review C1).
// · claim 5 is a SOURCE-TEXT SCAN of the extension: `allocateRenderResources` un-primes the
//   glide beside its tank reset, so a re-allocated unit starts like a fresh one.
// · HOST — automating address 6 in AUM and hearing no zipper — stays owed (WA3-5). ⚠️ The AUv3
//   render block reads only `.MIDI` render events; a host that schedules address 6 as a
//   `.parameter`/`.parameterRamp` render event reaches the unit through the observer at block
//   rate, never sample-accurately. That is outside this slice and recorded, not claimed.
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). It does not freeze a LINEAR ramp or a one-block glide
// length; a later slice may choose another shape. It freezes: the first sample of a changed block
// is not the new target, the last one is, and a fresh stage does not glide from the type default.
// The tank's rising-edge reset is pinned by `TheBodyVibeReverbIsHeardAndAnchoredTests` claim 9,
// which this change had to keep green (it does: the reset runs before the glide starts from 0).
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `de9fdd77b`: `mixRamp` and
// `mixGlidePrimed` do not exist, so this file does not COMPILE there — no assertion has a verdict
// on the parent; all are FORWARD guards (one absence, #486). Driven in Python on a float32
// transcription of `EchoelReverb` and both `renderSpace` bodies (scratchpad `g202.py`):
// · claim 2, new body — 510 of 512 samples readable, 0 blend mismatches, first blend 0.2014,
//   seam equal to the stepped reference. Parent body — 509 mismatches, first blend 0.9000.
// · claim 3 — equal on both bodies (the parent never glided); with `mixGlidePrimed` forced true
//   on the first block (the mutation it exists for) both targets turn red.
// · claim 1 — the COMPUTED last step `start + (end - start) * n / n` misses 0.1 on a 0.9 → 0.1
//   glide in float32; returning `end` is load-bearing, not tidiness.
// · `TheBodyVibeReverbIsHeardAndAnchoredTests` claim 9 re-driven on the new body: held 0.162,
//   risen 0.0 — still green.
// Claims 4–5 were added with the review repair (C1 + the re-allocation note): on `735a91968`
// claim 4 is a REGRESSION (the `defer` stored the target on a zero-length call and primed a
// fresh stage) and claim 5 is a REGRESSION (no un-prime in `allocateRenderResources`).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheAUv3ReverbMixGlidesAcrossABlockTests: XCTestCase {

    private static let rate: Float = 48000
    private static let block = 512
    private static let audioUnit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"

    // MARK: - claim 1 (the ramp's arithmetic)

    func testTheRampStepsEvenlyAndLandsExactlyOnTheTarget() {
        let four = (0..<4).map { EchoelBodyVibeDevice.mixRamp(from: 0, to: 1, sample: $0, of: 4) }
        XCTAssertEqual(four, [0.25, 0.5, 0.75, 1], "one even step per sample, the first one past the start")

        let glides: [(Float, Float)] = [(0.3, 0.7), (0.9, 0.1), (0.2, 0.2), (0, 0.999)]
        for (start, end) in glides {
            XCTAssertEqual(EchoelBodyVibeDevice.mixRamp(from: start, to: end, sample: Self.block - 1,
                                                         of: Self.block), end, """
                The last sample of a \(start) → \(end) glide is not exactly the target. The next \
                block starts from the stored target, so any residue here is a step at the seam.
                """)
        }
        XCTAssertEqual(EchoelBodyVibeDevice.mixRamp(from: 0.4, to: 0.4, sample: 7, of: Self.block), 0.4,
                       "an unchanged mix is played unchanged")
        for n in [0, -3] {
            XCTAssertEqual(EchoelBodyVibeDevice.mixRamp(from: 0.1, to: 0.6, sample: 0, of: n), 0.6,
                           "a degenerate block length (\(n)) is the target, never a division by it")
        }
    }

    // MARK: - claim 2 (RENDERED — a changed block glides; the seam is the target)

    func testAChangedMixGlidesAcrossTheBlockAndEndsOnTheTarget() {
        let synth = EchoelDDSP(sampleRate: Self.rate)
        let stage = EchoelReverb(sampleRate: Self.rate)   // through `renderSpace`
        let fullyWet = EchoelReverb(sampleRate: Self.rate) // the same tank, read at mix 1
        fullyWet.mix = 1
        let stepped = EchoelReverb(sampleRate: Self.rate)  // the pre-#202 behaviour, as reference

        var left = [Float](repeating: 0, count: Self.block)
        var right = [Float](repeating: 0, count: Self.block)
        func renderStage(_ input: (Int) -> Float) {
            for i in 0..<Self.block { left[i] = input(i) }
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    EchoelBodyVibeDevice.renderSpace(stage, synth: synth, left: l, right: r,
                                                     count: Self.block)
                }
            }
        }
        func renderDirect(_ reverb: EchoelReverb, _ input: (Int) -> Float) -> [Float] {
            (0..<Self.block).map { reverb.processStereo(input($0), input($0)).0 }
        }

        // Fill all three tanks identically at a steady blend.
        synth.reverbMix = 0.2
        stepped.mix = 0.2
        for b in 0..<20 {
            let tone: (Int) -> Float = { i in 0.5 * sinf(Float(b * Self.block + i) * 0.05) }
            renderStage(tone)
            _ = renderDirect(fullyWet, tone)
            _ = renderDirect(stepped, tone)
        }
        XCTAssertEqual(stage.mix, 0.2)

        // The host jumps the blend; the input is silent, so everything out is the tank × blend.
        synth.reverbMix = 0.9
        stepped.mix = 0.9
        renderStage { _ in 0 }
        let wet = renderDirect(fullyWet) { _ in 0 }
        let reference = renderDirect(stepped) { _ in 0 }

        var measured = 0
        for i in 0..<Self.block where abs(wet[i]) > 1e-3 {
            measured += 1
            let played = left[i] / wet[i]
            let expected = EchoelBodyVibeDevice.mixRamp(from: 0.2, to: 0.9, sample: i, of: Self.block)
            XCTAssertEqual(played, expected, accuracy: 1e-5, """
                Sample \(i) of the jump block played blend \(played), not the glide's \(expected). \
                A value at 0.9 on the first samples is the per-block step #202 removed.
                """)
        }
        XCTAssertGreaterThan(measured, Self.block / 4,
                             "too few samples carried a tail to read the blend from — the claim would be vacuous")
        // The named regression, stated on its own: the opening samples play near the OLD blend.
        let opening = (0..<64).filter { abs(wet[$0]) > 1e-3 }
        XCTAssertFalse(opening.isEmpty, "no readable sample in the opening 64 — the check below would be vacuous")
        for i in opening {
            XCTAssertLessThan(left[i] / wet[i], 0.3, """
                Sample \(i) of the jump block already plays \(left[i] / wet[i]). The blend steps at \
                the block edge again (#202).
                """)
        }
        XCTAssertEqual(left[Self.block - 1], reference[Self.block - 1], """
            The last sample of the glide is not the stepped reference at the target. The seam into \
            the next block would then carry a residue.
            """)
        XCTAssertEqual(stage.mix, 0.9, "the stage does not store the target the next block glides from")
    }

    // MARK: - claim 3 (RENDERED COUNTERWEIGHT — the first block does not glide)

    func testAFreshStageDoesNotGlideFromTheTypeDefault() {
        let targets: [Float] = [0, 0.6]
        for target in targets {
            let synth = EchoelDDSP(sampleRate: Self.rate)
            let stage = EchoelReverb(sampleRate: Self.rate)
            XCTAssertNotEqual(stage.mix, target,
                              "the type default equals the target — the claim could not see a glide")
            let reference = EchoelReverb(sampleRate: Self.rate)
            reference.mix = target
            synth.reverbMix = target

            let tone: (Int) -> Float = { i in 0.5 * sinf(Float(i) * 0.05) }
            var left = (0..<Self.block).map(tone)
            var right = [Float](repeating: 0, count: Self.block)
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    EchoelBodyVibeDevice.renderSpace(stage, synth: synth, left: l, right: r,
                                                     count: Self.block)
                }
            }
            let expected = (0..<Self.block).map { reference.processStereo(tone($0), tone($0)).0 }
            XCTAssertEqual(left, expected, """
                The first block of a fresh stage at target \(target) is not the target throughout. \
                It glided from the type's default \(EchoelReverb(sampleRate: Self.rate).mix) — a wet \
                fade no listener heard before. `mixGlidePrimed` exists to prevent exactly this.
                """)
            XCTAssertTrue(stage.mixGlidePrimed, "the first block did not prime the glide for the next one")
        }
    }

    // MARK: - claim 4 (a zero-length call changes nothing)

    func testAZeroLengthRenderLeavesTheGlideUntouched() {
        let synth = EchoelDDSP(sampleRate: Self.rate)
        let stage = EchoelReverb(sampleRate: Self.rate)
        var empty: [Float] = []
        var emptyRight: [Float] = []
        func renderNothing() {
            empty.withUnsafeMutableBufferPointer { l in
                emptyRight.withUnsafeMutableBufferPointer { r in
                    EchoelBodyVibeDevice.renderSpace(stage, synth: synth, left: l, right: r, count: 0)
                }
            }
        }

        synth.reverbMix = 0.6
        renderNothing()
        XCTAssertFalse(stage.mixGlidePrimed, "a zero-length call primed the glide — nothing was played")
        XCTAssertEqual(stage.mix, 0.25, "a zero-length call stored a target no sample played")

        // Primed at 0.2, then the host jumps to 0.9 during a zero-length call.
        var left = [Float](repeating: 0.1, count: Self.block)
        var right = [Float](repeating: 0, count: Self.block)
        synth.reverbMix = 0.2
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                EchoelBodyVibeDevice.renderSpace(stage, synth: synth, left: l, right: r, count: Self.block)
            }
        }
        synth.reverbMix = 0.9
        renderNothing()
        XCTAssertEqual(stage.mix, 0.2, """
            A zero-length call stored the new target 0.9. The next real block would then start ON \
            it and play the whole change at its first sample — the block-edge step #202 removes.
            """)
    }

    // MARK: - claim 5 (SOURCE-TEXT SCAN — a re-allocated unit starts like a fresh one)

    func testTheAudioUnitUnprimesTheGlideWhenItReallocates() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        let allocate = try XCTUnwrap(Self.body(
            startingWith: "public override func allocateRenderResources() throws", in: code),
            "ANCHOR MISSING: `allocateRenderResources` in \(Self.audioUnit) (#454)")
        guard let reset = allocate.range(of: "reverb.reset()"),
              let unprime = allocate.range(of: "reverb.mixGlidePrimed = false") else {
            return XCTFail("""
                `allocateRenderResources` no longer resets the tank AND un-primes the glide. The \
                first block of a re-allocated unit would glide out of the last session's mix.
                """)
        }
        XCTAssertLessThan(reset.lowerBound, unprime.lowerBound, "un-prime beside the tank reset, after it")
        XCTAssertEqual(code.components(separatedBy: "mixGlidePrimed").count - 1, 1,
                       "the extension writes the glide flag once, in allocation — the render path owns it otherwise")
    }

    // MARK: - helpers

    private static func body(startingWith anchor: String, in code: String) -> String? {
        guard let start = code.range(of: anchor) else { return nil }
        var depth = 0
        var out = ""
        for ch in code[start.lowerBound...] {
            if ch == "{" { depth += 1 }
            if depth > 0 { out.append(ch) }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return out }
            }
        }
        return nil
    }

    private func text(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relative) is not present — source-text claim cannot run (#454)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
