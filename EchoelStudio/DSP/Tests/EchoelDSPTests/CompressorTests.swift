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

    /// A turned Makeup glides to the new gain in ~10 ms instead of stepping the output in one
    /// sample — a MIDI knob moves it in steps, a zipper otherwise — and settled, the compressor
    /// plays the setting itself (audit 2026-10-23).
    func testAChangedMakeupGlidesInsteadOfStepping() {
        var settings = Compressor.Settings()
        settings.ratio = 1    // no reduction: the output is the input times the makeup
        settings.knee = 0
        var c = Compressor(sampleRate: rate, settings: settings)
        _ = run(&c, amplitude: 0.25, frames: 1_024)
        settings.makeup = 12
        c.settings = settings
        let after = run(&c, amplitude: 0.25, frames: 4_800)
        func input(_ n: Int) -> Float { 0.25 * Float(sin(Double(n) * 2 * .pi * 997 / 48_000)) }
        // Sample 12 sits near the top of the 997 Hz sine; 4 752 near its bottom.
        XCTAssertLessThan(after[12] / input(12), 1.2, "12 dB up arrives gradually, not in one sample")
        XCTAssertEqual(after[4_752] / input(4_752), Float(Foundation.pow(10, 12.0 / 20)), accuracy: 0.01, "and arrives")
    }

    /// Settled, the compressor plays the makeup itself — not 3.98101 for 12 dB, where a Float glide
    /// stops moving short of 3.98107 (review 2026-10-23).
    func testASettledMakeupIsTheSettingItself() {
        var settings = Compressor.Settings()
        settings.ratio = 1    // no reduction: the output is the input times the makeup
        settings.knee = 0
        var c = Compressor(sampleRate: rate, settings: settings)
        _ = run(&c, amplitude: 0.25, frames: 1_024)
        settings.makeup = 12
        c.settings = settings
        _ = run(&c, amplitude: 0.25, frames: 96_000)
        var left: [Float] = [0.25], right: [Float] = [0.25]
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                c.process(left: lp, right: rp, frames: 1)
            }
        }
        XCTAssertEqual(left[0], 0.25 * Float(Foundation.pow(10, 12.0 / 20)), "exactly the setting")
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
