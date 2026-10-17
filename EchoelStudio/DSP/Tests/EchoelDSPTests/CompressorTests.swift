import XCTest
@testable import EchoelDSP

final class CompressorTests: XCTestCase {
    private let rate = 48_000.0

    private func run(_ c: inout Compressor, amplitude: Float, frames: Int) -> [Float] {
        var l = (0..<frames).map { amplitude * Float(sin(Double($0) * 2 * .pi * 997 / 48_000)) }, r = l
        l.withUnsafeMutableBufferPointer { a in
            r.withUnsafeMutableBufferPointer { b in
                guard let x = a.baseAddress, let y = b.baseAddress else { return }
                c.process(left: x, right: y, frames: frames)
            }
        }
        return l
    }

    func testBelowTheThresholdNothingChanges() {
        var c = Compressor(sampleRate: rate)
        var settings = Compressor.Settings()
        settings.threshold = -20
        settings.knee = 0
        c.settings = settings
        let quiet = run(&c, amplitude: 0.05, frames: 4_800)
        let reference = (0..<4_800).map { 0.05 * Float(sin(Double($0) * 2 * .pi * 997 / 48_000)) }
        XCTAssertEqual(quiet, reference)
        XCTAssertEqual(c.reduction, 0)
    }

    func testALoudSignalSettlesAtTheRatio() {
        var settings = Compressor.Settings()
        settings.threshold = -20
        settings.ratio = 4
        settings.knee = 0
        settings.attack = 0.001
        settings.release = 0.05
        var c = Compressor(sampleRate: rate, settings: settings)
        // Peaks at −6 dBFS: 14 dB over, so 10.5 dB of reduction at 4:1.
        _ = run(&c, amplitude: 0.5, frames: 24_000)
        XCTAssertEqual(c.reduction, -10.5, accuracy: 0.8, "a peak detector settles just short of the peak target")
        XCTAssertEqual(c.target(at: -6), -10.5, accuracy: 1e-4)
        XCTAssertEqual(c.target(at: -30), 0)
        // It lets go at the release.
        _ = run(&c, amplitude: 0, frames: 24_000)
        XCTAssertEqual(c.reduction, 0, accuracy: 0.01)
    }

    func testTheKneeIsSmoothAndMixAndMakeupWork() {
        var settings = Compressor.Settings()
        settings.threshold = -20
        settings.knee = 12
        let c = Compressor(sampleRate: rate, settings: settings)
        XCTAssertEqual(c.target(at: -26), 0, accuracy: 1e-5, "the knee starts at its lower edge")
        XCTAssertLessThan(c.target(at: -20), 0, "and is already working at the threshold")
        XCTAssertGreaterThan(c.target(at: -20), c.target(at: -14))

        var parallel = Compressor.Settings()
        parallel.mix = 0
        parallel.makeup = 12
        var dry = Compressor(sampleRate: rate, settings: parallel)
        let out = run(&dry, amplitude: 0.9, frames: 1_000)
        let reference = (0..<1_000).map { 0.9 * Float(sin(Double($0) * 2 * .pi * 997 / 48_000)) }
        XCTAssertEqual(out, reference, "fully dry is the input")
        var bad = Compressor.Settings()
        bad.ratio = .nan
        XCTAssertEqual(Compressor(sampleRate: rate, settings: bad).settings.ratio, 4)
    }
}
