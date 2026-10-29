import XCTest
@testable import EchoelDSP

/// The camera pulse analyzer on synthetic fingertip frames: a steady pulse locks within tolerance,
/// nothing locks without a finger, on a flat scene or on a moving finger, and a confidence cannot
/// outlive the measurement it describes. Deterministic (seeded noise), no camera.
final class PulseAnalyzerTests: XCTestCase {

    /// One averaged frame.
    private struct Frame {
        var red: Float
        var green: Float
        var blue: Float
    }

    /// `seconds` of fingertip frames at `rate` Hz: red dominant (a lit finger) with a pulse of
    /// `pulseHz` and `swing` peak amplitude on the red channel, plus a little seeded noise and a
    /// slow drift (breathing, exposure settle) the detrend must survive.
    private func fingerFrames(pulseHz: Double, rate: Double, seconds: Double, swing: Float = 0.01,
                              noise: Float = 0.001, seed: UInt64 = 7) -> [Frame] {
        var rng = SeededRNG(seed: seed)
        let count = Int(rate * seconds)
        var frames: [Frame] = []
        frames.reserveCapacity(count)
        for index in 0..<count {
            let t = Double(index) / rate
            let pulse = Float(sin(2 * Double.pi * pulseHz * t))
            let drift = Float(0.01 * sin(2 * Double.pi * 0.1 * t))
            let jitter = (rng.unit() * 2 - 1) * noise
            let red: Float = 0.45 + swing * pulse + drift + jitter
            frames.append(Frame(red: red, green: 0.15 + jitter, blue: 0.10 + jitter))
        }
        return frames
    }

    /// Feeds `frames` at `rate` Hz starting at `startTime` seconds; returns the time after the last frame.
    @discardableResult
    private func feed(_ frames: [Frame], into analyzer: inout PulseAnalyzer, rate: Double,
                      from startTime: Double = 0) -> Double {
        var time = startTime
        for frame in frames {
            analyzer.process(red: frame.red, green: frame.green, blue: frame.blue, at: time)
            time += 1 / rate
        }
        return time
    }

    // MARK: - Locking

    func testASteadyFingertipPulseLocksAtItsRate() {
        var analyzer = PulseAnalyzer()
        analyzer.start()
        feed(fingerFrames(pulseHz: 1.1, rate: 15, seconds: 30), into: &analyzer, rate: 15)
        XCTAssertTrue(analyzer.isFingerDetected)
        XCTAssertEqual(analyzer.estimatedBPM, 66, accuracy: 4)
        XCTAssertGreaterThan(analyzer.confidence, PulseTrust.displayThreshold)
        XCTAssertGreaterThan(analyzer.autoStrength, PulseTrust.trustAutoFloor, "a steady pulse is periodic")
        XCTAssertTrue(PulseTrust.shouldPublish(bpm: analyzer.estimatedBPM, confidence: analyzer.confidence,
                                               autoStrength: analyzer.autoStrength))
        XCTAssertFalse(analyzer.rrIntervalsMs.isEmpty)
        XCTAssertEqual(analyzer.rrIntervalsMs.count, analyzer.beatTimes.count, "beat times stay 1:1 with the intervals")
        for interval in analyzer.rrIntervalsMs {
            XCTAssertEqual(interval, 60_000 / 66, accuracy: 120)
        }
    }

    func testAFasterPulseLocksTooAndTheWaveformHasTheTraceLength() {
        var analyzer = PulseAnalyzer()
        analyzer.start()
        feed(fingerFrames(pulseHz: 1.5, rate: 15, seconds: 30), into: &analyzer, rate: 15)
        XCTAssertEqual(analyzer.estimatedBPM, 90, accuracy: 5)
        XCTAssertEqual(analyzer.waveform.count, PulseAnalyzer.waveformDisplaySamples)
        XCTAssertTrue(analyzer.waveform.allSatisfy { abs($0) <= 1.0001 })
    }

    /// A camera that delivers 10 fps instead of the nominal 15: the band-pass is re-tuned to the
    /// measured rate and the pulse still locks at its rate.
    func testTheFilterFollowsTheMeasuredFrameRate() {
        var analyzer = PulseAnalyzer()
        analyzer.start()
        feed(fingerFrames(pulseHz: 1.1, rate: 10, seconds: 30), into: &analyzer, rate: 10)
        XCTAssertEqual(analyzer.estimatedBPM, 66, accuracy: 4)
        XCTAssertEqual(analyzer.actualRate, 10, accuracy: 0.5)
    }

    // MARK: - Refusing

    func testADarkLensIsNoFingerAndNoPulse() {
        var analyzer = PulseAnalyzer()
        analyzer.start()
        let dark = (0..<300).map { _ in Frame(red: 0.05, green: 0.05, blue: 0.05) }
        feed(dark, into: &analyzer, rate: 15)
        XCTAssertFalse(analyzer.isFingerDetected)
        XCTAssertEqual(analyzer.estimatedBPM, 0)
        XCTAssertEqual(analyzer.confidence, 0)
    }

    func testAFlatFingertipHasNoPulse() {
        var analyzer = PulseAnalyzer()
        analyzer.start()
        let flat = (0..<300).map { _ in Frame(red: 0.45, green: 0.15, blue: 0.10) }
        feed(flat, into: &analyzer, rate: 15)
        XCTAssertTrue(analyzer.isFingerDetected)
        XCTAssertEqual(analyzer.estimatedBPM, 0)
        XCTAssertFalse(PulseTrust.shouldPublish(bpm: analyzer.estimatedBPM, confidence: analyzer.confidence,
                                                autoStrength: analyzer.autoStrength))
    }

    /// A red swing of 0.3 is the finger moving, not a pulse (a real one tops out near 0.16):
    /// its steady period must not earn a rate.
    func testAMovingFingerEarnsNoPulse() {
        var analyzer = PulseAnalyzer()
        analyzer.start()
        feed(fingerFrames(pulseHz: 1.0, rate: 15, seconds: 30, swing: 0.15), into: &analyzer, rate: 15)
        XCTAssertEqual(analyzer.estimatedBPM, 0)
        XCTAssertTrue(PulseAnalyzer.isMotionAmplitude(analyzer.filteredAmplitude))
    }

    func testNothingIsAnalyzedBeforeStart() {
        var analyzer = PulseAnalyzer()
        feed(fingerFrames(pulseHz: 1.1, rate: 15, seconds: 20), into: &analyzer, rate: 15)
        XCTAssertEqual(analyzer.estimatedBPM, 0)
        XCTAssertFalse(analyzer.isDetecting)
    }

    // MARK: - Letting go

    func testALiftedFingerClearsTheRate() {
        var analyzer = PulseAnalyzer()
        analyzer.start()
        let end = feed(fingerFrames(pulseHz: 1.1, rate: 15, seconds: 30), into: &analyzer, rate: 15)
        XCTAssertGreaterThan(analyzer.estimatedBPM, 0)
        let dark = (0..<150).map { _ in Frame(red: 0.05, green: 0.05, blue: 0.05) }
        feed(dark, into: &analyzer, rate: 15, from: end)
        XCTAssertFalse(analyzer.isFingerDetected)
        XCTAssertEqual(analyzer.estimatedBPM, 0, "ten seconds without a finger leaves no phantom rate")
        XCTAssertTrue(analyzer.rrIntervalsMs.isEmpty)
    }

    /// The finger stays, the pulse signal stops: the confidence falls to zero within
    /// `confidenceZeroSeconds` of the last real measurement instead of describing a held number.
    func testAConfidenceCannotOutliveItsMeasurement() {
        var analyzer = PulseAnalyzer()
        analyzer.start()
        let end = feed(fingerFrames(pulseHz: 1.1, rate: 15, seconds: 30), into: &analyzer, rate: 15)
        XCTAssertGreaterThan(analyzer.confidence, PulseTrust.displayThreshold)
        let flat = (0..<450).map { _ in Frame(red: 0.45, green: 0.15, blue: 0.10) }   // 30 s
        feed(flat, into: &analyzer, rate: 15, from: end)
        XCTAssertTrue(analyzer.isFingerDetected)
        XCTAssertLessThan(analyzer.confidence, 0.05)
        XCTAssertFalse(PulseTrust.shouldPublish(bpm: analyzer.estimatedBPM, confidence: analyzer.confidence,
                                                autoStrength: analyzer.autoStrength))
    }

    func testResetForgetsTheContactAndTheEstimate() {
        var analyzer = PulseAnalyzer()
        analyzer.start()
        feed(fingerFrames(pulseHz: 1.1, rate: 15, seconds: 30), into: &analyzer, rate: 15)
        analyzer.reset()
        XCTAssertFalse(analyzer.isFingerDetected)
        XCTAssertFalse(analyzer.isDetecting)
        XCTAssertEqual(analyzer.estimatedBPM, 0)
        XCTAssertEqual(analyzer.confidence, 0)
        XCTAssertTrue(analyzer.waveform.isEmpty)
    }

    func testARecoveryFlushKeepsOrDropsTheEstimateAsTold() {
        var kept = PulseAnalyzer()
        kept.start()
        feed(fingerFrames(pulseHz: 1.1, rate: 15, seconds: 30), into: &kept, rate: 15)
        let bpm = kept.estimatedBPM
        let confidence = kept.confidence
        kept.resetForRecovery(keepEstimate: true)
        XCTAssertEqual(kept.estimatedBPM, bpm)
        XCTAssertEqual(kept.confidence, confidence * 0.5, accuracy: 1e-9)
        XCTAssertEqual(kept.autoStrength, 0, "the optical state is always flushed")
        XCTAssertTrue(kept.isFingerDetected, "a mid-take flush keeps the contact decision")

        var dropped = PulseAnalyzer()
        dropped.start()
        feed(fingerFrames(pulseHz: 1.1, rate: 15, seconds: 30), into: &dropped, rate: 15)
        dropped.resetForRecovery(keepEstimate: false)
        XCTAssertEqual(dropped.estimatedBPM, 0)
        XCTAssertEqual(dropped.confidence, 0)
    }

    // MARK: - Pure laws

    func testFingerFrameAcquiresHardAndHoldsEasy() {
        XCTAssertFalse(PulseAnalyzer.isFingerFrame(red: 0.25, green: 0.1, blue: 0.1, wasDetected: false, pulseCorroborated: false))
        XCTAssertTrue(PulseAnalyzer.isFingerFrame(red: 0.30, green: 0.1, blue: 0.1, wasDetected: false, pulseCorroborated: false))
        XCTAssertTrue(PulseAnalyzer.isFingerFrame(red: 0.15, green: 0.05, blue: 0.05, wasDetected: true, pulseCorroborated: false))
        XCTAssertFalse(PulseAnalyzer.isFingerFrame(red: 0.10, green: 0.05, blue: 0.05, wasDetected: true, pulseCorroborated: false))
        XCTAssertTrue(PulseAnalyzer.isFingerFrame(red: 0.08, green: 0.01, blue: 0.01, wasDetected: true, pulseCorroborated: true))
        XCTAssertFalse(PulseAnalyzer.isFingerFrame(red: 0.04, green: 0.01, blue: 0.01, wasDetected: true, pulseCorroborated: true))
        // Red dominance gates a non-finger scene at every floor; a saturated frame is a pressed finger.
        XCTAssertFalse(PulseAnalyzer.isFingerFrame(red: 0.5, green: 0.5, blue: 0.5, wasDetected: true, pulseCorroborated: true))
        XCTAssertTrue(PulseAnalyzer.isFingerFrame(red: 0.95, green: 0.95, blue: 0.95, wasDetected: false, pulseCorroborated: false))
    }

    func testOctaveCorrectionActsOnlyInOctaveBands() {
        XCTAssertEqual(PulseAnalyzer.octaveCorrected(raw: 36, autoBPM: 72, autoStrength: 0.8), 72)
        XCTAssertEqual(PulseAnalyzer.octaveCorrected(raw: 144, autoBPM: 72, autoStrength: 0.8), 72)
        XCTAssertEqual(PulseAnalyzer.octaveCorrected(raw: 100, autoBPM: 72, autoStrength: 0.8), 100, "a genuine change passes")
        XCTAssertEqual(PulseAnalyzer.octaveCorrected(raw: 36, autoBPM: 72, autoStrength: 0.3), 36, "weak periodicity is ignored")
    }

    func testAutoTrustPullsTowardTheFundamentalByStrength() {
        XCTAssertEqual(PulseAnalyzer.autoTrust(estimate: 100, autoBPM: 70, autoStrength: 0.3), 100)
        let moderate = PulseAnalyzer.autoTrust(estimate: 100, autoBPM: 70, autoStrength: 0.6)
        let strong = PulseAnalyzer.autoTrust(estimate: 100, autoBPM: 70, autoStrength: 0.9)
        XCTAssertLessThan(moderate, 100)
        XCTAssertLessThan(strong, moderate)
        XCTAssertEqual(strong, 100 * 0.2 + 70 * 0.8, accuracy: 1e-9, "the pull is capped at 80 %")
    }

    func testSlewAndRefractoryAndCeiling() {
        XCTAssertEqual(PulseAnalyzer.slewLimited(previous: 60, target: 100, maxDelta: 8), 68)
        XCTAssertEqual(PulseAnalyzer.slewLimited(previous: 60, target: 40, maxDelta: 8), 52)
        XCTAssertEqual(PulseAnalyzer.slewLimited(previous: 60, target: 100, maxDelta: 0), 100)
        XCTAssertEqual(PulseAnalyzer.refractorySeconds(autoBPM: 60), 0.5)
        XCTAssertEqual(PulseAnalyzer.refractorySeconds(autoBPM: 0), 0.3)
        XCTAssertEqual(PulseAnalyzer.refractorySeconds(autoBPM: 40), 0.6)
        XCTAssertTrue(PulseAnalyzer.isWithinRefractory(previous: 10, candidate: 10.2, autoBPM: 60))
        XCTAssertFalse(PulseAnalyzer.isWithinRefractory(previous: 10, candidate: 11, autoBPM: 60))
        XCTAssertFalse(PulseAnalyzer.isWithinRefractory(previous: 10, candidate: .nan, autoBPM: 60), "fails open")
        XCTAssertEqual(PulseAnalyzer.confidenceCeiling(forAge: 1), 1)
        XCTAssertEqual(PulseAnalyzer.confidenceCeiling(forAge: 5), 0.5, accuracy: 1e-9)
        XCTAssertEqual(PulseAnalyzer.confidenceCeiling(forAge: 9), 0)
        XCTAssertEqual(PulseAnalyzer.confidenceCeiling(forAge: .infinity), 0)
    }

    func testTheTraceGainComesFromTheLongerWindow() {
        var signal = [Float](repeating: 0.1, count: 300)
        signal[0] = 1.0   // one strong beat long before the displayed window
        let trace = PulseAnalyzer.normalizedTrace(signal, display: 90, gainWindow: 300)
        XCTAssertEqual(trace.count, 90)
        XCTAssertEqual(try XCTUnwrap(trace.last), 0.1, accuracy: 1e-6, "divided by the strong beat, not by the quiet display window")
        XCTAssertTrue(PulseAnalyzer.normalizedTrace([0.5], display: 90, gainWindow: 300).isEmpty)
    }
}

/// SplitMix64, as in `PulsePeriodEstimatorTests`, so the package's tests need nothing outside it.
private struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform Float in [0, 1).
    mutating func unit() -> Float {
        Float(next() >> 40) / Float(1 << 24)
    }
}
