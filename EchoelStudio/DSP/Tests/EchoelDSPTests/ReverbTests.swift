import XCTest
@testable import EchoelDSP

final class ReverbTests: XCTestCase {
    private let rate = 48_000.0

    private func response(_ settings: Reverb.Settings, seconds: Double = 1.4) -> ([Float], [Float]) {
        let reverb = Reverb(sampleRate: rate, settings: settings)
        let count = Int(rate * seconds)
        var left = [Float](repeating: 0, count: count), right = left
        left[0] = 1
        right[0] = 1
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let a = l.baseAddress, let b = r.baseAddress else { return }
                // In blocks, as a host renders.
                var done = 0
                while done < count {
                    let n = Swift.min(256, count - done)
                    reverb.process(left: a + done, right: b + done, frames: n)
                    done += n
                }
            }
        }
        return (left, right)
    }

    private func rms(_ x: [Float], from: Double, to: Double) -> Double {
        let part = x[Int(from * rate)..<Int(to * rate)]
        return (part.reduce(0) { $0 + Double($1 * $1) } / Double(part.count)).squareRoot()
    }

    func testTheTailFallsBySixtyDecibelsInTheDecayTime() {
        let (left, _) = response(.init(size: 0.6, decay: 1, damping: 20_000, predelay: 0, mix: 1))
        let fall = 20 * log10(rms(left, from: 1.1, to: 1.2) / rms(left, from: 0.1, to: 0.2))
        XCTAssertEqual(fall, -60, accuracy: 9)
        let (long, _) = response(.init(size: 0.6, decay: 4, damping: 20_000, predelay: 0, mix: 1))
        XCTAssertGreaterThan(rms(long, from: 1.1, to: 1.2), 10 * rms(left, from: 1.1, to: 1.2), "a longer decay rings longer")
    }

    /// The peak of `seconds` of a 0.5 sine at `hertz` through `settings`, after the first second.
    private func sustainedPeak(_ settings: Reverb.Settings, hertz: Double, seconds: Double = 6) -> Float {
        let reverb = Reverb(sampleRate: rate, settings: settings)
        var left = [Float](repeating: 0, count: 512), right = left
        var peak: Float = 0
        var done = 0
        while done < Int(seconds * rate) {
            for i in 0..<512 {
                let phase: Double = 2 * Double.pi * hertz * Double(done + i) / rate
                left[i] = Float(sin(phase)) * 0.5
                right[i] = left[i]
            }
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let a = l.baseAddress, let b = r.baseAddress else { return }
                    reverb.process(left: a, right: b, frames: 512)
                }
            }
            if done >= Int(rate) { peak = Swift.max(peak, left.map(abs).max() ?? 0, right.map(abs).max() ?? 0) }
            done += 512
        }
        return peak
    }

    /// A held tone on one of the network's modes rang up to 8.6 from a 0.5 sine — +24.7 dB — at
    /// Size 1, Decay 20 s, Damping 20 kHz, Mix 1, and to +16 dB at the default decay (audit
    /// 2026-11-04). The guard holds the wet within +6 dB of the input's peak, with a little room
    /// for its follower's ripple.
    func testAHeldToneNeverRingsFarAboveTheInput() {
        let extreme = Reverb.Settings(size: 1, decay: 20, damping: 20_000, predelay: 0.02, mix: 1)
        for hertz in [220.0, 1_107.5, 1_178.0] {
            let peak = sustainedPeak(extreme, hertz: hertz)
            XCTAssertLessThan(20 * log10(Double(peak) / 0.5), 8, "\(hertz) Hz rang to \(peak)")
        }
        let atDefault = sustainedPeak(.init(mix: 1), hertz: 280.3)
        XCTAssertLessThan(20 * log10(Double(atDefault) / 0.5), 8, "the default decay rang to \(atDefault)")
    }

    func testThePredelayHoldsTheTailBackAndTheSidesDiffer() {
        let (left, right) = response(.init(predelay: 0.1, mix: 1), seconds: 0.5)
        let first = left.firstIndex { abs($0) > 1e-9 } ?? 0
        XCTAssertGreaterThanOrEqual(first, 4_800, "nothing before the predelay")
        XCTAssertNotEqual(left, right, "a stereo tail, not two copies")
        XCTAssertTrue(left.allSatisfy { $0.isFinite && abs($0) < 1 })
    }

    func testDryPassesUntouchedAndABadSampleHeals() {
        let tone = (0..<4_800).map { Float(sin(Double($0) * 0.1)) }
        let dry = Reverb(sampleRate: rate, settings: .init(mix: 0))
        var a = tone, b = tone
        a.withUnsafeMutableBufferPointer { l in
            b.withUnsafeMutableBufferPointer { r in
                guard let x = l.baseAddress, let y = r.baseAddress else { return }
                dry.process(left: x, right: y, frames: l.count)
            }
        }
        XCTAssertEqual(a, tone)

        let reverb = Reverb(sampleRate: rate, settings: .init(decay: 20, mix: 1))
        var bad = tone, other = tone
        bad[10] = .infinity
        bad.withUnsafeMutableBufferPointer { l in
            other.withUnsafeMutableBufferPointer { r in
                guard let x = l.baseAddress, let y = r.baseAddress else { return }
                reverb.process(left: x, right: y, frames: l.count)
            }
        }
        XCTAssertTrue(bad.allSatisfy(\.isFinite))
        reverb.settings.decay = .nan
        XCTAssertEqual(reverb.settings.decay, 2.2, "non-finite takes the default")
    }
}
