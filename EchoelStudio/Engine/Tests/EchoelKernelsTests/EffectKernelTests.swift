import EchoelCore
import EchoelDSP
import XCTest
@testable import EchoelKernels

final class EffectKernelTests: XCTestCase {
    private let rate = 48_000.0

    private func process(_ kernel: EffectKernel, _ input: [Float]) -> [Float] {
        var l = input, r = input
        l.withUnsafeMutableBufferPointer { a in
            r.withUnsafeMutableBufferPointer { b in
                guard let x = a.baseAddress, let y = b.baseAddress else { return }
                kernel.process(left: x, right: y, frames: a.count)
            }
        }
        return l
    }

    func testEveryEffectStartsAtItsDefaultsAndHoldsValuesInRange() {
        for effect in StandardEffect.allCases {
            let kernel = EffectKernel(effect: effect, sampleRate: rate)
            XCTAssertFalse(kernel.parameters.isEmpty)
            XCTAssertEqual(kernel.parameters.map(\.address), Array(kernel.parameters.indices))
            XCTAssertEqual(Set(kernel.parameters.map(\.identifier)).count, kernel.parameters.count)
            for p in kernel.parameters {
                XCTAssertTrue(p.range.contains(p.defaultValue), "\(effect) \(p.title)")
                XCTAssertEqual(kernel.parameter(p.address), p.defaultValue)
                kernel.setParameter(p.address, p.range.upperBound + 1_000)
                XCTAssertEqual(kernel.parameter(p.address), p.range.upperBound)
                kernel.setParameter(p.address, .nan)
                XCTAssertEqual(kernel.parameter(p.address), p.defaultValue)
            }
            let noise = (0..<4_096).map { Float(sin(Double($0) * 0.21)) * 0.8 }
            XCTAssertTrue(process(kernel, noise).allSatisfy(\.isFinite), "\(effect)")
        }
    }

    func testAParameterReachesTheSoundAtTheNextBlockAndCarriesToANewRate() {
        let eq = EffectKernel(effect: .equalizer, sampleRate: rate)
        let tone = (0..<4_800).map { Float(sin(2 * Double.pi * 3_000 * Double($0) / 48_000)) }
        XCTAssertEqual(process(eq, tone), tone, "a flat EQ passes the signal")
        eq.setParameter(7, 12) // High Mid Gain at 3 kHz
        let boosted = process(eq, tone)
        XCTAssertGreaterThan(boosted.suffix(1_000).map { abs($0) }.max() ?? 0, 3)

        let moved = EffectKernel(effect: .equalizer, sampleRate: 44_100, values: eq.allValues)
        XCTAssertEqual(moved.parameter(7), 12)

        let compressor = EffectKernel(effect: .compressor, sampleRate: rate)
        compressor.setParameter(0, -30)
        _ = process(compressor, tone)
        XCTAssertLessThan(compressor.gainReduction, -10, "the meter reads the reduction")
    }

    private func voiceTone(_ hertz: Double) -> [Float] {
        (0..<48_000).map { (index: Int) -> Float in
            let phase = 2 * Double.pi * hertz * Double(index) / 48_000
            return Float(0.5 * sin(phase) + 0.2 * sin(2 * phase))
        }
    }

    private func cents(_ found: Double?, _ expected: Double) -> Double {
        guard let found else { return .infinity }
        return 1_200 * log2(found / expected)
    }

    /// The key and scale are names whose index the kernel turns into targets: an F sung 30 cents
    /// sharp stays F in C major and becomes F sharp in D major.
    func testTheCorrectionFollowsTheChosenKeyAndScale() throws {
        let kernel = EffectKernel(effect: .pitchCorrection, sampleRate: rate)
        let names = kernel.parameters.map(\.identifier)
        let key = try XCTUnwrap(names.firstIndex(of: "key"))
        let scale = try XCTUnwrap(names.firstIndex(of: "scale"))
        XCTAssertEqual(kernel.parameters[key].choice(at: kernel.parameter(key)), "C")
        XCTAssertEqual(kernel.parameters[scale].choice(at: kernel.parameter(scale)), "Major")
        let sung = voiceTone(349.23 * pow(2, 30.0 / 1_200))
        let inC = process(kernel, sung)
        XCTAssertEqual(cents(PitchTracker.frequency(of: Array(inC.suffix(4_096)), sampleRate: rate), 349.23), 0, accuracy: 3)
        let inD = EffectKernel(effect: .pitchCorrection, sampleRate: rate)
        inD.setParameter(key, 2)
        let output = process(inD, sung)
        XCTAssertEqual(cents(PitchTracker.frequency(of: Array(output.suffix(4_096)), sampleRate: rate), 369.99), 0, accuracy: 3)
    }

    func testAHarmonizerVoiceIsChosenByItsIntervalsName() throws {
        let kernel = EffectKernel(effect: .harmonizer, sampleRate: rate)
        let voice = kernel.parameters[0]
        XCTAssertEqual(voice.unit, .choice)
        XCTAssertEqual(voice.choices, HarmonyInterval.allCases.map(\.title))
        XCTAssertEqual(voice.choice(at: kernel.parameter(0)), "Fifth up")
        kernel.setParameter(0, Float(HarmonyInterval.octaveUp.rawValue))
        kernel.setParameter(3, 1)
        let input = voiceTone(220)
        let added = zip(process(kernel, input), input).map { (pair: (Float, Float)) -> Float in pair.0 - pair.1 }
        XCTAssertEqual(cents(PitchTracker.frequency(of: Array(added.suffix(6_000)), sampleRate: rate), 440), 0, accuracy: 3)
        kernel.setParameter(0, Float(HarmonyInterval.off.rawValue))
        let silent = process(kernel, input)
        XCTAssertEqual(Array(silent.suffix(1_000)), Array(input.suffix(1_000)), "every voice off passes the sound")
    }
}
