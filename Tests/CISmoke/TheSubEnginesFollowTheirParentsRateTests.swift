// TheSubEnginesFollowTheirParentsRateTests.swift
// Echoel — three nailed literals inside a type that already knows its own rate. #1406.
//
// WHAT WAS WRONG. `EchoelDDSP` takes `sampleRate` in its init, clamps it, stores it as
// `public let sampleRate`, and then built three of its own sub-engines with a CONSTANT:
//
//     public let filter     = EchoelSVFilter(sampleRate: 48000)
//     public let filterLFO  = EchoelLFO(sampleRate: 48000)
//     public let entrainment = EchoelEntrainment(sampleRate: 48000)
//
// A property initialiser cannot see `self`, so the literal was not laziness — it was the
// only thing writable at that position. The consequence is the same either way: an
// `EchoelDDSP(sampleRate: 44100)` carried a filter, an LFO and an entrainment oscillator
// still computing at 48 kHz, and nothing anywhere said so. That is #416 in its most
// invisible form — a second spelling of one decision, in a place no caller can correct.
//
// ⚠️ THIS SLICE CHANGES NO SOUND TODAY, AND THAT IS WHY IT IS ITS OWN SLICE. Measured, both
// production construction sites pass 48000:
//     Sources/Echoelmusic/Tools/BioReactiveSynthVoice.swift  (static let sampleRate = 48_000)
//     Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift     (EchoelDDSP(sampleRate: 48000))
// so `self.sampleRate` and the literal are the same number on every shipping path and every
// rendered sample is bit-identical. Claim 2 drives that rather than asserting it.
//
// WHY IT IS WORTH A SLICE ANYWAY: it is the DEEPER HALF of the AUv3 host-rate defect
// (`scratchpads/BAUSTELLEN_BOARD.md` A10). The audible half is that the extension nails
// 48 kHz instead of following the host's format; with these three literals in place, fixing
// the extension alone would NOT have fixed the sound, because a freshly built
// `EchoelDDSP(sampleRate: 44100)` would still have run its filter and LFO at 48 kHz. After
// this slice the remaining repair is a change to the extension and nothing else.
//
// ⛔ AND THE DIRECTION IN THAT BOARD ENTRY IS WRONG, which matters because it is what a
// device test would be checked against. It reads "alles klingt ~8,8 % zu hoch" in a
// 44,1-kHz-Host. The arithmetic goes the other way: the engine emits one sample per
// computed step assuming 48000 steps make a second, the host plays 44100 samples a second,
// so 48000 samples take 48000/44100 = 1,088 s and every frequency comes out multiplied by
// 44100/48000 = 0,91875. That is **8,1 % LOW** (≈ 1,47 semitones FLAT), with LFOs and
// envelopes running 8,8 % SLOW. ⚠️ Consistent with the one measurement that exists: the
// founder's AUM recording (#1386) ran at 48 kHz — rates equal — and the tone measured
// 220,15 Hz against the 220 Hz default, +1,2 cents. A matching rate is the one case where
// the defect is invisible, which is exactly why it survived the first device session.
//
// ⚠️ HONEST GRADING (#433/#464/#486). This file compiles against the parent tree — it names
// no symbol this commit adds (`EchoelDDSP`, `EchoelLFO` and their members are all public and
// pre-existing) — so every assertion has a verdict there. Graded by transcription (§0): a
// Python rebuild of `SourceText.codeOnly` for claim 3, a float32 rebuild of
// `EchoelLFO.next()`'s phase algebra for claims 1 and 2, and one of
// `EchoelEntrainment.process()` for claim 4, each driven against `git show HEAD:<path>`
// and the worktree, plus three mutants and one false-alarm probe.
//   · **TWO are regressions** on the parent, and they are one finding reported twice
//     (#486 — the same nailed literal): claim 1 (the LFO ignored a 24 kHz parent) and
//     claim 3 (the three construction lines carried a number instead of `self.sampleRate`).
//   · **claim 2 is a COUNTERWEIGHT** (#343) and is the point of the file: green on BOTH
//     trees, and it is what makes "no sound changed" a measurement instead of a promise. A
//     tree that made the sub-engines follow the parent AND moved the shipping rate off
//     48 kHz would satisfy claim 1 and break this one.
//   · **claim 4 is a COUNTERWEIGHT that became load-bearing BECAUSE of this slice**, which
//     is the part worth reading. `EchoelSVFilter.init` clamps (`sampleRate > 0 ? … : 48000`)
//     and `EchoelLFO.init`/`EchoelEntrainment.init` do NOT — they store the argument as
//     given. While the literal was 48000 those two could not be handed a bad rate at all;
//     now the `max(1, sampleRate)` in `EchoelDDSP.init` is the only thing between a caller's
//     0 and a division by it. Green on both trees, for DIFFERENT reasons — vacuously before,
//     by the clamp after. Said plainly rather than booked as a third regression.
//     ⛔ AND ITS FIRST DRAFT DROVE THE WRONG SUB-ENGINE, caught by driving rather than
//     reading: the LFO's #1207b wrap absorbs a non-finite phase, so the assertion was green
//     on the very mutation it was written to catch (#367, the mirror case). The subject is
//     now `EchoelEntrainment`, whose wrap does not rescue. Mutation-verified: passing the
//     RAW init parameter makes it NaN on the first call at rate 0.
//
// ⚠️ `SourceText.codeOnly` is TRAGEND for claim 3, measured rather than assumed: the repair
// commit's own doc block QUOTES the withdrawn `EchoelSVFilter(sampleRate: 48000)` in order to
// withdraw it, so the raw text contains the very shape claim 3 forbids. Raw → 1 finding on a
// correct tree (a false alarm); stripped → 0. 1 of 1 verdict flips.
//
// ⚠️ IT DOES NOT FORBID THE FOLLOW-UP (#364). Making the AUv3 rebuild its engines at the
// host format is exactly the work this slice exists to enable; claim 2 pins the APP's rate
// (`BioReactiveSynthVoice`), not the extension's, so that change leaves this file green.
// What claim 3 forbids is re-nailing a literal inside `EchoelDDSP` — and its message names
// the repair rather than the relaxation.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheSubEnginesFollowTheirParentsRateTests: XCTestCase {

    private static let ddsp = "Sources/Echoelmusic/DSP/EchoelDDSP.swift"

    /// The three sub-engine types whose construction inside `EchoelDDSP` is the subject.
    private static let subEngines = ["EchoelSVFilter(", "EchoelLFO(", "EchoelEntrainment("]

    /// A rate whose quotient is a power of two at BOTH test rates, so every expected value
    /// below is exact in `Float` and the assertions can be equalities (#442 — write the
    /// assertion from the algebra, not from a printed value). 375/32 Hz sits inside the
    /// LFO's own documented 0,01…20 Hz window, so nothing here drives it out of range.
    ///   11.71875 / 48000 = 2^-12     11.71875 / 24000 = 2^-11
    private static let exactRate: Float = 11.71875

    // MARK: - Claim 1 — the finding (END-TO-END BEHAVIOUR)

    /// Halving the parent's rate must double how far the LFO travels per sample.
    ///
    /// `EchoelLFO.next()` is `phase += rate / sampleRate` then, for `.sawtooth`,
    /// `(2 * phase - 1) * depth`. With `depth = 1` and the rate above, ONE call gives
    /// exactly `2 * 2^-12 - 1` at 48 kHz and `2 * 2^-11 - 1` at 24 kHz. Before this slice
    /// both instances answered the 48 kHz value, because both LFOs were built with a
    /// literal 48000 regardless of what the parent was told.
    func testTheLFOFollowsTheParentsRate() {
        let fast = EchoelDDSP(sampleRate: 24000)
        let slow = EchoelDDSP(sampleRate: 48000)

        let atHalfRate = Self.firstSawtoothSample(of: fast)
        let atFullRate = Self.firstSawtoothSample(of: slow)

        XCTAssertEqual(atFullRate, 2 * 0.000244140625 - 1, """
            `EchoelDDSP(sampleRate: 48000)`'s filter LFO no longer advances by rate/48000 \
            per sample. Either `EchoelLFO.next()`'s phase algebra changed or the LFO is no \
            longer built from the parent's rate.
            """)
        XCTAssertEqual(atHalfRate, 2 * 0.00048828125 - 1, """
            `EchoelDDSP(sampleRate: 24000)`'s filter LFO did NOT follow its parent — it \
            advanced as if the rate were 48000. That is the #1406 defect returning: the \
            sub-engines are built with a literal again instead of `self.sampleRate`. The \
            repair is in `EchoelDDSP.init`, not here.
            """)

        // The relationship, stated as itself so a future re-tune of `exactRate` cannot make
        // the two equalities above pass for a reason unrelated to the rate.
        XCTAssertEqual(atHalfRate + 1, 2 * (atFullRate + 1), """
            Halving the parent's sample rate must exactly double the LFO's per-sample \
            phase advance. It did not, so the sub-engine is not reading the parent's rate.
            """)
    }

    // MARK: - Claim 2 — COUNTERWEIGHT: the shipping rate is untouched

    /// At 48 kHz — the ONLY rate any production caller passes — the parent's LFO must be
    /// indistinguishable from a standalone `EchoelLFO(sampleRate: 48000)`, sample for
    /// sample. This is what makes "this slice changes no sound" a measurement.
    func testTheShippingRateSoundsExactlyAsItDidBefore() {
        let parent = EchoelDDSP(sampleRate: 48000)
        let reference = EchoelLFO(sampleRate: 48000)

        for lfo in [parent.filterLFO, reference] {
            lfo.reset()
            lfo.waveform = .sawtooth
            lfo.depth = 1
            lfo.rate = Self.exactRate
        }

        for step in 0..<64 {
            XCTAssertEqual(parent.filterLFO.next(), reference.next(), """
                Sample \(step): the 48 kHz parent's LFO diverged from a standalone \
                `EchoelLFO(sampleRate: 48000)`. Every production caller passes 48000 \
                (`BioReactiveSynthVoice.sampleRate`, `EchoelmusicAudioUnit`), so this \
                divergence is an audible change to the shipping instrument — not the \
                no-op #1406 claims to be.
                """)
        }
    }

    // MARK: - Claim 3 — the finding, as source text (SOURCE-TEXT SCAN)

    /// No sub-engine inside `EchoelDDSP.swift` may be constructed with anything but the
    /// parent's own rate.
    ///
    /// A PROPERTY, not a count (#818/#903): a legitimate second construction is fine as long
    /// as it follows the rate, and a re-nailed literal is red whether it is the first or the
    /// fourth. Comments are stripped first, because this file's own ⛔ blocks quote the
    /// forbidden shape in order to withdraw it.
    func testNoSubEngineIsConstructedWithANailedRate() throws {
        let code = SourceText.codeOnly(try rawText(Self.ddsp))
        var offenders: [String] = []
        var seen = 0

        for line in code.split(separator: "\n", omittingEmptySubsequences: false) {
            let text = String(line)
            guard Self.subEngines.contains(where: { text.contains($0) }) else { continue }
            seen += 1
            if !text.contains("self.sampleRate") {
                offenders.append(text.trimmingCharacters(in: .whitespaces))
            }
        }

        XCTAssertGreaterThan(seen, 0, """
            No `EchoelSVFilter(` / `EchoelLFO(` / `EchoelEntrainment(` construction was found \
            in \(Self.ddsp) at all. A scan that matches nothing is a finding, not a pass \
            (`.claude/rules/context.md` §2) — either the sub-engines were removed, in which \
            case this guard and the doc blocks at their declarations go in the same commit, \
            or the anchor has rotted.
            """)
        XCTAssertEqual(offenders, [], """
            A sub-engine inside `EchoelDDSP` is built with something other than \
            `self.sampleRate`. That is #1406 returning, and it is invisible at 48 kHz — it \
            only speaks in a host running at any other rate, where the parent is told one \
            number and its filter/LFO/entrainment use another. The repair is in \
            `EchoelDDSP.init`; do not relax this assertion.
            """)
    }

    // MARK: - Claim 4 — COUNTERWEIGHT that this slice made load-bearing

    /// A degenerate rate must not reach the sub-engine that has no rescue of its own.
    ///
    /// ⛔ THE FIRST DRAFT OF THIS CLAIM DROVE THE LFO AND COULD NOT FAIL FOR ITS NAMED
    /// REASON (#367) — found by driving it, not by reading it. `EchoelLFO.next()` carries the
    /// #1207b wrap, `phase = phase.isFinite ? phase - phase.rounded(.down) : 0`, so an `inf`
    /// phase from a divide-by-zero is caught one line later and the output is finite EITHER
    /// WAY. Asserting finiteness there is green on a tree that passes the raw parameter,
    /// which is precisely the mutation this claim exists to catch.
    ///
    /// `EchoelEntrainment.process` is the one that speaks: `phase += centerFrequency /
    /// sampleRate`, then `if phase >= 1.0 { phase -= 1.0 }` — a wrap that does NOT rescue a
    /// non-finite phase (`inf - 1 == inf`), so `cosf(inf * 2π)` is NaN and the returned
    /// sample is NaN. Measured: with the CLAMPED rate the output is finite; with the raw
    /// parameter at 0 it is NaN on the first call.
    ///
    /// ⚠️ REPORTED, NOT FIXED HERE: that non-rescuing wrap is the exact shape #1207b removed
    /// from `EchoelLFO`, still present in `EchoelEntrainment`. It is unreachable today
    /// (`EchoelDDSP` is the only construction site in `Sources/` and now always hands it a
    /// clamped rate), so it is a separate slice in a separate file — widening this one to
    /// chase it would be the batching this repo's loop forbids.
    func testAZeroParentRateCannotReachTheEntrainmentDivisor() {
        for degenerate in [Float(0), -48000, -1] {
            let ddsp = EchoelDDSP(sampleRate: degenerate)
            let entrainment = ddsp.entrainment
            entrainment.reset()
            entrainment.band = .alpha
            entrainment.depth = 0.5          // below 0.01 the method returns the input untouched

            for step in 0..<8 {
                let value = entrainment.process(1.0)
                XCTAssertTrue(value.isFinite, """
                    `EchoelDDSP(sampleRate: \(degenerate))` step \(step): the entrainment \
                    oscillator produced a non-finite sample. The sub-engines must be built \
                    from the CLAMPED `self.sampleRate` (`max(1, sampleRate)`), never from the \
                    raw init parameter — `EchoelEntrainment` neither clamps its rate nor \
                    rescues a non-finite phase, so a caller's 0 divides straight through.
                    """)
            }
        }
    }

    // MARK: - Helpers

    /// One deterministic sample from a parent's filter LFO, sawtooth at unit depth.
    private static func firstSawtoothSample(of ddsp: EchoelDDSP) -> Float {
        let lfo = ddsp.filterLFO
        lfo.reset()
        lfo.waveform = .sawtooth
        lfo.depth = 1
        lfo.rate = exactRate
        return lfo.next()
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
