import XCTest
@testable import EchoelDSP

final class StereoWidthTests: XCTestCase {
    private let rate = 48_000.0

    private func run(_ effect: x, left: [Float], right: [Float]) -> ([Float], [Float]) {
        var l = left, r = right
        l.withUnsafeMutableBufferPointer { lp in
            r.withUnsafeMutableBufferPointer { rp in
                guard let a = lp.baseAddress, let b = rp.baseAddress else { return }
                effect.process(left: a, right: b, frames: lp.count)
            }
        }
        return (l, r)
    }

    private func sine(_ hertz: Double, amplitude: Double, count: Int) -> [Float] {
        (0..<count).map { (index: Int) -> Float in
            let phase = 2 * Double.pi * hertz * Double(index) / 48_000
            return Float(Foundation.sin(phase) * amplitude)
        }
    }

    private func pair() -> ([Float], [Float]) {
        (sine(220, amplitude: 0.5, count: 2_400), sine(330, amplitude: 0.3, count: 2_400))
    }

    func testWidthOneLeavesTheSound() {
        let width = StereoWidth(sampleRate: rate, settings: .init(width: 1))
        let (a, b) = pair()
        let (l, r) = run(width, left: a, right: b)
        for index in a.indices {
            XCTAssertEqual(l[index], a[index], accuracy: 1e-6)
            XCTAssertEqual(r[index], b[index], accuracy: 1e-6)
        }
    }

    func testWidthZeroFoldsToMonoAndTwoDoublesTheSide() {
        let (a, b) = pair()
        let mono = StereoWidth(sampleRate: rate, settings: .init(width: 0))
        let (ml, mr) = run(mono, left: a, right: b)
        XCTAssertEqual(ml, mr)
        XCTAssertEqual(ml[100], (a[100] + b[100]) / 2, accuracy: 1e-6)
        let wide = StereoWidth(sampleRate: rate, settings: .init(width: 2))
        let (wl, wr) = run(wide, left: a, right: b)
        XCTAssertEqual(wl[100] - wr[100], 2 * (a[100] - b[100]), accuracy: 1e-5)
        XCTAssertEqual(wl[100] + wr[100], a[100] + b[100], accuracy: 1e-5, "the mid stays")
    }

    func testABadSampleIsSilenceAndSettingsAreClamped() {
        let width = StereoWidth(sampleRate: rate, settings: .init(width: .infinity))
        XCTAssertEqual(width.settings, .init(width: 1.4))
        width.settings = .init(width: 7)
        XCTAssertEqual(width.settings.width, 2)
        var input = [Float](repeating: 0.5, count: 100)
        input[10] = .nan
        let (l, r) = run(width, left: input, right: input)
        XCTAssertEqual(l[10], 0)
        XCTAssertTrue(l.allSatisfy(\.isFinite) && r.allSatisfy(\.isFinite))
    }
}
