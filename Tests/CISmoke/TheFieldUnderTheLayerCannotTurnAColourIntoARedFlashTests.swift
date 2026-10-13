// TheFieldUnderTheLayerCannotTurnAColourIntoARedFlashTests.swift
// Echoel — GMMW VV-4e, the open gap in the footage flash limiter, pinned as an EXPECTED FAILURE.
// It repairs nothing. The case and its arithmetic came from an outside review (orchestra task 10b,
// 2026-10-13) and were re-derived here before this file was written.
//
// THE GAP. Footage is composited as a SCREEN over the generated field, per channel in linear light:
// shown = F + g·L·(1 − F) (`MetalBioView`, `lin + outCol * (1.0 - lin)`). `VideoFlashLimiter` counts the
// luminance and the red signal (linear R − G − B, floored at 0) of the LAYER L, not of what is shown.
// Over a reddish field a blue or green change in the layer still moves R − G − B ON SCREEN, and no
// channel counts it. Measured below on three reddish fields × two layer colours flickering against
// black at 10 Hz: the layers' luminance is 0.02166 and 0.02159 (under the 0.025 window step), their
// red signal is 0, so the gain stays 1 — while the shown red signal swings by 0.2095…0.3 twenty times a
// second, against a WCAG red step of 20/320 = 0.0625 and an allowance of five transitions a second.
//
// WHY AN EXPECTED FAILURE AND NOT A RED TEST. A guard that is red on today's tree would sit in the
// blocking bundle as a permanent false alarm (Tests/CISmoke/CLAUDE.md §4). `XCTExpectFailure` keeps the
// gap on record and flips the other way: the day a repair makes claim A hold, the expectation is not
// met and the test fails — remove the `XCTExpectFailure` wrapper in that commit. No user can reach this
// today: nothing calls `VideoLayerSlot.attachVideoOutput` yet, so the gap must close before a footage
// door does.
//
// WHAT A REPAIR MUST DO (not how): over a fixed field, the layer must not move the SHOWN red signal by
// `redCellTransitionThreshold` more than `engageTransitions` times in a second, even when its own red
// signal is 0. Two ways are under discussion — count the field's colour, or bound each colour channel
// of the layer — and this file prescribes neither.
//
// GRADING (Tests/CISmoke/CLAUDE.md §3). All four claims are END-TO-END on the shipped, public,
// Foundation-only `VideoFlashLimiter` and `VideoLayerMath`; the screen blend is transcribed from the
// shader, not executed. Claim 1 (premise) and claims 3 and 4 (counterweights) are green on this tree;
// claim 2 is the expected failure. The driver models the dial at 1 and the 8-bit drawable not at all.
// Re-derived in Python before commit: the six shown swings 0.3 · 0.21 · 0.3 · 0.21 · 0.25 · 0.2095, both
// layer luminances, and 0 over black.

import XCTest
@testable import Echoelmusic

final class TheFieldUnderTheLayerCannotTurnAColourIntoARedFlashTests: XCTestCase {

    /// A colour in LINEAR light; the luminance and red signal below are taken in linear light too, with
    /// `VideoLayerMath`'s own weights, so no sRGB round trip sits between the case and the count.
    private struct Linear {
        let r: Double
        let g: Double
        let b: Double
    }

    private static let framesPerSecond = 60
    private static let seconds = 3
    private static let fastHertz = 10
    private static let slowHertz = 1

    private static let black = Linear(r: 0, g: 0, b: 0)
    private static let reddishFields = [Linear(r: 0.5, g: 0, b: 0),
                                        Linear(r: 1, g: 0, b: 0),
                                        Linear(r: 0.3, g: 0.05, b: 0)]
    /// Each flickers against black. Neither carries red, and neither moves the luminance a whole step.
    private static let layers = [Linear(r: 0, g: 0, b: 0.3),
                                 Linear(r: 0, g: 0.01, b: 0.2)]

    private static func luminance(_ c: Linear) -> Double {
        VideoLayerMath.redWeight * c.r + VideoLayerMath.greenWeight * c.g + VideoLayerMath.blueWeight * c.b
    }

    private static func redSignal(_ c: Linear) -> Double {
        Swift.max(0, c.r - c.g - c.b)
    }

    /// The shader's screen blend, per channel: F + g·L·(1 − F).
    private static func screen(field f: Linear, layer l: Linear, gain g: Double) -> Linear {
        Linear(r: f.r + g * l.r * (1 - f.r),
               g: f.g + g * l.g * (1 - f.g),
               b: f.b + g * l.b * (1 - f.b))
    }

    /// Drives the real limiter frame by frame with what `VideoLayerSlot` hands it (every cell the
    /// layer's luminance and red signal, dial at 1), and returns the most SHOWN red transitions — moves
    /// of at least the WCAG red step against the last counted level — inside any one second.
    private static func mostShownRedTransitions(field: Linear, layer: Linear, hertz: Int) -> Int {
        var limiter = VideoFlashLimiter()
        let side = VideoLayerMath.flashCellsPerSide
        let cellCount = side * side
        let framesPerHalfPeriod = framesPerSecond / (2 * hertz)
        var reference: Double?
        var times: [Double] = []
        for frame in 0..<(framesPerSecond * seconds) {
            let time = Double(frame) / Double(framesPerSecond)
            let current = (frame / framesPerHalfPeriod) % 2 == 1 ? layer : black
            let gain = limiter.step(time: time,
                                    cells: [Double](repeating: luminance(current), count: cellCount),
                                    redCells: [Double](repeating: redSignal(current), count: cellCount),
                                    cellsPerSide: side)
            let shown = redSignal(screen(field: field, layer: current, gain: gain))
            guard let last = reference else {
                reference = shown
                continue
            }
            if abs(shown - last) >= VideoFlashLimiter.redCellTransitionThreshold - VideoFlashLimiter.roundingAllowance {
                times.append(time)
                reference = shown
            }
        }
        var most = 0
        for end in times {
            let inWindow = times.filter { $0 > end - VideoFlashLimiter.windowSeconds && $0 <= end }.count
            most = Swift.max(most, inWindow)
        }
        return most
    }

    // 1 — premise: the layer alone is invisible to every channel the limiter counts.
    func testTheLayerColoursAloneStayUnderEveryStepTheLimiterCounts() {
        for layer in Self.layers {
            XCTAssertLessThan(Self.luminance(layer), VideoFlashLimiter.transitionThreshold,
                              "a layer that moves the luminance a whole window step would make claim 2 prove something else")
            XCTAssertEqual(Self.redSignal(layer), 0,
                           "claim 2 needs a layer that carries no red of its own")
        }
    }

    // 2 — the gap: EXPECTED to fail until VV-4e is repaired. When it starts passing, remove the wrapper.
    func testAColourFlickerOverAReddishFieldIsCapped() {
        XCTExpectFailure("VV-4e: the limiter counts the layer, not the colour it shows over the field") {
            for field in Self.reddishFields {
                for layer in Self.layers {
                    let most = Self.mostShownRedTransitions(field: field, layer: layer, hertz: Self.fastHertz)
                    XCTAssertLessThanOrEqual(most, VideoFlashLimiter.engageTransitions, """
                        over the field (\(field.r), \(field.g), \(field.b)) the layer (\(layer.r), \(layer.g), \
                        \(layer.b)) at \(Self.fastHertz) Hz shows \(most) red transitions in one second; \
                        the cap allows \(VideoFlashLimiter.engageTransitions)
                        """)
                }
            }
        }
    }

    // 3 — counterweight: the same flicker over black shows no red change, so claim 2 needs the field.
    func testTheSameFlickerOverABlackFieldShowsNoRedChange() {
        for layer in Self.layers {
            XCTAssertEqual(Self.mostShownRedTransitions(field: Self.black, layer: layer, hertz: Self.fastHertz), 0,
                           "over black the layer shows a red change — claim 2 would no longer measure the field")
        }
    }

    // 4 — counterweight: one change a half second over the same fields is allowed.
    func testTheSameColoursAtOneHertzAreAllowed() {
        for field in Self.reddishFields {
            for layer in Self.layers {
                let most = Self.mostShownRedTransitions(field: field, layer: layer, hertz: Self.slowHertz)
                XCTAssertLessThanOrEqual(most, VideoFlashLimiter.engageTransitions,
                                         "a 1 Hz change counts \(most) a second — the count in this file is too strict")
            }
        }
    }
}
