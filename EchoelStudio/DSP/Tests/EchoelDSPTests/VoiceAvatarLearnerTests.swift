import Foundation
import XCTest
@testable import EchoelDSP

/// The voice avatar learner (VA-2): a recording in, a voice avatar out — the envelope in hertz, so a
/// vowel keeps its formants whatever note it was sung on; noise learns the noise half; nothing is
/// learned from silence; the same recording always learns the same avatar; a cancelled learning
/// stops. And the rules that keep a reading true hold: a pitch is not heard an octave high, a stray
/// reading does not stretch the pitch range, the end of a note is not counted as noise, the lowest
/// harmonics keep their levels. The oracle is the vocal tract the choir engine sings through
/// (`VocalTract`, `Vowel`): its formants are known.
final class VoiceAvatarLearnerTests: XCTestCase {
    private let rate = 48_000.0

    /// A bass's vowels, the formant table the choir engine sings from: oo, oh, ah, eh, ee.
    private let vowels: [(name: String, character: Float)] = [("oo", 0), ("oh", 0.25), ("ah", 0.5), ("eh", 0.75), ("ee", 1)]

    private func vowel(_ character: Float) -> Vowel {
        Vowel.at(character: character, register: 0)
    }

    /// A vowel sung through the vocal tract: a band-limited sawtooth whose pitch at `time` seconds is
    /// `pitch(time)` hertz, at a peak of 0.3.
    private func sung(_ vowel: Vowel, seconds: Double, at sampleRate: Double? = nil,
                      pitch: (_ time: Double) -> Double) -> [Float] {
        let samplingRate = sampleRate ?? rate
        var saw = Oscillator(waveform: .saw)
        var tract = VocalTract()
        tract.tune(to: vowel, sampleRate: Float(samplingRate))
        let count = Int(samplingRate * seconds)
        var samples = [Float](repeating: 0, count: count)
        for index in 0..<count {
            let time = Double(index) / samplingRate
            samples[index] = tract.process(saw.next(increment: Float(pitch(time) / samplingRate)))
        }
        let loudest = samples.reduce(Float(0)) { (top: Float, value: Float) -> Float in Swift.max(top, Swift.abs(value)) }
        return samples.map { (value: Float) -> Float in value / loudest * 0.3 }
    }

    /// A vowel sung gliding from `from` to `to` hertz, evenly in cents, with a vibrato of
    /// ±`vibrato.cents` at `vibrato.rate` hertz on top.
    private func sung(_ vowel: Vowel, from: Double, to: Double? = nil, seconds: Double,
                      vibrato: (rate: Double, cents: Double)? = nil, at sampleRate: Double? = nil) -> [Float] {
        let end = to ?? from
        return sung(vowel, seconds: seconds, at: sampleRate) { (time: Double) -> Double in
            var hertz: Double = from * Foundation.pow(end / from, time / seconds)
            if let vibrato {
                let sway: Double = vibrato.cents / 1_200 * Foundation.sin(2 * Double.pi * vibrato.rate * time)
                hertz *= Foundation.pow(2, sway)
            }
            return hertz
        }
    }

    /// A vowel sung up a line from A2 to A3, `seconds` on each of six notes.
    private func line(_ vowel: Vowel, seconds: Double, at sampleRate: Double? = nil) -> [Float] {
        var samples: [Float] = []
        for hertz in [110.0, 131, 147, 165, 196, 220] { samples += sung(vowel, from: hertz, seconds: seconds, at: sampleRate) }
        return samples
    }

    /// White noise from a fixed seed, evenly spread over ±`level`.
    private func noise(_ count: Int, level: Float, seed: UInt64 = 0x5EED) -> [Float] {
        var state = seed
        var samples = [Float](repeating: 0, count: count)
        for index in 0..<count {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            samples[index] = level * (Float(state >> 40) / Float(1 << 23) - 1)
        }
        return samples
    }

    /// Noise through one resonance at `hertz`, `width` hertz wide, at a peak of 0.3: a hiss.
    private func hiss(at hertz: Float, width: Float, seconds: Double, seed: UInt64 = 0x5EED) -> [Float] {
        var tract = VocalTract()
        // Formants at or above 45 % of the rate pass nothing of their own: one resonance is left.
        tract.tune(to: Vowel((hertz, 40_000, 40_000, 40_000, 40_000), (width, 100, 100, 100, 100)), sampleRate: Float(rate))
        let samples = noise(Int(rate * seconds), level: 1, seed: seed).map { (value: Float) -> Float in tract.process(value) }
        let loudest = samples.reduce(Float(0)) { (top: Float, value: Float) -> Float in Swift.max(top, Swift.abs(value)) }
        return samples.map { (value: Float) -> Float in value / loudest * 0.3 }
    }

    private func energy(_ samples: [Float]) -> Float {
        samples.reduce(0) { (sum: Float, value: Float) -> Float in sum + value * value }
    }

    private func learn(_ samples: [Float], origin: VoiceAvatar.Origin = .ownVoice, at sampleRate: Double? = nil,
                       isCancelled: () -> Bool = { false }) throws -> VoiceAvatar {
        try VoiceAvatarLearner.learn(from: samples, sampleRate: sampleRate ?? rate, label: "Test", origin: origin,
                                     isCancelled: isCancelled)
    }

    /// Why `learning` learned nothing, or nil when it learned an avatar.
    private func failure(_ learning: () throws -> VoiceAvatar) -> VoiceAvatarLearner.Failure? {
        do {
            _ = try learning()
            return nil
        } catch {
            return error as? VoiceAvatarLearner.Failure
        }
    }

    /// The peaks of a table on the band grid, lowest first, in hertz: its local maxima, each refined
    /// by a parabola through its band and the two beside it.
    private func peaks(_ table: [Float]) -> [Double] {
        var found: [Double] = []
        for band in 1..<(table.count - 1) where table[band] > table[band - 1] && table[band] >= table[band + 1] {
            let left = Double(table[band - 1]), middle = Double(table[band]), right = Double(table[band + 1])
            let curve = left - 2 * middle + right
            let offset = curve < 0 ? 0.5 * (left - right) / curve : 0
            found.append(Double(VoiceAvatar.lowestHertz) * Foundation.pow(VoiceAvatar.bandRatio, Double(band) + offset))
        }
        return found
    }

    /// Hertz to the nearest whole hertz, for a message.
    private func whole(_ hertz: Double) -> Int {
        Int(hertz.rounded())
    }

    /// The peak of `table` nearest `hertz`.
    private func peak(of table: [Float], near hertz: Double) throws -> Double {
        try XCTUnwrap(peaks(table).min { (a: Double, b: Double) -> Bool in Swift.abs(a - hertz) < Swift.abs(b - hertz) })
    }

    /// How far two avatars' envelopes lie apart at `hertz` (the first) and `other` (the second; the
    /// same frequencies unless given), in decibels, once their levels are aligned — their mean
    /// difference there taken out: levels are relative.
    private func aligned(_ a: VoiceAvatar, _ b: VoiceAvatar, at hertz: [Float], and other: [Float]? = nil) -> [Float] {
        let differences = zip(hertz, other ?? hertz).map { (pair: (Float, Float)) -> Float in
            a.level(at: pair.0, character: 0.5) - b.level(at: pair.1, character: 0.5)
        }
        let mean = differences.reduce(0, +) / Float(differences.count)
        return differences.map { (difference: Float) -> Float in difference - mean }
    }

    /// The vocal tract's levels at `hertz` under a sawtooth's 1/f slope, in decibels: what a vowel
    /// sung on it measures as, by a DFT of the tract's impulse response.
    private func oracle(_ vowel: Vowel, at hertz: [Float]) -> [Float] {
        var tract = VocalTract()
        tract.tune(to: vowel, sampleRate: Float(rate))
        let response = (0..<8_192).map { (n: Int) -> Double in Double(tract.process(n == 0 ? 1 : 0)) }
        return hertz.map { (frequency: Float) -> Float in
            var re: Double = 0, im: Double = 0
            for (n, x) in response.enumerated() {
                let angle: Double = 2 * Double.pi * Double(frequency) * Double(n) / rate
                re += x * Foundation.cos(angle)
                im -= x * Foundation.sin(angle)
            }
            return Float(10 * Foundation.log10(re * re + im * im) - 20 * Foundation.log10(Double(frequency)))
        }
    }

    /// For each vowel (by its character), the snapshot of `avatar` nearest that vowel's tract: the one
    /// whose levels from 150 Hz to 4 kHz differ least from the tract's (`oracle`) about their mean.
    private func nearestSnapshots(of avatar: VoiceAvatar, to characters: [Float]) throws -> [Int] {
        let bands = (0..<VoiceAvatar.bandCount).map { (band: Int) -> Float in VoiceAvatar.centre(ofBand: band) }
            .filter { (hertz: Float) -> Bool in hertz >= 150 && hertz <= 4_000 }
        return try characters.map { (character: Float) throws -> Int in
            let truth = oracle(vowel(character), at: bands)
            let distances = avatar.snapshots.map { (table: [Float]) -> Float in
                let differences = zip(bands, truth).map { (pair: (Float, Float)) -> Float in
                    table.withUnsafeBufferPointer { (levels: UnsafeBufferPointer<Float>) -> Float in
                        VoiceAvatar.level(at: pair.0, in: levels)
                    } - pair.1
                }
                let mean = differences.reduce(0, +) / Float(differences.count)
                return differences.reduce(0) { (sum: Float, difference: Float) -> Float in
                    sum + (difference - mean) * (difference - mean)
                }
            }
            return try XCTUnwrap(distances.indices.min { (a: Int, b: Int) -> Bool in distances[a] < distances[b] })
        }
    }

    // MARK: The envelope is kept in hertz

    func testAVowelSungAtTwoPitchesLearnsOneEnvelope() throws {
        let a2 = sung(vowel(0.5), from: 110, seconds: 0.5), a3 = sung(vowel(0.5), from: 220, seconds: 0.5)
        let low = try learn(a2), high = try learn(a3)
        XCTAssertEqual(low.snapshots.count, 1, "one vowel, one snapshot")
        XCTAssertEqual(high.snapshots.count, 1)
        XCTAssertNil(low.vibrato, "a held note has no vibrato")

        // At every harmonic of A3 below 4 kHz — the frequencies both recordings carry — the avatar
        // learned at A2 and the one learned at A3 agree within 3 dB, levels aligned.
        let harmonics = (1...18).map { (k: Int) -> Float in Float(k) * 220 }
        for (hertz, difference) in zip(harmonics, aligned(low, high, at: harmonics)) {
            XCTAssertEqual(difference, 0, accuracy: 3, "\(hertz) Hz")
        }
        // Kept per harmonic number instead — the A2 avatar's k-th harmonic against the A3 avatar's —
        // they would differ by far more: the formants would have moved with the pitch.
        let lowHarmonics = (1...18).map { (k: Int) -> Float in Float(k) * 110 }
        let perHarmonic = aligned(low, high, at: lowHarmonics, and: harmonics)
        XCTAssertGreaterThan(perHarmonic.map { (difference: Float) -> Float in Swift.abs(difference) }.max() ?? 0, 9)

        // Sung at both pitches in one take, it is still one snapshot, and that agrees with both.
        let both = try learn(a2 + a3)
        XCTAssertEqual(both.snapshots.count, 1, "one vowel at two pitches is one envelope, not two")
        for single in [low, high] {
            for (hertz, difference) in zip(harmonics, aligned(both, single, at: harmonics)) {
                XCTAssertEqual(difference, 0, accuracy: 3, "\(hertz) Hz")
            }
        }
        let range = try XCTUnwrap(both.pitchRange)
        XCTAssertEqual(range.lowerBound, 110, accuracy: 1)
        XCTAssertEqual(range.upperBound, 220, accuracy: 2)
    }

    func testTheLearnedPeaksSitAtTheVowelsFormants() throws {
        // "ah" (600 and 1040 Hz) and "eh" (400 and 1620 Hz), each sung up a line from A2 to A3, and
        // "ah" again at 44.1 kHz: the learner pools the notes into one snapshot, whose peaks sit
        // within 8 % of the first two formants. These two of the bass's five vowels, because on
        // this line they keep both: oh and oo lose their second formant into the first, and ee's
        // first lies too near the fundamental (`VoiceAvatarLearner`, Limits).
        for (character, formants, sampleRate) in [(Float(0.5), [600.0, 1_040], 48_000.0), (0.75, [400, 1_620], 48_000),
                                                  (0.5, [600, 1_040], 44_100)] {
            let avatar = try learn(line(vowel(character), seconds: 0.2, at: sampleRate), at: sampleRate)
            XCTAssertEqual(avatar.snapshots.count, 1, "character \(character) at \(sampleRate)")
            for formant in formants {
                XCTAssertEqual(try peak(of: avatar.snapshots[0], near: formant) / formant, 1, accuracy: 0.08,
                               "character \(character) at \(sampleRate), \(formant) Hz: peaks \(peaks(avatar.snapshots[0]).map(whole))")
            }
        }

        // Sung on one low note, A2, it keeps them too, at either rate.
        for sampleRate in [48_000.0, 44_100] {
            let avatar = try learn(sung(vowel(0.5), from: 110, seconds: 0.3, at: sampleRate), at: sampleRate)
            for formant in [600.0, 1_040] {
                XCTAssertEqual(try peak(of: avatar.snapshots[0], near: formant) / formant, 1, accuracy: 0.08,
                               "A2 at \(sampleRate), \(formant) Hz: peaks \(peaks(avatar.snapshots[0]).map(whole))")
            }
        }
    }

    func testEachVowelOfATakeBecomesASnapshotFromDarkToBright() throws {
        // oh, ah, eh and ee one after another on one note, C3 (131 Hz): four snapshots, ordered by
        // where their power sits (`VoiceAvatar.brightness(of:)`), each the nearest of the four to its
        // own vowel's tract — no vowel taken twice. The closest two, eh and ee, lie 7.5 dB apart
        // (`shapeDistance`), well past `splitDecibels`.
        let four = Array(vowels.dropFirst())
        var take: [Float] = []
        for entry in four { take += sung(vowel(entry.character), from: 131, seconds: 0.3) }
        let avatar = try learn(take)
        XCTAssertEqual(avatar.snapshots.count, 4)
        let brightness = avatar.snapshots.map { (table: [Float]) -> Float in VoiceAvatar.brightness(of: table) }
        XCTAssertEqual(brightness, brightness.sorted(), "dark to bright")
        let nearest = try nearestSnapshots(of: avatar, to: four.map { (entry: (name: String, character: Float)) -> Float in
            entry.character
        })
        for (index, entry) in four.enumerated() {
            XCTAssertFalse(nearest[..<index].contains(nearest[index]),
                           "\(entry.name) is nearest snapshot \(nearest[index]), already taken")
        }

        // With oo sung before them, four snapshots or five: oo and oh on one note lie only 2.5 to 6 dB
        // apart, at C3 4.1, on the threshold, so they may read as one. ah, eh and ee keep one each.
        let withOo = try learn(sung(vowel(vowels[0].character), from: 131, seconds: 0.3) + take)
        XCTAssertTrue((4...5).contains(withOo.snapshots.count), "\(withOo.snapshots.count) snapshots")
        let bright = vowels.suffix(3)
        let kept = try nearestSnapshots(of: withOo, to: bright.map { (entry: (name: String, character: Float)) -> Float in
            entry.character
        })
        for (index, entry) in bright.enumerated() {
            XCTAssertFalse(kept[..<index].contains(kept[index]), "\(entry.name) is nearest snapshot \(kept[index]), already taken")
        }
    }

    func testTheLowestHarmonicsKeepTheirLevels() throws {
        // ah sung at A3 and B3 (220 and 247 Hz): at its first six harmonics the snapshot reads the vocal
        // tract's own levels within 2 dB, levels aligned. Below the fundamental a frame holds nothing;
        // the learner holds the first harmonic's level there, else the envelope bends up beside the
        // first harmonic and reads it 4 to 7 dB too loud.
        for hertz in [Float(220), 247] {
            let avatar = try learn(sung(vowel(0.5), from: Double(hertz), seconds: 0.5))
            let harmonics = (1...6).map { (k: Int) -> Float in Float(k) * hertz }
            let truth = oracle(vowel(0.5), at: harmonics)
            let differences = zip(harmonics, truth).map { (pair: (Float, Float)) -> Float in
                avatar.level(at: pair.0, character: 0.5) - pair.1
            }
            let mean = differences.reduce(0, +) / Float(differences.count)
            for (harmonic, difference) in zip(harmonics, differences) {
                XCTAssertEqual(difference - mean, 0, accuracy: 2, "ah at \(hertz) Hz, its harmonic at \(harmonic) Hz")
            }
        }
    }

    // MARK: Noise, breath, pitch

    func testNoiseLearnsANoiseOnlyAvatar() throws {
        // A hiss through one resonance at 1500 Hz: nothing voiced, so no snapshot, no pitch, no
        // vibrato, and all of it breath. Its noise envelope peaks at the resonance.
        let resonant = hiss(at: 1_500, width: 200, seconds: 0.5)
        let avatar = try learn(resonant)
        XCTAssertTrue(avatar.snapshots.isEmpty)
        XCTAssertNil(avatar.pitchRange)
        XCTAssertNil(avatar.vibrato)
        XCTAssertEqual(avatar.breath, 1)
        XCTAssertEqual(avatar.envelope(character: 0.5), [Float](repeating: VoiceAvatar.floorDecibels, count: 48))
        XCTAssertEqual(try peak(of: avatar.noise, near: 1_500) / 1_500, 1, accuracy: 0.03, "peaks \(peaks(avatar.noise).map(whole))")
        XCTAssertEqual(avatar.noise.max(), 0, "the loudest band at 0 dB")

        // Declared as a voice, it is still a sound's: the learner never says it measured a voice it
        // did not hear. Echoel's own stays Echoel's own.
        XCTAssertEqual(avatar.origin, .sound)
        XCTAssertEqual(try learn(resonant, origin: .sound).origin, .sound)
        XCTAssertEqual(try learn(resonant, origin: .factory).origin, .factory)

        // White noise learns a flat noise envelope: every band within 1.5 dB of their mean. (The
        // loudest band, at 0 dB, is the one the draw raised most.)
        let white = try learn(noise(Int(rate), level: 0.3))
        XCTAssertTrue(white.snapshots.isEmpty)
        let mean = white.noise.reduce(0, +) / Float(white.noise.count)
        for (band, level) in white.noise.enumerated() {
            XCTAssertEqual(level, mean, accuracy: 1.5, "band \(band), \(VoiceAvatar.centre(ofBand: band)) Hz")
        }
    }

    func testTheNoiseEnvelopeHoldsNothingOfANote() throws {
        // A vowel that stops dead, a white hiss 30 dB below it, then the vowel again: the noise
        // envelope is the hiss's own — the one the hiss learns alone — within 1.5 dB in every band,
        // levels aligned. The frames that still hold the end or the start of a note are not counted:
        // the note is 30 dB louder, and they would put its formants into the noise.
        let ah = sung(vowel(0.5), from: 165, seconds: 0.4)
        let hush = noise(Int(rate * 0.5), level: 1, seed: 9)
        let thirtyDecibelsDown: Float = Foundation.pow(10, -1.5)
        let scale = (energy(ah) / Float(ah.count) / (energy(hush) / Float(hush.count))).squareRoot() * thirtyDecibelsDown
        let between = try learn(ah + hush.map { (value: Float) -> Float in value * scale } + ah)
        XCTAssertEqual(between.snapshots.count, 1)
        let alone = try learn(hush.map { (value: Float) -> Float in value * 0.3 })
        let differences = zip(between.noise, alone.noise).map { (pair: (Float, Float)) -> Float in pair.0 - pair.1 }
        let mean = differences.reduce(0, +) / Float(differences.count)
        for (band, difference) in differences.enumerated() {
            XCTAssertEqual(difference - mean, 0, accuracy: 1.5, "band \(band), \(VoiceAvatar.centre(ofBand: band)) Hz")
        }
    }

    func testBreathIsTheShareOfTheSoundThatDoesNotRepeat() throws {
        let ah = sung(vowel(0.5), from: 165, seconds: 0.4)
        // A vowel alone is tone, not breath.
        XCTAssertLessThan(try learn(ah).breath, 0.02)

        // A vowel with a breath of noise under it at 5 % of its power: about 5 % breath.
        let hush = noise(ah.count, level: 1, seed: 7)
        let scale = (0.05 * energy(ah) / energy(hush)).squareRoot()
        let breathy = try learn(zip(ah, hush).map { (pair: (Float, Float)) -> Float in pair.0 + scale * pair.1 })
        XCTAssertEqual(breathy.snapshots.count, 1, "still a voice")
        XCTAssertEqual(breathy.breath, 0.05, accuracy: 0.03)

        // A vowel and then a hiss of as much energy: half of it is breath, the vowel is the snapshot,
        // and the hiss — its resonance at 5 kHz — is the noise envelope.
        let sss = hiss(at: 5_000, width: 800, seconds: 0.4, seed: 11)
        let level = (energy(ah) / energy(sss)).squareRoot()
        let take = ah + [Float](repeating: 0, count: Int(rate * 0.1)) + sss.map { (value: Float) -> Float in value * level }
        let avatar = try learn(take)
        XCTAssertEqual(avatar.snapshots.count, 1)
        XCTAssertEqual(avatar.breath, 0.5, accuracy: 0.1)
        XCTAssertEqual(try peak(of: avatar.noise, near: 5_000) / 5_000, 1, accuracy: 0.05, "peaks \(peaks(avatar.noise).map(whole))")
        XCTAssertEqual(try peak(of: avatar.snapshots[0], near: 600) / 600, 1, accuracy: 0.08)
    }

    func testAVibratoIsLearnedAtItsRateAndDepth() throws {
        for (rateHertz, cents) in [(5.5, 30.0), (4.2, 60)] {
            let avatar = try learn(sung(vowel(0.5), from: 220, seconds: 1, vibrato: (rateHertz, cents)))
            let vibrato = try XCTUnwrap(avatar.vibrato, "\(rateHertz) Hz ±\(cents) ct")
            XCTAssertEqual(Double(vibrato.rate), rateHertz, accuracy: 0.2)
            XCTAssertEqual(Double(vibrato.depth), cents, accuracy: 0.15 * cents)
            // The pitch range spans the swing, short of its very ends (the 5 % and 95 % points).
            let range = try XCTUnwrap(avatar.pitchRange)
            let swing = Foundation.pow(2, 0.95 * cents / 1_200)
            XCTAssertEqual(Double(range.lowerBound), 220 / swing, accuracy: 1.5)
            XCTAssertEqual(Double(range.upperBound), 220 * swing, accuracy: 1.5)
        }
        // A slow glide is no vibrato: the line it moves along is not a swing.
        let glide = try learn(sung(vowel(0.5), from: 196, to: 247, seconds: 1))
        XCTAssertNil(glide.vibrato)
        let range = try XCTUnwrap(glide.pitchRange)
        XCTAssertLessThan(range.lowerBound, 202)
        XCTAssertGreaterThan(range.upperBound, 240)
    }

    func testAVowelIsNotHeardAnOctaveTooHigh() throws {
        // eh and oh (first formant 400 Hz) sung at G3, 196 Hz: the second harmonic sits on the formant,
        // and the tracker hears it, an octave too high. The learner tries twice and three times the
        // period it heard and keeps the shortest that repeats nearly as well as the best: the pitch
        // range is G3's, within 2 % (it reads up to 1 % sharp).
        for character in [Float(0.75), 0.25] {
            let range = try XCTUnwrap(try learn(sung(vowel(character), from: 196, seconds: 0.5)).pitchRange)
            XCTAssertEqual(range.lowerBound, 196, accuracy: 196 * 0.02, "character \(character)")
            XCTAssertEqual(range.upperBound, 196, accuracy: 196 * 0.02, "character \(character)")
        }
    }

    func testAStrayReadingDoesNotStretchThePitchRange() throws {
        // A3 held for 1.5 s, scooped into from G3 over its first 40 ms and flipped up to B3 over its
        // last: the frames read on the way in and out (as low as 204 Hz, as high as 230 Hz) lie below
        // the 5 % point and above the 95 % point, so the pitch range is A3's, within 0.5 %.
        let note = sung(vowel(0.5), seconds: 1.5) { (time: Double) -> Double in
            if time < 0.04 { return 196 * Foundation.pow(220.0 / 196, time / 0.04) }
            if time > 1.46 { return 220 * Foundation.pow(247.0 / 220, (time - 1.46) / 0.04) }
            return 220
        }
        let range = try XCTUnwrap(try learn(note).pitchRange)
        XCTAssertEqual(range.lowerBound, 220, accuracy: 1.1)
        XCTAssertEqual(range.upperBound, 220, accuracy: 1.1)
    }

    // MARK: Nothing learned

    func testSilenceOrTooShortLearnsNothing() throws {
        let second = Int(rate)
        XCTAssertEqual(failure { try learn([Float](repeating: 0, count: second)) }, .silent)
        XCTAssertEqual(failure { try learn([Float](repeating: .nan, count: second)) }, .silent, "not a number is silence")
        XCTAssertEqual(failure { try learn([Float](repeating: .infinity, count: second)) }, .silent)
        XCTAssertEqual(failure { try learn(noise(second, level: 1e-4)) }, .silent, "−80 dBFS is below the gate")

        // Too short: under one frame and nine hops, however loud — 1920 + 9 · 480 samples at 48 kHz,
        // 130 ms.
        let vowelTake = sung(vowel(0.5), from: 165, seconds: 0.2)
        let shortest = 1_920 + 9 * 480
        XCTAssertEqual(failure { try learn([]) }, .tooShort)
        XCTAssertEqual(failure { try learn(Array(vowelTake.prefix(shortest - 1))) }, .tooShort)
        XCTAssertNotNil(try? learn(Array(vowelTake.prefix(shortest))), "ten frames that sound are enough")

        // Too little of it sounds: a 30 ms burst in a second of silence.
        var burst = [Float](repeating: 0, count: second)
        for (offset, value) in vowelTake.prefix(Int(rate * 0.03)).enumerated() { burst[second / 2 + offset] = value }
        XCTAssertEqual(failure { try learn(burst) }, .tooShort)
        XCTAssertNil(try? learn(burst), "nothing is learned")
    }

    func testABadRateOrLabelIsRefusedBeforeListening() throws {
        let take = sung(vowel(0.5), from: 165, seconds: 0.3)
        var asked = 0
        for sampleRate in [Double.nan, .infinity, 0, -48_000, 4_000, 400_000] {
            XCTAssertEqual(failure {
                try learn(take, at: sampleRate) {
                    asked += 1
                    return false
                }
            }, .unsupportedSampleRate, "\(sampleRate)")
        }
        for (label, refusal) in [("", VoiceAvatar.Refusal.emptyLabel), ("  \n", .emptyLabel),
                                 (String(repeating: "a", count: 129), .labelTooLong)] {
            XCTAssertEqual(failure {
                try VoiceAvatarLearner.learn(from: take, sampleRate: rate, label: label, origin: .ownVoice) {
                    asked += 1
                    return false
                }
            }, .refused(refusal))
        }
        XCTAssertEqual(asked, 0, "refused at the door, before a frame was heard")
    }

    // MARK: Deterministic and cancellable

    func testTheSameInputAlwaysLearnsTheSameAvatar() throws {
        // A take with two vowels, a vibrato and a hiss between them, with silence in a few places.
        var take = sung(vowel(0.5), from: 165, seconds: 0.7, vibrato: (5.5, 25))
            + hiss(at: 5_000, width: 800, seconds: 0.3, seed: 3).map { (value: Float) -> Float in value * 0.5 }
            + sung(vowel(1), from: 196, seconds: 0.4)
        let holes = Array(stride(from: 1_000, to: take.count, by: 9_973))
        for index in holes { take[index] = 0 }
        let first = try learn(take)
        XCTAssertEqual(first.snapshots.count, 2)
        XCTAssertNotNil(first.vibrato)
        let encoding = try first.encoded()
        XCTAssertEqual(try learn(take).encoded(), encoding, "bit for bit")

        // A sample that is not a number is silence: with NaN and infinity in those places it learns
        // the same avatar, to the bit.
        var damaged = take
        for index in holes { damaged[index] = index % 2 == 0 ? .nan : -.infinity }
        XCTAssertEqual(try learn(damaged).encoded(), encoding)
    }

    func testCancellingStopsTheLearning() throws {
        let take = sung(vowel(0.5), from: 220, seconds: 0.4) + hiss(at: 3_000, width: 400, seconds: 0.3)
        var asked = 0
        let learned = try learn(take) {
            asked += 1
            return false
        }
        XCTAssertEqual(learned.snapshots.count, 1)
        // Asked between frames: at least once for every frame of the recording.
        let frames = (take.count - 1_920) / 480 + 1
        XCTAssertGreaterThan(asked, frames)

        // Cancelled at the first question, halfway, or at the last: nothing is learned, and it is not
        // asked again.
        for stop in [1, asked / 2, asked] {
            var calls = 0
            XCTAssertEqual(failure {
                try learn(take) {
                    calls += 1
                    return calls >= stop
                }
            }, .cancelled, "stopped at question \(stop)")
            XCTAssertEqual(calls, stop, "it stopped when told")
        }
    }
}
