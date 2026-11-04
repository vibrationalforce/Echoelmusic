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

    /// A voice switched on, a style changed, an interval changed while the voice sounds: the
    /// harmonies fade out and in again over a few milliseconds, the dry sound goes on, and nothing
    /// moves faster than the sound itself does. Before, a voice entered mid-waveform — Free to
    /// Organum stepped by the whole level (click hunt, 2026-11-01).
    func testAChangeOfVoicesFadesInsteadOfStepping() {
        let changes: [(Harmonizer.Settings, Harmonizer.Settings)] = [
            (.init(first: 7, level: 1), .init(first: 7, second: -12, level: 1)),
            (.init(first: 7, level: 1), .init(first: nil, level: 1, voicing: .ison(root: 9, reference: 440))),
            (.init(first: 7, level: 1), .init(first: -5, level: 1)),
        ]
        for (index, change) in changes.enumerated() {
            let harmonizer = Harmonizer(sampleRate: rate, settings: change.0)
            let input = tone(220, seconds: 1)
            var first = Array(input[..<24_037]), second = Array(input[24_037...])
            first.withUnsafeMutableBufferPointer { a in
                guard let x = a.baseAddress else { return }
                var copy = Array(a)
                copy.withUnsafeMutableBufferPointer { b in
                    guard let y = b.baseAddress else { return }
                    harmonizer.process(left: x, right: y, frames: a.count)
                }
            }
            harmonizer.settings = change.1
            second.withUnsafeMutableBufferPointer { a in
                guard let x = a.baseAddress else { return }
                var copy = Array(a)
                copy.withUnsafeMutableBufferPointer { b in
                    guard let y = b.baseAddress else { return }
                    harmonizer.process(left: x, right: y, frames: a.count)
                }
            }
            let heard = first + second
            // The second difference: a step's spike, where a tone barely bends.
            func sharpest(_ range: Range<Int>) -> Float {
                range.map { Swift.abs(heard[$0] - 2 * heard[$0 - 1] + heard[$0 - 2]) }.max() ?? 0
            }
            let steady = Swift.max(sharpest(12_000..<24_000), sharpest(30_000..<47_000))
            XCTAssertLessThanOrEqual(sharpest(24_030..<24_600), steady * 1.5, "change \(index)")
        }
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

    /// The same interval for every pitch class, and the left voice's table differing from the right's.
    private func table(_ value: Float, _ overrides: [Int: Float] = [:]) -> SIMD16<Float> {
        var lanes = SIMD16<Float>(repeating: 0)
        for lane in 0..<12 { lanes[lane] = overrides[lane] ?? value }
        return lanes
    }

    /// The voice alone on each side, with the side voices spread hard left and right.
    private func sides(_ settings: Harmonizer.Settings, _ input: [Float]) -> (left: [Float], right: [Float]) {
        let (l, r) = run(Harmonizer(sampleRate: rate, settings: settings), input)
        let left = zip(l, input).map { (pair: (Float, Float)) -> Float in pair.0 - pair.1 }
        let right = zip(r, input).map { (pair: (Float, Float)) -> Float in pair.0 - pair.1 }
        return (left, right)
    }

    private func pitch(_ samples: ArraySlice<Float>) throws -> Double {
        try XCTUnwrap(PitchTracker.frequency(of: Array(samples), sampleRate: rate))
    }

    /// A style's two voices: each sings its table's interval for the sung note, left and right.
    func testTheSideVoicesSingTheirTablesIntervalForTheSungNote() throws {
        // A3 is pitch class 9: a minor third up on the left, a major third down on the right.
        let following = Harmonizer.Voicing.following(left: table(0, [9: 3]), right: table(0, [9: -4]), reference: 440)
        let input = tone(220)
        let voices = sides(.init(first: 7, level: 1, spread: 1, voicing: following), input)
        XCTAssertEqual(cents(try pitch(voices.left.suffix(6_000)), 220 * Foundation.pow(2, 3.0 / 12)), 0, accuracy: 3)
        XCTAssertEqual(cents(try pitch(voices.right.suffix(6_000)), 220 * Foundation.pow(2, -4.0 / 12)), 0, accuracy: 3)
        // A fixed style (organum) needs no pitch: a fifth and an octave below on any note.
        let organum = Harmonizer.Voicing.following(left: table(-7), right: table(-12), reference: 440)
        let low = sides(.init(level: 1, spread: 1, voicing: organum), tone(330))
        XCTAssertEqual(cents(try pitch(low.left.suffix(6_000)), 330 * Foundation.pow(2, -7.0 / 12)), 0, accuracy: 3)
        XCTAssertEqual(cents(try pitch(low.right.suffix(6_000)), 165), 0, accuracy: 3)
    }

    /// The interval moves with the melody: C takes a major third above in C major, D a minor one.
    func testASideVoiceChangesItsIntervalWithTheSungNote() throws {
        let diatonic = Harmonizer.Voicing.following(left: table(0, [0: 4, 2: 3]), right: table(-12), reference: 440)
        let c4 = 261.63, d4 = 293.66
        let input = tone(c4) + tone(d4)
        let voices = sides(.init(level: 1, spread: 1, voicing: diatonic), input)
        let half = input.count / 2
        XCTAssertEqual(cents(try pitch(voices.left[(half - 6_000)..<half]), c4 * Foundation.pow(2, 4.0 / 12)), 0, accuracy: 4)
        XCTAssertEqual(cents(try pitch(voices.left.suffix(6_000)), d4 * Foundation.pow(2, 3.0 / 12)), 0, accuracy: 4)
    }

    /// The ison holds the key's root below the melody while the melody moves, at the voice's level,
    /// and is silent while the voice is.
    func testTheIsonHoldsTheRootBelowTheMelodyAtItsLevel() throws {
        let ison = Harmonizer.Voicing.ison(root: 0, reference: 440)
        let a4 = tone(440), e4 = tone(329.63)
        let quiet = tone(440).map { (sample: Float) -> Float in sample * 0.25 }
        let input = a4 + e4 + quiet + [Float](repeating: 0, count: 9_600)
        let voice = sides(.init(level: 1, voicing: ison), input).left
        let c4 = 261.63
        let part = a4.count
        XCTAssertEqual(cents(try pitch(voice[(part - 6_000)..<part]), c4), 0, accuracy: 5, "under A4")
        XCTAssertEqual(cents(try pitch(voice[(2 * part - 6_000)..<(2 * part)]), c4), 0, accuracy: 5, "still C4 under E4")
        func rms(_ slice: ArraySlice<Float>) -> Float {
            (slice.reduce(0) { $0 + $1 * $1 } / Float(Swift.max(slice.count, 1))).squareRoot()
        }
        let loud = rms(voice[(part - 6_000)..<part]), soft = rms(voice[(3 * part - 6_000)..<(3 * part)])
        XCTAssertGreaterThan(loud, 0.1)
        XCTAssertEqual(soft / loud, 0.25, accuracy: 0.05, "the ison follows the voice's level")
        XCTAssertLessThan(rms(voice.suffix(2_000)), 1e-4, "silent with the voice")
    }

    /// A sung note on the root takes the ison in unison; far below it, an octave lower.
    func testTheIsonMovesAnOctaveWhenTheMelodyLeavesItBehind() throws {
        let ison = Harmonizer.Voicing.ison(root: 9, reference: 440)
        let input = tone(440) + tone(146.83)
        let voice = sides(.init(level: 1, voicing: ison), input).left
        let part = input.count / 2
        XCTAssertEqual(cents(try pitch(voice[(part - 6_000)..<part]), 440), 0, accuracy: 5, "on the root: A4")
        XCTAssertEqual(cents(try pitch(voice.suffix(6_000)), 110), 0, accuracy: 5, "D3 is below A4 by more than a fifth: A2")
    }

    func testAStylesSettingsAreClampedAndABadSampleDoesNotRingOn() {
        var lanes = SIMD16<Float>(repeating: 50)
        lanes[3] = .nan
        let harmonizer = Harmonizer(sampleRate: rate, settings: .init(
            voicing: .following(left: lanes, right: table(-4), reference: .nan)))
        guard case let .following(left, right, reference) = harmonizer.settings.voicing else {
            return XCTFail("still a following voicing")
        }
        XCTAssertEqual(left[0], 24)
        XCTAssertEqual(left[3], 0)
        XCTAssertEqual(left[12], 0, "the lanes past B are unused")
        XCTAssertEqual(right[5], -4)
        XCTAssertEqual(reference, 440)
        XCTAssertEqual(Harmonizer.Settings(voicing: .ison(root: -1, reference: 999)).clamped.voicing,
                       .ison(root: 11, reference: 480))
        for voicing in [harmonizer.settings.voicing, .ison(root: 4, reference: 440)] {
            var input = tone(220, seconds: 0.2)
            input[300] = .nan
            input[4_000] = .infinity
            let (l, r) = run(Harmonizer(sampleRate: rate, settings: .init(level: 1, voicing: voicing)), input)
            XCTAssertTrue(l.allSatisfy(\.isFinite) && r.allSatisfy(\.isFinite), "\(voicing)")
        }
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
