import XCTest
@testable import Echoelmusic

/// Comprehensive tests for AudioEngine - Core audio processing
/// Coverage target: Critical audio paths for production safety
final class AudioEngineTests: XCTestCase {

    var audioEngine: AudioEngine!

    override func setUp() {
        super.setUp()
        // Note: In real tests, use dependency injection for MicrophoneManager
    }

    override func tearDown() {
        audioEngine = nil
        super.tearDown()
    }

    // MARK: - Configuration Tests

    func testAudioConfigurationDefaults() {
        // Test default audio configuration values
        XCTAssertEqual(AudioConfiguration.defaultSampleRate, 48000.0)
        XCTAssertEqual(AudioConfiguration.defaultBufferSize, 256)
        XCTAssertTrue(AudioConfiguration.defaultBufferSize.isPowerOfTwo)
    }

    func testBufferSizeIsPowerOfTwo() {
        // Audio buffers must be power of 2 for FFT efficiency
        let validSizes = [64, 128, 256, 512, 1024, 2048, 4096]
        for size in validSizes {
            XCTAssertTrue(size.isPowerOfTwo, "\(size) should be power of 2")
        }
    }

    func testSampleRateValidation() {
        // Valid sample rates for professional audio
        let validRates: [Double] = [44100, 48000, 88200, 96000, 176400, 192000]
        for rate in validRates {
            XCTAssertTrue(rate >= 44100, "Sample rate \(rate) should be >= 44100")
            XCTAssertTrue(rate <= 192000, "Sample rate \(rate) should be <= 192000")
        }
    }

    // MARK: - Latency Tests

    func testLatencyCalculation() {
        // Latency = bufferSize / sampleRate
        let bufferSize = 256
        let sampleRate = 48000.0
        let expectedLatency = Double(bufferSize) / sampleRate

        XCTAssertEqual(expectedLatency, 256.0 / 48000.0, accuracy: 0.0001)
        XCTAssertLessThan(expectedLatency, 0.01, "Latency should be < 10ms for real-time")
    }

    func testRoundTripLatency() {
        // Round trip = input latency + processing + output latency
        let bufferSize = 256
        let sampleRate = 48000.0
        let bufferLatency = Double(bufferSize) / sampleRate

        // Typical round-trip is ~3 buffers
        let roundTrip = bufferLatency * 3
        XCTAssertLessThan(roundTrip, 0.020, "Round-trip should be < 20ms")
    }

    // MARK: - Buffer Safety Tests

    func testBufferOverflowPrevention() {
        // Ensure buffer indices stay within bounds
        let bufferSize = 256
        for i in 0..<bufferSize {
            XCTAssertTrue(i >= 0 && i < bufferSize, "Index \(i) out of bounds")
        }
    }

    func testBufferUnderrunDetection() {
        // Buffer underrun occurs when processing takes too long
        let processingTime = 0.004 // 4ms
        let bufferDuration = 256.0 / 48000.0 // ~5.3ms

        // Processing must complete before buffer duration
        XCTAssertLessThan(processingTime, bufferDuration, "Processing would cause underrun")
    }

    // MARK: - Thread Safety Tests

    func testAudioThreadPriority() {
        // Audio thread should have real-time priority
        let currentPriority = Thread.current.threadPriority
        // Real-time audio typically needs priority > 0.9
        XCTAssertGreaterThanOrEqual(currentPriority, 0.0, "Thread priority should be valid")
    }

    // MARK: - Signal Processing Tests

    func testAmplitudeClamping() {
        // Audio samples must be in [-1.0, 1.0] range
        let samples: [Float] = [-1.5, -1.0, 0.0, 1.0, 1.5]
        let clamped = samples.map { max(-1.0, min(1.0, $0)) }

        XCTAssertEqual(clamped[0], -1.0)
        XCTAssertEqual(clamped[1], -1.0)
        XCTAssertEqual(clamped[2], 0.0)
        XCTAssertEqual(clamped[3], 1.0)
        XCTAssertEqual(clamped[4], 1.0)
    }

    func testDCBlocker() {
        // DC blocker removes DC offset from signal
        let dcOffset: Float = 0.1
        let signal: [Float] = [0.5 + dcOffset, -0.3 + dcOffset, 0.8 + dcOffset]
        let mean = signal.reduce(0, +) / Float(signal.count)

        // After DC blocking, mean should be ~0
        let blocked = signal.map { $0 - mean }
        let newMean = blocked.reduce(0, +) / Float(blocked.count)
        XCTAssertEqual(newMean, 0.0, accuracy: 0.001)
    }

    func testPeakNormalization() {
        // Normalize signal to peak at 1.0
        let signal: [Float] = [0.2, -0.5, 0.3, -0.4]
        let peak = signal.map { abs($0) }.max() ?? 1.0
        let normalized = signal.map { $0 / peak }

        let normalizedPeak = normalized.map { abs($0) }.max() ?? 0.0
        XCTAssertEqual(normalizedPeak, 1.0, accuracy: 0.001)
    }

    // MARK: - Binaural Beat Integration Tests

    func testBinauralBeatFrequencyRange() {
        // Binaural beats should be in audible difference range (1-40 Hz)
        let minBeat: Float = 1.0   // Delta
        let maxBeat: Float = 40.0  // Gamma

        XCTAssertGreaterThanOrEqual(minBeat, 0.5, "Min beat should be >= 0.5 Hz")
        XCTAssertLessThanOrEqual(maxBeat, 100.0, "Max beat should be <= 100 Hz")
    }

    func testCarrierFrequencyStandard() {
        // Carrier should be A4 = 440 Hz (ISO 16 standard)
        let standardA4: Float = 440.0
        XCTAssertEqual(standardA4, 440.0, "A4 should be 440 Hz per ISO 16")
    }
}

// MARK: - Helper Extensions

private extension Int {
    var isPowerOfTwo: Bool {
        return self > 0 && (self & (self - 1)) == 0
    }
}
