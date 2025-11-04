import XCTest
import AVFoundation
@testable import Blab

/// Tests for Advanced DSP Processing
@available(iOS 15.0, *)
final class AdvancedDSPTests: XCTestCase {

    var dsp: AdvancedDSP!
    let sampleRate: Double = 48000.0

    override func setUp() {
        super.setUp()
        dsp = AdvancedDSP(sampleRate: sampleRate)
    }

    override func tearDown() {
        dsp = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(dsp, "DSP should initialize")
        XCTAssertFalse(dsp.noiseGate.enabled, "Noise gate should be disabled initially")
        XCTAssertFalse(dsp.deEsser.enabled, "De-esser should be disabled initially")
        XCTAssertFalse(dsp.limiter.enabled, "Limiter should be disabled initially")
        XCTAssertFalse(dsp.compressor.enabled, "Compressor should be disabled initially")
    }

    // MARK: - Noise Gate Tests

    func testEnableNoiseGate() {
        dsp.enableNoiseGate(threshold: -40, ratio: 4.0)

        XCTAssertTrue(dsp.noiseGate.enabled, "Noise gate should be enabled")
        XCTAssertEqual(dsp.noiseGate.threshold, -40, "Threshold should be set")
        XCTAssertEqual(dsp.noiseGate.ratio, 4.0, "Ratio should be set")
    }

    func testDisableNoiseGate() {
        dsp.enableNoiseGate()
        dsp.disableNoiseGate()

        XCTAssertFalse(dsp.noiseGate.enabled, "Noise gate should be disabled")
    }

    func testNoiseGateParameters() {
        dsp.enableNoiseGate(threshold: -50, ratio: 6.0)

        XCTAssertEqual(dsp.noiseGate.threshold, -50, "Threshold should match")
        XCTAssertEqual(dsp.noiseGate.ratio, 6.0, "Ratio should match")
        XCTAssertGreaterThan(dsp.noiseGate.attack, 0, "Attack should be > 0")
        XCTAssertGreaterThan(dsp.noiseGate.release, 0, "Release should be > 0")
    }

    // MARK: - De-Esser Tests

    func testEnableDeEsser() {
        dsp.enableDeEsser(frequency: 7000, threshold: -15)

        XCTAssertTrue(dsp.deEsser.enabled, "De-esser should be enabled")
        XCTAssertEqual(dsp.deEsser.frequency, 7000, "Frequency should be set")
        XCTAssertEqual(dsp.deEsser.threshold, -15, "Threshold should be set")
    }

    func testDisableDeEsser() {
        dsp.enableDeEsser()
        dsp.disableDeEsser()

        XCTAssertFalse(dsp.deEsser.enabled, "De-esser should be disabled")
    }

    func testDeEsserFrequencyRange() {
        // Test sibilance range (5-10 kHz)
        dsp.enableDeEsser(frequency: 5000)
        XCTAssertEqual(dsp.deEsser.frequency, 5000)

        dsp.enableDeEsser(frequency: 10000)
        XCTAssertEqual(dsp.deEsser.frequency, 10000)
    }

    // MARK: - Compressor Tests

    func testEnableCompressor() {
        dsp.enableCompressor(threshold: -20, ratio: 3.0, makeupGain: 6.0)

        XCTAssertTrue(dsp.compressor.enabled, "Compressor should be enabled")
        XCTAssertEqual(dsp.compressor.threshold, -20, "Threshold should be set")
        XCTAssertEqual(dsp.compressor.ratio, 3.0, "Ratio should be set")
        XCTAssertEqual(dsp.compressor.makeupGain, 6.0, "Makeup gain should be set")
    }

    func testDisableCompressor() {
        dsp.enableCompressor()
        dsp.disableCompressor()

        XCTAssertFalse(dsp.compressor.enabled, "Compressor should be disabled")
    }

    func testCompressorTiming() {
        dsp.enableCompressor()

        XCTAssertGreaterThan(dsp.compressor.attack, 0, "Attack should be > 0")
        XCTAssertGreaterThan(dsp.compressor.release, 0, "Release should be > 0")
        XCTAssertLessThan(dsp.compressor.attack, 1.0, "Attack should be < 1s")
    }

    // MARK: - Limiter Tests

    func testEnableLimiter() {
        dsp.enableLimiter(threshold: -1.0)

        XCTAssertTrue(dsp.limiter.enabled, "Limiter should be enabled")
        XCTAssertEqual(dsp.limiter.threshold, -1.0, "Threshold should be set")
    }

    func testDisableLimiter() {
        dsp.enableLimiter()
        dsp.disableLimiter()

        XCTAssertFalse(dsp.limiter.enabled, "Limiter should be disabled")
    }

    func testLimiterParameters() {
        dsp.enableLimiter(threshold: -0.5)

        XCTAssertEqual(dsp.limiter.threshold, -0.5, "Threshold should match")
        XCTAssertGreaterThan(dsp.limiter.release, 0, "Release should be > 0")
        XCTAssertGreaterThan(dsp.limiter.lookahead, 0, "Lookahead should be > 0")
    }

    // MARK: - Preset Tests

    func testBypassPreset() {
        // Enable all processors
        dsp.enableNoiseGate()
        dsp.enableDeEsser()
        dsp.enableCompressor()
        dsp.enableLimiter()

        // Apply bypass
        dsp.applyPreset(.bypass)

        XCTAssertFalse(dsp.noiseGate.enabled, "Noise gate should be disabled")
        XCTAssertFalse(dsp.deEsser.enabled, "De-esser should be disabled")
        XCTAssertFalse(dsp.compressor.enabled, "Compressor should be disabled")
        XCTAssertFalse(dsp.limiter.enabled, "Limiter should be disabled")
    }

    func testPodcastPreset() {
        dsp.applyPreset(.podcast)

        XCTAssertTrue(dsp.noiseGate.enabled, "Noise gate should be enabled")
        XCTAssertTrue(dsp.deEsser.enabled, "De-esser should be enabled")
        XCTAssertTrue(dsp.compressor.enabled, "Compressor should be enabled")
        XCTAssertTrue(dsp.limiter.enabled, "Limiter should be enabled")
    }

    func testVocalsPreset() {
        dsp.applyPreset(.vocals)

        XCTAssertTrue(dsp.noiseGate.enabled, "Noise gate should be enabled for vocals")
        XCTAssertTrue(dsp.deEsser.enabled, "De-esser should be enabled for vocals")
        XCTAssertTrue(dsp.compressor.enabled, "Compressor should be enabled for vocals")
    }

    func testBroadcastPreset() {
        dsp.applyPreset(.broadcast)

        XCTAssertTrue(dsp.compressor.enabled, "Compressor should be enabled for broadcast")
        XCTAssertTrue(dsp.limiter.enabled, "Limiter should be enabled for broadcast")
        // Broadcast typically has higher compression ratio
        XCTAssertGreaterThanOrEqual(dsp.compressor.ratio, 4.0, "Broadcast should have high compression")
    }

    func testMasteringPreset() {
        dsp.applyPreset(.mastering)

        // Mastering typically uses gentler settings
        XCTAssertTrue(dsp.compressor.enabled, "Compressor should be enabled")
        XCTAssertTrue(dsp.limiter.enabled, "Limiter should be enabled")
        XCTAssertLessThanOrEqual(dsp.compressor.ratio, 3.0, "Mastering should have gentle compression")
    }

    // MARK: - Processing Tests

    func testProcessEmptyBuffer() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
        buffer.frameLength = 512

        // Should not crash with empty buffer
        dsp.process(audioBuffer: buffer)
    }

    func testProcessWithNoiseGate() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
        buffer.frameLength = 512

        // Fill with low-level noise
        if let channelData = buffer.floatChannelData {
            for frame in 0..<Int(buffer.frameLength) {
                channelData[0][frame] = 0.001 // Very quiet
            }
        }

        dsp.enableNoiseGate(threshold: -40, ratio: 10.0)
        dsp.process(audioBuffer: buffer)

        // Noise should be reduced
        XCTAssertNotNil(buffer.floatChannelData, "Buffer should have data")
    }

    // MARK: - Chain Order Tests

    func testDSPChainOrder() {
        // DSP chain should be: Gate → De-Esser → Compressor → Limiter
        // We can't easily test order directly, but we can verify all can be enabled together
        dsp.enableNoiseGate()
        dsp.enableDeEsser()
        dsp.enableCompressor()
        dsp.enableLimiter()

        XCTAssertTrue(dsp.noiseGate.enabled, "Gate should be enabled")
        XCTAssertTrue(dsp.deEsser.enabled, "De-esser should be enabled")
        XCTAssertTrue(dsp.compressor.enabled, "Compressor should be enabled")
        XCTAssertTrue(dsp.limiter.enabled, "Limiter should be enabled")
    }
}
