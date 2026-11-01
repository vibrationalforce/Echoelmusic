import EchoelDSP
import XCTest

/// The measuring device itself, before anything is measured with it: it finds a step of any size
/// worth hearing where it is, and none in music that has no step — a sine, a band-limited saw,
/// noise, a swell and a fade.
final class ClickDetectorTests: XCTestCase {
    private func sine(_ frequency: Double, amplitude: Float = 0.5, count: Int = 48_000) -> [Float] {
        (0..<count).map { (i: Int) -> Float in
            amplitude * Float(sin(2 * Double.pi * frequency * Double(i) / 48_000))
        }
    }

    func testASineHasNoClickAndAStepInItIsFoundWhereItIs() {
        let detector = ClickDetector()
        for frequency in [30.0, 220, 1_000, 8_000] {
            XCTAssertEqual(detector.clicks(in: sine(frequency)), [], "\(frequency) Hz")
        }
        var stepped = sine(220)
        for i in 20_000..<stepped.count { stepped[i] += 0.02 }
        let found = detector.clicks(in: stepped)
        XCTAssertEqual(found.map(\.index), [20_000])
    }

    func testAJumpInPhaseIsAClick() {
        // A sine whose phase jumps by a quarter turn where it crosses zero: from 0 to its peak.
        var bent = sine(220, count: 24_000)
        let quarterTurn = Double.pi / 2
        let step: Double = 2 * Double.pi * 220 / 48_000
        for i in 24_000..<48_000 {
            let angle: Double = step * Double(i) + quarterTurn
            bent.append(0.5 * Float(sin(angle)))
        }
        XCTAssertFalse(ClickDetector().clicks(in: bent).isEmpty)
    }

    func testABandLimitedSawNoiseASwellAndAFadeHaveNoClick() {
        var oscillator = Oscillator(waveform: .saw)
        let saw = (0..<48_000).map { (_: Int) -> Float in 0.5 * oscillator.next(increment: 55 / 48_000) }
        XCTAssertEqual(ClickDetector().clicks(in: saw), [], "a saw's reset is its own edge, every period")

        var state: UInt32 = 0x1234_5678
        let noise = (0..<48_000).map { (_: Int) -> Float in
            state ^= state << 13
            state ^= state >> 17
            state ^= state << 5
            return Float(Int32(bitPattern: state)) / Float(Int32.max) * 0.3
        }
        XCTAssertEqual(ClickDetector().clicks(in: noise), [])

        let tone = sine(440, count: 48_000)
        let swell = tone.enumerated().map { (i: Int, x: Float) -> Float in x * Float(i) / 48_000 }
        XCTAssertEqual(ClickDetector().clicks(in: swell), [])
        let fade = tone.enumerated().map { (i: Int, x: Float) -> Float in x * Float(48_000 - i) / 48_000 }
        XCTAssertEqual(ClickDetector().clicks(in: fade), [])
    }

    /// The classic crackle: a small step at every 256-sample block. Among each other they hide;
    /// against what a sine can carry, every one stands out.
    func testAStepAtEveryBlockIsFoundInSmoothMaterial() {
        var tone = sine(440, count: 24_000)
        for block in 1..<(24_000 / 256) {
            for i in (block * 256)..<tone.count { tone[i] += block % 2 == 0 ? 0.01 : -0.01 }
        }
        XCTAssertEqual(ClickDetector.forSine(hertz: 440, amplitude: 0.5).clicks(in: tone).count, 24_000 / 256 - 1)
        XCTAssertEqual(ClickDetector.forSine(hertz: 440, amplitude: 0.5).clicks(in: sine(440, count: 24_000)), [])
    }

    func testASoundThatStartsWithAStepFromSilenceIsAClick() {
        let start = [Float](repeating: 0, count: 10_000) + sine(220, count: 20_000).map { $0 + 0.3 }
        XCTAssertEqual(ClickDetector().clicks(in: start).map(\.index), [10_000])
    }

    /// A millisecond's linear fade on a full-level tone — the envelopes' shortest segment, the
    /// regions' edges — is no click; a fade over four samples is.
    func testAMillisecondFadeIsNoClickAndAFourSampleFadeIs() {
        let tone = sine(220, count: 24_000)
        func faded(over frames: Int) -> [Float] {
            [Float](repeating: 0, count: 2_400) + tone.enumerated().map { (i: Int, x: Float) -> Float in
                x * Swift.min(1, Float(i + 1) / Float(frames))
            }
        }
        XCTAssertEqual(ClickDetector().clicks(in: faded(over: 64)), [])
        XCTAssertEqual(ClickDetector().clicks(in: faded(over: 48)), [])
        // A cosine starts at its peak: four samples take it from silence to full level.
        let peak = (0..<24_000).map { (i: Int) -> Float in Float(0.5 * cos(2 * Double.pi * 220 * Double(i) / 48_000)) }
        let abrupt = [Float](repeating: 0, count: 2_400) + peak.enumerated().map { (i: Int, x: Float) -> Float in
            x * Swift.min(1, Float(i + 1) / 4)
        }
        XCTAssertFalse(ClickDetector.forSine(hertz: 220, amplitude: 0.5).clicks(in: abrupt).isEmpty)
    }
}
