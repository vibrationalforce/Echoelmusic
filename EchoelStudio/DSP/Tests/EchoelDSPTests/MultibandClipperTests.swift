import XCTest
@testable import EchoelDSP

final class MultibandClipperTests: XCTestCase {
    private let rate = 48_000.0

    private func sine(_ hertz: Double, amplitude: Double, count: Int = 9_600) -> [Float] {
        (0..<count).map { (index: Int) -> Float in
            Float(Foundation.sin(2 * Double.pi * hertz * Double(index) / 48_000) * amplitude)
        }
    }

    private func run(_ clipper: MultibandClipper, _ input: [Float], block: Int = 256) -> [Float] {
        var l = input, r = input
        var start = 0
        while start < input.count {
            let n = Swift.min(block, input.count - start)
            l.withUnsafeMutableBufferPointer { lp in
                r.withUnsafeMutableBufferPointer { rp in
                    guard let a = lp.baseAddress, let b = rp.baseAddress else { return }
                    clipper.process(left: a + start, right: b + start, frames: n)
                }
            }
            start += n
        }
        return l
    }

    private func rms(_ signal: [Float]) -> Double {
        var sum = 0.0
        for value in signal { sum += Double(value) * Double(value) }
        return (sum / Double(Swift.max(signal.count, 1))).squareRoot()
    }

    private func decibels(_ ratio: Double) -> Double { 20 * Foundation.log10(ratio) }

    /// The amplitude of `hertz` in `signal` (one bin of a DFT, Goertzel's single frequency). Every
    /// frequency asked for is a whole number of cycles in 4800 samples, so no bin leaks into another.
    private func amplitude(_ signal: [Float], _ hertz: Double) -> Double {
        var re = 0.0, im = 0.0
        for (index, value) in signal.enumerated() {
            let phase = 2 * Double.pi * hertz * Double(index) / 48_000
            re += Double(value) * Foundation.cos(phase)
            im += Double(value) * Foundation.sin(phase)
        }
        return 2 * (re * re + im * im).squareRoot() / Double(Swift.max(signal.count, 1))
    }

    /// The dry path's own filter: the two crossovers' allpasses, as the clipper's bands sum to.
    private func allpassed(_ input: [Float], low: Double = 150, high: Double = 3_000) -> [Float] {
        let k = ZDFStage.butterworth
        let g1 = ZDFStage.g(low, sampleRate: 48_000), g2 = ZDFStage.g(high, sampleRate: 48_000)
        var first = ZDFStage(), second = ZDFStage()
        var out: [Float] = []
        out.reserveCapacity(input.count)
        for x in input {
            let a = x - 2 * k * first.process(x, g: g1, k: k).band
            out.append(a - 2 * k * second.process(a, g: g2, k: k).band)
        }
        return out
    }

    private func delayed(_ signal: [Float], by samples: Int) -> [Float] {
        let pad = [Float](repeating: 0, count: samples)
        return Array((pad + signal).prefix(signal.count))
    }

    // MARK: (1) transparency

    /// Under the ceiling with every drive at 0 dB, the split, the oversampling and the guard leave
    /// the level where it was.
    func testUnderTheCeilingTheSoundComesOutAtItsOwnLevel() {
        let settings = MultibandClipper.Settings(ceiling: 0)
        let amplitude = Foundation.pow(10, -24.0 / 20)
        for hertz in [100.0, 1_000, 8_000, 150, 3_000] {
            let input = sine(hertz, amplitude: amplitude)
            let out = run(MultibandClipper(sampleRate: rate, settings: settings), input)
            let change = decibels(rms(Array(out.suffix(4_800))) / rms(Array(input.suffix(4_800))))
            XCTAssertEqual(change, 0, accuracy: 0.1, "\(hertz) Hz")
        }
    }

    // MARK: (2) the ceiling

    /// Driven 12 dB and more into the ceiling, at any softness and frequency, no sample passes it:
    /// the look-ahead guard catches what the downsampling brings back over it.
    func testTheCeilingHoldsAtEveryFrequencyAndSoftness() {
        for ceiling in [-6.0, -0.3] {
            let limit = Float(Foundation.pow(10, (ceiling + 0.05) / 20))
            for softness in [0.0, 0.3, 1.0] {
                let settings = MultibandClipper.Settings(inputGain: 12, lowDrive: 6, midDrive: 6, highDrive: 6,
                                                         softness: softness, ceiling: ceiling)
                for hertz in [60.0, 440, 2_000, 5_000, 9_000, 15_000] {
                    let out = run(MultibandClipper(sampleRate: rate, settings: settings), sine(hertz, amplitude: 0.5, count: 4_800))
                    let peak = out.map { (value: Float) -> Float in Swift.abs(value) }.max() ?? 0
                    XCTAssertLessThanOrEqual(peak, limit, "\(hertz) Hz, softness \(softness), ceiling \(ceiling)")
                    XCTAssertGreaterThan(peak, limit * 0.5, "it is driven into the ceiling")
                }
            }
        }
    }

    // MARK: (3) aliasing

    /// A 7 kHz sine hard-clipped 12 dB into the ceiling at 48 kHz: its 5th harmonic (35 kHz) folds
    /// to 13 kHz and its 7th (49 kHz) to 1 kHz when the clip runs at the base rate. Computed for
    /// this exact signal (a plain clip of the sample values, numpy, 2026-11-06): 13 kHz at −16.1 dB
    /// and 1 kHz at −21.5 dB under the fundamental — and the loop below computes it again. Clipped
    /// at 4× and brought down, this design measured −58.9 dB and −57.7 dB in a float simulation of
    /// the same arithmetic.
    func testOversamplingKeepsTheFoldedHarmonicsFiftyDecibelsDown() {
        let input = sine(7_000, amplitude: 0.5)
        let settings = MultibandClipper.Settings(inputGain: 12, softness: 0, ceiling: -6)
        let out = Array(run(MultibandClipper(sampleRate: rate, settings: settings), input).suffix(4_800))
        let fundamental = amplitude(out, 7_000)
        XCTAssertGreaterThan(fundamental, 0.3, "the fundamental comes through")
        XCTAssertLessThan(decibels(amplitude(out, 13_000) / fundamental), -50, "the 5th harmonic folded to 13 kHz")
        XCTAssertLessThan(decibels(amplitude(out, 1_000) / fundamental), -50, "the 7th harmonic folded to 1 kHz")

        // The same clip without oversampling, for comparison.
        let ceiling = Float(Foundation.pow(10, -6.0 / 20))
        let plain = input.suffix(4_800).map { (value: Float) -> Float in
            Swift.min(Swift.max(value * 4, -ceiling), ceiling)
        }
        let plainFundamental = amplitude(plain, 7_000)
        XCTAssertGreaterThan(decibels(amplitude(plain, 13_000) / plainFundamental), -30, "a base-rate clip folds loudly")
        XCTAssertGreaterThan(decibels(amplitude(plain, 1_000) / plainFundamental), -30)
    }

    /// The two halfband stages as designed: at least 70 dB of stopband where their images lie
    /// (stage 1 from 0.55·fs, stage 2 from 1.45·fs of the base rate) and a flat passband.
    func testTheHalfbandStagesReachTheirStopband() {
        let stages: [(taps: Int, beta: Double, pass: Double, stop: Double)] = [
            (MultibandClipper.firstTaps, 7.6, 0.225, 0.275), (MultibandClipper.secondTaps, 7.4, 0.1375, 0.3625),
        ]
        for stage in stages {
            let response = MultibandClipper.impulseResponse(taps: stage.taps, beta: stage.beta)
            func gain(_ frequency: Double) -> Double {
                var re = 0.0, im = 0.0
                for (index, tap) in response.enumerated() {
                    re += Double(tap) * Foundation.cos(2 * Double.pi * frequency * Double(index))
                    im -= Double(tap) * Foundation.sin(2 * Double.pi * frequency * Double(index))
                }
                return (re * re + im * im).squareRoot()
            }
            let dc = gain(0)
            XCTAssertEqual(dc, 1, accuracy: 0.001)
            for step in 0...200 {
                let stop = stage.stop + (0.5 - stage.stop) * Double(step) / 200
                XCTAssertLessThan(decibels(gain(stop) / dc), -70, "\(stage.taps) taps at \(stop)")
                let pass = stage.pass * Double(step) / 200
                XCTAssertEqual(decibels(gain(pass) / dc), 0, accuracy: 0.01, "\(stage.taps) taps at \(pass)")
            }
        }
    }

    // MARK: (4) mix

    /// Mix 0 is the dry sound exactly — delayed by the latency and through the crossovers' own
    /// allpass, so that a Mix between lines up with the clipped sound at every frequency. That
    /// allpass changes no level.
    func testMixZeroIsTheAlignedDrySoundExactly() {
        let input: [Float] = (0..<4_800).map { (index: Int) -> Float in
            let t = Double(index) / 48_000
            return Float(0.5 * Foundation.sin(2 * Double.pi * 440 * t) + 0.3 * Foundation.sin(2 * Double.pi * 3_000 * t))
        }
        let settings = MultibandClipper.Settings(lowDrive: 18, midDrive: 18, highDrive: 18, ceiling: -12, mix: 0)
        let out = run(MultibandClipper(sampleRate: rate, settings: settings), input, block: 61)
        XCTAssertEqual(out, delayed(allpassed(input), by: MultibandClipper.latencySamples))
        let tone = sine(150, amplitude: 0.5)
        let dry = run(MultibandClipper(sampleRate: rate, settings: settings), tone)
        XCTAssertEqual(decibels(rms(Array(dry.suffix(4_800))) / rms(Array(tone.suffix(4_800)))), 0, accuracy: 0.01)
    }

    /// The dry sound is the input as it came in, before Input: a +12 dB Input at Mix 0 leaves the
    /// level as it was, and at Mix 0.5 the output's peak is half the dry peak plus at most half the
    /// ceiling — never the raised input unclipped.
    func testTheDrySoundIsTheInputBeforeTheInputGain() {
        let tone = sine(1_000, amplitude: 0.5)
        let dryOnly = run(MultibandClipper(sampleRate: rate, settings: MultibandClipper.Settings(inputGain: 12, mix: 0)), tone)
        XCTAssertEqual(decibels(rms(Array(dryOnly.suffix(4_800))) / rms(Array(tone.suffix(4_800)))), 0, accuracy: 0.01)
        let settings = MultibandClipper.Settings(inputGain: 24, ceiling: -0.3, mix: 0.5)
        let half = run(MultibandClipper(sampleRate: rate, settings: settings), tone)
        let peak = Array(half.suffix(4_800)).map { (sample: Float) -> Float in Swift.abs(sample) }.max() ?? 0
        let ceiling = Float(Foundation.pow(10, -0.3 / 20))
        XCTAssertLessThanOrEqual(peak, 0.5 * 0.5 + 0.5 * ceiling + 1e-3)
    }

    /// Half dry, half clipped, under the ceiling: the level of the input — even on the crossovers,
    /// where a dry path that was only delayed would cancel half of it.
    func testHalfMixUnderTheCeilingKeepsTheLevel() {
        let settings = MultibandClipper.Settings(ceiling: 0, mix: 0.5)
        let amplitude = Foundation.pow(10, -24.0 / 20)
        for hertz in [150.0, 1_000, 3_000] {
            let input = sine(hertz, amplitude: amplitude)
            let out = run(MultibandClipper(sampleRate: rate, settings: settings), input)
            XCTAssertEqual(decibels(rms(Array(out.suffix(4_800))) / rms(Array(input.suffix(4_800)))), 0, accuracy: 0.1, "\(hertz) Hz")
        }
    }

    // MARK: (5) latency

    /// The reported latency is where an impulse comes out, dry and clipped alike: the lag at which
    /// the output best matches the crossovers' allpass response of the impulse.
    func testTheReportedLatencyIsTheMeasuredDelay() {
        XCTAssertEqual(MultibandClipper.latencySamples, 85)
        var impulse = [Float](repeating: 0, count: 600)
        impulse[10] = 0.25
        let reference = allpassed(impulse)
        for mix in [0.0, 1.0] {
            let clipper = MultibandClipper(sampleRate: rate, settings: .init(ceiling: 0, mix: mix))
            XCTAssertEqual(clipper.latencySamples, MultibandClipper.latencySamples)
            let out = run(clipper, impulse)
            var best = -1, bestScore = -Double.infinity
            for lag in 0..<200 {
                var score = 0.0
                for index in 0..<(out.count - lag) { score += Double(out[index + lag]) * Double(reference[index]) }
                if score > bestScore {
                    bestScore = score
                    best = lag
                }
            }
            XCTAssertEqual(best, MultibandClipper.latencySamples, "mix \(mix)")
        }
    }

    // MARK: (6) bad samples and silence

    func testABadSampleNeverComesOutAndSilenceStaysSilent() {
        let clipper = MultibandClipper(sampleRate: rate, settings: .init(inputGain: 12, lowDrive: 12))
        var input = sine(1_000, amplitude: 0.4, count: 4_800)
        input[500] = .nan
        input[900] = .infinity
        input[901] = -.infinity
        let out = run(clipper, input)
        XCTAssertTrue(out.allSatisfy(\.isFinite))
        clipper.reset()
        let silence = [Float](repeating: 0, count: 2_048)
        XCTAssertEqual(run(clipper, silence), silence)
        let fresh = MultibandClipper(sampleRate: rate)
        XCTAssertEqual(run(fresh, silence, block: 1_000), silence)
    }

    /// Any block length plays the same sound: the glide steps count samples, not blocks.
    func testABlockOfAnySizePlaysTheSame() {
        let input = sine(220, amplitude: 0.6, count: 4_800)
        let settings = MultibandClipper.Settings(inputGain: 6, midDrive: 9, softness: 0.5)
        let small = run(MultibandClipper(sampleRate: rate, settings: settings), input, block: 37)
        let large = run(MultibandClipper(sampleRate: rate, settings: settings), input, block: 1_024)
        XCTAssertEqual(small, large)
    }

    // MARK: (7) ranges

    func testSettingsAreClampedToTheirRanges() {
        let wild = MultibandClipper.Settings(inputGain: 99, lowCrossover: 1, highCrossover: 99_999, lowDrive: -3,
                                             midDrive: 40, highDrive: .infinity, softness: 2, ceiling: 6, mix: -1)
        XCTAssertEqual(wild.clamped, MultibandClipper.Settings(inputGain: 24, lowCrossover: 40, highCrossover: 10_000,
                                                               lowDrive: 0, midDrive: 18, highDrive: 0, softness: 1,
                                                               ceiling: 0, mix: 0))
        let low = MultibandClipper.Settings(inputGain: -99, lowCrossover: .nan, highCrossover: 5, softness: -1, ceiling: -99)
        XCTAssertEqual(low.clamped, MultibandClipper.Settings(inputGain: -12, lowCrossover: 150, highCrossover: 1_000,
                                                              softness: 0, ceiling: -12))
        let clipper = MultibandClipper(sampleRate: rate, settings: wild)
        XCTAssertEqual(clipper.settings, wild.clamped)
        XCTAssertEqual(MultibandClipper.Settings(), MultibandClipper.Settings(inputGain: 0, lowCrossover: 150, highCrossover: 3_000,
                                                                              lowDrive: 0, midDrive: 0, highDrive: 0,
                                                                              softness: 0.3, ceiling: -0.3, mix: 1))
    }

    /// The clip curve: unchanged up to the knee, continuous with slope 1 there, never above the ceiling.
    func testTheClipCurveIsLinearToTheKneeAndNeverPassesTheCeiling() {
        let ceiling: Float = 0.5
        for softness: Float in [0, 0.3, 1] {
            let knee = (1 - softness) * ceiling
            XCTAssertEqual(MultibandClipper.clip(knee * 0.999, ceiling: ceiling, inverseCeiling: 2, softness: softness), knee * 0.999)
            for step in 0...400 {
                let x = Float(step) / 100
                let y = MultibandClipper.clip(x, ceiling: ceiling, inverseCeiling: 2, softness: softness)
                XCTAssertLessThanOrEqual(y, ceiling)
                XCTAssertEqual(MultibandClipper.clip(-x, ceiling: ceiling, inverseCeiling: 2, softness: softness), -y)
            }
            if softness > 0 {
                let above = MultibandClipper.clip(knee + 0.001, ceiling: ceiling, inverseCeiling: 2, softness: softness)
                XCTAssertEqual(above, knee + 0.001, accuracy: 0.0001, "slope 1 just over the knee")
            }
        }
    }
}
