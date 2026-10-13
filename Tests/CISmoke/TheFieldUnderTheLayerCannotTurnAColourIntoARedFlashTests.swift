// TheFieldUnderTheLayerCannotTurnAColourIntoARedFlashTests.swift
// Echoel — GMMW VV-4e: the footage flash limiter bounds what a layer adds to the red over ANY field.
// The case and its arithmetic came from an outside review (orchestra task 10b, 2026-10-13) and were
// re-derived here; the file first pinned the gap as an expected failure (`d3480ac13`), and the repair
// that closed it lifted the wrapper in the same commit, as the file asked.
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
// THE REPAIR (VV-4e, `VideoFlashLimiter` header, COLOUR). The limiter never sees the field, so it
// bounds every field at once: the layer's share of the shown R − G − B is linear in (1 − F) per
// channel, so its move is largest at a corner of that box, and the limiter counts the seven corner
// sums (`VideoFlashLimiter.colourCombinations`) on linear R, G, B cell means the slot hands it. The
// driver below hands the same cells (`colourCells:`); with `colourCells: nil` claim 2 is red again —
// that is the regression it catches. No user can reach this yet: nothing calls
// `VideoLayerSlot.attachVideoOutput`; the bound has to be in place before a footage door is.
//
// GRADING (Tests/CISmoke/CLAUDE.md §3). All five claims are END-TO-END on the shipped, public,
// Foundation-only `VideoFlashLimiter` and `VideoLayerMath`; the screen blend is transcribed from the
// shader, not executed. The file does NOT COMPILE on its parent (`colourCells:` and `ColourCells` are
// new), so no assertion has a verdict there; transcribed in Python against the parent's limiter, claim
// 2 counts 21 shown red transitions in a second on each of the six cases (a REGRESSION guard), and
// against this tree 4. Claims 1, 3, 4 and 5 are counterweights, green on both. The driver models the
// dial at 1 and the 8-bit drawable not at all. Re-derived in Python before commit: the six shown
// swings 0.3 · 0.21 · 0.3 · 0.21 · 0.25 · 0.2095, both layer luminances, 0 over black, 2 a second at
// 1 Hz, and 400 random fields × random colour strobes at 3…30 Hz with none above 5.

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
    /// layer's luminance, red signal and linear R, G, B, dial at 1), and returns the most SHOWN red
    /// transitions — moves of at least the WCAG red step against the last counted level — inside any
    /// one second.
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
            let colour = VideoFlashLimiter.ColourCells(red: [Double](repeating: current.r, count: cellCount),
                                                       green: [Double](repeating: current.g, count: cellCount),
                                                       blue: [Double](repeating: current.b, count: cellCount))
            let gain = limiter.step(time: time,
                                    cells: [Double](repeating: luminance(current), count: cellCount),
                                    redCells: [Double](repeating: redSignal(current), count: cellCount),
                                    colourCells: colour,
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

    // 2 — VV-4e: a colour flicker the layer's own red signal cannot see is capped over a reddish field.
    func testAColourFlickerOverAReddishFieldIsCapped() {
        for field in Self.reddishFields {
            for layer in Self.layers {
                let most = Self.mostShownRedTransitions(field: field, layer: layer, hertz: Self.fastHertz)
                XCTAssertLessThanOrEqual(most, VideoFlashLimiter.engageTransitions, """
                    over the field (\(field.r), \(field.g), \(field.b)) the layer (\(layer.r), \(layer.g), \
                    \(layer.b)) at \(Self.fastHertz) Hz shows \(most) red transitions in one second; \
                    the cap allows \(VideoFlashLimiter.engageTransitions) — the colour sums no longer reach the \
                    count (VV-4e)
                    """)
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

    // 5 — the seven sums are the non-zero corners of the field box, each with a span that holds 0 and
    //     every value its weights can reach — the premises the header's argument stands on.
    func testTheColourSumsAreTheCornersOfTheFieldBox() {
        let sums = VideoFlashLimiter.colourCombinations
        XCTAssertEqual(sums.count, 7, "three channels, each weight 0 or 1: seven non-zero corners")
        let up: [Double] = [0, 1]
        let down: [Double] = [0, -1]
        var corners = Set<[Double]>()
        for sum in sums {
            XCTAssertTrue(up.contains(sum.red), "red counts up in the shown R − G − B")
            XCTAssertTrue(down.contains(sum.green), "green counts down in the shown R − G − B")
            XCTAssertTrue(down.contains(sum.blue), "blue counts down in the shown R − G − B")
            corners.insert([sum.red, sum.green, sum.blue])
            let lowest = Swift.min(0, sum.green) + Swift.min(0, sum.blue)
            let highest = Swift.max(0, sum.red)
            XCTAssertEqual(sum.lowest, lowest, accuracy: 1e-12, "the sum's lowest value over 0…1 channels")
            XCTAssertEqual(sum.lowest + sum.span, highest, accuracy: 1e-12, "the sum's highest value over 0…1 channels")
            XCTAssertLessThanOrEqual(sum.lowest, 0, "a span that does not hold 0 would let the gain move the share")
            XCTAssertGreaterThanOrEqual(sum.lowest + sum.span, 0)
        }
        XCTAssertEqual(corners.count, 7, "no corner twice, none missing")
    }
}
