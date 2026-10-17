import XCTest
@testable import EchoelDSP

final class SVFilterTests: XCTestCase {
    private let rate: Float = 48_000

    /// RMS of a filtered sine after the filter has settled.
    private func rms(_ filter: inout SVFilter, hz: Float) -> Float {
        var sum: Float = 0
        let n = 9_600
        for i in 0..<(2 * n) {
            let x = sinf(2 * .pi * hz * Float(i) / rate)
            let y = filter.process(x)
            if i >= n { sum += y * y }
        }
        return (sum / Float(n)).squareRoot()
    }

    func testLowpassPassesTheBandAndCutsAboveTheCutoff() {
        var low = SVFilter(mode: .lowpass, cutoff: 1_000, resonance: 0.3, sampleRate: rate)
        let pass = rms(&low, hz: 100)
        low.reset()
        let stop = rms(&low, hz: 10_000)
        XCTAssertGreaterThan(pass, 0.6)          // a sine's RMS is 0.707
        XCTAssertLessThan(stop, pass * 0.05)     // two-pole: roughly −40 dB a decade
    }

    func testHighpassIsTheMirror() {
        var high = SVFilter(mode: .highpass, cutoff: 1_000, resonance: 0.3, sampleRate: rate)
        let stop = rms(&high, hz: 100)
        high.reset()
        let pass = rms(&high, hz: 10_000)
        XCTAssertGreaterThan(pass, 0.6)
        XCTAssertLessThan(stop, pass * 0.05)
    }

    func testCutoffsUpToNyquistStayStable() {
        // The Chamberlin form this replaces whined above SR/6; TPT must not.
        for hz: Float in [8_000, 16_000, 23_000, 30_000, .infinity, .nan, -5] {
            var f = SVFilter(mode: .lowpass, cutoff: 0, resonance: 0.95, sampleRate: rate)
            f.setCutoff(hz)
            var peak: Float = 0
            for i in 0..<48_000 {
                let y = f.process(i % 100 == 0 ? 1 : 0)
                XCTAssertTrue(y.isFinite, "\(hz)")
                peak = Swift.max(peak, Swift.abs(y))
            }
            XCTAssertLessThan(peak, 20, "\(hz)")
        }
    }

    func testANonFiniteInputHealsOnTheNextSample() {
        var f = SVFilter(sampleRate: rate)
        _ = f.process(.nan)
        var last: Float = .nan
        for _ in 0..<10 { last = f.process(0.5) }
        XCTAssertTrue(last.isFinite)
    }

    func testLowpassDoesNotHoldDCAtTheFloor() {
        var f = SVFilter(mode: .lowpass, cutoff: 0, resonance: 0.3, sampleRate: rate)
        for _ in 0..<1_000 { _ = f.process(1) }
        var y: Float = 1
        for _ in 0..<(48_000 * 3) { y = f.process(0) }
        XCTAssertLessThan(Swift.abs(y), 0.01)
    }
}

final class OscillatorTests: XCTestCase {
    private let rate: Float = 48_000

    private func crossings(_ waveform: Oscillator.Waveform, hz: Float, seconds: Float = 1) -> Int {
        var osc = Oscillator(waveform: waveform, phase: 0.25)
        let dt = hz / rate
        var previous = osc.next(increment: dt)
        var count = 0
        for _ in 1..<Int(rate * seconds) {
            let x = osc.next(increment: dt)
            if previous < 0, x >= 0 { count += 1 }
            previous = x
        }
        return count
    }

    func testEveryWaveformCompletesOneCyclePerPeriod() {
        for waveform in Oscillator.Waveform.allCases {
            let n = crossings(waveform, hz: 440)
            XCTAssertTrue((438...442).contains(n), "\(waveform): \(n)")
        }
    }

    func testOutputStaysBoundedAcrossTheKeyboard() {
        for waveform in Oscillator.Waveform.allCases {
            for midi in stride(from: 0, through: 127, by: 7) {
                let hz = 440 * powf(2, Float(midi - 69) / 12)
                var osc = Oscillator(waveform: waveform)
                for _ in 0..<4_800 {
                    let x = osc.next(increment: hz / rate)
                    XCTAssertTrue(x.isFinite)
                    XCTAssertLessThanOrEqual(Swift.abs(x), 1.2, "\(waveform) at MIDI \(midi)")
                }
            }
        }
    }

    func testANonsenseIncrementIsSilenceNotGarbage() {
        var osc = Oscillator(waveform: .saw)
        for dt: Float in [.nan, .infinity, -0.1, 0, 0.5, 2] {
            XCTAssertEqual(osc.next(increment: dt), 0, "\(dt)")
        }
        XCTAssertEqual(osc.phase, 0)
    }

    func testPolyBLEPIsZeroAwayFromTheEdge() {
        XCTAssertEqual(Oscillator.polyBLEP(0.5, 0.01), 0)
        XCTAssertEqual(Oscillator.polyBLEP(0, 0.01), -1, accuracy: 1e-6)
        XCTAssertEqual(Oscillator.polyBLEP(0.999_999, 0.01), 1, accuracy: 1e-3)
    }
}

final class EnvelopeTests: XCTestCase {
    private let rate: Float = 48_000

    private func run(_ env: inout Envelope, seconds: Float) -> Float {
        var last: Float = 0
        for _ in 0..<Int(seconds * rate) { last = env.next() }
        return last
    }

    func testAttackReachesThePeakOnTimeThenDecaysToSustain() {
        var env = Envelope(settings: .init(attack: 0.010, decay: 0.050, sustain: 0.5, release: 0.1), sampleRate: rate)
        env.gateOn()
        var samplesToPeak = 0
        while env.stage == .attack, samplesToPeak < 10_000 { _ = env.next(); samplesToPeak += 1 }
        XCTAssertEqual(Float(samplesToPeak) / rate, 0.010, accuracy: 0.001)
        XCTAssertEqual(run(&env, seconds: 0.2), 0.5, accuracy: 1e-3)
        XCTAssertEqual(env.stage, .sustain)
    }

    func testReleaseEndsInSilenceAndIdle() {
        var env = Envelope(settings: .init(attack: 0.001, decay: 0.01, sustain: 0.8, release: 0.05), sampleRate: rate)
        env.gateOn()
        _ = run(&env, seconds: 0.1)
        env.gateOff()
        XCTAssertEqual(env.stage, .release)
        XCTAssertEqual(run(&env, seconds: 0.1), 0)
        XCTAssertEqual(env.stage, .idle)
        XCTAssertFalse(env.isActive)
    }

    func testTheLevelNeverJumps() {
        // Retrigger mid-release and release mid-attack: no step bigger than a fast attack's.
        var env = Envelope(settings: .init(attack: 0.005, decay: 0.05, sustain: 0.6, release: 0.2), sampleRate: rate)
        env.gateOn()
        var previous: Float = 0
        var biggest: Float = 0
        for i in 0..<Int(rate) {
            if i == 2_000 { env.gateOff() }
            if i == 4_000 { env.gateOn() }
            if i == 4_100 { env.gateOff() }
            let x = env.next()
            biggest = Swift.max(biggest, Swift.abs(x - previous))
            previous = x
        }
        XCTAssertLessThan(biggest, 0.02)
    }

    func testFullSustainSkipsTheDecay() {
        var env = Envelope(settings: .init(attack: 0.001, decay: 1, sustain: 1, release: 0.1), sampleRate: rate)
        env.gateOn()
        XCTAssertEqual(run(&env, seconds: 0.01), 1)
        XCTAssertEqual(env.stage, .sustain)
    }

    func testNonFiniteSettingsStillProduceAFiniteEnvelope() {
        var env = Envelope(settings: .init(attack: .nan, decay: .infinity, sustain: .nan, release: -1), sampleRate: .nan)
        env.gateOn()
        for _ in 0..<10_000 { XCTAssertTrue(env.next().isFinite) }
        env.gateOff()
        XCTAssertEqual(run(&env, seconds: 0.1), 0)
    }
}
