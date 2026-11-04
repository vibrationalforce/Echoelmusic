import XCTest
@testable import EchoelDSP

/// The Field's two meters read the master through these: the spectrum's bands light where the
/// sound is, and the scope's trace starts on a rising zero crossing so a steady tone stands still.
final class ScopeTraceTests: XCTestCase {
    /// Runs the trigger over `samples` into a trace of `length`.
    private static func capture(_ samples: [Float], length: Int) -> (trace: [Float], triggered: Bool) {
        var trace = [Float](repeating: 9, count: length)
        var triggered = false
        samples.withUnsafeBufferPointer { input in
            trace.withUnsafeMutableBufferPointer { output in
                guard let source = input.baseAddress, let target = output.baseAddress else { return }
                triggered = ScopeTrace.capture(source, count: input.count, into: target, length: length)
            }
        }
        return (trace, triggered)
    }

    private static func sine(_ hertz: Double, amplitude: Double, phase: Double, count: Int, rate: Double = 48_000) -> [Float] {
        (0..<count).map { (index: Int) -> Float in
            let angle = 2 * Double.pi * hertz * Double(index) / rate + phase
            return Float(amplitude * sin(angle))
        }
    }

    func testASteadyToneStartsAtTheSamePlaceWhateverItsPhase() {
        var traces: [[Float]] = []
        for phase in [0.3, 1.9, 4.4] {
            let samples = Self.sine(440, amplitude: 0.5, phase: phase, count: 2_048)
            let (trace, triggered) = Self.capture(samples, length: 256)
            XCTAssertTrue(triggered)
            XCTAssertGreaterThanOrEqual(trace[0], 0)
            XCTAssertLessThan(trace[0], 0.05, "the trace starts at the crossing")
            XCTAssertGreaterThan(trace[3], trace[0], "and rising")
            traces.append(trace)
        }
        for index in 0..<256 {
            XCTAssertEqual(traces[0][index], traces[1][index], accuracy: 0.03)
            XCTAssertEqual(traces[0][index], traces[2][index], accuracy: 0.03)
        }
    }

    func testSilenceDoesNotTriggerAndBadSamplesAreZero() {
        let samples: [Float] = [0, .nan, .infinity, 0, 0, 0, 0, 0]
        let (trace, triggered) = Self.capture(samples, length: 4)
        XCTAssertFalse(triggered)
        XCTAssertEqual(trace, [0, 0, 0, 0])
    }

    func testTheSpectrumLightsTheBandOfItsTone() {
        let analyzer = SpectrumAnalyzer(sampleRate: 48_000)
        let samples = Self.sine(1_000, amplitude: 0.5, phase: 0, count: analyzer.size)
        samples.withUnsafeBufferPointer { buffer in
            if let base = buffer.baseAddress { analyzer.push(base, count: buffer.count) }
        }
        _ = analyzer.analyze()
        var levels = [Double](repeating: -1, count: 30)
        levels.withUnsafeMutableBufferPointer { buffer in
            if let base = buffer.baseAddress { analyzer.bandLevels(into: base, count: 30) }
        }
        // 20 Hz … 20 kHz in 30 bands: 1 kHz lies in band floor(30 · log(50) / log(1000)) = 16.
        let loudest = levels.indices.max { levels[$0] < levels[$1] }
        XCTAssertEqual(loudest, 16)
        XCTAssertEqual(levels[16], (20 * log10(0.5) + 72) / 72, accuracy: 0.03, "−6 dBFS reads as −6 dBFS")
        XCTAssertLessThan(levels[2], 0.2, "the bass is dark")
        XCTAssertTrue(levels.allSatisfy { (0...1).contains($0) })
    }
}
