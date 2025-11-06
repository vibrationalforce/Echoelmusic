import XCTest
@testable import Echoelmusic

/// Tests for AppConfiguration constants
class AppConfigurationTests: XCTestCase {

    // MARK: - Control Loop Tests

    func testControlLoopFrequency() {
        XCTAssertEqual(AppConfiguration.controlLoopFrequency, 60.0)
        XCTAssertGreaterThan(AppConfiguration.controlLoopFrequency, 0.0)
    }

    func testControlLoopQoS() {
        XCTAssertEqual(AppConfiguration.controlLoopQoS, .userInteractive)
    }

    // MARK: - Audio Configuration Tests

    func testAudioSampleRate() {
        XCTAssertEqual(AppConfiguration.Audio.sampleRate, 48000.0)
    }

    func testAudioBufferSize() {
        XCTAssertEqual(AppConfiguration.Audio.bufferSize, 512)
        XCTAssertGreaterThan(AppConfiguration.Audio.bufferSize, 0)
    }

    func testAudioChannels() {
        XCTAssertEqual(AppConfiguration.Audio.maxChannels, 2)
    }

    func testVolumeRange() {
        let range = AppConfiguration.Audio.volumeRange
        XCTAssertEqual(range.lowerBound, 0.0)
        XCTAssertEqual(range.upperBound, 1.0)
    }

    // MARK: - Filter Configuration Tests

    func testFilterFrequencyRange() {
        XCTAssertEqual(AppConfiguration.Filter.minFrequency, 200.0)
        XCTAssertEqual(AppConfiguration.Filter.maxFrequency, 8000.0)
        XCTAssertGreaterThan(AppConfiguration.Filter.maxFrequency, AppConfiguration.Filter.minFrequency)
    }

    func testFilterDefaultValues() {
        let defaultFreq = AppConfiguration.Filter.defaultFrequency
        XCTAssertGreaterThanOrEqual(defaultFreq, AppConfiguration.Filter.minFrequency)
        XCTAssertLessThanOrEqual(defaultFreq, AppConfiguration.Filter.maxFrequency)
    }

    func testFilterResonanceRange() {
        XCTAssertEqual(AppConfiguration.Filter.minResonance, 0.5)
        XCTAssertEqual(AppConfiguration.Filter.maxResonance, 10.0)
    }

    // MARK: - Biofeedback Configuration Tests

    func testHeartRateRange() {
        XCTAssertEqual(AppConfiguration.Biofeedback.minHeartRate, 40.0)
        XCTAssertEqual(AppConfiguration.Biofeedback.maxHeartRate, 180.0)
        XCTAssertGreaterThan(AppConfiguration.Biofeedback.maxHeartRate, AppConfiguration.Biofeedback.minHeartRate)
    }

    func testCoherenceThresholds() {
        let low = AppConfiguration.Biofeedback.lowCoherenceThreshold
        let high = AppConfiguration.Biofeedback.highCoherenceThreshold

        XCTAssertEqual(low, 40.0)
        XCTAssertEqual(high, 60.0)
        XCTAssertGreaterThan(high, low)
    }

    func testBreathingRateRange() {
        let min = AppConfiguration.Biofeedback.minBreathingRate
        let max = AppConfiguration.Biofeedback.maxBreathingRate
        let optimal = AppConfiguration.Biofeedback.optimalBreathingRate

        XCTAssertEqual(min, 4.0)
        XCTAssertEqual(max, 30.0)
        XCTAssertEqual(optimal, 6.0)

        XCTAssertGreaterThanOrEqual(optimal, min)
        XCTAssertLessThanOrEqual(optimal, max)
    }

    func testHRVBufferSize() {
        XCTAssertEqual(AppConfiguration.Biofeedback.hrvBufferSize, 120)
        XCTAssertGreaterThan(AppConfiguration.Biofeedback.hrvBufferSize, 0)
    }

    // MARK: - Spatial Audio Configuration Tests

    func testSpatialAudioMaxSources() {
        XCTAssertEqual(AppConfiguration.SpatialAudio.maxSources, 16)
        XCTAssertGreaterThan(AppConfiguration.SpatialAudio.maxSources, 0)
    }

    func testSpatialAudioModes() {
        let modes = AppConfiguration.SpatialAudio.Mode.allCases
        XCTAssertEqual(modes.count, 6)
        XCTAssertTrue(modes.contains(.stereo))
        XCTAssertTrue(modes.contains(.afa))
    }

    // MARK: - MIDI Configuration Tests

    func testMIDIConfiguration() {
        XCTAssertTrue(AppConfiguration.MIDI.midi2Enabled)
        XCTAssertEqual(AppConfiguration.MIDI.mpeMemberChannels, 15)
        XCTAssertEqual(AppConfiguration.MIDI.pitchBendRange, 48)
    }

    func testMIDICCIndices() {
        XCTAssertEqual(AppConfiguration.MIDI.brightnessCCIndex, 74)
        XCTAssertEqual(AppConfiguration.MIDI.timbreCCIndex, 71)
    }

    // MARK: - Lighting Configuration Tests

    func testDMXConfiguration() {
        XCTAssertEqual(AppConfiguration.Lighting.dmxUniverseSize, 512)
        XCTAssertEqual(AppConfiguration.Lighting.artNetPort, 6454)
    }

    func testPush3Configuration() {
        let gridSize = AppConfiguration.Lighting.push3GridSize
        XCTAssertEqual(gridSize.rows, 8)
        XCTAssertEqual(gridSize.cols, 8)
    }

    // MARK: - Visual Configuration Tests

    func testVisualModes() {
        let modes = AppConfiguration.Visual.Mode.allCases
        XCTAssertEqual(modes.count, 5)
        XCTAssertTrue(modes.contains(.cymatics))
        XCTAssertTrue(modes.contains(.particles))
    }

    func testVisualFrameRate() {
        XCTAssertEqual(AppConfiguration.Visual.targetFrameRate, 60)
    }

    // MARK: - Recording Configuration Tests

    func testRecordingConfiguration() {
        XCTAssertEqual(AppConfiguration.Recording.maxTracksPerSession, 8)
        XCTAssertEqual(AppConfiguration.Recording.defaultBitDepth, 24)
        XCTAssertEqual(AppConfiguration.Recording.defaultSampleRate, 48000.0)
    }

    // MARK: - Environment Tests

    func testEnvironment() {
        #if DEBUG
        XCTAssertEqual(AppConfiguration.currentEnvironment, .development)
        #else
        XCTAssertEqual(AppConfiguration.currentEnvironment, .production)
        #endif
    }

    // MARK: - Feature Flags Tests

    func testFeatureFlags() {
        // Phase 5 features should be disabled by default
        XCTAssertFalse(AppConfiguration.FeatureFlags.enableAIComposition)

        // Future features should be disabled
        XCTAssertFalse(AppConfiguration.FeatureFlags.enableGazeTracking)
    }

    // MARK: - Performance Configuration Tests

    func testPerformanceThresholds() {
        XCTAssertEqual(AppConfiguration.Performance.memoryWarningThreshold, 150)
        XCTAssertEqual(AppConfiguration.Performance.cpuWarningThreshold, 80.0)
    }
}
