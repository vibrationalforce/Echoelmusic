// TheAllpassInterpolatorCannotRingForeverTests.swift
// Echoel — the shared fractional-delay interpolator must not park a pole on the unit
// circle. BLOCKING. #1205.
//
// THE DEFECT. `EchoelDelayLine.readAllpass` is `y[n] = s1 + eta * (s0 - y[n-1])`, a
// first-order allpass whose pole sits at `-eta`, with `eta = (1 - frac) / (1 + frac)`. At an
// EXACTLY integer delay `frac` is 0, `eta` is 1.0, and the pole lands ON the unit circle:
// whatever value the filter state already holds alternates ±forever, at Nyquist, with no decay.
//
// IT IS REACHABLE, and that is why this is a guard and not a note. `EchoelChorus.baseDelayMs`
// is 12 and `EchoelFlanger.baseDelayMs` is 3; at 48 kHz those are 576.0 and 144.0 samples
// EXACTLY. Both stages expose a `Depth` field with range `0...1`, so setting depth to 0 — a
// natural thing to try, "chorus without the wobble" — parks the read on that integer while the
// state still holds whatever the last modulated read left there.
//
// ⚠️ IT NEEDS A STATE TRANSITION, and the guard must not over-claim. From silence with a cold
// filter there is nothing to ring: the transfer at eta = 1 is a pole-zero cancellation, i.e. an
// exact pure delay, so the mode is never excited by the input. What excites it is arriving at
// the integer with state already in the filter — dragging Depth to 0 while a note sounds, or a
// preset change. Measured that way on a 0.5-amplitude tone: an undecayed alternating residue,
// still there after three seconds.
// ⚠️ ITS AMPLITUDE IS PHASE-DEPENDENT, so quote it as a range and not as a constant. Two runs
// that differ only in WHEN the depth reaches the integer measured ±0.46 and +0.744 (wet peak
// 1.244) — the state the filter is holding at that instant is whatever the last modulated read
// left, so the seed is the signal's phase. The durable fact is "does not decay", not a figure.
//
// ⛔ AND THE FIRST MEASUREMENT OF THIS SLICE REPORTED A SECOND, COLD-START ARTEFACT THAT DOES
// NOT EXIST. It read "peak 0.0144, never decays, from rounding alone". That number was the
// error in the MEASUREMENT, not in the code: the reference signal was delayed by 576 samples
// while the line's own contract makes `delaySamples: 1.0` the MOST RECENT write — so a request
// for d and a reference delayed by d are one sample apart. (⛔ The first wording said the call
// "returns the sample `d - 1` back", which reads as contradicting the contract quoted in the
// same breath; it is a statement about the reference alignment, not about the function.) One
// sample of a
// 220 Hz sine at amplitude 0.5 is 0.0144. The clamp left that figure untouched, which is what
// exposed it — a fix that does not move a number it should have moved is a finding about the
// number. Recorded because the retracted figure was already in a status report.
//
// THE FIX is a clamp on the coefficient, not on the requested delay: `eta` is capped at 0.99.
// The stage stays an EXACT allpass — `(eta + z⁻¹)/(1 + eta·z⁻¹)` has magnitude 1 at every
// frequency for any real `|eta| < 1`, verified numerically at 1.0, 0.99 and 0.9 — so the clamp
// changes only the fractional delay it realises (0.005 samples, 0.1 µs at 48 kHz), never the
// magnitude response. It engages on 0.75 % of samples over a chorus LFO cycle at depth 0.5.
//
// ⭐ AN UNCLAIMED BENEFIT, recorded because the slice argues only the exactly-integer case. The
// clamp also bounds the NEAR-integer one, which an ordinary sweep passes through every cycle:
// at frac ≈ 0.0001 the raw coefficient is ≈ 0.9998, a half-life of ~144 ms on the parent tree.
// After the clamp that is 1.4 ms. Nothing in this file asserts it — it is a consequence, not a
// claim — but a future reader weighing whether 0.99 is worth it should have the whole figure.
//
// ⚠️ THE CLAMP OPENS A DENORMAL PATH — stated in the constant's own doc block rather than
// fixed. The residue now decays as 0.99ⁿ instead of not at all, so it crosses ~1e-38 after
// roughly 8 700 samples and underflows a few thousand later. Scalar FP on Apple silicon does
// not penalise that; recorded so it is not re-derived.
//
// ⚠️ NEW BUNDLE ON PURPOSE (#416 asks for ONE home per law, not for NO new bundle). This law —
// the interpolator's pole must stay inside the unit circle — had no home.
// `ANonFiniteControlCannotReachTheRenderTests` owns a different one (a NaN at a control
// boundary must fail quiet) and says so in its own heading;
// `SleepingChainDoesNotHoardAudioTests` owns the drain.
//
// LIMITS (§1). Claims 1–3b are END-TO-END BEHAVIOUR on the shipped `EchoelDelayLine` — it is
// `public` and Foundation-only, so this drives real floats through the real filter. Claim 4 is
// a SOURCE-TEXT SCAN. No DEVICE PROBE: whether the ring was ever audible through the wet mix
// and the downstream limiter is a founder's ear, not a test.
//
// GRADING against `git show HEAD:<path>` (§3), transcribed in Python (§0, no toolchain) by
// re-driving BOTH trees' actual formula, not the diff:
// Counted as ASSERTIONS, not as list items — an earlier tally said "FIVE counterweights" and
// then enumerated four groups, which is the flattering direction §3 warns about.
//  · FOUR RED ASSERTIONS on the parent, but THREE findings (#486 — one absence reported twice
//    is one finding): claim 1's decay assertion (|y| = 0.333 on the parent, 0.00219 here, a
//    factor of 152), claim 3b's boundary probe (the one delay where the two trees differ), and
//    claim 4's TWO needles, which are the single absence of the fix seen from two angles.
//  · SEVEN COUNTERWEIGHT ASSERTIONS, green on both trees and the point of the file (#343),
//    across FIVE named items in FOUR test methods: claim 1's own seed check (so the derived
//    expectation stays derived) · claim 2 · claim 3's THREE bit-identical values · claim 3's
//    boundary probe on the safe side · claim 4's call-site pin. Each names a way to satisfy
//    the letter of the fix and lose it: return zero, stop interpolating, quietly move
//    ordinary output, or guard a function nothing calls.
//    ⛔ THIS TALLY SAID "SIX" AND LISTED FIVE — in the very paragraph that retracts an earlier
//    "FIVE that listed four". Second offence, same direction. The lesson is not "count again":
//    it is that ITEMS, METHODS and ASSERTIONS are three different denominators, and a tally
//    that does not say WHICH is unfalsifiable. All three are now written out.
//  · ZERO anchor absences — every needle and every behavioural path resolves on BOTH trees.
//
// NEEDS-FOUNDER-VERIFY — und das REZEPT ist beim ersten Mal falsch gewesen, in beiden Haelften.
// Es sagte "Tiefe LANGSAM auf 0 ziehen" und "hoeren". Ein langsamer Zug regt die Mode kaum an
// (der Zustand laeuft mit), und der Rest sitzt bei GENAU Nyquist — als Ton praktisch unhoerbar.
// Richtig: Chorus an, Mix hoerbar auf, dann Depth SPRUNGHAFT auf 0 setzen — im Zahlenfeld die 0
// tippen, oder ein Genre-Preset laden (`GenreFX` schreibt `chorus.depth` direkt). Danach NICHT
// nur hinhoeren, sondern den Master-Pegel bzw. die Gain-Reduction des Limiters ansehen: bleibt
// dort ein stehender Rest, der erst beim Weiterdrehen verschwindet? (#1205)

import Foundation
import XCTest
@testable import Echoelmusic

final class TheAllpassInterpolatorCannotRingForeverTests: XCTestCase {

    /// A line whose taps are all zero, with the filter state deliberately charged.
    /// Returns the seed value so a claim can state what it started from.
    private func chargedLine() -> (EchoelDelayLine, Float) {
        let line = EchoelDelayLine(maxDelaySeconds: 0.01, sampleRate: 48000)
        line.write(1.0)
        // frac = 0.5 ⇒ eta = 1/3, and the only non-zero tap is the sample just written,
        // so the output — and therefore the stored state — is exactly eta.
        let seed = line.readAllpass(delaySamples: 1.5)
        // Walk the impulse away so every later read sees zeros.
        for _ in 0..<10 { line.write(0) }
        return (line, seed)
    }

    // MARK: - 1. the ring decays

    /// REGRESSION (#1205). END-TO-END BEHAVIOUR.
    ///
    /// The expectation is DERIVED, not observed (#442/#686): the seed is exactly 1/3 in Float,
    /// and with zero input at an integer delay the recursion is `y[n] = -eta · y[n-1]`, so
    /// after 500 reads the magnitude is `(1/3) · 0.99^500 = 0.00219`. Without the clamp
    /// `eta` is 1.0 and the magnitude is still exactly `1/3` — a factor of 152.
    /// ⛔ THE MARGINS ARE NOT SYMMETRIC, and an earlier draft claimed "two orders on each side".
    /// Measured: the threshold 0.01 sits **4.57×** above the clamped value and **33.3×** below
    /// the unclamped one. Both are comfortable; neither is two orders, and the tighter side is
    /// the one this claim depends on.
    func testAChargedFilterAtAnIntegerDelayDecays() {
        let (line, seed) = chargedLine()
        XCTAssertEqual(seed, 1.0 / 3.0, accuracy: 1e-6, """
            the charge step no longer stores 1/3, so this claim's derived expectation below \
            no longer follows from it. Re-derive before changing the threshold (#1205).
            """)

        var last: Float = 0
        for _ in 0..<500 {
            line.write(0)
            last = line.readAllpass(delaySamples: 4.0)
        }

        XCTAssertLessThan(abs(last), 0.01, """
            the allpass interpolator still rings forever at an exactly integer delay. With \
            `eta` uncapped the pole sits ON the unit circle and the state alternates ± the \
            same value with no decay — measured 0.333 here, unchanged after 500 samples of \
            silence, and unchanged after three seconds in the chorus simulation. \
            `EchoelChorus` reaches this state at Depth 0 on 48 kHz (12 ms = 576.0 samples \
            exactly), and Depth is a user field with range 0...1 (#1205).
            """)
    }

    // MARK: - 2. and it does not decay by accident of the input

    /// COUNTERWEIGHT (#343). Claim 1 would also pass if `readAllpass` simply returned 0, or if
    /// the line stopped holding audio at all. This drives the SAME filter with a real signal at
    /// a fractional delay and asserts it still returns the interpolated sample.
    func testTheInterpolatorStillReturnsAudio() {
        let line = EchoelDelayLine(maxDelaySeconds: 0.01, sampleRate: 48000)
        for x in [Float(1.0), -0.5, 0.25, 0.75] { line.write(x) }
        XCTAssertEqual(line.readAllpass(delaySamples: 1.5), 0.5, accuracy: 1e-6, """
            `readAllpass` no longer interpolates. Claim 1 above is satisfied by a filter that \
            returns zero as easily as by one that decays, so this is the half that says the \
            stage is still doing its job (#1205).
            """)
    }

    // MARK: - 3. the clamp is neutral where it must be

    /// COUNTERWEIGHT (#343), and the one that keeps this slice honest about its cost. The clamp
    /// engages only for `frac < 0.005025`. At ordinary fractional delays the output must be
    /// BIT-IDENTICAL to the unclamped formula — these three values were computed from the
    /// unclamped arithmetic in Float and are asserted with ZERO tolerance.
    func testOrdinaryFractionalReadsAreBitIdentical() {
        // The last row is the BOUNDARY PROBE on the safe side: frac = 0.0051 puts the raw
        // coefficient at 0.98985, just under the cap, so the clamp must not fire. Without it
        // claim 3 only samples delays far from the edge and cannot tell a 0.99 cap from a 0.9
        // one (#367 — able to fail for its NAMED reason).
        let expected: [(Float, Float)] = [
            (1.5, 0.5),
            (2.25, -0.3499999940395355),
            (3.75, 0.9285714030265808),
            (1.0051, 0.9923887848854065),
        ]
        for (delay, value) in expected {
            let line = EchoelDelayLine(maxDelaySeconds: 0.01, sampleRate: 48000)
            for x in [Float(1.0), -0.5, 0.25, 0.75] { line.write(x) }
            XCTAssertEqual(line.readAllpass(delaySamples: delay), value, """
                `readAllpass(delaySamples: \(delay))` changed. #1205's clamp must be inert \
                wherever the raw coefficient is already below 0.99 — that is every delay whose \
                fractional part exceeds 0.005025, i.e. essentially all of them. A change here \
                means the clamp is altering sound it was measured not to touch.
                """)
        }
    }

    // MARK: - 3b. and it DOES engage on the other side of the boundary

    /// REGRESSION (#1205). END-TO-END BEHAVIOUR, and the twin of claim 3: one delay's fractional
    /// part sits just BELOW 0.005025, so the raw coefficient is 0.99025 and the cap bites. This
    /// is the only assertion in the file that reads a value the parent tree cannot produce, so
    /// it is what proves the clamp is wired rather than merely present in source text.
    ///
    /// Both numbers are derived (#442): unclamped 0.9926859140396118, clamped 0.9925000071525574.
    /// They differ in the fifth decimal — that IS the cost of the fix, stated rather than hidden.
    func testTheClampEngagesJustInsideTheBoundary() {
        let line = EchoelDelayLine(maxDelaySeconds: 0.01, sampleRate: 48000)
        for x in [Float(1.0), -0.5, 0.25, 0.75] { line.write(x) }
        XCTAssertEqual(line.readAllpass(delaySamples: 1.0049), 0.9925000071525574, """
            the coefficient cap no longer engages at frac = 0.0049, where the raw value is \
            0.99025. Either the cap is gone (the parent tree returns 0.9926859140396118 here) \
            or it was retuned — in which case this expectation, claim 1's 0.00219, and the four \
            derived figures in `maxAllpassCoefficient`'s doc block all move together (#364).
            """)
    }

    // MARK: - 4. the bound is a named constant, applied NaN-safely

    /// REGRESSION (#1205). SOURCE-TEXT SCAN (§1).
    ///
    /// Two things a behavioural test cannot see. The bound must be a NAMED constant — an
    /// inline 0.99 in the hot loop is the kind of magic number this repo keeps having to
    /// excavate. And the argument order of `Swift.min` is the NaN rule, not style:
    /// `min(a, b)` is `b < a ? b : a`, so `min(0.99, NaN)` is 0.99 while `min(NaN, 0.99)` is
    /// NaN. Prophylactic today — `frac` cannot be NaN because `d` is `clamped(to:)` — and free.
    ///
    /// ⚠️ It also pins that the guarded call has PRODUCTION callers. A stability guard over a
    /// function nobody calls guards nothing (#367).
    func testTheCoefficientBoundIsNamedAndNaNSafe() throws {
        let line = try SourceText.codeOnly(Self.read("Sources/Echoelmusic/DSP/EchoelDelayLine.swift"))
        XCTAssertTrue(line.contains("private let maxAllpassCoefficient: Float = 0.99"), """
            the allpass coefficient bound is no longer a named constant at 0.99. If you \
            retuned it, these move with it and must be re-derived in the SAME commit (#364): \
            the four derived numbers in its own doc block (half-life, engagement share, \
            realised-delay error, denormal residency), the 0.00219 expectation in claim 1 \
            above, and claim 3b's 0.9925000071525574 below. \
            ⚠️ ONE OF THEM IS IN ANOTHER FILE and was missing from this list: \
            `SleepingChainDoesNotHoardAudioTests.testTheStorageGateIsNeutralInNormalOperation` \
            reads back this coefficient from a whole-sample delay. Its band is deliberately \
            `(0, 1]` so ANY cap in that range passes — but if you move the cap OUTSIDE it, \
            that file goes red on correct code with a message that blames the gate.
            """)
        XCTAssertTrue(
            line.contains("Swift.min(maxAllpassCoefficient, (1.0 - frac) / (1.0 + frac))"), """
            the coefficient clamp is gone, or its argument order changed. `Swift.min(a, b)` is \
            `b < a ? b : a`, so the known-good value must come FIRST or a NaN passes straight \
            through — the rule CLAUDE.md states for `max`/`min` (#1205).
            """)

        let modFX = try SourceText.codeOnly(Self.read("Sources/Echoelmusic/DSP/EchoelModFX.swift"))
        XCTAssertEqual(modFX.components(separatedBy: "readAllpass(delaySamples:").count - 1, 4, """
            the number of `readAllpass` call sites IN `EchoelModFX.swift` changed. #1205 guards \
            a stability property of that function; with no caller it guards nothing, and with a \
            new caller the reachability argument in this file's heading — chorus at 12 ms and \
            flanger at 3 ms, both exact integers at 48 kHz — is no longer the whole story.
            ⚠️ This pin reads ONE file. Today that file holds EVERY production caller \
            (`git grep -n "readAllpass(delaySamples:" -- Sources` = the declaration plus these \
            four), but a caller added elsewhere is invisible here — re-run that command rather \
            than reading this pin as a repo-wide count.
            """)
    }

    // MARK: - Source helpers

    private static func read(_ path: String) throws -> String {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("""
                \(path) is not present at \(url.path) — this claim inspects source text, so it \
                SKIPS rather than reporting a green it did not earn
                """)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
