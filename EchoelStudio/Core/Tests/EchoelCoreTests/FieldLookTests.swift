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
        let before = shown.turns
        phase += 0.01
        shown = motion.step(primary: .water, partner: .aurora, mix: 0.5, hertz: nil, drive: 0, tonicHz: 261.63,
                            fieldPhase: phase, after: 1.0 / 60, still: false, patternScale: 1)
        var step = shown.turns - before
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

    /// The weave's key in these tests: C major, seven cells in the middle of the ring.
    private static let weaveKey = BarWeave.keyMask(MusicalContext(root: 0, scale: .major))

    /// The quarters' mean light of `patterns` mixed by the look motion's mix, frame by frame; the
    /// song runs three bars a second, so the weave moves (and fades through) as well.
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
                                  after: 1 / rate, still: false, patternScale: 1, beat: beat,
                                  bars: Double(frame) * 3 / rate, keyMask: Self.weaveKey)
            let figure = plate.step(towards: plateFigures[frame % plateFigures.count], after: 1 / rate, still: false)
            let turns = look.turns
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
        for look in [FieldPattern.dish, .water, .aurora, .depth, .moire, .weave, .film] {
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

    /// Every look that hears the sound, at every point of a grid, wide and square, at full level
    /// and the song's fastest drift (the bar slammed ahead every frame, the Field caps it), the
    /// pitch jumping between the lowest and the highest every two seconds: no point may change its
    /// light more than three flashes a second — a mean over a quarter could hide a band racing
    /// across one point, and the worst-frame series above holds the level near zero. Simulated
    /// per pixel on 2026-11-06, the water, the aurora, the dish and the depth flashed 22 to 45
    /// times a second here (the pitch's glide swept their spacing) and the first thin film 12
    /// (its phase jumped at each wrap); with the spacings rate-limited, 3 to 6.
    func testNoLookFlashesAtAnyPixelAtFullLevel() {
        let rate = 60.0
        for pattern in [FieldPattern.dish, .water, .aurora, .depth, .film] {
            for aspect in [1.0, 16.0 / 9] {
                var field = FieldMotion(), looks = FieldLookMotion()
                var series = [[Double]](repeating: [], count: 100)
                for frame in 0..<Int(8 * rate) {
                    let loud = FieldFrame(beatPhase: 0, barPhase: Double(frame % 3) / 3, tonicHz: 220, level: 1, pulse: 1,
                                          coherence: 0.5, breath: 0.5, isPlaying: true)
                    let shown = field.step(loud, after: 1 / rate, still: false, patternScale: 1)
                    let hertz = (frame / Int(2 * rate)) % 2 == 0 ? 6_000.0 : 55.0
                    let look = looks.step(primary: pattern, partner: nil, mix: 0, hertz: hertz, drive: 0.8,
                                          tonicHz: shown.toneHz, fieldPhase: shown.fieldPhase, after: 1 / rate,
                                          still: false, patternScale: 1)
                    for i in 0..<10 {
                        for j in 0..<10 {
                            series[i * 10 + j].append(FieldLook.light(pattern, u: (Double(i) + 0.5) / 10,
                                                                      v: (Double(j) + 0.5) / 10, aspect: aspect, field: shown,
                                                                      look: look, plate: ChladniMotion.Shown(),
                                                                      turns: look.turns))
                        }
                    }
                }
                XCTAssertGreaterThan(series.flatMap { $0 }.max() ?? 0, 0.3, "\(pattern.title) is lit, not dark")
                assertAtMostThreeFlashesASecond(series, "\(pattern.title) at aspect \(aspect)")
            }
        }
    }

    /// The rings at every point of a grid at full level and the fastest drift, with everything
    /// else that moves them at its worst: a beat ring three times a second, the key jumping from
    /// C to B and back every two seconds, coherence and breath slammed from end to end. Simulated
    /// per pixel on 2026-11-06 this flashed up to 34 times a second; with the beat ring and the
    /// halo under the flash threshold and the rings' spacing and coherence rate-limited, six.
    func testTheRingsFlashAtNoPixelMoreThanThreeTimesASecondAtFullLevel() {
        let rate = 60.0
        for aspect in [1.0, 16.0 / 9] {
            var field = FieldMotion(), looks = FieldLookMotion()
            var series = [[Double]](repeating: [], count: 100)
            for frame in 0..<Int(8 * rate) {
                let beat = (Double(frame) * 3 / rate).truncatingRemainder(dividingBy: 1)
                let loud = FieldFrame(beatPhase: beat, barPhase: Double(frame % 3) / 3,
                                      tonicHz: (frame / Int(2 * rate)) % 2 == 0 ? 261.63 : 493.88, level: 1, pulse: 1,
                                      coherence: Double((frame / 30) % 2), breath: Double((frame / 20) % 2), isPlaying: true)
                let shown = field.step(loud, after: 1 / rate, still: false, patternScale: 1)
                let look = looks.step(primary: .rings, partner: nil, mix: 0, hertz: nil, drive: 0, tonicHz: shown.toneHz,
                                      fieldPhase: shown.fieldPhase, after: 1 / rate, still: false, patternScale: 1)
                for i in 0..<10 {
                    for j in 0..<10 {
                        series[i * 10 + j].append(FieldLook.light(.rings, u: (Double(i) + 0.5) / 10, v: (Double(j) + 0.5) / 10,
                                                                  aspect: aspect, field: shown, look: look,
                                                                  plate: ChladniMotion.Shown(), turns: look.turns))
                    }
                }
            }
            XCTAssertGreaterThan(series.flatMap { $0 }.max() ?? 0, 0.3, "the rings are lit")
            assertAtMostThreeFlashesASecond(series, "rings at aspect \(aspect)")
        }
    }

    func testTheRingsSpacingAndCoherenceMoveAtCappedSpeeds() {
        var field = FieldMotion()
        var last = field.step(FieldFrame(tonicHz: 261.63, coherence: 0), after: 1.0 / 60, still: false, patternScale: 1)
        XCTAssertEqual(last.ringsK, FieldMotion.ringsK(density: FieldMotion.ringDensity, toneHz: 261.63), accuracy: 1e-9,
                       "the first frame shows the key as it is")
        XCTAssertEqual(last.ringsCoherence, 0, accuracy: 1e-12)
        for _ in 0..<120 {
            let shown = field.step(FieldFrame(tonicHz: 493.88, coherence: 1), after: 1.0 / 60, still: false, patternScale: 1)
            XCTAssertLessThanOrEqual(abs(shown.ringsK - last.ringsK), FieldMotion.ringsKRate / 60 + 1e-9)
            XCTAssertLessThanOrEqual(abs(shown.ringsCoherence - last.ringsCoherence), FieldMotion.ringsCoherenceRate / 60 + 1e-12)
            last = shown
        }
        XCTAssertGreaterThan(last.ringsK, FieldMotion.ringsK(density: FieldMotion.ringDensity, toneHz: 261.63),
                             "a higher tonic tightens the rings")
        XCTAssertLessThan(FieldPulse.beatRingGain * (1 - FieldPulse.ambient), FlashLimit.generalFlashThreshold,
                          "the beat ring alone stays under the flash threshold")
        XCTAssertLessThan(FieldPulse.haloGain * (1 - FieldPulse.ambient), FlashLimit.generalFlashThreshold)
    }

    /// The aurora's rays re-space with the pitch at most `auroraRayRate` a second, and arrive.
    func testTheAurorasRaysFollowThePitchSlowly() {
        var looks = FieldLookMotion()
        var last = looks.step(primary: .aurora, partner: nil, mix: 0, hertz: 220, drive: 0.5, tonicHz: FieldFrame.middleC,
                              fieldPhase: 0, after: 1.0 / 60, still: false, patternScale: 1).auroraRays
        XCTAssertEqual(last, FieldLook.auroraRays(toneHz: 220), accuracy: 1e-9)
        for _ in 0..<(60 * 30) {
            let rays = looks.step(primary: .aurora, partner: nil, mix: 0, hertz: 6_000, drive: 0.5, tonicHz: FieldFrame.middleC,
                                  fieldPhase: 0, after: 1.0 / 60, still: false, patternScale: 1).auroraRays
            XCTAssertLessThanOrEqual(abs(rays - last), FieldLook.auroraRayRate / 60 + 1e-12)
            last = rays
        }
        XCTAssertEqual(last, FieldLook.auroraRayRange.upperBound, accuracy: 1e-9, "and arrives")
    }

    /// The looks that turn at fractions of the drift (the rings at 0.5 and 0.25, the dish at 0.4,
    /// the water's 0.4 · 0.7 …, the aurora's 0.25 · 0.6 …, the depth's 0.3) draw the same picture
    /// at the drift's wrap as just before it, so the wrap is no jump; and the drift counts on
    /// across the song phase's own wraps.
    func testTheLooksDoNotJumpWhereTheirDriftWraps() {
        var field = FieldMotion(), looks = FieldLookMotion()
        let frame = FieldFrame(beatPhase: 0.3, barPhase: 0.4, tonicHz: 330, level: 1, pulse: 1, coherence: 0.6,
                               breath: 0.4, isPlaying: true)
        let shown = field.step(frame, after: 1.0 / 60, still: false, patternScale: 1)
        let look = looks.step(primary: .dish, partner: nil, mix: 0, hertz: 330, drive: 0.9, tonicHz: 330,
                              fieldPhase: shown.fieldPhase, after: 1.0 / 60, still: false, patternScale: 1)
        for pattern in [FieldPattern.rings, .dish, .water, .aurora, .depth] {
            for (u, v) in [(0.5, 0.5), (0.2, 0.7), (0.81, 0.33), (0.4, 0.05)] {
                let at = { (turns: Double) in
                    FieldLook.light(pattern, u: u, v: v, aspect: 1.4, field: shown, look: look,
                                    plate: ChladniMotion.Shown(), turns: turns)
                }
                XCTAssertEqual(at(0), at(FieldLookMotion.driftPeriod), accuracy: 1e-6, "\(pattern.title) at (\(u), \(v))")
            }
        }
        var counted = FieldLookMotion()
        var phase = 0.0, last = 0.0
        for frame in 0..<300 {
            phase = (phase + 0.05).truncatingRemainder(dividingBy: 1)
            let turns = counted.step(primary: .water, partner: nil, mix: 0, hertz: nil, drive: 0, tonicHz: 261.63,
                                     fieldPhase: phase, after: 1.0 / 60, still: false, patternScale: 1).turns
            if frame > 0 { XCTAssertEqual(turns - last, 0.05, accuracy: 1e-9, "no step back at the song phase's wrap") }
            last = turns
        }
    }

    func testAThinFilmIsBlackWhereItIsThinnestAndColouredByItsThickness() {
        XCTAssertEqual(FieldLook.filmColour(nanometres: 0), SIMD3(repeating: 0), "far thinner than light: black")
        // First order: a film reflects most where four times its optical thickness is the wavelength.
        let blue = FieldLook.filmColour(nanometres: 450 / (4 * FieldLook.filmIndex))
        let red = FieldLook.filmColour(nanometres: 650 / (4 * FieldLook.filmIndex))
        XCTAssertGreaterThan(red.x / Swift.max(red.z, 1e-6), blue.x / Swift.max(blue.z, 1e-6),
                             "the thicker film reflects the redder light")
        for d in stride(from: 0.0, through: 1_200, by: 7) {
            let c = FieldLook.filmColour(nanometres: d)
            XCTAssertTrue((0...1).contains(c.x) && (0...1).contains(c.y) && (0...1).contains(c.z), "\(d) nm")
        }
        let top = FieldLook.filmThickness(x: 0, y: 1, k: 9, phase: 0, level: 0)
        let bottom = FieldLook.filmThickness(x: 0, y: -1, k: 9, phase: 0, level: 0)
        XCTAssertLessThan(top, bottom, "it drains: thin at the top, thick below")
        XCTAssertEqual(FieldLook.filmThickness(x: 0.4, y: 0.2, k: 4, phase: 1, level: 0),
                       FieldLook.filmThickness(x: 0.4, y: 0.2, k: 20, phase: 1, level: 0),
                       "silent, the ripple is gone")
        XCTAssertNotEqual(FieldLook.filmThickness(x: 0.4, y: 0.2, k: 4, phase: 1, level: 1),
                          FieldLook.filmThickness(x: 0.4, y: 0.2, k: 20, phase: 1, level: 1),
                          "loud, the ripple's spacing shows")
        XCTAssertLessThan(FieldLook.rippleK(toneHz: 110), FieldLook.rippleK(toneHz: 880), "a higher pitch, a finer ripple")
        XCTAssertTrue(FieldPattern.film.listensToSound)
    }

    func testTheThinFilmsRippleFollowsThePitchSlowlyAndRestsOffScreen() {
        var a = FieldLookMotion.Shown(), b = FieldLookMotion.Shown()
        a.primary = .film; b.primary = .film
        a.rippleK = 6; b.rippleK = 12
        XCTAssertNotEqual(a.onScreen, b.onScreen, "the film reads its ripple")
        a.primary = .rings; b.primary = .rings
        XCTAssertEqual(a.onScreen, b.onScreen, "the rings do not")

        var looks = FieldLookMotion()
        var last = looks.step(primary: .film, partner: nil, mix: 0, hertz: 220, drive: 0.5, tonicHz: FieldFrame.middleC,
                              fieldPhase: 0, after: 1.0 / 60, still: false, patternScale: 1).rippleK
        XCTAssertGreaterThan(last, FieldLook.rippleKRange.lowerBound, "220 Hz lies inside the range, not on its floor")
        XCTAssertEqual(last, FieldLook.rippleK(toneHz: 220), accuracy: 1e-9, "the first frame starts at the pitch")
        for _ in 0..<720 {   // 3 to 24 at the capped rate: about ten and a half seconds
            let k = looks.step(primary: .film, partner: nil, mix: 0, hertz: 6_000, drive: 0.5, tonicHz: FieldFrame.middleC,
                               fieldPhase: 0, after: 1.0 / 60, still: false, patternScale: 1).rippleK
            XCTAssertLessThanOrEqual(abs(k - last), FieldLook.rippleKRate / 60 + 1e-12)
            last = k
        }
        XCTAssertEqual(last, FieldLook.rippleK(toneHz: 6_000), accuracy: 1e-9, "and arrives")
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

    /// The weave at points on its lit cells, through what moves it most: bars far faster than the
    /// eye may follow, a one-bar loop wrapping four times a second, the key changed four times a
    /// second. No point flashes more than three times a second — and the points do light.
    func testTheWeaveFlashesAtNoPixelMoreThanThreeTimesASecond() {
        let rate = 60.0
        let major = Self.weaveKey
        let other = BarWeave.keyMask(MusicalContext(root: 3, scale: .major))
        var field = FieldMotion.Shown()
        field.levelLight = 1
        let width = Double(BarWeave.width)
        var points: [(u: Double, v: Double)] = []
        for cell in 26...34 {
            for row in [0.5, 1.5, 2.5, 3.5] { points.append(((Double(cell) + 0.5) / width, row / width)) }
        }
        let songs: [(label: String, at: (Int) -> (bars: Double, key: UInt16))] = [
            ("six bars a second", { (Double($0) * 6 / rate, major) }),
            ("a one-bar loop wrapping four times a second", { (12 + Double($0 % 15) / 15, major) }),
            ("the key changed four times a second", { (Double($0) / rate, ($0 / 15) % 2 == 0 ? major : other) }),
        ]
        for song in songs {
            var looks = FieldLookMotion()
            var series = Array(repeating: [Double](), count: points.count)
            for frame in 0..<Int(6 * rate) {
                let place = song.at(frame)
                let look = looks.step(primary: .weave, partner: nil, mix: 0, hertz: nil, drive: 0,
                                      tonicHz: FieldFrame.middleC, fieldPhase: 0, after: 1 / rate, still: false,
                                      patternScale: 1, bars: place.bars, keyMask: place.key)
                for (index, point) in points.enumerated() {
                    series[index].append(FieldLook.light(.weave, u: point.u, v: point.v, aspect: 1, field: field,
                                                         look: look, plate: ChladniMotion.Shown(), turns: 0))
                }
            }
            assertAtMostThreeFlashesASecond(series, song.label)
            XCTAssertTrue(series.contains { ($0.max() ?? 0) - ($0.min() ?? 0) > FlashLimit.generalFlashThreshold },
                          "\(song.label): the points light at all")
        }
    }

    /// The weave glides to a place a little ahead, at its ceiling; a place behind, one far ahead
    /// and a new key fade through dark — the rows change unseen and the light comes back; held
    /// still, the rows stand while a new key still fades through.
    func testTheWeaveGlidesAheadAndFadesThroughEverythingElse() {
        var looks = FieldLookMotion()
        let major = Self.weaveKey
        let other = BarWeave.keyMask(MusicalContext(root: 3, scale: .major))
        func advance(_ bars: Double, key: UInt16? = nil, still: Bool = false, seconds: Double = 1.0 / 60)
            -> FieldLookMotion.Shown {
            looks.step(primary: .weave, partner: nil, mix: 0, hertz: nil, drive: 0, tonicHz: FieldFrame.middleC,
                       fieldPhase: 0, after: seconds, still: still, patternScale: 1, bars: bars, keyMask: key ?? major)
        }
        XCTAssertEqual(advance(0).weavePosition, 1, "the key's row stands whole from the start")
        XCTAssertEqual(advance(0.5, seconds: 1).weavePosition, 1.5, accuracy: 1e-9)
        XCTAssertEqual(advance(1.5, seconds: 0.4).weavePosition, 2, accuracy: 1e-9, "a bar ahead, at the ceiling")
        // Back: the light goes first, the place changes in the dark, the light returns.
        var shown = advance(0.25)
        XCTAssertEqual(shown.weavePosition, 2, accuracy: 1e-9)
        XCTAssertLessThan(shown.weaveLight, 1)
        for _ in 0..<200 { shown = advance(0.25) }
        XCTAssertEqual(shown.weavePosition, 1.25, accuracy: 1e-9)
        XCTAssertGreaterThan(shown.weaveLight, 0.5)
        // Far ahead: the same.
        for _ in 0..<200 { shown = advance(40) }
        XCTAssertEqual(shown.weavePosition, 41, accuracy: 1e-9)
        // Held still the rows stand; a new key still comes in through dark.
        shown = advance(45, still: true, seconds: 1)
        XCTAssertEqual(shown.weavePosition, 41, accuracy: 1e-9)
        for _ in 0..<200 { shown = advance(45, key: other, still: true) }
        XCTAssertEqual(shown.weaveSeed, BarWeave.seed(keyMask: other))
        XCTAssertEqual(shown.weavePosition, 41, accuracy: 1e-9, "held still, the place stays")
    }

    /// The shown looks that listen are what an export analyses its mix for; the stored choice
    /// reads as the Field window reads it.
    func testTheShownLooksThatListenAreWhatAnExportHearsFor() {
        XCTAssertEqual(FieldLookChoice(primary: .dish, partner: .weave, mix: 1).listening, [.dish])
        XCTAssertEqual(FieldLookChoice(primary: .moire, partner: .aurora, mix: 1).listening, [.aurora])
        XCTAssertEqual(FieldLookChoice(primary: .water, partner: .water, mix: 1).listening, [.water])
        XCTAssertEqual(FieldLookChoice(primary: .weave, partner: .moire, mix: 1).listening, [])
        XCTAssertEqual(FieldLookChoice(primary: .weave, partner: .dish, mix: 0).listening, [], "a partner at 0 % is not shown")
        XCTAssertEqual(FieldLookChoice(storedPattern: "weave", storedPartner: "", mixPercent: 50),
                       FieldLookChoice(primary: .weave, partner: nil, mix: 0.5))
        XCTAssertEqual(FieldLookChoice(storedPattern: "unknown", storedPartner: "nothing", mixPercent: 140),
                       FieldLookChoice(primary: .rings, partner: nil, mix: 1))
        XCTAssertEqual(FieldLookChoice(primary: .moire, mix: -3).mix, 0)
        XCTAssertEqual(FieldLookChoice(primary: .moire, mix: .nan).mix, 0)
    }

    /// Two frames that draw the same picture compare equal on screen: an unshown moiré's drift or an
    /// unshown weave's place does not count; a shown one does.
    func testWhatNoShownLookDrawsIsAtRestOnScreen() {
        var a = FieldLookMotion.Shown(), b = FieldLookMotion.Shown()
        b.moirePhase = 0.4
        b.weavePosition = 9
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a.onScreen, b.onScreen, "the rings read neither")
        a.primary = .moire
        b.primary = .moire
        XCTAssertNotEqual(a.onScreen, b.onScreen, "the moiré reads its phase")
        b.moirePhase = a.moirePhase
        XCTAssertEqual(a.onScreen, b.onScreen, "and not the weave")
        a.partner = .weave
        b.partner = .weave
        a.mix = 0.5
        b.mix = 0.5
        XCTAssertNotEqual(a.onScreen, b.onScreen, "a blended weave reads its place")
    }

    /// The film's step is the window's step with the frame's tuning, bars and key, hearing what it is given.
    func testAFilmsLooksComeFromTheFramesTuningBarsAndKey() {
        let context = MusicalContext(root: 0, scale: .major)
        let frame = FieldFrame(tonicHz: 261.6, tuningBeat: TuningBeat.of(context), bars: 7.25,
                               keyMask: BarWeave.keyMask(context))
        var drawn = FieldLookMotion()
        var spelled = FieldLookMotion()
        let a = drawn.step(drawing: FieldLookChoice(primary: .weave, partner: .moire, mix: 0.5), from: frame,
                           fieldPhase: 0.3, after: 1.0 / 30, still: false, patternScale: 1)
        let b = spelled.step(primary: .weave, partner: .moire, mix: 0.5, hertz: nil, drive: 0, tonicHz: frame.tonicHz,
                             fieldPhase: 0.3, after: 1.0 / 30, still: false, patternScale: 1, beat: frame.tuningBeat,
                             bars: frame.bars, keyMask: frame.keyMask)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.weavePosition, 8.25, accuracy: 1e-12)
        XCTAssertEqual(a.weaveSeed, BarWeave.seed(keyMask: frame.keyMask))
        var dish = FieldLookMotion()
        var spelledDish = FieldLookMotion()
        let heard = dish.step(drawing: FieldLookChoice(primary: .dish), from: frame, hertz: 440, drive: 0.8, fieldPhase: 0,
                              after: 1.0 / 30, still: false, patternScale: 1)
        XCTAssertEqual(heard.primary, .dish)
        XCTAssertEqual(heard, spelledDish.step(primary: .dish, partner: nil, mix: 0, hertz: 440, drive: 0.8,
                                               tonicHz: frame.tonicHz, fieldPhase: 0, after: 1.0 / 30, still: false,
                                               patternScale: 1, beat: frame.tuningBeat, bars: frame.bars,
                                               keyMask: frame.keyMask))
    }

    /// A tick back while paused (a tempo change re-rounds the playhead) is no step back: the light
    /// stays. While two looks show, the weave glides at the blend's share of its ceiling.
    func testTheWeaveIgnoresATickBackAndGlidesAtTheBlendsShare() {
        let major = Self.weaveKey
        var paused = FieldLookMotion()
        _ = paused.step(primary: .weave, partner: nil, mix: 0, hertz: nil, drive: 0, tonicHz: FieldFrame.middleC,
                        fieldPhase: 0, after: 1.0 / 60, still: false, patternScale: 1, bars: 32, keyMask: major)
        var shown = FieldLookMotion.Shown()
        for _ in 0..<120 {
            shown = paused.step(primary: .weave, partner: nil, mix: 0, hertz: nil, drive: 0, tonicHz: FieldFrame.middleC,
                                fieldPhase: 0, after: 1.0 / 60, still: false, patternScale: 1, bars: 32 - 1.0 / 3_840,
                                keyMask: major)
        }
        XCTAssertEqual(shown.weaveLight, 1, "no fade for a tick")
        XCTAssertEqual(shown.weavePosition, 33, accuracy: 1e-9)

        var blended = FieldLookMotion()
        var last = 0.0
        var checked = false
        for frame in 0..<240 {
            let look = blended.step(primary: .weave, partner: .rings, mix: 1, hertz: nil, drive: 0,
                                    tonicHz: FieldFrame.middleC, fieldPhase: 0, after: 1.0 / 60, still: false,
                                    patternScale: 1, bars: Double(frame) / 60, keyMask: major)
            if frame > 0, look.isBlending {
                XCTAssertLessThanOrEqual(look.weavePosition - last,
                                         BarWeave.maximumRowsPerSecond * FieldLookMotion.blendPhaseShare / 60 + 1e-12)
                checked = true
            }
            last = look.weavePosition
        }
        XCTAssertTrue(checked, "the blend came in")
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
        XCTAssertEqual(FieldPattern.allCases.map(\.shaderIndex), [0, 1, 2, 3, 4, 5, 6, 7, 8])
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
