import Foundation
import XCTest
@testable import EchoelDSP

final class GranulatorTests: XCTestCase {
    private let rate = 48_000.0

    private func tone(_ hertz: Double, seconds: Double = 1) -> [Float] {
        (0..<Int(rate * seconds)).map { (index: Int) -> Float in
            Float(0.5 * Foundation.sin(2 * Double.pi * hertz * Double(index) / 48_000))
        }
    }

    private func run(_ granulator: Granulator, _ input: [Float]) -> ([Float], [Float]) {
        var l = input, r = input
        l.withUnsafeMutableBufferPointer { a in
            r.withUnsafeMutableBufferPointer { b in
                guard let x = a.baseAddress, let y = b.baseAddress else { return }
                granulator.process(left: x, right: y, frames: a.count)
            }
        }
        return (l, r)
    }

    /// The strength of one frequency in a signal.
    private func magnitude(_ samples: [Float], at hertz: Double) -> Double {
        var real = 0.0, imaginary = 0.0
        for (index, sample) in samples.enumerated() {
            let phase = 2 * Double.pi * hertz * Double(index) / 48_000
            real += Double(sample) * Foundation.cos(phase)
            imaginary -= Double(sample) * Foundation.sin(phase)
        }
        return (real * real + imaginary * imaginary).squareRoot()
    }

    func testFullyDryPassesTheSoundThrough() {
        let input = tone(330, seconds: 0.3)
        let (l, r) = run(Granulator(sampleRate: rate, settings: .init(mix: 0)), input)
        XCTAssertEqual(l, input)
        XCTAssertEqual(r, input)
    }

    /// Pitched grains carry the transposed tone and hardly the original.
    func testTheGrainsSoundAtTheirPitch() {
        let input = tone(220)
        for semitones in [12.0, -12, 7] {
            let settings = Granulator.Settings(size: 0.1, density: 1, pitch: semitones, position: 0.1, spray: 0,
                                               spread: 0, mix: 1)
            let (l, _) = run(Granulator(sampleRate: rate, settings: settings), input)
            let tail = Array(l.suffix(24_000))
            let shifted = magnitude(tail, at: 220 * Foundation.pow(2, semitones / 12))
            XCTAssertGreaterThan(shifted, 10 * magnitude(tail, at: 220), "\(semitones) semitones")
            XCTAssertTrue(l.allSatisfy(\.isFinite))
        }
    }

    func testTheSameSeedGivesTheSameCloudAndThePoolHolds() {
        let input = tone(180, seconds: 0.5)
        let settings = Granulator.Settings(size: 0.05, density: 1, pitch: 5, spray: 0.3, spread: 1, mix: 1)
        let first = Granulator(sampleRate: rate, settings: settings, seed: 7)
        let (a, _) = run(first, input)
        let (b, _) = run(Granulator(sampleRate: rate, settings: settings, seed: 7), input)
        let (c, _) = run(Granulator(sampleRate: rate, settings: settings, seed: 8), input)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertLessThanOrEqual(first.activeGrainCount, Granulator.maxGrains)
        XCTAssertGreaterThan(first.activeGrainCount, 0)
        first.reset()
        XCTAssertEqual(first.activeGrainCount, 0)
        XCTAssertEqual(run(first, input).0, a, "a reset cloud plays what a new one does")
    }

    func testSettingsAreClampedAndABadSampleDoesNotRingOn() {
        let granulator = Granulator(sampleRate: rate, settings: .init(size: 9, density: -1, pitch: 99, position: .nan,
                                                                    spray: 1, spread: 2, mix: .infinity))
        XCTAssertEqual(granulator.settings, .init(size: 0.5, density: 0, pitch: 24, position: 0.25, spray: 0.5,
                                                  spread: 1, mix: 0.5))
        var input = tone(220, seconds: 0.3)
        input[200] = .nan
        let (l, r) = run(granulator, input)
        XCTAssertTrue(l.allSatisfy(\.isFinite) && r.allSatisfy(\.isFinite))
    }
}
