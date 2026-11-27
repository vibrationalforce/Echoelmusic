import Foundation
import XCTest
@testable import EchoelDSP

final class GrainShifterTests: XCTestCase {
    private let rate = 48_000.0

    /// A harmonic tone: ten partials at k·hertz, each 1/k, in cosine phase, so every period starts
    /// with a pulse — the way a voice's energy gathers after each closure of the glottis.
    private func tone(_ hertz: Double, seconds: Double) -> [Float] {
        let count = Int(rate * seconds)
        var samples = [Float](repeating: 0, count: count)
        for index in 0..<count {
            var sum = 0.0
            for partial in 1...10 {
                let phase: Double = 2 * Double.pi * hertz * Double(partial) * Double(index) / rate
                sum += Foundation.cos(phase) / Double(partial)
            }
            samples[index] = Float(0.2 * sum)
        }
        return samples
    }

    /// How strongly a resonance at `centre` hertz, `width` hertz wide, passes `hertz`: 1 at its
    /// centre, half its power `width / 2` to either side.
    private static func resonance(_ hertz: Double, centre: Double, width: Double) -> Double {
        let distance = (hertz - centre) / (width / 2)
        return 1 / (1 + distance * distance).squareRoot()
    }

    /// A vowel-like tone: every harmonic of `hertz` below 4 kHz in cosine phase, weighted by two
    /// resonances — formants at 700 Hz (120 Hz wide) and 1200 Hz (140 Hz wide, 4.4 dB lower) unless
    /// given — over a floor 30 dB down, its odd harmonics scaled by `odd`. Its formants are known,
    /// so a shifter can be measured against them.
    private func vowel(_ hertz: Double, seconds: Double, first: (centre: Double, width: Double) = (700, 120),
                       second: (centre: Double, width: Double) = (1_200, 140), odd: Double = 1) -> [Float] {
        var weights: [Double] = []
        var partial = 1
        while Double(partial) * hertz < 4_000 {
            let harmonic = Double(partial) * hertz
            let lower = Self.resonance(harmonic, centre: first.centre, width: first.width)
            let upper = 0.6 * Self.resonance(harmonic, centre: second.centre, width: second.width)
            weights.append((lower + upper + 0.03) * (partial % 2 == 1 ? odd : 1))
            partial += 1
        }
        let count = Int(rate * seconds)
        var samples = [Float](repeating: 0, count: count)
        for index in 0..<count {
            var sum = 0.0
            for (number, weight) in weights.enumerated() {
                let phase: Double = 2 * Double.pi * hertz * Double(number + 1) * Double(index) / rate
                sum += weight * Foundation.cos(phase)
            }
            samples[index] = Float(0.1 * sum)
        }
        return samples
    }

    /// A sung line: the vowel's spectrum (its harmonics keep the weights they start with) gliding
    /// from `from` to `to` hertz over `seconds`, evenly in cents, with a vibrato of ±`vibrato` cents
    /// at 5.5 Hz on top.
    private func sung(from: Double, to: Double, seconds: Double, vibrato: Double = 0) -> [Float] {
        var weights: [Double] = []
        for partial in 1...40 {
            let harmonic = Double(partial) * from
            let lower = Self.resonance(harmonic, centre: 700, width: 120)
            let upper = 0.6 * Self.resonance(harmonic, centre: 1_200, width: 140)
            weights.append(lower + upper + 0.03)
        }
        let count = Int(rate * seconds)
        var samples = [Float](repeating: 0, count: count)
        var phase = 0.0
        for index in 0..<count {
            let time = Double(index) / rate
            let glide: Double = from * Foundation.pow(to / from, time / seconds)
            let sway: Double = vibrato / 1_200 * Foundation.sin(2 * Double.pi * 5.5 * time)
            let hertz = glide * Foundation.pow(2, sway)
            phase += 2 * Double.pi * hertz / rate
            var sum = 0.0
            for (number, weight) in weights.enumerated() where Double(number + 1) * hertz < 8_000 {
                sum += weight * Foundation.cos(phase * Double(number + 1))
            }
            samples[index] = Float(0.1 * sum)
        }
        return samples
    }

    /// White noise from a fixed seed, evenly spread over ±`level`.
    private func noise(_ count: Int, level: Float, seed: UInt64 = 12_345) -> [Float] {
        var state = seed
        var samples = [Float](repeating: 0, count: count)
        for index in 0..<count {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            samples[index] = level * Float(Int64(bitPattern: state >> 1) % 1_000 - 500) / 500
        }
        return samples
    }

    /// The shifter over `input` on both sides, in blocks of `block` frames; the left side, after
    /// checking the right one carries the same sound.
    private func run(_ shifter: GrainShifter, _ input: [Float], block: Int = 256) -> [Float] {
        var left = input, right = input
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let x = l.baseAddress, let y = r.baseAddress else { return }
                var done = 0
                while done < l.count {
                    let frames = Swift.min(block, l.count - done)
                    shifter.process(left: x + done, right: y + done, frames: frames)
                    done += frames
                }
            }
        }
        XCTAssertTrue(left == right, "both sides carry the same sound")
        return left
    }

    /// The input played `semitones` higher by `SpliceHead` — the read head the harmonizer and the
    /// pitch correction play through today — given the tracker's period the way `PitchCorrector`
    /// gives it, for contrast.
    private func spliced(_ input: [Float], semitones: Double) -> [Float] {
        let history = StereoHistory(seconds: 0.08, sampleRate: rate)
        var head = SpliceHead(sampleRate: rate)
        let tracker = PitchTracker(sampleRate: rate)
        let ratio = Foundation.pow(2, semitones / 12)
        var samples = [Float](repeating: 0, count: input.count)
        for (index, sample) in input.enumerated() {
            tracker.push(sample)
            history.push(sample, sample)
            head.advance(ratio: ratio, period: tracker.period)
            samples[index] = head.read(history).0
        }
        return samples
    }

    private func cents(_ found: Double, _ expected: Double) -> Double {
        1_200 * Foundation.log2(found / expected)
    }

    private func pitch(_ samples: [Float]) throws -> Double {
        try XCTUnwrap(PitchTracker.frequency(of: samples, sampleRate: rate))
    }

    /// The tracker's pitch of the stretch from `start` on, exactly as long as its window — at
    /// 48 kHz two periods of 70 Hz at half the rate, 1,368 samples. It analyses every 256 samples,
    /// so given the 1,536 that end where that stretch ends, its last analysis reads exactly it.
    private func pitch(_ samples: [Float], from start: Int) throws -> Double {
        let tracker = PitchTracker(sampleRate: rate)
        let window = 2 * Int(rate / Double(tracker.factor) / PitchTracker.minimumHertz) * tracker.factor
        let given = (window + tracker.hop - 1) / tracker.hop * tracker.hop
        return try pitch(Array(samples[(start + window - given)..<(start + window)]))
    }

    /// The fundamental of a steady sound in hertz, also above the tracker's 1 kHz: the shortest lag,
    /// from 8 samples (6 kHz) to 800 (60 Hz), whose normalised autocorrelation peaks within 0.03 of
    /// the highest, refined by a parabola. 0 where nothing repeats.
    private func frequency(of samples: [Float]) -> Double {
        let shortestLag = 8, longestLag = 800
        let span = samples.count - longestLag - 2
        guard span > 0 else { return 0 }
        var head = 0.0
        for index in 0..<span { head += Double(samples[index]) * Double(samples[index]) }
        var correlations = [Double](repeating: -2, count: longestLag + 2)
        for lag in shortestLag...(longestLag + 1) {
            var cross = 0.0, energy = 0.0
            for index in 0..<span {
                let later = Double(samples[index + lag])
                cross += Double(samples[index]) * later
                energy += later * later
            }
            correlations[lag] = cross / (head * energy + 1e-30).squareRoot()
        }
        let highest = Array(correlations[(shortestLag + 1)...longestLag]).max() ?? 0
        for lag in (shortestLag + 1)...longestLag {
            let before = correlations[lag - 1], at = correlations[lag], after = correlations[lag + 1]
            guard at >= before, at >= after, at >= highest - 0.03 else { continue }
            let curve = before - 2 * at + after
            let shift = curve < 0 ? 0.5 * (before - after) / curve : 0
            return rate / (Double(lag) + shift)
        }
        return 0
    }

    /// The RMS level in dB.
    private func level(_ samples: ArraySlice<Float>) -> Double {
        var sum = 0.0
        for sample in samples { sum += Double(sample) * Double(sample) }
        return 10 * Foundation.log10(Swift.max(sum / Double(Swift.max(samples.count, 1)), 1e-20))
    }

    /// The largest difference between `heard` and `input` played `delay` samples later.
    private func largestDifference(_ heard: [Float], _ input: [Float], delay: Int) -> Float {
        var largest: Float = 0
        for index in delay..<heard.count {
            largest = Swift.max(largest, Swift.abs(heard[index] - input[index - delay]))
        }
        return largest
    }

    /// The spectral envelope's two strongest peaks in hertz, low first: the level of every harmonic
    /// of `hertz` below 3 kHz (a Hann-windowed Fourier sum at exactly k·hertz), each local maximum
    /// refined by a parabola through it and its two neighbours in dB.
    private func formants(of samples: [Float], hertz: Double) -> [Double] {
        let count = samples.count
        var window = [Double](repeating: 0, count: count)
        for index in 0..<count {
            window[index] = 0.5 - 0.5 * Foundation.cos(2 * Double.pi * Double(index) / Double(count - 1))
        }
        var levels: [Double] = [0]
        var partial = 1
        while Double(partial) * hertz < 3_000 {
            let step: Double = 2 * Double.pi * Double(partial) * hertz / rate
            var real = 0.0, imaginary = 0.0
            for index in 0..<count {
                let weighted = Double(samples[index]) * window[index]
                real += weighted * Foundation.cos(step * Double(index))
                imaginary -= weighted * Foundation.sin(step * Double(index))
            }
            let magnitude = (real * real + imaginary * imaginary).squareRoot()
            levels.append(20 * Foundation.log10(Swift.max(magnitude, 1e-12)))
            partial += 1
        }
        var peaks: [(level: Double, hertz: Double)] = []
        if levels.count > 3 {
            for k in 2..<(levels.count - 1) where levels[k] > levels[k - 1] && levels[k] >= levels[k + 1] {
                let curve = levels[k - 1] - 2 * levels[k] + levels[k + 1]
                let shift = curve < 0 ? 0.5 * (levels[k - 1] - levels[k + 1]) / curve : 0
                peaks.append((level: levels[k], hertz: (Double(k) + shift) * hertz))
            }
        }
        let loudest = peaks.sorted { (a: (level: Double, hertz: Double), b: (level: Double, hertz: Double)) -> Bool in
            a.level > b.level
        }
        return loudest.prefix(2).map { (peak: (level: Double, hertz: Double)) -> Double in peak.hertz }.sorted()
    }

    /// The steady middle of a 0.8 s sound, well past the latency and the tracker's first window.
    private func steady(_ samples: [Float]) -> [Float] {
        Array(samples[19_200..<38_400])
    }

    /// A fifth up (seven semitones, ×1.498307) on a plain harmonic tone and on a vowel, from a low
    /// male voice to a high one: the shifted sound's fundamental, measured by the tracker on its
    /// steady end, lands within two cents of the input's times the ratio.
    func testAFifthUpLandsWithinTwoCents() throws {
        let ratio = Foundation.pow(2, 7.0 / 12)
        for hertz in [98.0, 220, 440] {
            for (name, source) in [("tone", tone(hertz, seconds: 0.6)), ("vowel", vowel(hertz, seconds: 0.6))] {
                let heard = run(GrainShifter(sampleRate: rate, settings: .init(pitch: 7)), source)
                let found = try pitch(Array(heard.suffix(12_000)))
                XCTAssertEqual(cents(found, hertz * ratio), 0, accuracy: 2, "\(name) at \(hertz) Hz")
            }
        }
    }

    /// The marks follow the voice as it moves: a vowel gliding a fifth (220 to 330 Hz) over a second,
    /// and one with a vibrato of ±50 cents at 5.5 Hz, both a fifth up, stay within 6 cents of the
    /// input's pitch times 1.498, each measured over the tracker's 28.5 ms window every 50 ms. After
    /// a leap — an octave up, an octave and a fifth up, a fifth up, an octave down — the new note is
    /// shifted within 3 cents in such a window starting 20 ms after the leap, and in one starting
    /// every 20 ms after that up to 200 ms. (Before the marks took the shortest period that repeats,
    /// an octave leap up came out an octave too low: the new note also repeats at its old period,
    /// two of its own.)
    func testTheShiftFollowsAGlideAVibratoAndALeap() throws {
        let ratio = Foundation.pow(2, 7.0 / 12)
        let latency = GrainShifter.latencySamples(sampleRate: rate)
        let lines = [("a glide", sung(from: 220, to: 330, seconds: 1)),
                     ("a vibrato", sung(from: 220, to: 220, seconds: 1, vibrato: 50))]
        for (name, input) in lines {
            let heard = run(GrainShifter(sampleRate: rate, settings: .init(pitch: 7)), input)
            for start in stride(from: 4_800, to: input.count - latency - 2_400, by: 2_400) {
                let sang = try pitch(input, from: start)
                let shifted = try pitch(heard, from: start + latency)
                XCTAssertEqual(cents(shifted, sang * ratio), 0, accuracy: 6, "\(name) at \(start)")
            }
        }
        for (first, second) in [(220.0, 440.0), (110, 330), (220, 330), (220, 110)] {
            let input = vowel(first, seconds: 0.5) + vowel(second, seconds: 0.5)
            let heard = run(GrainShifter(sampleRate: rate, settings: .init(pitch: 7)), input)
            for after in stride(from: 960, through: 9_600, by: 960) {
                let shifted = try pitch(heard, from: 24_000 + after + latency)
                XCTAssertEqual(cents(shifted, second * ratio), 0, accuracy: 3,
                               "\(first) to \(second) Hz, \(after / 48) ms after the leap")
            }
        }
    }

    /// Where the tracker or the marks could take another octave, the shift still lands on the note's
    /// own: a tone above the tracker's 1 kHz, which it hears an octave low; a vowel whose first
    /// formant sits on its second or third harmonic, which it hears an octave or more high; and a
    /// vowel leaping an octave down to odd harmonics 10.5 dB below its even ones, which still nearly
    /// repeats at the old period. Each lands within 3 cents of its pitch times the ratio, a fifth up
    /// and a fourth down. (Before a note's period was settled from the tracker's half, third, double
    /// and triple, and the marks checked the longer period the tracker hears, each of them came out
    /// at the wrong pitch.)
    func testTheShiftLandsInTheNotesOwnOctave() throws {
        for hertz in [1_200.0, 1_500] {
            let input = tone(hertz, seconds: 0.4)
            XCTAssertEqual(try pitch(input) / hertz, 0.5, accuracy: 0.01, "the tracker hears \(hertz) Hz an octave low")
            for semitones in [7.0, -5] {
                let heard = run(GrainShifter(sampleRate: rate, settings: .init(pitch: semitones)), input)
                let found = frequency(of: Array(heard.suffix(4_800)))
                XCTAssertEqual(cents(found, hertz * Foundation.pow(2, semitones / 12)), 0, accuracy: 3,
                               "a tone at \(hertz) Hz, \(semitones) semitones")
            }
        }
        let voices: [(hertz: Double, first: (centre: Double, width: Double), second: (centre: Double, width: Double))] = [
            (350, (700, 80), (1_400, 100)),
            (233.3, (700, 30), (1_400, 30)),
        ]
        for voice in voices {
            let input = vowel(voice.hertz, seconds: 0.5, first: voice.first, second: voice.second)
            XCTAssertGreaterThan(try pitch(input) / voice.hertz, 1.9, "the tracker hears \(voice.hertz) Hz too high")
            for semitones in [7.0, -5] {
                let heard = run(GrainShifter(sampleRate: rate, settings: .init(pitch: semitones)), input)
                let found = frequency(of: Array(heard.suffix(4_800)))
                XCTAssertEqual(cents(found, voice.hertz * Foundation.pow(2, semitones / 12)), 0, accuracy: 3,
                               "a vowel at \(voice.hertz) Hz, \(semitones) semitones")
            }
        }
        let leap = vowel(220, seconds: 0.5) + vowel(110, seconds: 0.5, odd: 0.3)
        for semitones in [7.0, -5] {
            let heard = run(GrainShifter(sampleRate: rate, settings: .init(pitch: semitones)), leap)
            let found = frequency(of: Array(heard.suffix(4_800)))
            XCTAssertEqual(cents(found, 110 * Foundation.pow(2, semitones / 12)), 0, accuracy: 3,
                           "an octave leap down to weak odd harmonics, \(semitones) semitones")
        }
    }

    /// A vowel at 110 Hz a fifth up: its two formants stay where the input had them (within 8 %),
    /// where `SpliceHead` moves both with the pitch, ×1.498 (within 0.1). The vowel keeps its level
    /// within 2 dB.
    func testTheFormantsStayWhereTheyWereAfterAFifthUp() {
        let hertz = 110.0
        let ratio = Foundation.pow(2, 7.0 / 12)
        let input = vowel(hertz, seconds: 0.8)
        let before = formants(of: steady(input), hertz: hertz)
        let heard = run(GrainShifter(sampleRate: rate, settings: .init(pitch: 7)), input)
        let after = formants(of: steady(heard), hertz: hertz * ratio)
        let moved = formants(of: steady(spliced(input, semitones: 7)), hertz: hertz * ratio)
        XCTAssertEqual(before.count, 2, "the ruler finds the vowel's two formants")
        XCTAssertEqual(after.count, 2)
        XCTAssertEqual(moved.count, 2)
        guard before.count == 2, after.count == 2, moved.count == 2 else { return }
        XCTAssertEqual(before[0], 700, accuracy: 35, "the ruler reads the first formant")
        XCTAssertEqual(before[1], 1_200, accuracy: 60, "and the second")
        for index in 0..<2 {
            XCTAssertEqual(after[index] / before[index], 1, accuracy: 0.08, "F\(index + 1) stays put")
            XCTAssertEqual(moved[index] / before[index], ratio, accuracy: 0.1, "SpliceHead moves F\(index + 1)")
        }
        XCTAssertEqual(level(steady(heard)[...]) - level(steady(input)[...]), 0, accuracy: 2, "the vowel keeps its level")
    }

    /// Four semitones of formant shift without any pitch shift: both formants move by ×1.26 up or
    /// ×0.794 down (within 8 %), and the fundamental stays within two cents of the input's.
    func testAFormantShiftMovesTheFormantsAndNotThePitch() throws {
        let hertz = 110.0
        let input = vowel(hertz, seconds: 0.8)
        let before = formants(of: steady(input), hertz: hertz)
        XCTAssertEqual(before.count, 2)
        for semitones in [4.0, -4.0] {
            let heard = run(GrainShifter(sampleRate: rate, settings: .init(formant: semitones)), input)
            let shift = Foundation.pow(2, semitones / 12)
            let after = formants(of: steady(heard), hertz: hertz)
            XCTAssertEqual(after.count, 2, "\(semitones)")
            if before.count == 2, after.count == 2 {
                for index in 0..<2 {
                    XCTAssertEqual(after[index] / before[index], shift, accuracy: 0.08, "F\(index + 1) at \(semitones)")
                }
            }
            XCTAssertEqual(cents(try pitch(Array(heard.suffix(12_000))), hertz), 0, accuracy: 2, "\(semitones)")
            XCTAssertEqual(level(steady(heard)[...]) - level(steady(input)[...]), 0, accuracy: 2, "\(semitones)")
        }
    }

    /// Noise has no pitch, so it comes out as it went in, only later. The noise between two sung
    /// notes — a consonant, 4.5 dB or 18.5 dB below the vowel — keeps its level within 1.5 dB, and
    /// from two of the notes' periods after its start to its very end it passes untouched: the note
    /// before fades out over its last period, the note after fades in over its own first, and no
    /// grains chop the consonant between.
    func testConsonantsAndNoisePassAtTheirLevel() {
        let hiss = noise(24_000, level: 0.2)
        let shifter = GrainShifter(sampleRate: rate, settings: .init(pitch: 7))
        let latency = shifter.latencySamples
        let heard = run(shifter, hiss)
        XCTAssertEqual(level(heard[latency...]) - level(hiss[..<(hiss.count - latency)]), 0, accuracy: 1.5)
        XCTAssertLessThan(largestDifference(heard, hiss, delay: latency), 1e-6, "noise passes untouched")

        for loudness in [Float(0.1), 0.02] {
            let first = vowel(220, seconds: 0.3), consonant = noise(14_400, level: loudness, seed: 777)
            let phrase = first + consonant + vowel(220, seconds: 0.3)
            let shifted = run(GrainShifter(sampleRate: rate, settings: .init(pitch: 7)), phrase)
            // The consonant's level in its middle, 50 ms in from either edge.
            let start = first.count + 2_400, end = first.count + consonant.count - 2_400
            let inLevel = level(phrase[start..<end]), outLevel = level(shifted[(start + latency)..<(end + latency)])
            XCTAssertEqual(outLevel - inLevel, 0, accuracy: 1.5, "the consonant keeps its level (\(loudness))")
            // Untouched from two periods of 220 Hz after its start to its last sample.
            var largest: Float = 0
            for index in (first.count + 436)..<(first.count + consonant.count) {
                largest = Swift.max(largest, Swift.abs(shifted[index + latency] - phrase[index]))
            }
            XCTAssertLessThan(largest, 1e-6, "and passes untouched (\(loudness))")
        }
    }

    /// The latency is one number per sample rate, whatever the settings, the sound or the block
    /// size: at no shift the output is the input exactly `latencySamples` later — a low tone, a
    /// high vowel, noise, and notes broken up by silence and hiss; with a shift a note's onset
    /// arrives that late (within a millisecond); and after `tailSamples` of silence nothing is left.
    func testTheLatencyIsConstant() {
        let reported = GrainShifter.latencySamples(sampleRate: rate)
        XCTAssertGreaterThan(reported, 0)
        for settings in [GrainShifter.Settings(), .init(pitch: 7), .init(pitch: -24, formant: 12), .init(formant: -12)] {
            let shifter = GrainShifter(sampleRate: rate, settings: settings)
            XCTAssertEqual(shifter.latencySamples, reported)
            shifter.settings = .init(pitch: 12, formant: 3)
            XCTAssertEqual(shifter.latencySamples, reported, "a change of settings keeps it")
        }
        let silence = [Float](repeating: 0, count: 4_800)
        let inputs: [(String, [Float])] = [
            ("a low tone", tone(98, seconds: 0.5)),
            ("a high vowel", vowel(440, seconds: 0.5)),
            ("noise", noise(24_000, level: 0.3)),
            ("notes and hiss", tone(220, seconds: 0.2) + silence + noise(4_800, level: 0.1) + vowel(150, seconds: 0.3)),
        ]
        for (name, input) in inputs {
            let heard = run(GrainShifter(sampleRate: rate), input)
            XCTAssertTrue(heard[..<reported].allSatisfy { (sample: Float) -> Bool in sample == 0 }, name)
            XCTAssertLessThan(largestDifference(heard, input, delay: reported), 1e-5, name)
        }
        let blocks = tone(220, seconds: 0.3) + noise(4_800, level: 0.2) + vowel(330, seconds: 0.2)
        let one = run(GrainShifter(sampleRate: rate, settings: .init(pitch: 5, formant: -2)), blocks, block: 1)
        for block in [37, 512, 4_096] {
            let heard = run(GrainShifter(sampleRate: rate, settings: .init(pitch: 5, formant: -2)), blocks, block: block)
            XCTAssertTrue(heard == one, "block \(block) plays exactly what single frames play")
        }
        for settings in [GrainShifter.Settings(pitch: 7), .init(pitch: -12), .init(formant: 4), .init(pitch: 12, formant: -5)] {
            let note = silence + tone(220, seconds: 0.3)
            let heard = run(GrainShifter(sampleRate: rate, settings: settings), note)
            let onset = heard.firstIndex { (sample: Float) -> Bool in Swift.abs(sample) > 1e-3 } ?? heard.count
            XCTAssertEqual(Double(onset - silence.count - reported), 0, accuracy: 48, "\(settings)")
        }
        let shifter = GrainShifter(sampleRate: rate, settings: .init(pitch: -7, formant: -12))
        let note = vowel(98, seconds: 0.3)
        let tail = run(shifter, note + [Float](repeating: 0, count: shifter.tailSamples + 2_000))
        XCTAssertTrue(tail[(note.count + shifter.tailSamples)...].allSatisfy { (sample: Float) -> Bool in sample == 0 },
                      "silent after the tail")
        for other in [44_100.0, 96_000] {
            let shifter = GrainShifter(sampleRate: other)
            XCTAssertEqual(shifter.latencySamples, GrainShifter.latencySamples(sampleRate: other))
            XCTAssertEqual(Double(shifter.latencySamples) / other, Double(reported) / rate, accuracy: 0.001,
                           "about the same time at \(other)")
            let input = noise(4_800, level: 0.2) + tone(196, seconds: 0.3)
            XCTAssertLessThan(largestDifference(run(shifter, input), input, delay: shifter.latencySamples), 1e-5, "\(other)")
        }
    }

    /// A sample that is not a number, or is infinite, on either side: that frame is silence on both,
    /// what was heard before it never comes out, and from there the shifter plays exactly what a new
    /// one would. A run of them is silence too, and from its first sample on the shifter plays
    /// exactly what a new one plays given silence for the run. Nothing that is not a number ever
    /// leaves it.
    func testABadSampleIsSilenceAndResets() {
        let input = vowel(220, seconds: 0.5)
        let bad = 12_000
        for (value, onLeft) in [(Float.nan, true), (Float.infinity, false), (-Float.infinity, true)] {
            let shifter = GrainShifter(sampleRate: rate, settings: .init(pitch: 7, formant: 2))
            let latency = shifter.latencySamples
            var left = input, right = input
            if onLeft { left[bad] = value } else { right[bad] = value }
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let x = l.baseAddress, let y = r.baseAddress else { return }
                    shifter.process(left: x, right: y, frames: l.count)
                }
            }
            XCTAssertTrue(left.allSatisfy(\.isFinite) && right.allSatisfy(\.isFinite), "\(value)")
            XCTAssertTrue(left[bad..<(bad + latency)].allSatisfy { (sample: Float) -> Bool in sample == 0 },
                          "nothing from before \(value) comes out")
            XCTAssertTrue(right[bad..<(bad + latency)].allSatisfy { (sample: Float) -> Bool in sample == 0 }, "\(value)")
            let fresh = run(GrainShifter(sampleRate: rate, settings: .init(pitch: 7, formant: 2)), [0] + input[(bad + 1)...])
            XCTAssertTrue(Array(left[bad...]) == fresh && Array(right[bad...]) == fresh, "a new shifter after \(value)")
            XCTAssertGreaterThan(fresh.map { (sample: Float) -> Float in Swift.abs(sample) }.max() ?? 0, 0.05,
                                 "and it sings again")
        }
        let length = 3_000
        let shifter = GrainShifter(sampleRate: rate, settings: .init(pitch: 7, formant: 2))
        let latency = shifter.latencySamples
        var left = input, right = input
        for index in bad..<(bad + length) { left[index] = .nan }
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let x = l.baseAddress, let y = r.baseAddress else { return }
                shifter.process(left: x, right: y, frames: l.count)
            }
        }
        XCTAssertTrue(left.allSatisfy(\.isFinite) && right.allSatisfy(\.isFinite), "a run of bad samples")
        XCTAssertTrue(left[bad..<(bad + length + latency)].allSatisfy { (sample: Float) -> Bool in sample == 0 },
                      "a run is silence, and what came before it never comes out")
        let quiet = [Float](repeating: 0, count: length)
        let fresh = run(GrainShifter(sampleRate: rate, settings: .init(pitch: 7, formant: 2)), quiet + input[(bad + length)...])
        XCTAssertTrue(Array(left[bad...]) == fresh && Array(right[bad...]) == fresh, "a new shifter after the run")
    }

    /// A finite sample far beyond any real level — the largest float inside a note, or it and its
    /// negative in the silence before one — neither lets a value that is not a number out nor stops
    /// the shift for good: about a second after it the voice is shifted again, within two cents.
    /// (Before the two sides were halved before they were added, and a blocker that overflowed
    /// started again from silence, either left the DC blocker on the analysed mean NaN, and no note
    /// was found again.)
    func testAHugeSampleDoesNotStopTheShift() throws {
        let ratio = Foundation.pow(2, 7.0 / 12)
        var alone = vowel(220, seconds: 1.5)
        alone[12_000] = .greatestFiniteMagnitude
        var pair = [Float](repeating: 0, count: 4_800) + vowel(220, seconds: 1.5)
        pair[2_400] = .greatestFiniteMagnitude
        pair[2_401] = -.greatestFiniteMagnitude
        for (name, input) in [("inside a note", alone), ("a pair before one", pair)] {
            let heard = run(GrainShifter(sampleRate: rate, settings: .init(pitch: 7)), input)
            XCTAssertTrue(heard.allSatisfy(\.isFinite), name)
            XCTAssertEqual(cents(try pitch(Array(heard.suffix(12_000))), 220 * ratio), 0, accuracy: 2, name)
        }
    }

    func testSettingsOutsideTheirRangesAreClamped() {
        let shifter = GrainShifter(sampleRate: rate, settings: .init(pitch: 40, formant: -30))
        XCTAssertEqual(shifter.settings, .init(pitch: 24, formant: -12))
        shifter.settings = .init(pitch: .nan, formant: .infinity)
        XCTAssertEqual(shifter.settings, .init(pitch: 0, formant: 0))
        XCTAssertEqual(GrainShifter(sampleRate: .nan).sampleRate, 48_000)
        XCTAssertEqual(GrainShifter(sampleRate: -1).latencySamples, GrainShifter.latencySamples(sampleRate: 48_000))
    }
}
