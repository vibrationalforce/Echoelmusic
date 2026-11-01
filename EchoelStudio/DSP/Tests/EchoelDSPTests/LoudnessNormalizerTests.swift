import Foundation
import XCTest
@testable import EchoelDSP

final class LoudnessNormalizerTests: XCTestCase {
    private let rate = 48_000.0
    private let ceiling = -1.0

    /// A mix in memory, replayed in blocks as a file would be read.
    private struct Mix {
        var left: [Float]
        var right: [Float]

        func replay(block: Int = 4_096) -> LoudnessNormalizer.Replay {
            { consume in
                try left.withUnsafeBufferPointer { leftBuffer in
                    try right.withUnsafeBufferPointer { rightBuffer in
                        guard let l = leftBuffer.baseAddress, let r = rightBuffer.baseAddress else { return }
                        var done = 0
                        while done < leftBuffer.count {
                            let count = Swift.min(block, leftBuffer.count - done)
                            try consume(l + done, r + done, count)
                            done += count
                        }
                    }
                }
            }
        }
    }

    private func mix(seconds: Double, _ sample: (Int) -> (Float, Float)) -> Mix {
        let frames = Int(seconds * rate)
        var left = [Float](repeating: 0, count: frames), right = left
        for index in 0..<frames { (left[index], right[index]) = sample(index) }
        return Mix(left: left, right: right)
    }

    private func sine(dBFS level: Double, hertz: Double = 1_000) -> (Int) -> Float {
        let amplitude = Foundation.pow(10, level / 20)
        return { (index: Int) -> Float in
            Float(amplitude * Foundation.sin(2 * Double.pi * hertz * Double(index) / 48_000))
        }
    }

    private func measure(_ mix: Mix) -> LoudnessNormalizer.Measurement {
        var meter = LoudnessMeter(sampleRate: rate)
        mix.left.withUnsafeBufferPointer { leftBuffer in
            mix.right.withUnsafeBufferPointer { rightBuffer in
                guard let l = leftBuffer.baseAddress, let r = rightBuffer.baseAddress else { return }
                meter.process(left: l, right: r, count: leftBuffer.count)
            }
        }
        return LoudnessNormalizer.Measurement(meter)
    }

    /// The search and the pass that writes, as an export runs them.
    private func normalize(_ mix: Mix, to target: Double, block: Int = 4_096) throws
        -> (settings: LoudnessNormalizer.Settings, after: LoudnessNormalizer.Measurement, out: Mix) {
        let settings = try LoudnessNormalizer.settings(target: target, ceiling: ceiling, measured: measure(mix),
                                                       sampleRate: rate, replay: mix.replay(block: block))
        var out = Mix(left: [], right: [])
        let after = try LoudnessNormalizer.apply(settings, sampleRate: rate, replay: mix.replay(block: block)) { l, r, count in
            out.left.append(contentsOf: UnsafeBufferPointer(start: l, count: count))
            out.right.append(contentsOf: UnsafeBufferPointer(start: r, count: count))
        }
        return (settings, after, out)
    }

    /// A quiet, even mix reaches every target by gain alone: no limiter, the reading on the
    /// target and the true peak moved by the same gain.
    func testAQuietMixReachesEachTargetByGainAlone() throws {
        let tone = sine(dBFS: -30)
        let quiet = mix(seconds: 3) { index in (tone(index), tone(index)) }
        for target in [-14.0, -16, -23] {
            let result = try normalize(quiet, to: target)
            XCTAssertNil(result.settings.limiterCeiling, "\(target) LUFS")
            XCTAssertEqual(result.after.integrated, target, accuracy: 0.5, "\(target) LUFS")
            XCTAssertLessThanOrEqual(result.after.truePeak, ceiling, "\(target) LUFS")
            XCTAssertEqual(measure(result.out), result.after, "the pass reports what it wrote")
        }
    }

    /// A mix whose peaks would pass −1 dBTP at the gain the target needs: the limiter holds them,
    /// and the gain rises until the limited mix lands on the target.
    func testAPeakyMixIsLimitedOntoTheTargetUnderTheCeiling() throws {
        let tone = sine(dBFS: -20)
        // A full-scale click every 100 ms over the tone: a true peak near 0 dBTP.
        let peaky = mix(seconds: 3) { index in
            let value = index % 4_800 == 0 ? 0.99 : tone(index)
            return (value, value)
        }
        let before = measure(peaky)
        XCTAssertGreaterThan(before.truePeak, -1, "the clicks reach the ceiling before any gain")
        for target in [-14.0, -16] {
            let result = try normalize(peaky, to: target)
            XCTAssertNotNil(result.settings.limiterCeiling, "\(target) LUFS: the gain alone would pass the ceiling")
            XCTAssertEqual(result.after.integrated, target, accuracy: 0.5, "\(target) LUFS")
            XCTAssertLessThanOrEqual(result.after.truePeak, ceiling, "\(target) LUFS")
        }
    }

    /// Clicks 24 dB above a quiet tone: after each one the limiter holds the tone down while its
    /// detector decays, so more gain makes the mix no louder. It comes out under the ceiling, as
    /// loud as the limiter lets it — louder than the gain alone could make it — and the reading
    /// says it missed the target; the search stops instead of piling on gain.
    func testAMixTheLimiterCannotLiftComesOutUnderTheCeilingAndSaysHowClose() throws {
        let tone = sine(dBFS: -24)
        let clicks = mix(seconds: 3) { index in
            let value = index % 4_800 == 0 ? 0.99 : tone(index)
            return (value, value)
        }
        let before = measure(clicks)
        let result = try normalize(clicks, to: -14)
        XCTAssertLessThanOrEqual(result.after.truePeak, ceiling)
        XCTAssertLessThan(result.after.integrated, -14.5, "the target is out of reach, and the reading shows it")
        XCTAssertGreaterThan(result.after.integrated, before.integrated + (ceiling - before.truePeak) + 1,
                             "louder than the gain alone could bring it under the ceiling")
        XCTAssertLessThan(result.settings.gain, 30, "no gain piled on once more gain stops helping")
    }

    /// The hard case of a real song: drum hits at full scale over a quiet pad, a crest of more
    /// than 20 dB. The limiter works hard and the target and the ceiling still hold.
    func testDrumHitsOverAQuietPadLandOnTheTargetUnderTheCeiling() throws {
        let pad = sine(dBFS: -32, hertz: 220)
        var seed: UInt32 = 0x9E37_79B9
        let hits = mix(seconds: 3) { index in
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let noise = Float(Int32(bitPattern: seed)) / Float(Int32.max)
            let sinceHit = Double(index % 12_000) / 48_000
            let hit = Float(0.95 * Foundation.exp(-sinceHit / 0.012)) * noise
            return (pad(index) + hit, pad(index) - hit * 0.8)
        }
        let result = try normalize(hits, to: -14)
        XCTAssertEqual(result.after.integrated, -14, accuracy: 0.5)
        XCTAssertLessThanOrEqual(result.after.truePeak, ceiling)
    }

    /// A mix rendered past full scale is lowered, and the samples above 1.0 count before the gain:
    /// nothing was clipped on the way.
    func testAMixPastFullScaleIsLoweredOntoTheTarget() throws {
        let hot = sine(dBFS: 6)
        let loud = mix(seconds: 3) { index in (hot(index), hot(index)) }
        let result = try normalize(loud, to: -23)
        XCTAssertNil(result.settings.limiterCeiling)
        XCTAssertLessThan(result.settings.gain, -25)
        XCTAssertEqual(result.after.integrated, -23, accuracy: 0.5)
        XCTAssertLessThanOrEqual(result.after.truePeak, ceiling)
    }

    /// Off: the mix as it plays — every sample passes bit for bit, a non-finite one included.
    func testUnchangedSettingsPassEverySampleBitForBit() throws {
        var seed: UInt32 = 1
        var source = mix(seconds: 1) { _ in
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let value = Float(Int32(bitPattern: seed)) / Float(Int32.max) * 1.5
            return (value, -value)
        }
        source.left[100] = .nan
        source.right[200] = .infinity
        var out = Mix(left: [], right: [])
        _ = try LoudnessNormalizer.apply(.unchanged, sampleRate: rate, replay: source.replay(block: 1_000)) { l, r, count in
            out.left.append(contentsOf: UnsafeBufferPointer(start: l, count: count))
            out.right.append(contentsOf: UnsafeBufferPointer(start: r, count: count))
        }
        XCTAssertEqual(out.left.map(\.bitPattern), source.left.map(\.bitPattern))
        XCTAssertEqual(out.right.map(\.bitPattern), source.right.map(\.bitPattern))
    }

    /// Nothing measured, nothing raised: silence, a sound shorter than one 400 ms block, a mix under
    /// the absolute gate, and a target or ceiling that is not a number all leave the mix as it is.
    func testWhatWasNotMeasuredIsNotRaised() throws {
        let silence = mix(seconds: 1) { _ in (0, 0) }
        let blip = mix(seconds: 0.2) { index in (index % 2 == 0 ? 0.5 : -0.5, 0) }
        let faint = sine(dBFS: -80)
        let underTheGate = mix(seconds: 2) { index in (faint(index), faint(index)) }
        for source in [silence, blip, underTheGate] {
            let settings = try LoudnessNormalizer.settings(target: -14, ceiling: ceiling, measured: measure(source),
                                                           sampleRate: rate, replay: source.replay())
            XCTAssertEqual(settings, .unchanged)
        }
        let tone = sine(dBFS: -20)
        let even = mix(seconds: 1) { index in (tone(index), tone(index)) }
        let measured = measure(even)
        for (target, top) in [(Double.nan, ceiling), (-14, .infinity), (.infinity, ceiling)] {
            let settings = try LoudnessNormalizer.settings(target: target, ceiling: top, measured: measured,
                                                           sampleRate: rate, replay: even.replay())
            XCTAssertEqual(settings, .unchanged)
        }
    }

    /// The search and the write are separate passes, so they must agree: the same settings give the
    /// same samples whatever the size of the blocks the file is read in.
    func testThePassDoesNotDependOnTheBlockSize() throws {
        let tone = sine(dBFS: -24)
        let peaky = mix(seconds: 2) { index in
            let value = index % 4_800 == 0 ? 0.99 : tone(index)
            return (value, value * 0.5)
        }
        let large = try normalize(peaky, to: -14, block: 8_192)
        let small = try normalize(peaky, to: -14, block: 333)
        XCTAssertEqual(large.settings, small.settings)
        XCTAssertEqual(large.out.left, small.out.left)
        XCTAssertEqual(large.out.right, small.out.right)
        XCTAssertEqual(large.after, small.after)
    }

    /// A pass that is stopped stops: the error reaches the caller.
    func testAThrowingWriteStopsThePass() {
        struct Stop: Error {}
        let tone = sine(dBFS: -20)
        let even = mix(seconds: 1) { index in (tone(index), tone(index)) }
        XCTAssertThrowsError(try LoudnessNormalizer.apply(.unchanged, sampleRate: rate, replay: even.replay()) { _, _, _ in
            throw Stop()
        })
    }
}
