import XCTest
@testable import EchoelCore

/// The Chladni plate: a sine chooses the mode that rings at its pitch, silence is a calm plate,
/// sand lies on the nodal lines, the same sound is the same figure, and no sound — however it
/// jumps — makes the plate flash more than three times a second (WCAG 2.3.1).
final class ChladniPlateTests: XCTestCase {
    private func partials(_ pairs: [(Double, Double)]) -> ChladniModes {
        var frequencies = SIMD8<Double>(repeating: 0), amplitudes = SIMD8<Double>(repeating: 0)
        for (index, pair) in pairs.prefix(8).enumerated() {
            frequencies[index] = pair.0
            amplitudes[index] = pair.1
        }
        return ChladniPlate.modes(frequencies: frequencies, amplitudes: amplitudes, count: Swift.min(pairs.count, 8))
    }

    func testASineChoosesTheModeThatRingsAtItsPitch() {
        let a4 = partials([(440, 0.5)])
        XCTAssertEqual(a4.dominant?.m, 0)
        XCTAssertEqual(a4.dominant?.n, 4)
        XCTAssertEqual(ChladniPlate.frequency(m: 0, n: 4), 440)
        let a6 = partials([(1_760, 0.5)])
        XCTAssertEqual(a6.dominant?.m, 0)
        XCTAssertEqual(a6.dominant?.n, 8)
        XCTAssertGreaterThan(a4.weight[0], a4.weight[1])
        XCTAssertEqual(a4.weight.sum(), 1, accuracy: 1e-9)
    }

    func testAHigherPitchIsAFinerFigure() {
        let low = partials([(110, 0.5)]), high = partials([(3_520, 0.5)])
        guard let lowMode = low.dominant, let highMode = high.dominant else { return XCTFail("both ring") }
        XCTAssertLessThan(lowMode.m * lowMode.m + lowMode.n * lowMode.n, highMode.m * highMode.m + highMode.n * highMode.n)
    }

    func testSilenceIsACalmPlate() {
        XCTAssertEqual(partials([]), .calm)
        XCTAssertEqual(partials([(440, 0.000_1)]), .calm, "−80 dBFS does not move the plate")
        XCTAssertEqual(partials([(.nan, 0.5), (440, .infinity)]), .calm)
        // A calm plate shows only the ambient light, everywhere.
        var motion = ChladniMotion()
        var shown = motion.step(towards: .calm, after: 1.0 / 60, still: false)
        for _ in 0..<60 { shown = motion.step(towards: .calm, after: 1.0 / 60, still: false) }
        for x in stride(from: 0.0, through: 1, by: 0.25) {
            XCTAssertEqual(shown.luminance(x: x, y: 0.3), FieldPulse.ambient, accuracy: 1e-12)
        }
    }

    func testTheLoudnessIsTheDrive() {
        XCTAssertEqual(partials([(440, 0.6)]).drive, 1, accuracy: 1e-9, "−6 dBFS and up is full")
        let quiet = partials([(440, 0.01)]).drive
        XCTAssertGreaterThan(quiet, 0)
        XCTAssertLessThan(quiet, 0.5)
    }

    func testSandLiesOnTheNodalLines() {
        // (0, 1): cos(πy) − cos(πx), still on the diagonal x = y, moving most at the corners.
        let modes = ChladniModes(m: SIMD4(0, 0, 0, 0), n: SIMD4(1, 0, 0, 0), weight: SIMD4(1, 0, 0, 0), drive: 1)
        XCTAssertEqual(ChladniPlate.displacement(x: 0.3, y: 0.3, modes: modes), 0, accuracy: 1e-12)
        XCTAssertEqual(ChladniPlate.sand(ChladniPlate.displacement(x: 0.3, y: 0.3, modes: modes)), 1, accuracy: 1e-12)
        XCTAssertLessThan(ChladniPlate.sand(ChladniPlate.displacement(x: 0, y: 1, modes: modes)), 1e-6)
        XCTAssertEqual(ChladniPlate.sand(.nan), 0)
        XCTAssertEqual(Double(ChladniPlate.sandWidthLiteral), ChladniPlate.sandWidth, "the shader draws the same width")
    }

    func testTheSameSoundIsTheSameFigure() {
        let sound: [(Double, Double)] = [(196, 0.3), (392, 0.2), (588, 0.1), (1_200, 0.05)]
        XCTAssertEqual(partials(sound), partials(sound))
        var one = ChladniMotion(), two = ChladniMotion()
        for frame in 0..<120 {
            let target = frame % 40 < 20 ? partials(sound) : partials([(440, 0.4)])
            XCTAssertEqual(one.step(towards: target, after: 1.0 / 60, still: false),
                           two.step(towards: target, after: 1.0 / 60, still: false))
        }
    }

    func testAFigureChangesByCrossFadeNeverByACut() {
        var motion = ChladniMotion()
        let first = partials([(440, 0.5)]), second = partials([(1_760, 0.5)])
        _ = motion.step(towards: first, after: 1.0 / 60, still: false)
        var mixes: [Double] = []
        for _ in 0..<60 { mixes.append(motion.step(towards: second, after: 1.0 / 60, still: false).mix) }
        XCTAssertLessThan(mixes[0], 0.05, "the new figure starts from the old one")
        for (a, b) in zip(mixes, mixes.dropFirst()) { XCTAssertLessThan(Swift.abs(b - a), 0.1) }
        XCTAssertEqual(mixes.last ?? 0, 1, accuracy: 1e-9)
    }

    func testStillHoldsTheFigure() {
        var motion = ChladniMotion()
        _ = motion.step(towards: partials([(440, 0.5)]), after: 1.0 / 60, still: false)
        for _ in 0..<120 { _ = motion.step(towards: partials([(1_760, 0.5)]), after: 1.0 / 60, still: true) }
        XCTAssertEqual(motion.figuresTaken, 0)
    }

    /// The worst a sound can do — a different figure every frame, full level against silence —
    /// takes at most one figure per fade, and the light of each quarter of the plate swings by a
    /// tenth or more at most three times a second (WCAG 2.3.1's general flash: two opposing
    /// transitions of at least 0.10 in relative luminance make one flash).
    func testNoSoundFlashesThePlateMoreThanThreeTimesASecond() {
        let figures = [partials([(440, 0.5)]), .calm, partials([(1_760, 0.5)]), partials([(110, 0.5), (3_000, 0.4)]),
                       partials([(55, 0.5)]), .calm, partials([(6_000, 0.5)])]
        let rate = 60.0, seconds = 8.0
        var motion = ChladniMotion()
        var quarters: [[Double]] = Array(repeating: [], count: 4)
        for frame in 0..<Int(rate * seconds) {
            let shown = motion.step(towards: figures[frame % figures.count], after: 1 / rate, still: false)
            for quarter in 0..<4 {
                let x0 = Double(quarter % 2) * 0.5, y0 = Double(quarter / 2) * 0.5
                var sum = 0.0
                for i in 0..<12 {
                    for j in 0..<12 {
                        sum += shown.luminance(x: x0 + (Double(i) + 0.5) / 24, y: y0 + (Double(j) + 0.5) / 24)
                    }
                }
                quarters[quarter].append(sum / 144)
            }
        }
        XCTAssertLessThanOrEqual(Double(motion.figuresTaken), seconds / ChladniMotion.morphSeconds + 1)
        for series in quarters {
            let transitions = Self.transitionFrames(series, step: FlashLimit.generalFlashThreshold)
            let window = Int(rate)
            for start in 0..<Swift.max(1, series.count - window) {
                let inWindow = transitions.filter { $0 >= start && $0 < start + window }.count
                XCTAssertLessThanOrEqual(inWindow, 6, "at most three flashes (six transitions) in any second")
            }
        }
    }

    /// The frames where the luminance has moved by `step` or more against the last extreme in the
    /// opposite direction: each is one transition of a flash.
    private static func transitionFrames(_ series: [Double], step: Double) -> [Int] {
        guard var extreme = series.first else { return [] }
        var rising: Bool?
        var frames: [Int] = []
        for (index, value) in series.enumerated() {
            switch rising {
            case nil:
                if Swift.abs(value - extreme) >= step {
                    rising = value > extreme
                    frames.append(index)
                    extreme = value
                }
            case true?:
                if value > extreme { extreme = value } else if extreme - value >= step {
                    rising = false
                    frames.append(index)
                    extreme = value
                }
            case false?:
                if value < extreme { extreme = value } else if value - extreme >= step {
                    rising = true
                    frames.append(index)
                    extreme = value
                }
            }
        }
        return frames
    }

    func testThePatternNamesAreStoredAndOrdered() {
        XCTAssertEqual(FieldPattern.allCases.map(\.rawValue), ["rings", "chladni", "dish", "water", "aurora", "depth", "moire"])
        XCTAssertEqual(FieldPattern(stored: "chladni"), .chladni)
        XCTAssertEqual(FieldPattern(stored: nil), .rings)
        XCTAssertEqual(FieldPattern(stored: "unknown"), .rings)
        XCTAssertEqual(FieldPattern.storageKey, "field.pattern")
    }
}
