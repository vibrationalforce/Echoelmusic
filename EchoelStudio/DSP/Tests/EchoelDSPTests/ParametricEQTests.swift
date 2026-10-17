import XCTest
@testable import EchoelDSP

final class ParametricEQTests: XCTestCase {
    private let rate = 48_000.0

    private func gain(of eq: inout ParametricEQ, at hz: Double) -> Double {
        let count = 24_000
        let tone = (0..<count).map { Float(sin(2 * Double.pi * hz * Double($0) / rate)) }
        var l = tone, r = tone
        l.withUnsafeMutableBufferPointer { a in
            r.withUnsafeMutableBufferPointer { b in
                guard let x = a.baseAddress, let y = b.baseAddress else { return }
                eq.process(left: x, right: y, frames: count)
            }
        }
        func rms(_ v: ArraySlice<Float>) -> Double { (v.reduce(0) { $0 + Double($1 * $1) } / Double(v.count)).squareRoot() }
        return 20 * log10(rms(l[12_000...]) / rms(tone[12_000...]))
    }

    func testAFlatEQPassesTheSignalBitForBit() {
        var eq = ParametricEQ(sampleRate: rate)
        let tone = (0..<1_000).map { Float(sin(Double($0) * 0.3)) }
        var l = tone, r = tone
        l.withUnsafeMutableBufferPointer { a in
            r.withUnsafeMutableBufferPointer { b in
                guard let x = a.baseAddress, let y = b.baseAddress else { return }
                eq.process(left: x, right: y, frames: 1_000)
            }
        }
        XCTAssertEqual(l, tone)
        XCTAssertTrue(eq.sections.isEmpty)
    }

    func testABellBoostsItsFrequencyAndLeavesTheRest() {
        var settings = ParametricEQ.Settings()
        settings.highMidFrequency = 1_000
        settings.highMidGain = 6
        var eq = ParametricEQ(sampleRate: rate, settings: settings)
        XCTAssertEqual(eq.response(at: 1_000), 6, accuracy: 0.05)
        XCTAssertEqual(eq.response(at: 50), 0, accuracy: 0.2)
        XCTAssertEqual(gain(of: &eq, at: 1_000), 6, accuracy: 0.2, "the signal agrees with the curve")
    }

    func testShelvesAndTheHighpassShapeTheEnds() {
        var settings = ParametricEQ.Settings()
        settings.lowFrequency = 100
        settings.lowGain = -12
        settings.highFrequency = 8_000
        settings.highGain = 6
        settings.highpass = 200
        let eq = ParametricEQ(sampleRate: rate, settings: settings)
        XCTAssertLessThan(eq.response(at: 50), -20, "the highpass cuts below its corner")
        XCTAssertEqual(eq.response(at: 1_000), 0, accuracy: 1)
        XCTAssertEqual(eq.response(at: 18_000), 6, accuracy: 1, "the high shelf lifts the top")

        var wild = ParametricEQ.Settings()
        wild.lowGain = 99
        wild.highMidQ = .nan
        let held = ParametricEQ(sampleRate: rate, settings: wild)
        XCTAssertEqual(held.settings.lowGain, 18)
        XCTAssertEqual(held.settings.highMidQ, 1)
    }
}
