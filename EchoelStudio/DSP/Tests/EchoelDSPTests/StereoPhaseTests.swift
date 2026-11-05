import Foundation
import XCTest
@testable import EchoelDSP

/// The phase meter: correlation +1 for mono, −1 for an inverted side, about 0 for unrelated sides,
/// nothing for silence; the goniometer draws mono upright and an inverted pair flat.
final class StereoPhaseTests: XCTestCase {
    private func sine(_ hertz: Double, phase: Double = 0, count: Int = 4_800) -> [Float] {
        (0..<count).map { (index: Int) -> Float in
            Float(0.5 * sin(2 * Double.pi * hertz * Double(index) / 48_000 + phase))
        }
    }

    private func correlation(_ left: [Float], _ right: [Float]) -> Float? {
        left.withUnsafeBufferPointer { l in
            right.withUnsafeBufferPointer { r in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return nil }
                return StereoPhase.correlation(left: lp, right: rp, count: Swift.min(l.count, r.count))
            }
        }
    }

    func testMonoIsOneAnInvertedSideIsMinusOneAndUnrelatedSidesAreNearZero() throws {
        let tone = sine(440)
        XCTAssertEqual(try XCTUnwrap(correlation(tone, tone)), 1, accuracy: 1e-5)
        XCTAssertEqual(try XCTUnwrap(correlation(tone, tone.map { -$0 })), -1, accuracy: 1e-5)
        // A quarter period apart over whole periods (440 Hz, 4 800 samples = 44 periods).
        XCTAssertEqual(try XCTUnwrap(correlation(tone, sine(440, phase: Double.pi / 2))), 0, accuracy: 1e-3)
        XCTAssertEqual(try XCTUnwrap(correlation(tone, tone.map { 0.25 * $0 })), 1, accuracy: 1e-5,
                       "a quieter side is still in phase")
    }

    func testSilenceAndDamageHaveNoCorrelation() {
        let tone = sine(440)
        let quiet = [Float](repeating: 0, count: tone.count)
        XCTAssertNil(correlation(tone, quiet), "one side silent")
        XCTAssertNil(correlation(quiet, quiet))
        XCTAssertNil(correlation([], []))
        var damaged = tone
        damaged[10] = .nan
        damaged[20] = .infinity
        XCTAssertEqual(correlation(damaged, damaged) ?? -2, 1, accuracy: 1e-4, "damage counts as 0")
    }

    func testTheGoniometerDrawsMonoUprightAndAnInvertedPairFlat() {
        let tone = sine(440)
        let inverted = tone.map { -$0 }
        let pairs = 64
        var points = [Float](repeating: 9, count: 2 * pairs)
        func capture(_ left: [Float], _ right: [Float]) {
            left.withUnsafeBufferPointer { l in
                right.withUnsafeBufferPointer { r in
                    points.withUnsafeMutableBufferPointer { p in
                        guard let lp = l.baseAddress, let rp = r.baseAddress, let pp = p.baseAddress else { return }
                        StereoPhase.capture(left: lp, right: rp, count: l.count, into: pp, pairs: pairs)
                    }
                }
            }
        }
        capture(tone, tone)
        for pair in 0..<pairs { XCTAssertEqual(points[2 * pair], 0, accuracy: 1e-6, "mono has no side") }
        XCTAssertGreaterThan(points.enumerated().filter { $0.offset % 2 == 1 }.map { abs($0.element) }.max() ?? 0, 0.3)
        capture(tone, inverted)
        for pair in 0..<pairs { XCTAssertEqual(points[2 * pair + 1], 0, accuracy: 1e-6, "inverted has no mid") }
        capture([], [])
        XCTAssertEqual(points, [Float](repeating: 0, count: 2 * pairs), "an empty block draws the centre")
    }
}
