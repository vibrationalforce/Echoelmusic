// TheWaveformGainDoesNotBreatheTests.swift
// Echoel — #1270. Founder 2026-09-11: "die Wellenform EKG wird mal größer mal kleiner es
// reicht wenn alles in einer übersichtlichen Form daherkommt".
//
// ⭐ THE MECHANISM, measured before anything was changed. `CameraAnalyzer.recentWaveform`
// divided the DISPLAYED 6 s of filtered signal by the largest magnitude IN THAT SAME 6 s, and
// the property is read at ~10 Hz. Two things followed, both visible:
//   · The gain jumped. As the window slid past a strong beat the divisor dropped abruptly and
//     the same shape was redrawn taller. Nothing smoothed it — the divisor was recomputed from
//     scratch on every read.
//   · Everything reached full scale. A stretch with almost no pulse was amplified until it
//     filled the box, so noise was indistinguishable from a strong signal — in the one display
//     whose job is to tell the player the finger is placed right.
//
// THE FIX keeps the function PURE: measure the SHAPE over the display window and the HEIGHT
// over a longer one (~20 s). The divisor then changes only as slowly as that window slides,
// and a quiet stretch is drawn small because it IS small relative to the recent past. No
// absolute threshold is invented, so the signal's units never have to be guessed at.
//
// ⛔ WHY THE COUNTERWEIGHT (claim 4) IS NOT OPTIONAL. The cheap way to stop a trace from
// breathing is to shrink it, and every assertion above would still pass. Claim 4 pins that a
// strong steady signal still reaches full height — otherwise this slice would have traded a
// jumpy display for a dead one, which is the same complaint with a different shape.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheWaveformGainDoesNotBreatheTests: XCTestCase {

    /// A signal whose recent stretch is `tailAmplitude` and whose earlier stretch is 1.0.
    private func signal(total: Int, tail: Int, tailAmplitude: Float) -> [Float] {
        (0..<total).map { i in
            let a: Float = i >= total - tail ? tailAmplitude : 1
            return a * (i % 2 == 0 ? 1 : -1)
        }
    }

    private func peak(_ xs: [Float]) -> Float { xs.map { abs($0) }.max() ?? 0 }

    /// claim 1 (THE FIX) — a quiet stretch is drawn quiet, not stretched to full height.
    func testAQuietStretchIsNotAmplifiedToFullScale() {
        let s = signal(total: 300, tail: 90, tailAmplitude: 0.1)
        let out = CameraAnalyzer.normalizedTrace(s, display: 90, gainWindow: 300)
        XCTAssertEqual(out.count, 90)
        XCTAssertEqual(peak(out), 0.1, accuracy: 0.02, """
            A stretch at a tenth of the recent maximum was drawn at \(peak(out)) of full \
            height. Normalising to the DISPLAY window is what made noise look like a strong \
            pulse; the gain must come from the longer window.
            """)
    }

    /// claim 2 (THE COMPLAINT, reproduced numerically) — a sample of CONSTANT true amplitude
    /// must not suddenly be drawn tall because a loud beat slid out of the display window.
    ///
    /// ⛔ THE OBVIOUS METRIC IS USELESS HERE AND THE FIRST DRAFT USED IT. Under the old law the
    /// displayed PEAK is always exactly 1.0 — dividing a window by its own maximum guarantees
    /// it — so a peak-based assertion passes under both laws and proves nothing. What actually
    /// jumped is how a QUIET sample is drawn, so that is what this measures: the newest sample
    /// has a true amplitude of 0.3 in every one of the thirteen reads.
    ///
    /// ⭐ IT IS KNOWN TO DISCRIMINATE, not assumed to: on this exact sweep the OLD law draws
    /// that sample 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, then 1.0 for the rest — the beat leaves the
    /// 90-sample window at the sixth read and the height triples between two frames. Spread
    /// 0.70 old, 0.00 new.
    func testAQuietSampleIsNotDrawnTallWhenABeatLeavesTheWindow() {
        var full: [Float] = (0..<400).map { i in
            let a: Float = (i == 315) ? 1.0 : 0.3
            let sign: Float = (i % 2 == 0) ? 1 : -1
            return a * sign
        }
        full += (0..<13).map { i in
            let sign: Float = (i % 2 == 0) ? 1 : -1
            return 0.3 * sign
        }
        let heights: [Float] = (0..<13).map { i in
            let view = Array(full.prefix(400 + i))
            let trace = CameraAnalyzer.normalizedTrace(view, display: 90, gainWindow: 300)
            return abs(trace.last ?? 0)
        }
        let spread = (heights.max() ?? 0) - (heights.min() ?? 0)
        XCTAssertLessThan(spread, 0.05, """
            A sample whose true amplitude never changed was drawn across a range of \(spread) \
            over thirteen consecutive reads (\(heights.map { ($0 * 100).rounded() / 100 })). \
            That is the founder's "mal größer mal kleiner": the gain is measured over a window \
            short enough that one beat entering or leaving it rescales everything else.
            """)
    }

    /// claim 3 (THE FLOOR) — a gain window SHORTER than the display window must be raised to
    /// it, never honoured. Asking for a shorter one is asking for the old behaviour.
    ///
    /// ⚠️ THIS IS A FLOOR, NOT A PROMISE ABOUT THE SHIPPED WINDOW. Raised to the display
    /// length the trace still normalises to its own 6 s — i.e. exactly the old defect. What
    /// keeps the SHIPPED path honest is claim 5, which pins that the real window is longer.
    /// Stating that distinction here because the first draft of this claim asserted the
    /// short window behaved like the 300-sample one, which is not what the code does and not
    /// what it should do: silently substituting a caller's number by a factor of thirty would
    /// be a worse contract than clamping it.
    func testAGainWindowShorterThanTheDisplayWindowIsRaisedToIt() {
        let s = signal(total: 300, tail: 90, tailAmplitude: 0.1)
        let asked = CameraAnalyzer.normalizedTrace(s, display: 90, gainWindow: 10)
        let floor = CameraAnalyzer.normalizedTrace(s, display: 90, gainWindow: 90)
        XCTAssertEqual(asked, floor, """
            A gain window of 10 against a display of 90 did not behave like a window of 90. \
            A gain window shorter than the drawn window cannot be meaningful — it would \
            rescale the trace faster than the trace itself moves.
            """)
    }

    /// claim 4 (COUNTERWEIGHT) — a strong steady signal still fills the box. Without this, the
    /// cheapest way to pass every assertion above is to make the trace permanently small.
    func testASteadySignalStillReachesFullHeight() {
        let s = signal(total: 300, tail: 90, tailAmplitude: 1)
        let out = CameraAnalyzer.normalizedTrace(s, display: 90, gainWindow: 300)
        XCTAssertEqual(peak(out), 1, accuracy: 1e-6, """
            A signal at the recent maximum drew at \(peak(out)) of full height. The fix is \
            meant to stop the trace BREATHING, not to shrink it.
            """)
    }

    /// claim 5 (THE CONSTANTS) — the shipped pair must keep the relation the fix depends on.
    func testTheShippedGainWindowIsLongerThanTheShippedDisplayWindow() {
        XCTAssertGreaterThan(CameraAnalyzer.waveformGainSamples,
                             CameraAnalyzer.waveformDisplaySamples, """
            The shipped gain window (\(CameraAnalyzer.waveformGainSamples)) is no longer \
            longer than the display window (\(CameraAnalyzer.waveformDisplaySamples)). Equal \
            windows ARE the old behaviour — the trace would breathe again with every read.
            """)
    }

    /// claim 6 (THE BOUND) — the gain window must stay inside the analyzer's ring buffer, or
    /// it silently degrades to "whatever exists" and the guarantee is only as good as uptime.
    func testTheGainWindowFitsInTheSignalBuffer() {
        XCTAssertLessThanOrEqual(CameraAnalyzer.waveformGainSamples, 600, """
            The gain window exceeds the 600-sample (~40 s) signal buffer, so it can never be \
            filled and the effective window is just the buffer. Either shorten it or raise \
            `maxSignalLength` deliberately.
            """)
    }
}
