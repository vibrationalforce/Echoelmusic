import XCTest
@testable import EchoelCore

/// The looks ported from the earlier app's Field — Dish, Water, Aurora, Depth — and the blend of
/// two looks: the physics they claim, and that no look, and no pair of looks at any mix, flashes
/// more than three times a second (WCAG 2.3.1), whatever the song, the sound and the body do.
final class FieldLookTests: XCTestCase {
    private static func sound(_ pairs: [(Double, Double)]) -> (hertz: Double?, drive: Double) {
        var frequencies = SIMD8<Double>(repeating: 0), amplitudes = SIMD8<Double>(repeating: 0)
        for (index, pair) in pairs.prefix(8).enumerated() {
            frequencies[index] = pair.0
            amplitudes[index] = pair.1
        }
        return FieldLookMotion.hearing(frequencies: frequencies, amplitudes: amplitudes, count: Swift.min(pairs.count, 8))
    }

    func testTheStrongestPartialIsThePitchAndTheLevelIsTheDrive() {
        let heard = Self.sound([(220, 0.1), (440, 0.5), (880, 0.2)])
        XCTAssertEqual(heard.hertz, 440)
        XCTAssertEqual(heard.drive, 1, accuracy: 1e-9, "−6 dBFS and up is full")
        let silent = Self.sound([])
        XCTAssertNil(silent.hertz)
        XCTAssertEqual(silent.drive, 0)
        XCTAssertNil(Self.sound([(440, 0.000_1)]).hertz, "−80 dBFS is silence")
        XCTAssertNil(Self.sound([(.nan, 0.5), (440, .infinity)]).hertz)
    }

    func testTheDishIsAMirrorInSilenceAndALatticeWhenDriven() throws {
        let silent = try XCTUnwrap(FaradayDish.response(driveHz: 440, drive: 0))
        XCTAssertEqual(silent.patternStrength, 0)
        let loud = try XCTUnwrap(FaradayDish.response(driveHz: 440, drive: 1))
        XCTAssertEqual(loud.patternStrength, 1, accuracy: 1e-9)
        XCTAssertEqual(loud.responseHz, 220, "the surface answers at half the drive")
        // A mirror shows the lamp and no lattice: its light does not depend on the wavenumber.
        let a = FieldLook.dish(x: 0.1, y: 0.2, k: 30, strength: 0, hex: 0, phase: 0, coherence: 0.5)
        let b = FieldLook.dish(x: 0.1, y: 0.2, k: 90, strength: 0, hex: 1, phase: 0, coherence: 0.5)
        XCTAssertEqual(a, b, accuracy: 1e-12)
        let c = FieldLook.dish(x: 0.1, y: 0.2, k: 30, strength: 1, hex: 0, phase: 0, coherence: 0.5)
        let d = FieldLook.dish(x: 0.1 + .pi / 30, y: 0.2, k: 30, strength: 1, hex: 0, phase: 0, coherence: 0.5)
        XCTAssertGreaterThan(Swift.abs(c - d), 0.05, "a driven dish shows its lattice")
    }

    /// Capillary waves: one octave up makes the lattice 2^(2/3) finer, in the dish and the water.
    func testAnOctaveUpIsTwoToTheTwoThirdsFiner() throws {
        let low = try XCTUnwrap(FaradayDish.response(driveHz: 880, drive: 1)).wavenumber
        let high = try XCTUnwrap(FaradayDish.response(driveHz: 1_760, drive: 1)).wavenumber
        XCTAssertEqual(high / low, pow(2, 2.0 / 3), accuracy: 0.01)
        let hex = FaradayDish.latticeHexagonality(capillaryFraction:
            try XCTUnwrap(FaradayDish.response(driveHz: 1_760, drive: 1)).capillaryFraction)
        XCTAssertEqual(hex, 1, accuracy: 1e-6, "an audio ripple is all surface tension: a hexagonal lattice")
    }

    func testTheLooksHearTheSoundAndFallBackToTheKey() {
        var motion = FieldLookMotion()
        var shown = FieldLookMotion.Shown()
        for _ in 0..<240 {
            shown = motion.step(primary: .water, partner: nil, mix: 0, hertz: 880, drive: 0.8, tonicHz: 261.63,
                                fieldPhase: 0, after: 1.0 / 60, still: false, patternScale: 1)
        }
        XCTAssertEqual(shown.soundHz, 880, accuracy: 1)
        XCTAssertGreaterThan(shown.dishStrength, 0.5)
        for _ in 0..<240 {
            shown = motion.step(primary: .water, partner: nil, mix: 0, hertz: nil, drive: 0, tonicHz: 261.63,
                                fieldPhase: 0, after: 1.0 / 60, still: false, patternScale: 1)
        }
        XCTAssertEqual(shown.soundHz, 261.63, accuracy: 1, "silence: back to the key's tonic")
        XCTAssertEqual(shown.dishStrength, 0, accuracy: 1e-9, "silence: a mirror")
    }

    func testStillHoldsThePitchAndTheLattice() {
        var motion = FieldLookMotion()
        let first = motion.step(primary: .dish, partner: nil, mix: 0, hertz: 220, drive: 1, tonicHz: 261.63,
                                fieldPhase: 0, after: 1.0 / 60, still: true, patternScale: 1)
        var shown = first
        for _ in 0..<120 {
            shown = motion.step(primary: .dish, partner: nil, mix: 0, hertz: 3_000, drive: 1, tonicHz: 261.63,
                                fieldPhase: 0, after: 1.0 / 60, still: true, patternScale: 1)
        }
        XCTAssertEqual(shown.soundHz, first.soundHz)
        XCTAssertEqual(shown.dishK, first.dishK)
    }

    func testTheLowestDetailCoarsensTheLattice() {
        var full = FieldLookMotion(), low = FieldLookMotion()
        let fine = full.step(primary: .dish, partner: nil, mix: 0, hertz: 12_000, drive: 1, tonicHz: 261.63,
                             fieldPhase: 0, after: 1.0 / 60, still: false, patternScale: 1)
        let coarse = low.step(primary: .dish, partner: nil, mix: 0, hertz: 12_000, drive: 1, tonicHz: 261.63,
                              fieldPhase: 0, after: 1.0 / 60, still: false, patternScale: 0.5)
        XCTAssertLessThanOrEqual(coarse.dishK, FieldLook.dishKRange.upperBound * 0.5 + 1e-9)
        XCTAssertLessThan(coarse.dishK, fine.dishK)
    }

    /// A new partner is never cut in: the mix fades out, the partner changes, the mix fades back.
    func testANewPartnerFadesInNeverCuts() {
        var motion = FieldLookMotion()
        var shown = FieldLookMotion.Shown()
        for _ in 0..<180 {
            shown = motion.step(primary: .rings, partner: .water, mix: 1, hertz: nil, drive: 0, tonicHz: 261.63,
                                fieldPhase: 0, after: 1.0 / 60, still: false, patternScale: 1)
        }
        XCTAssertEqual(shown.partner, .water)
        XCTAssertEqual(shown.mix, 1, accuracy: 1e-9)
        var previous = shown.mix
        var sawZero = false
        for _ in 0..<600 {
            shown = motion.step(primary: .rings, partner: .aurora, mix: 1, hertz: nil, drive: 0, tonicHz: 261.63,
                                fieldPhase: 0, after: 1.0 / 60, still: false, patternScale: 1)
            XCTAssertLessThanOrEqual(Swift.abs(shown.mix - previous), FlashLimit.maximumRate / 60 + 1e-12)
            if shown.partner == .water { XCTAssertGreaterThan(shown.mix + 1e-12, 0) }
            if shown.mix <= FieldLookMotion.blendThreshold { sawZero = true }
            if shown.partner == .aurora { XCTAssertTrue(sawZero, "the partner changed only under a hidden mix") }
            previous = shown.mix
        }
        XCTAssertEqual(shown.partner, .aurora)
        XCTAssertEqual(shown.mix, 1, accuracy: 1e-9)
    }

    /// While two looks are mixed, they drift at half the song's rate; alone, at the full rate.
    func testABlendDriftsAtHalfTheRate() {
        var motion = FieldLookMotion()
        var phase = 0.0
        var shown = FieldLookMotion.Shown()
        for _ in 0..<600 {
            phase = (phase + 0.01).truncatingRemainder(dividingBy: 1)
            shown = motion.step(primary: .water, partner: .aurora, mix: 0.5, hertz: nil, drive: 0, tonicHz: 261.63,
                                fieldPhase: phase, after: 1.0 / 60, still: false, patternScale: 1)
        }
        let before = shown.turns(fieldPhase: phase)
        phase += 0.01
        shown = motion.step(primary: .water, partner: .aurora, mix: 0.5, hertz: nil, drive: 0, tonicHz: 261.63,
                            fieldPhase: phase, after: 1.0 / 60, still: false, patternScale: 1)
        var step = shown.turns(fieldPhase: phase) - before
        if step < 0 { step += 1 }
        XCTAssertEqual(step, 0.005, accuracy: 1e-9)
    }

    // MARK: - The flash law

    /// The worst a song, the sound and the body can ask of one frame: a bar faster than the cap, a
    /// loud partial jumping octaves and to silence, breath and coherence slamming from end to end,
    /// the level jumping, a fast heart.
    private static func worstFrame(_ index: Int) -> FieldFrame {
        FieldFrame(beatPhase: Double(index % 8) / 8, barPhase: Double(index % 6) / 6, tonicHz: index % 2 == 0 ? 130 : 1_900,
                   level: Double(index % 2), pulse: 1, coherence: Double(index % 2), breath: Double((index / 2) % 2),
                   isPlaying: true)
    }

    private static let sounds: [(Double, Double)?] = [(440, 0.5), nil, (1_760, 0.5), (55, 0.5), (6_000, 0.4), nil, (220, 0.02)]

    /// The quarters' mean light of `patterns` mixed by the look motion's mix, frame by frame.
    private func lightSeries(primary: FieldPattern, partner: FieldPattern?, mixes: (Int) -> Double,
                             seconds: Double = 6, rate: Double = 60,
                             beat: TuningBeat = TuningBeat.of(MusicalContext())) -> [[Double]] {
        var field = FieldMotion(), looks = FieldLookMotion(), plate = ChladniMotion()
        var quarters: [[Double]] = Array(repeating: [], count: 4)
        let plateFigures = [ChladniModes(m: SIMD4(0, 1, 0, 0), n: SIMD4(4, 3, 0, 0), weight: SIMD4(0.7, 0.3, 0, 0), drive: 1),
                            .calm, ChladniModes(m: SIMD4(2, 0, 0, 0), n: SIMD4(8, 0, 0, 0), weight: SIMD4(1, 0, 0, 0), drive: 0.8)]
        for frame in 0..<Int(seconds * rate) {
            let shown = field.step(Self.worstFrame(frame), after: 1 / rate, still: false, patternScale: 1)
            let heard: (hertz: Double?, drive: Double) = Self.sounds[frame % Self.sounds.count].map { Self.sound([$0]) } ?? (hertz: nil, drive: 0)
            let look = looks.step(primary: primary, partner: partner, mix: mixes(frame), hertz: heard.hertz,
                                  drive: heard.drive, tonicHz: shown.toneHz, fieldPhase: shown.fieldPhase,
                                  after: 1 / rate, still: false, patternScale: 1, beat: beat)
            let figure = plate.step(towards: plateFigures[frame % plateFigures.count], after: 1 / rate, still: false)
            let turns = look.turns(fieldPhase: shown.fieldPhase)
            for quarter in 0..<4 {
                let u0 = Double(quarter % 2) * 0.5, v0 = Double(quarter / 2) * 0.5
                var sum = 0.0
                for i in 0..<10 {
                    for j in 0..<10 {
                        let u = u0 + (Double(i) + 0.5) / 20, v = v0 + (Double(j) + 0.5) / 20
                        let a = FieldLook.light(look.primary, u: u, v: v, aspect: 1, field: shown, look: look,
                                                plate: figure, turns: turns)
                        var value = a
                        if look.isBlending {
                            let b = FieldLook.light(look.partner, u: u, v: v, aspect: 1, field: shown, look: look,
                                                    plate: figure, turns: turns)
                            value = a + (b - a) * look.mix
                        }
                        sum += value
                    }
                }
                quarters[quarter].append(sum / 100)
            }
        }
        return quarters
    }

    private func assertAtMostThreeFlashesASecond(_ quarters: [[Double]], _ label: String, rate: Int = 60) {
        for series in quarters {
            let transitions = Self.transitionFrames(series, step: FlashLimit.generalFlashThreshold)
            var worst = 0
            for start in 0..<Swift.max(1, series.count - rate) {
                worst = Swift.max(worst, transitions.filter { $0 >= start && $0 < start + rate }.count)
            }
            XCTAssertLessThanOrEqual(worst, 6, "\(label): at most three flashes (six transitions) in any second")
        }
    }

    func testNoLookFlashesMoreThanThreeTimesASecond() {
        for look in [FieldPattern.dish, .water, .aurora, .depth, .moire] {
            assertAtMostThreeFlashesASecond(lightSeries(primary: look, partner: nil, mixes: { _ in 0 }), look.title)
        }
    }

    /// The moiré at one point, under a 12-equal third (its fastest drift): the quarters' means would
    /// average the gratings away, a single pixel cannot hide a flash. Held still, it does not move.
    func testTheMoireFlashesAtNoPixelMoreThanThreeTimesASecond() {
        let rate = 60.0
        let beat = TuningBeat.of(MusicalContext())
        XCTAssertGreaterThan(beat.driftHz, 1.9)
        for (u, v) in [(0.5, 0.5), (0.31, 0.62), (0.7, 0.4)] {
            var looks = FieldLookMotion()
            var series: [Double] = []
            var held: [Double] = []
            var still = FieldLookMotion()
            for _ in 0..<Int(6 * rate) {
                let look = looks.step(primary: .moire, partner: nil, mix: 0, hertz: nil, drive: 0,
                                      tonicHz: FieldFrame.middleC, fieldPhase: 0, after: 1 / rate, still: false,
                                      patternScale: 1, beat: beat)
                series.append(FieldLook.light(.moire, u: u, v: v, aspect: 1, field: FieldMotion.Shown(), look: look,
                                              plate: ChladniMotion.Shown(), turns: 0))
                let stood = still.step(primary: .moire, partner: nil, mix: 0, hertz: nil, drive: 0,
                                       tonicHz: FieldFrame.middleC, fieldPhase: 0, after: 1 / rate, still: true,
                                       patternScale: 1, beat: beat)
                held.append(stood.moirePhase)
            }
            assertAtMostThreeFlashesASecond([series], "moiré at (\(u), \(v))")
            XCTAssertEqual(Set(held), [0], "held still, the gratings do not move")
        }
    }

    /// The moiré drifts at the blend's share the moment a second look comes in, not after its
    /// pulse has slewed down: two looks never drift together at full speed.
    func testTheMoireHalvesItsDriftTheMomentABlendStarts() {
        let rate = 60.0
        let beat = TuningBeat.of(MusicalContext())
        var looks = FieldLookMotion()
        var last = 0.0
        for _ in 0..<Int(6 * rate) {
            last = looks.step(primary: .moire, partner: nil, mix: 0, hertz: nil, drive: 0, tonicHz: FieldFrame.middleC,
                              fieldPhase: 0, after: 1 / rate, still: false, patternScale: 1, beat: beat).moirePhase
        }
        var blended = false
        for _ in 0..<30 {
            let look = looks.step(primary: .moire, partner: .rings, mix: 1, hertz: nil, drive: 0, tonicHz: FieldFrame.middleC,
                                  fieldPhase: 0, after: 1 / rate, still: false, patternScale: 1, beat: beat)
            var step = look.moirePhase - last
            if step < 0 { step += 1 }
            last = look.moirePhase
            if look.isBlending {
                blended = true
                XCTAssertLessThanOrEqual(step, TuningBeat.maximumDriftHz * FieldLookMotion.blendPhaseShare / rate + 1e-9)
            }
        }
        XCTAssertTrue(blended)
    }

    /// Every pair at an even mix, and every pair with the mix control thrown from end to end each frame.
    func testNoBlendFlashesMoreThanThreeTimesASecond() {
        let looks = FieldPattern.allCases
        for (index, primary) in looks.enumerated() {
            for partner in looks[(index + 1)...] {
                assertAtMostThreeFlashesASecond(lightSeries(primary: primary, partner: partner, mixes: { _ in 0.5 },
                                                            seconds: 4),
                                                "\(primary.title) + \(partner.title) at 50 %")
                assertAtMostThreeFlashesASecond(lightSeries(primary: primary, partner: partner,
                                                            mixes: { Double($0 % 2) }, seconds: 4),
                                                "\(primary.title) + \(partner.title), mix thrown")
            }
        }
    }

    func testAMeterRisesQuicklyAndFallsSlowly() {
        let up = MeterBallistics.follow(0, 1, after: 1.0 / 30)
        let down = 1 - MeterBallistics.follow(1, 0, after: 1.0 / 30)
        XCTAssertGreaterThan(up, 0.6)
        XCTAssertLessThan(down, 0.1)
        XCTAssertEqual(MeterBallistics.follow(.nan, .infinity, after: 1.0 / 30), 0)
        var shown = 0.0
        for _ in 0..<120 { shown = MeterBallistics.follow(shown, 0.7, after: 1.0 / 60) }
        XCTAssertEqual(shown, 0.7, accuracy: 1e-6)
    }

    func testTheMeterNamesAreStoredAndOrdered() {
        XCTAssertEqual(FieldMeter.allCases.map(\.rawValue), ["off", "spectrum", "scope", "phase", "partials"])
        XCTAssertEqual(FieldMeter(stored: "scope"), .scope)
        XCTAssertEqual(FieldMeter(stored: "phase"), .phase)
        XCTAssertEqual(FieldMeter(stored: nil), .off)
        XCTAssertEqual(FieldMeter(stored: "unknown"), .off)
        XCTAssertEqual(FieldMeter.storageKey, "field.meter")
        XCTAssertEqual(FieldPattern.blend(stored: "water"), .water)
        XCTAssertNil(FieldPattern.blend(stored: ""))
        XCTAssertNil(FieldPattern.blend(stored: nil))
        XCTAssertEqual(FieldPattern.allCases.map(\.shaderIndex), [0, 1, 2, 3, 4, 5, 6])
    }

    /// The frames where the light has moved by `step` or more against the last extreme in the
    /// opposite direction: each is one transition of a flash (as `ChladniPlateTests`).
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
}
