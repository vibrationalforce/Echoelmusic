import Foundation
import XCTest
@testable import EchoelDSP

/// The channel vocoder (VA-5): the modulator's bands, followed in seconds, laid on the carrier's
/// bands at centres given in exact hertz; the modulator's own highs above the crossover; and
/// silence, a bad sample and a change of the band count handled without a sound of their own.
final class ChannelVocoderTests: XCTestCase {
    private let rate = 48_000.0

    // MARK: Signals

    /// White noise uniform in −`amplitude` … `amplitude`, the same every run for the same seed.
    private func noise(_ frames: Int, amplitude: Float = 1, seed: UInt32 = 0x2545_F491) -> [Float] {
        var state = seed == 0 ? 1 : seed
        return (0..<frames).map { (_: Int) -> Float in
            state ^= state << 13
            state ^= state >> 17
            state ^= state << 5
            return amplitude * Float(Int32(bitPattern: state)) / Float(Int32.max)
        }
    }

    /// A sawtooth at `hertz`, swinging about ±`amplitude`: every harmonic below 12 kHz, the k-th at
    /// 2/(πk) of `amplitude`.
    private func saw(_ hertz: Double, frames: Int, amplitude: Double = 0.5) -> [Float] {
        let count = Int(12_000 / hertz)
        return (0..<frames).map { (index: Int) -> Float in
            var sum = 0.0
            let phase: Double = 2 * Double.pi * hertz * Double(index) / rate
            for k in 1...Swift.max(1, count) { sum += Foundation.sin(phase * Double(k)) / Double(k) }
            return Float(amplitude * 2 / Double.pi * sum)
        }
    }

    /// `source` through the package's vocal tract at a vowel (0 oo … 0.5 ah … 1 ee, a bass's
    /// formants), brought to a root mean square of `level`.
    private func vowel(_ source: [Float], character: Float = 0.5, level: Float = 0.1) -> [Float] {
        var tract = VocalTract()
        tract.tune(to: Vowel.at(character: character, register: 0), sampleRate: Float(rate))
        let shaped = source.map { (x: Float) -> Float in tract.process(x) }
        let now = rms(shaped[...])
        return shaped.map { (x: Float) -> Float in now > 0 ? x * level / now : 0 }
    }

    /// A whispered "ah" as a spectrum, in decibels at `hertz`: formants at 600, 1 100 and 2 400 Hz,
    /// each a third of an octave wide, over a slope of −6 dB per octave above 250 Hz. No edge in it is
    /// sharper than a band's own skirts, so a band's power reads the same through the vocoder's
    /// filters and through a transform's bins.
    private func whisperedAh(_ hertz: Double) -> Double {
        func formant(_ centre: Double, _ height: Double) -> Double {
            let octaves = Foundation.log2(hertz / centre) / 0.3
            return height * Foundation.exp(-0.5 * octaves * octaves)
        }
        let slope = -6 * Foundation.log2(Swift.max(hertz, 250) / 250)
        return slope + 10 * Foundation.log10(1 + formant(600, 30) + formant(1_100, 15) + formant(2_400, 6))
    }

    /// White noise given the spectrum `decibels` in the frequency domain — one transform, the shape
    /// applied bin by bin, the transform back — brought to a root mean square of `level`.
    private func shapedNoise(_ frames: Int, seed: UInt32, level: Float = 0.1, decibels: (Double) -> Double) -> [Float] {
        var size = 1
        while size < frames { size <<= 1 }
        let transform = FFT(size: size)
        var real = noise(size, seed: seed)
        var imaginary = [Float](repeating: 0, count: size)
        transform.transform(real: &real, imaginary: &imaginary)
        for bin in 0..<size {
            let hertz = Double(Swift.min(bin, size - bin)) * rate / Double(size)
            let gain = Float(Foundation.pow(10, decibels(Swift.max(hertz, 1)) / 20))
            real[bin] *= gain
            imaginary[bin] = -imaginary[bin] * gain
        }
        // The inverse transform: the forward one of the conjugate, conjugated (the result is real).
        transform.transform(real: &real, imaginary: &imaginary)
        let shaped = Array(real.prefix(frames))
        let now = rms(shaped[...])
        return shaped.map { (x: Float) -> Float in now > 0 ? x * level / now : 0 }
    }

    private func sine(_ hertz: Double, frames: Int, amplitude: Float) -> [Float] {
        (0..<frames).map { (index: Int) -> Float in
            amplitude * Float(Foundation.sin(2 * Double.pi * hertz * Double(index) / rate))
        }
    }

    // MARK: Running

    /// The vocoder over `modulator` and `carrier` (the shorter sets the length) in blocks of 256; each
    /// change of settings takes effect between two blocks at its frame.
    private func vocode(_ vocoder: ChannelVocoder, modulator: [Float], carrier: [Float],
                        changes: [(frame: Int, settings: ChannelVocoder.Settings)] = []) -> [Float] {
        let frames = Swift.min(modulator.count, carrier.count)
        var out = [Float](repeating: 0, count: frames)
        var next = 0
        var start = 0
        while start < frames {
            while next < changes.count, changes[next].frame <= start {
                vocoder.settings = changes[next].settings
                next += 1
            }
            var end = Swift.min(start + 256, frames)
            if next < changes.count { end = Swift.min(end, Swift.max(changes[next].frame, start + 1)) }
            let count = end - start
            modulator.withUnsafeBufferPointer { (voice: UnsafeBufferPointer<Float>) in
                carrier.withUnsafeBufferPointer { (tone: UnsafeBufferPointer<Float>) in
                    out.withUnsafeMutableBufferPointer { (result: inout UnsafeMutableBufferPointer<Float>) in
                        if let m = voice.baseAddress, let c = tone.baseAddress, let o = result.baseAddress {
                            vocoder.process(modulator: m + start, carrier: c + start, output: o + start, frames: count)
                        }
                    }
                }
            }
            start = end
        }
        return out
    }

    /// The modulator band levels a vocoder reads after hearing `modulator`, averaged over its last
    /// 2 400 samples, read every 100.
    private func bandLevels(_ vocoder: ChannelVocoder, modulator: [Float]) -> [Float] {
        let silence = [Float](repeating: 0, count: 100)
        let settle = modulator.count - 2_400
        _ = vocode(vocoder, modulator: Array(modulator[..<settle]), carrier: [Float](repeating: 0, count: settle))
        var sums = [Double](repeating: 0, count: ChannelVocoder.bandCounts.upperBound)
        var reads = 0
        var levels = [Float](repeating: 0, count: ChannelVocoder.bandCounts.upperBound)
        var start = settle
        var written = 0
        while start + 100 <= modulator.count {
            _ = vocode(vocoder, modulator: Array(modulator[start..<(start + 100)]), carrier: silence)
            written = levels.withUnsafeMutableBufferPointer { (buffer: inout UnsafeMutableBufferPointer<Float>) -> Int in
                vocoder.readBandLevels(into: buffer)
            }
            for band in 0..<written { sums[band] += Double(levels[band]) }
            reads += 1
            start += 100
        }
        return (0..<written).map { (band: Int) -> Float in Float(sums[band] / Double(Swift.max(reads, 1))) }
    }

    // MARK: Measuring

    private func rms(_ samples: ArraySlice<Float>) -> Float {
        var sum: Double = 0
        for x in samples { sum += Double(x) * Double(x) }
        return Float((sum / Double(Swift.max(1, samples.count))).squareRoot())
    }

    private func maxStep(_ samples: ArraySlice<Float>) -> Float {
        var largest: Float = 0
        var previous = samples.first ?? 0
        for x in samples {
            largest = Swift.max(largest, Swift.abs(x - previous))
            previous = x
        }
        return largest
    }

    /// The power in each range of hertz: Hann-windowed transforms of 8 192 samples, half overlapping,
    /// their bin powers summed over the range and averaged over the windows (Welch).
    private func powers(_ samples: ArraySlice<Float>, ranges: [(low: Double, high: Double)]) -> [Double] {
        let size = 8_192
        let transform = FFT(size: size)
        let window = (0..<size).map { (index: Int) -> Float in
            Float(0.5 - 0.5 * Foundation.cos(2 * Double.pi * Double(index) / Double(size)))
        }
        let values = Array(samples)
        var totals = [Double](repeating: 0, count: ranges.count)
        var segments = 0
        var start = 0
        while start + size <= values.count {
            var real = (0..<size).map { (index: Int) -> Float in values[start + index] * window[index] }
            var imaginary = [Float](repeating: 0, count: size)
            transform.transform(real: &real, imaginary: &imaginary)
            for (index, range) in ranges.enumerated() {
                let first = Swift.max(1, Int((range.low / rate * Double(size)).rounded(.up)))
                let last = Swift.min(size / 2 - 1, Int((range.high / rate * Double(size)).rounded(.down)))
                guard first <= last else { continue }
                for bin in first...last {
                    totals[index] += Double(real[bin] * real[bin] + imaginary[bin] * imaginary[bin])
                }
            }
            segments += 1
            start += size / 2
        }
        return totals.map { (total: Double) -> Double in total / Double(Swift.max(segments, 1)) }
    }

    /// The vocoder's bands as ranges of hertz: each from the geometric middle below its centre to
    /// the one above.
    private func bandRanges(_ count: Int) -> [(low: Double, high: Double)] {
        let centres = ChannelVocoder.bandCentres(bandCount: count)
        let half = Foundation.pow(80, 0.5 / Double(count - 1))
        return centres.map { (centre: Double) -> (low: Double, high: Double) in (centre / half, centre * half) }
    }

    private func decibels(_ values: [Double]) -> [Double] {
        values.map { (power: Double) -> Double in 10 * Foundation.log10(Swift.max(power, 1e-30)) }
    }

    /// How closely two band profiles in decibels rise and fall together, over the bands where the
    /// first lies within 40 dB of its loudest: a band the modulator leaves empty carries nothing to
    /// follow.
    private func agreement(_ a: [Double], _ b: [Double]) -> Double {
        let loudest = a.max() ?? 0
        let kept = zip(a, b).filter { (pair: (Double, Double)) -> Bool in pair.0 > loudest - 40 }
        return pearson(kept.map { (pair: (Double, Double)) -> Double in pair.0 }, kept.map { (pair: (Double, Double)) -> Double in pair.1 })
    }

    private func pearson(_ a: [Double], _ b: [Double]) -> Double {
        let count = Double(Swift.min(a.count, b.count))
        guard count > 1 else { return 0 }
        let meanA = a.reduce(0, +) / count, meanB = b.reduce(0, +) / count
        var shared = 0.0, spreadA = 0.0, spreadB = 0.0
        for (x, y) in zip(a, b) {
            shared += (x - meanA) * (y - meanB)
            spreadA += (x - meanA) * (x - meanA)
            spreadB += (y - meanB) * (y - meanB)
        }
        return shared / Swift.max((spreadA * spreadB).squareRoot(), 1e-30)
    }

    // MARK: The bands

    /// The centres are exact: 100 · 80^(n / (count − 1)) Hz, 100 Hz to 8 kHz, for every band count
    /// from 8 to 32 — and the filters sit there. A sine at a band's centre reads its own level in that
    /// band, the loudest of all; between two neighbours, at the point their warped frequency axis puts
    /// halfway, both read alike, where 2 % to either side of it they do not.
    func testTheBandCentresAreExactHertz() {
        XCTAssertEqual(ChannelVocoder.bandCounts, 8...32)
        for count in [8, 12, 16, 24, 32] {
            let centres = ChannelVocoder.bandCentres(bandCount: count)
            XCTAssertEqual(centres.count, count)
            XCTAssertEqual(centres.first, 100, "\(count) bands")
            XCTAssertEqual(centres.last, 8_000, "\(count) bands")
            for band in 0..<count {
                let exact = 100 * Foundation.pow(80, Double(band) / Double(count - 1))
                XCTAssertEqual(centres[band], exact, accuracy: exact * 1e-12, "\(count) bands, band \(band)")
                XCTAssertEqual(ChannelVocoder.centre(ofBand: band, bandCount: count), centres[band])
            }
        }
        // Sixteen bands lie 80^(1/15) apart, ×1.339 68 or 5.06 semitones: band 5 at 100 · 80^(1/3) Hz.
        XCTAssertEqual(ChannelVocoder.centre(ofBand: 5, bandCount: 16), 430.886_938, accuracy: 1e-5)
        XCTAssertEqual(ChannelVocoder.centre(ofBand: 1, bandCount: 8), 187.012_225, accuracy: 1e-5)   // 100 · 80^(1/7)
        XCTAssertEqual(ChannelVocoder.centre(ofBand: 16, bandCount: 32), 959.930_948, accuracy: 1e-5) // 100 · 80^(16/31)
        XCTAssertEqual(ChannelVocoder.centre(ofBand: -3, bandCount: 16), 100, "outside the grid: its nearest end")
        XCTAssertEqual(ChannelVocoder.centre(ofBand: 40, bandCount: 16), 8_000)
        XCTAssertEqual(ChannelVocoder.bandCentres(bandCount: 2), ChannelVocoder.bandCentres(bandCount: 8), "a count is held to 8 … 32")
        XCTAssertEqual(ChannelVocoder.bandCentres(bandCount: 99), ChannelVocoder.bandCentres(bandCount: 32))

        let settings = ChannelVocoder.Settings(bandCount: 16, attack: 0.05, release: 0.05, sibilance: 0)
        let centres = ChannelVocoder.bandCentres(bandCount: 16)
        for band in [0, 5, 10, 15] {
            let levels = bandLevels(ChannelVocoder(sampleRate: rate, settings: settings),
                                    modulator: sine(centres[band], frames: 24_000, amplitude: 0.5))
            XCTAssertEqual(levels.count, 16)
            let whole = Float(0.5 / 2.0.squareRoot())
            XCTAssertEqual(levels[band], whole, accuracy: whole * 0.012, "band \(band): the whole sine, within 0.1 dB")
            XCTAssertEqual(levels.firstIndex(of: levels.max() ?? 0), band)
        }
        for band in [0, 7, 14] {
            let below = Foundation.tan(Double.pi * centres[band] / rate), above = Foundation.tan(Double.pi * centres[band + 1] / rate)
            let middle = rate / Double.pi * Foundation.atan((below * above).squareRoot())
            func difference(_ hertz: Double) -> Double {
                let levels = bandLevels(ChannelVocoder(sampleRate: rate, settings: settings),
                                        modulator: sine(hertz, frames: 24_000, amplitude: 0.5))
                return 20 * Foundation.log10(Double(levels[band]) / Double(levels[band + 1]))
            }
            XCTAssertEqual(difference(middle), 0, accuracy: 0.05, "bands \(band) and \(band + 1) meet halfway")
            XCTAssertGreaterThan(difference(middle / 1.02), 0.3)
            XCTAssertLessThan(difference(middle * 1.02), -0.3)
        }
    }

    /// The output's bands follow the modulator's: a whispered "ah" on a noise carrier as loud as a
    /// full-scale sine comes out with the band levels it went in with, at every band count — and,
    /// with the attack as long as the release, as loud within 1.5 dB (0.5 to 0.7 dB under, measured:
    /// a follower averages a noise band's amplitude); the default fast attack rides its peaks, about
    /// 2 to 3 dB over. On a sawtooth carrier it follows too, in the bands that hold its harmonics; and
    /// shifted up an octave, the output's bands follow the modulator's an octave lower. (A spectrum
    /// with an edge sharper than a band's skirts — the vocal tract's above its fifth formant — comes
    /// out with the edge softened to them: a band two away lets through about 18 dB less at 16 bands.)
    ///
    /// The voice research's test vector is a voiced "ah" on a sawtooth at 110 Hz, its output's band
    /// powers correlating with the modulator's at r ≥ 0.9. Read so — each band's power by a
    /// transform, against the modulator's alone, over the bands within 40 dB of its loudest — a voiced
    /// "ah" at 150 Hz reaches r = 0.78 at 16 bands and 0.42 at 32 (measured): in bands narrower than
    /// the harmonics' spacing, which harmonic of either signal falls in which band decides more than
    /// the voice does. So the precise check runs on the whisper above, which fills every band, and the
    /// voiced case is read through the vocoder's own bands, as it hears them: the output's band levels
    /// less the carrier's follow the voice's at r ≥ 0.9 at 8 and 16 bands and ≥ 0.8 at 32 (0.995,
    /// 0.933 and 0.872 measured) — the limit of two pitched signals in narrow bands that
    /// `ChannelVocoder` states.
    func testTheOutputBandsFollowTheModulatorsBands() {
        let frames = 72_000
        let whisper = shapedNoise(frames, seed: 7, decibels: whisperedAh)
        let carrier = noise(frames, amplitude: Float(1.5.squareRoot()), seed: 99)
        for count in [8, 16, 32] {
            let vocoder = ChannelVocoder(sampleRate: rate, settings: ChannelVocoder.Settings(bandCount: count, sibilance: 0))
            let out = vocode(vocoder, modulator: whisper, carrier: carrier)
            XCTAssertTrue(out.allSatisfy(\.isFinite))
            let ranges = bandRanges(count)
            let sung = decibels(powers(whisper[24_000...], ranges: ranges))
            let heard = decibels(powers(out[24_000...], ranges: ranges))
            XCTAssertGreaterThan(agreement(sung, heard), 0.97, "\(count) bands: \(sung) \(heard)")
            XCTAssertEqual(Double(20 * log10f(rms(out[24_000...]) / rms(whisper[24_000...]))), 1.5, accuracy: 2,
                           "\(count) bands: the default attack rides the noise a little above its mean")
            let even = ChannelVocoder(sampleRate: rate, settings: ChannelVocoder.Settings(bandCount: count, attack: 0.015, sibilance: 0))
            let level = vocode(even, modulator: whisper, carrier: carrier)
            XCTAssertEqual(Double(20 * log10f(rms(level[24_000...]) / rms(whisper[24_000...]))), 0, accuracy: 1.5,
                           "\(count) bands: the modulator's level")
        }

        let bright = saw(110, frames: frames, amplitude: 1)
        let vocoder = ChannelVocoder(sampleRate: rate, settings: ChannelVocoder.Settings(bandCount: 16, sibilance: 0))
        let out = vocode(vocoder, modulator: whisper, carrier: bright)
        let ranges = bandRanges(16).filter { (range: (low: Double, high: Double)) -> Bool in range.low >= 500 }
        XCTAssertGreaterThan(agreement(decibels(powers(whisper[24_000...], ranges: ranges)), decibels(powers(out[24_000...], ranges: ranges))),
                             0.9)

        let shifted = ChannelVocoder(sampleRate: rate, settings: ChannelVocoder.Settings(bandCount: 16, shift: 12, sibilance: 0))
        let up = vocode(shifted, modulator: whisper, carrier: carrier)
        let below = bandRanges(16).filter { (range: (low: Double, high: Double)) -> Bool in range.high * 2 < 16_000 }
        let above = below.map { (range: (low: Double, high: Double)) -> (low: Double, high: Double) in (range.low * 2, range.high * 2) }
        XCTAssertGreaterThan(agreement(decibels(powers(whisper[24_000...], ranges: below)), decibels(powers(up[24_000...], ranges: above))),
                             0.95)

        // A voiced "ah" at 150 Hz on the sawtooth at 110 Hz, each signal's band levels as a vocoder
        // of that count hears them.
        let voiced = vowel(saw(150, frames: 48_000, amplitude: 1), level: 0.1)
        let pitched = saw(110, frames: 48_000, amplitude: 1)
        for (count, least) in [(8, 0.9), (16, 0.9), (32, 0.8)] {
            let played = vocode(ChannelVocoder(sampleRate: rate, settings: ChannelVocoder.Settings(bandCount: count, sibilance: 0)),
                                modulator: voiced, carrier: pitched)
            XCTAssertTrue(played.allSatisfy(\.isFinite))
            func throughBands(_ signal: [Float]) -> [Double] {
                let listener = ChannelVocoder(sampleRate: rate,
                                              settings: ChannelVocoder.Settings(bandCount: count, attack: 0.015, release: 0.015, sibilance: 0))
                return bandLevels(listener, modulator: signal).map { (level: Float) -> Double in
                    20 * Foundation.log10(Swift.max(Double(level), 1e-15))
                }
            }
            let carried = throughBands(pitched)
            let followed = zip(throughBands(played), carried).map { (pair: (Double, Double)) -> Double in pair.0 - pair.1 }
            XCTAssertGreaterThan(agreement(throughBands(voiced), followed), least, "\(count) bands, voiced")
        }
    }

    /// The followers move in seconds: a tone in one band rises to within 1/e of its level in the
    /// attack's time and, stopped, falls to 1/e of its level in the release's.
    func testTheFollowersRiseAndFallInTheirSeconds() {
        let attack = 0.02, release = 0.08
        let settings = ChannelVocoder.Settings(bandCount: 16, attack: attack, release: release, sibilance: 0)
        let vocoder = ChannelVocoder(sampleRate: rate, settings: settings)
        let centre = ChannelVocoder.centre(ofBand: 10, bandCount: 16)
        let tone = sine(centre, frames: 24_000, amplitude: 0.5)
        var readings: [Float] = []
        var levels = [Float](repeating: 0, count: 32)
        let zeros = [Float](repeating: 0, count: 48)
        for start in stride(from: 0, to: 48_000, by: 48) {
            let piece = start < 24_000 ? Array(tone[start..<(start + 48)]) : zeros
            _ = vocode(vocoder, modulator: piece, carrier: zeros)
            _ = levels.withUnsafeMutableBufferPointer { (buffer: inout UnsafeMutableBufferPointer<Float>) -> Int in
                vocoder.readBandLevels(into: buffer)
            }
            readings.append(levels[10])
        }
        let full = Float(0.5 / 2.0.squareRoot())   // the level of a sine of amplitude 0.5
        let risen = readings.firstIndex { (level: Float) -> Bool in level >= full * (1 - 1 / expf(1)) } ?? 0
        XCTAssertEqual(Double(risen + 1) * 0.001, attack, accuracy: attack * 0.15, "the attack")
        let stop = 24_000 / 48
        let fallen = readings[stop...].firstIndex { (level: Float) -> Bool in level <= full / expf(1) } ?? 0
        XCTAssertEqual(Double(fallen - stop + 1) * 0.001, release, accuracy: release * 0.1, "the release")
    }

    // MARK: Silence

    /// Silence in is silence out, sample for sample: nothing in, nothing out; a carrier alone, however
    /// loud, never sounds; and when the modulator stops, the output falls below −80 dBFS within
    /// 0.2 s and reaches exact silence within half a second, once the filters have rung out (0.18 s
    /// and 0.32 s at 32 bands, measured), the carrier still playing.
    func testSilenceInIsSilenceOut() {
        let frames = 48_000
        let zeros = [Float](repeating: 0, count: frames)
        let carrier = saw(110, frames: frames, amplitude: 1)
        XCTAssertTrue(vocode(ChannelVocoder(sampleRate: rate), modulator: zeros, carrier: zeros).allSatisfy { $0 == 0 })
        XCTAssertTrue(vocode(ChannelVocoder(sampleRate: rate), modulator: zeros, carrier: carrier).allSatisfy { $0 == 0 },
                      "a carrier alone is silent")
        let quiet = ChannelVocoder(sampleRate: rate, settings: ChannelVocoder.Settings(sibilance: 0))
        XCTAssertTrue(vocode(quiet, modulator: noise(frames, amplitude: 0.5), carrier: zeros).allSatisfy { $0 == 0 },
                      "a modulator alone is silent without its sibilance")

        let stop = 24_000, length = 60_000
        let tone = saw(110, frames: length, amplitude: 1)
        for count in [8, 16, 32] {
            let vocoder = ChannelVocoder(sampleRate: rate, settings: ChannelVocoder.Settings(bandCount: count))
            var voice = vowel(noise(length, amplitude: 1, seed: 3), level: 0.3)
            for index in stop..<length { voice[index] = 0 }
            let out = vocode(vocoder, modulator: voice, carrier: tone)
            XCTAssertGreaterThan(rms(out[12_000..<stop]), 0.01, "\(count) bands")
            let loud = out[stop...].lastIndex { (x: Float) -> Bool in Swift.abs(x) >= 1e-4 } ?? stop
            XCTAssertLessThan(Double(loud - stop) / rate, 0.2, "\(count) bands: below −80 dBFS")
            let sounding = out[stop...].lastIndex { (x: Float) -> Bool in x != 0 } ?? stop
            XCTAssertLessThan(Double(sounding - stop) / rate, 0.5, "\(count) bands: exact silence after the tail")
        }
    }

    /// A sample that is not a number, in the modulator or the carrier, is silence and empties the
    /// vocoder; it goes on vocoding after it, finite throughout.
    func testABadSampleIsSilenceAndEmptiesTheVocoder() {
        let frames = 24_000
        let voice = vowel(noise(frames, amplitude: 1, seed: 5))
        let carrier = noise(frames, amplitude: 1, seed: 6)
        let clean = vocode(ChannelVocoder(sampleRate: rate), modulator: voice, carrier: carrier)
        for bad: Float in [.nan, .infinity, -.infinity] {
            for inCarrier in [false, true] {
                var modulator = voice, tones = carrier
                if inCarrier { tones[4_000] = bad } else { modulator[4_000] = bad }
                let out = vocode(ChannelVocoder(sampleRate: rate), modulator: modulator, carrier: tones)
                XCTAssertTrue(out.allSatisfy(\.isFinite), "\(bad)")
                XCTAssertEqual(out[4_000], 0)
                XCTAssertEqual(Double(rms(out[12_000...])), Double(rms(clean[12_000...])), accuracy: Double(rms(clean[12_000...])) * 0.1,
                               "it vocodes again after it")
            }
        }
    }

    // MARK: Band count

    /// Changing the band count while a voice sings crosses over to the new bands: no step at the
    /// change exceeds the steps the vocoder makes on its own at either count, the level stays where
    /// it was, and the new count is the one heard once the crossing is done. On a whispered vowel
    /// and a noise carrier, where the two layouts' outputs share nothing (correlation under 0.06,
    /// measured), the crossing shows its two parts: for `warmSeconds` the old bands play alone,
    /// sample for sample, while the new ones settle unheard; then, in the middle third of the fade,
    /// the level is the mean power of the two counts within 1 dB (0.25 dB at most measured) — a
    /// straight-line crossing would lose 2.9 dB there.
    func testChangingTheBandCountDoesNotClick() {
        let frames = 57_600
        let voice = vowel(saw(150, frames: frames, amplitude: 1), level: 0.2)
        let carrier = saw(110, frames: frames, amplitude: 1)
        // At each count alone: its largest step, and the quietest and the loudest 20 ms it plays.
        var steps: [Int: Float] = [:]
        var levels: [Int: (quietest: Float, loudest: Float)] = [:]
        let alone = 36_000
        for count in [8, 16, 24, 32] {
            let out = vocode(ChannelVocoder(sampleRate: rate, settings: ChannelVocoder.Settings(bandCount: count)),
                             modulator: Array(voice[..<alone]), carrier: Array(carrier[..<alone]))
            steps[count] = maxStep(out[12_000...])
            let windows = stride(from: 12_000, to: alone - 960, by: 240).map { (start: Int) -> Float in
                rms(out[start..<(start + 960)])
            }
            levels[count] = (windows.min() ?? 0, windows.max() ?? 0)
        }
        let vocoder = ChannelVocoder(sampleRate: rate, settings: ChannelVocoder.Settings(bandCount: 16))
        let changes: [(frame: Int, settings: ChannelVocoder.Settings)] = [
            (14_400, ChannelVocoder.Settings(bandCount: 32)),
            (28_800, ChannelVocoder.Settings(bandCount: 8)),
            (43_200, ChannelVocoder.Settings(bandCount: 24)),
        ]
        let out = vocode(vocoder, modulator: voice, carrier: carrier, changes: changes)
        XCTAssertTrue(out.allSatisfy(\.isFinite))
        XCTAssertEqual(vocoder.bandCount, 24)
        for (index, change) in [(16, 32), (32, 8), (8, 24)].enumerated() {
            let at = changes[index].frame
            let limit = Swift.max(steps[change.0] ?? 0, steps[change.1] ?? 0) * 1.1
            XCTAssertLessThanOrEqual(maxStep(out[(at - 480)..<(at + 4_800)]), limit, "\(change.0) to \(change.1) bands")
            let before = levels[change.0] ?? (0, 1), after = levels[change.1] ?? (0, 1)
            for start in stride(from: at - 480, to: at + 4_800, by: 240) {
                let level = rms(out[start..<(start + 960)])
                XCTAssertGreaterThan(level, Swift.min(before.quietest, after.quietest) * 0.8, "\(change.0) to \(change.1) bands at \(start)")
                XCTAssertLessThan(level, Swift.max(before.loudest, after.loudest) * 1.2, "\(change.0) to \(change.1) bands at \(start)")
            }
        }

        let whisper = vowel(noise(frames, amplitude: 1, seed: 3), level: 0.2)
        let hiss = noise(frames, amplitude: 1, seed: 4)
        let at = 14_400
        let warm = Int((ChannelVocoder.warmSeconds * rate).rounded()), fade = Int((ChannelVocoder.fadeSeconds * rate).rounded())
        for (from, to) in [(16, 32), (32, 8)] {
            let old = vocode(ChannelVocoder(sampleRate: rate, settings: ChannelVocoder.Settings(bandCount: from)), modulator: whisper, carrier: hiss)
            let new = vocode(ChannelVocoder(sampleRate: rate, settings: ChannelVocoder.Settings(bandCount: to)), modulator: whisper, carrier: hiss)
            let crossing = vocode(ChannelVocoder(sampleRate: rate, settings: ChannelVocoder.Settings(bandCount: from)),
                                  modulator: whisper, carrier: hiss, changes: [(at, ChannelVocoder.Settings(bandCount: to))])
            XCTAssertTrue(crossing.allSatisfy(\.isFinite))
            XCTAssertEqual(Array(crossing[..<(at + warm)]), Array(old[..<(at + warm)]),
                           "\(from) to \(to) bands: the old bands alone while the new ones settle")
            let middle = (at + warm + fade / 3)..<(at + warm + 2 * fade / 3)
            let leaving = Double(rms(old[middle])), arriving = Double(rms(new[middle]))
            let mean = ((leaving * leaving + arriving * arriving) / 2).squareRoot()
            XCTAssertEqual(20 * Foundation.log10(Double(rms(crossing[middle])) / mean), 0, accuracy: 1,
                           "\(from) to \(to) bands: equal power in the middle of the crossing")
        }
    }

    // MARK: Sibilance

    /// The modulator's highs above the crossover pass at the sibilance level whatever the carrier
    /// holds, so an "s" stays an "s"; below the crossover they do not, and at sibilance 0 nothing does.
    func testSibilantsPassAboveTheCrossover() {
        let frames = 48_000
        let hiss = noise(frames, amplitude: 0.3, seed: 11)
        let silent = [Float](repeating: 0, count: frames)
        let high = [(low: 12_000.0, high: 20_000.0)], low = [(low: 1_000.0, high: 3_000.0)]
        let hissHigh = powers(hiss[4_800...], ranges: high)[0], hissLow = powers(hiss[4_800...], ranges: low)[0]
        for (level, expected) in [(1.0, 0.0), (0.5, -6.02)] {
            let vocoder = ChannelVocoder(sampleRate: rate, settings: ChannelVocoder.Settings(sibilance: level, crossover: 6_000))
            let out = vocode(vocoder, modulator: hiss, carrier: silent)
            XCTAssertTrue(out.allSatisfy(\.isFinite))
            XCTAssertEqual(10 * Foundation.log10(powers(out[4_800...], ranges: high)[0] / hissHigh), expected, accuracy: 1,
                           "sibilance \(level) above the crossover")
            XCTAssertLessThan(10 * Foundation.log10(powers(out[4_800...], ranges: low)[0] / hissLow), -30,
                              "sibilance \(level) below the crossover")
        }
        // A lower crossover lets more of the hiss through: from 3 kHz, the band 6 … 8 kHz passes.
        let lower = ChannelVocoder(sampleRate: rate, settings: ChannelVocoder.Settings(sibilance: 1, crossover: 3_000))
        let middle = [(low: 6_000.0, high: 8_000.0)]
        let passed = powers(vocode(lower, modulator: hiss, carrier: silent)[4_800...], ranges: middle)[0]
        XCTAssertEqual(10 * Foundation.log10(passed / powers(hiss[4_800...], ranges: middle)[0]), 0, accuracy: 1)
        let off = ChannelVocoder(sampleRate: rate, settings: ChannelVocoder.Settings(sibilance: 0))
        XCTAssertTrue(vocode(off, modulator: hiss, carrier: silent).allSatisfy { $0 == 0 })
    }
}
