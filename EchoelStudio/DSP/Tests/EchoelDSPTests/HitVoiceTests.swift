import XCTest
@testable import EchoelDSP

/// The hit voice plays a sound that is numbers. These tests hold the sound's shape in numbers too:
/// what the ruler (`SoundRuler`) reads from it, as the mean over eight hits of one voice — one hit
/// of noise is one draw, and its readings move with the draw.
final class HitVoiceTests: XCTestCase {
    private let rate: Float = 48_000

    private func render(_ voice: inout HitVoice, seconds: Float, block: Int = 256) -> [Float] {
        var buffer = [Float](repeating: 0, count: Int(seconds * rate))
        var start = 0
        while start < buffer.count {
            let end = Swift.min(start + block, buffer.count)
            buffer[start..<end].withUnsafeMutableBufferPointer { voice.render(into: $0) }
            start = end
        }
        return buffer
    }

    private func hit(_ sound: HitSound, velocity: UInt8 = 100, seconds: Float = 1.2, block: Int = 256) -> [Float] {
        var voice = HitVoice(sampleRate: rate)
        voice.trigger(sound, velocity: velocity)
        return render(&voice, seconds: seconds, block: block)
    }

    /// The mean reading of eight hits of one voice, each from silence.
    private func reading(of sound: HitSound, file: StaticString = #filePath, line: UInt = #line) -> SoundRuler.Reading {
        var voice = HitVoice(sampleRate: rate)
        var readings: [SoundRuler.Reading] = []
        for _ in 0..<8 {
            voice.trigger(sound, velocity: 100)
            let samples = render(&voice, seconds: 1.2)
            XCTAssertFalse(voice.isActive, "a hit is over before the next one", file: file, line: line)
            if let one = SoundRuler.measure(samples) { readings.append(one) }
        }
        XCTAssertEqual(readings.count, 8, "every hit sounds", file: file, line: line)
        return SoundRuler.mean(readings)
    }

    private func rms(_ samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        var sum = 0.0
        for sample in samples { sum += Double(sample) * Double(sample) }
        return (sum / Double(samples.count)).squareRoot()
    }

    /// The kit's noise, for signals with a known answer.
    private struct Noise {
        var state: UInt32 = 0x9E37_79B9
        mutating func next() -> Float {
            state ^= state << 13
            state ^= state >> 17
            state ^= state << 5
            return Float(state) / Float(UInt32.max) * 2 - 1
        }
    }

    private func changed(_ change: (inout HitSound) -> Void) -> HitSound {
        var sound = HitSound.clap
        change(&sound)
        return sound
    }

    // MARK: - The ruler, on signals whose answer is known

    /// A level that falls to 1/e in 10 ms is 20 dB down after 23.0 ms and 40 dB after 46.1 ms.
    func testTheRulerReadsAKnownDecay() throws {
        let samples: [Float] = (0..<14_400).map { (frame: Int) -> Float in
            let time = Float(frame) / 48_000
            return sinf(2 * Float.pi * 1_000 * time) * expf(-time / 0.010)
        }
        let read = try XCTUnwrap(SoundRuler.measure(samples))
        XCTAssertEqual(read.fall20, 23.0, accuracy: 2)
        XCTAssertEqual(read.fall40, 46.1, accuracy: 2)
        XCTAssertEqual(read.bursts, 1)
        XCTAssertEqual(read.crossingsEarly, 1_000, accuracy: 60, "a 1 kHz sine crosses a thousand times a second")
    }

    func testTheRulerCountsBurstsAndReadsARise() throws {
        var noise = Noise()
        var gated = [Float](repeating: 0, count: 9_600)
        for start in [0, 576, 1_152] {
            for frame in start..<(start + 240) { gated[frame] = noise.next() }
        }
        XCTAssertEqual(try XCTUnwrap(SoundRuler.measure(gated)).bursts, 3, "5 ms of noise at 0, 12 and 24 ms")

        var source = Noise()
        let rising: [Float] = (0..<14_400).map { (frame: Int) -> Float in
            let time = Float(frame) / 48_000
            let level: Float = time < 0.015 ? time / 0.015 : expf(-(time - 0.015) / 0.05)
            return source.next() * level
        }
        XCTAssertEqual(try XCTUnwrap(SoundRuler.measure(rising)).attack, 15, accuracy: 4, "a 15 ms rise")
    }

    func testTheRulerReadsNothingFromSilence() {
        XCTAssertNil(SoundRuler.measure([Float](repeating: 0, count: 4_800)))
        XCTAssertNil(SoundRuler.measure([]))
    }

    // MARK: - The clap

    /// The clap's shape: two bursts, 20 dB down some 55 ms after its peak and 40 dB after some
    /// 150 ms, a third of a second long, and darker as it rings out.
    func testTheClapHasItsShape() {
        let clap = reading(of: .clap)
        XCTAssertEqual(clap.bursts, 2, accuracy: 0.13)
        XCTAssertEqual(clap.attack, 13, accuracy: 5)
        XCTAssertEqual(clap.fall20, 55, accuracy: 10)
        XCTAssertEqual(clap.fall40, 149, accuracy: 25)
        XCTAssertEqual(clap.seconds, 0.31, accuracy: 0.06)
        XCTAssertEqual(clap.crossingsEarly, 2_730, accuracy: 450)
        XCTAssertEqual(clap.crossingsLate, 2_010, accuracy: 330)
        XCTAssertLessThan(clap.crossingsLate, clap.crossingsEarly * 0.85, "it gets darker")
    }

    /// The check can fail: the classic kit's clap, measured the same way, rings several times as long.
    func testTheClassicKitsClapRingsSeveralTimesAsLong() {
        var kit = DrumKit(sampleRate: rate)
        var readings: [SoundRuler.Reading] = []
        for _ in 0..<8 {
            kit.noteOn(pitch: 39, velocity: 100)
            var buffer = [Float](repeating: 0, count: 57_600)
            buffer.withUnsafeMutableBufferPointer { kit.render(into: $0) }
            if let one = SoundRuler.measure(buffer) { readings.append(one) }
        }
        XCTAssertEqual(readings.count, 8)
        let classic = SoundRuler.mean(readings)
        let clap = reading(of: .clap)
        XCTAssertGreaterThan(classic.fall20, clap.fall20 * 3)
        XCTAssertGreaterThan(classic.seconds, clap.seconds * 2)
    }

    /// The first hit of a fresh voice at velocity 100, as it measured when the sound was set
    /// (tolerant of the last digits a platform's `expf`/`tanf` may round differently). A change
    /// to the voice that moves this is a change of the sound.
    func testTheClapsLevelIsHeld() {
        let first = Array(hit(.clap).prefix(19_200))
        XCTAssertEqual(rms(first), 0.021964, accuracy: 0.021964 * 0.01)
        let peak = first.reduce(Float(0)) { Swift.max($0, Swift.abs($1)) }
        XCTAssertEqual(peak, 0.29, accuracy: 0.03)
    }

    // MARK: - Each number moves its own trait

    func testTheNumberOfBurstsIsTheNumberMeasured() {
        for count in 1...4 {
            let measured = reading(of: changed { $0.bursts = count })
            XCTAssertEqual(measured.bursts, Double(count), accuracy: 0.3, "\(count) bursts")
        }
    }

    func testSnapMovesTheStrikeAndTailMovesTheRing() {
        let clap = reading(of: .clap)
        let longStrike = reading(of: changed { $0.snap = 0.044 })
        XCTAssertGreaterThan(longStrike.fall20, clap.fall20 * 1.4, "snap doubled")
        let longRing = reading(of: changed { $0.tail = 0.12 })
        XCTAssertGreaterThan(longRing.fall40, clap.fall40 * 1.6, "tail doubled")
        XCTAssertGreaterThan(longRing.seconds, clap.seconds * 1.5)
        XCTAssertLessThan(longRing.fall20, clap.fall20 * 1.4, "the ring leaves the strike alone")
        let noRing = reading(of: changed { $0.tailLevel = 0 })
        XCTAssertLessThan(noRing.seconds, clap.seconds * 0.7, "without its ring a hit is over sooner")
    }

    func testAttackIsTheRiseOfABurst() {
        let sharp = reading(of: changed { $0.bursts = 1 })
        XCTAssertLessThan(sharp.attack, 4, "1 ms")
        let soft = reading(of: changed { $0.bursts = 1; $0.attack = 0.02 })
        XCTAssertEqual(soft.attack, 17, accuracy: 6, "20 ms")
    }

    func testBandFocusAirAndDarkMoveTheBrightness() {
        let low = reading(of: changed { $0.band = 800 })
        let high = reading(of: changed { $0.band = 2_000 })
        XCTAssertGreaterThan(high.crossingsEarly, low.crossingsEarly * 1.3, "a higher band is brighter")

        let wide = reading(of: changed { $0.focus = 0.1 })
        let narrow = reading(of: changed { $0.focus = 0.9 })
        XCTAssertLessThan(narrow.crossingsEarly, wide.crossingsEarly * 0.75, "a narrow band lets less of the top through")

        let dry = reading(of: changed { $0.air = 0 })
        let airy = reading(of: changed { $0.air = 1 })
        XCTAssertGreaterThan(airy.crossingsEarly, dry.crossingsEarly * 2, "air brightens the strike")
        XCTAssertEqual(airy.crossingsLate, dry.crossingsLate, accuracy: dry.crossingsLate * 0.05, "and is gone when the hit rings out")

        let same = reading(of: changed { $0.dark = 0 })
        let darker = reading(of: changed { $0.dark = 1 })
        XCTAssertLessThan(darker.crossingsLate, same.crossingsLate * 0.8, "a dark ring is duller late")
    }

    /// Band and focus move the colour, not the loudness. Unlevelled, a narrow band at the top
    /// played close to ten times as loud as the clap, and a wide low one a quarter as loud.
    func testBandAndFocusLeaveTheLoudnessAboutWhereItWas() {
        let reference = rms(Array(hit(changed { $0.air = 0 }).prefix(19_200)))
        XCTAssertGreaterThan(reference, 0.01)
        for band: Float in [200, 800, 3_000, 12_000] {
            for focus: Float in [0, 0.45, 0.95] {
                let sound = changed { $0.air = 0; $0.band = band; $0.focus = focus }
                let level = rms(Array(hit(sound).prefix(19_200))) / reference
                XCTAssertGreaterThan(level, 0.6, "band \(band), focus \(focus)")
                XCTAssertLessThan(level, 1.8, "band \(band), focus \(focus)")
            }
        }
    }

    // MARK: - The voice

    func testVelocityIsLoudnessAndNothingElse() throws {
        let soft = hit(.clap, velocity: 64)
        let hard = hit(.clap, velocity: 127)
        let law = (64.0 / 127.0) * (64.0 / 127.0)
        XCTAssertEqual(rms(soft) / rms(hard), law, accuracy: law * 1e-4)
        // The same shape at every loudness: the ruler reads levels against the hit's own peak.
        let softReading = try XCTUnwrap(SoundRuler.measure(soft))
        let hardReading = try XCTUnwrap(SoundRuler.measure(hard))
        XCTAssertEqual(softReading.bursts, hardReading.bursts)
        XCTAssertEqual(softReading.fall20, hardReading.fall20, accuracy: 1)
        XCTAssertEqual(softReading.fall40, hardReading.fall40, accuracy: 1)
        XCTAssertEqual(softReading.crossingsEarly, hardReading.crossingsEarly, accuracy: 50)

        var voice = HitVoice(sampleRate: rate)
        voice.trigger(.clap, velocity: 0)
        XCTAssertFalse(voice.isActive, "velocity 0 is no hit")
        XCTAssertTrue(render(&voice, seconds: 0.1).allSatisfy { $0 == 0 })
    }

    func testAHitIsTheSameSamplesInBlocksOfAnySize() {
        let reference = hit(.clap, block: 256)
        XCTAssertEqual(hit(.clap, block: 64), reference)
        XCTAssertEqual(hit(.clap, block: 4_096), reference)
        XCTAssertEqual(hit(.clap, block: 1), reference)
    }

    func testAHitEndsAndLeavesSilence() {
        var voice = HitVoice(sampleRate: rate)
        voice.trigger(.clap, velocity: 127)
        XCTAssertTrue(voice.isActive)
        let sounding = render(&voice, seconds: 1.2)
        XCTAssertGreaterThan(rms(Array(sounding.prefix(4_800))), 0.01)
        XCTAssertFalse(voice.isActive, "never stopped")
        XCTAssertTrue(render(&voice, seconds: 0.1).allSatisfy { $0 == 0 })
    }

    /// No two hits draw the same noise, and every hit of one voice has the same shape.
    func testTwoHitsAreNeverTheSameSamples() {
        var voice = HitVoice(sampleRate: rate)
        voice.trigger(.clap, velocity: 100)
        let first = render(&voice, seconds: 1.2)
        voice.trigger(.clap, velocity: 100)
        let second = render(&voice, seconds: 1.2)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(SoundRuler.measure(first)?.bursts, 2)
        XCTAssertEqual(SoundRuler.measure(second)?.bursts, 2)
    }

    /// A hit on a voice that still rings rises from where the voice stands: it stays bounded and ends.
    func testAHitOnARingingVoiceRingsOnAndEnds() {
        var voice = HitVoice(sampleRate: rate)
        voice.trigger(.clap, velocity: 127)
        var played = render(&voice, seconds: 0.02)
        for _ in 0..<12 {
            voice.trigger(.clap, velocity: 127)
            played += render(&voice, seconds: 0.03)
        }
        played += render(&voice, seconds: 1.2)
        XCTAssertTrue(played.allSatisfy(\.isFinite))
        XCTAssertLessThan(played.reduce(Float(0)) { Swift.max($0, Swift.abs($1)) }, 1)
        XCTAssertFalse(voice.isActive)
    }

    func testNumbersOutsideTheirRangeStillPlay() {
        let wild = HitSound(bursts: 99, gap: .nan, attack: -.infinity, snap: .infinity, tail: -3, tailLevel: 7, dark: .nan,
                            band: 1e9, focus: 5, air: -1, airTime: .nan, level: .infinity)
        let samples = hit(wild, velocity: 127, seconds: 4)
        XCTAssertTrue(samples.allSatisfy(\.isFinite))
        XCTAssertGreaterThan(rms(samples), 0)
        XCTAssertLessThan(samples.reduce(Float(0)) { Swift.max($0, Swift.abs($1)) }, 1)
        XCTAssertEqual(wild.playable.bursts, 4)
        XCTAssertEqual(HitSound.clap.playable, HitSound.clap, "the clap is inside every range")

        for bad: Float in [.nan, .infinity, 0, -44_100, 1e12] {
            var voice = HitVoice(sampleRate: bad)
            voice.trigger(.clap, velocity: 100)
            var buffer = [Float](repeating: 0, count: 57_600)
            buffer.withUnsafeMutableBufferPointer { voice.render(into: $0) }
            XCTAssertEqual(buffer, hit(.clap), "a sample rate of \(bad) plays at 48 kHz")
        }
    }

    // MARK: - The filter step the voice plays through

    func testOneFilterStepGivesTheBandAndTheLowOfTwoFilters() {
        var both = SVFilter(mode: .notch, cutoff: 1_500, resonance: 0.45, sampleRate: rate)
        var band = SVFilter(mode: .bandpass, cutoff: 1_500, resonance: 0.45, sampleRate: rate)
        var low = SVFilter(mode: .lowpass, cutoff: 1_500, resonance: 0.45, sampleRate: rate)
        var noise = Noise()
        for _ in 0..<4_800 {
            let input = noise.next()
            let pair = both.processBandAndLow(input)
            XCTAssertEqual(pair.band, band.process(input))
            XCTAssertEqual(pair.low, low.process(input))
        }
    }
}
