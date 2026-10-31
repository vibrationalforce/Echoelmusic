import Foundation
import XCTest
@testable import EchoelDSP

final class HarmonizerTests: XCTestCase {
    private let rate = 48_000.0

    private func tone(_ hertz: Double, seconds: Double = 0.6) -> [Float] {
        (0..<Int(rate * seconds)).map { (index: Int) -> Float in
            let phase = 2 * Double.pi * hertz * Double(index) / 48_000
            return Float(0.5 * Foundation.sin(phase) + 0.2 * Foundation.sin(2 * phase))
        }
    }

    private func run(_ harmonizer: Harmonizer, _ input: [Float]) -> ([Float], [Float]) {
        var l = input, r = input
        l.withUnsafeMutableBufferPointer { a in
            r.withUnsafeMutableBufferPointer { b in
                guard let x = a.baseAddress, let y = b.baseAddress else { return }
                harmonizer.process(left: x, right: y, frames: a.count)
            }
        }
        return (l, r)
    }

    private func cents(_ found: Double, _ expected: Double) -> Double {
        1_200 * Foundation.log2(found / expected)
    }

    func testWithEveryVoiceOffTheSoundPassesUnchanged() {
        let input = tone(220)
        let (l, r) = run(Harmonizer(sampleRate: rate, settings: .init(first: nil)), input)
        XCTAssertEqual(l, input)
        XCTAssertEqual(r, input)
    }

    /// The voice alone (output minus the dry sound) sounds the interval above or below.
    func testAVoiceSoundsItsInterval() throws {
        for (hertz, semitones) in [(220.0, 7.0), (220, 12), (220, -12), (330, -5), (150, 4)] {
            let input = tone(hertz)
            let (l, _) = run(Harmonizer(sampleRate: rate, settings: .init(first: semitones, level: 1)), input)
            let voice = zip(l, input).map { (pair: (Float, Float)) -> Float in pair.0 - pair.1 }
            let found = try XCTUnwrap(PitchTracker.frequency(of: Array(voice.suffix(6_000)), sampleRate: rate))
            XCTAssertEqual(cents(found, hertz * Foundation.pow(2, semitones / 12)), 0, accuracy: 3, "\(semitones)")
        }
    }

    func testTheSideVoicesSitLeftAndRight() {
        let input = tone(220)
        let (l, r) = run(Harmonizer(sampleRate: rate, settings: .init(first: nil, second: 4, level: 1, spread: 1)), input)
        XCTAssertEqual(r, input, "the second voice sits hard left")
        XCTAssertGreaterThan(zip(l, input).map { abs($0 - $1) }.max() ?? 0, 0.2)
        let (l3, r3) = run(Harmonizer(sampleRate: rate, settings: .init(first: nil, third: 7, level: 1, spread: 1)), input)
        XCTAssertEqual(l3, input, "the third sits hard right")
        XCTAssertGreaterThan(zip(r3, input).map { abs($0 - $1) }.max() ?? 0, 0.2)
    }

    func testSettingsAreClampedAndABadSampleDoesNotRingOn() {
        let harmonizer = Harmonizer(sampleRate: rate, settings: .init(first: 40, second: .nan, third: -3, level: 2,
                                                                     spread: .nan))
        XCTAssertEqual(harmonizer.settings, .init(first: 24, second: nil, third: -3, level: 1, spread: 0.5))
        var input = tone(220, seconds: 0.2)
        input[300] = .nan
        let (l, r) = run(harmonizer, input)
        XCTAssertTrue(l.allSatisfy(\.isFinite) && r.allSatisfy(\.isFinite))
    }
}
