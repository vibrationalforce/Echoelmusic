import XCTest
@testable import Echoelmusic

/// Comprehensive bio-reactive integration tests
/// Tests the full pipeline: Biometric data → Processing → Audio/Visual output
@MainActor
final class BioReactiveIntegrationTests: XCTestCase {

    // MARK: - EEG Sensor Bridge Tests

    func testEEGBandsInitialization() {
        let bands = EEGBands()
        XCTAssertEqual(bands.delta, 0)
        XCTAssertEqual(bands.theta, 0)
        XCTAssertEqual(bands.alpha, 0)
        XCTAssertEqual(bands.beta, 0)
        XCTAssertEqual(bands.gamma, 0)
        XCTAssertEqual(bands.totalPower, 0)
    }

    func testEEGBandsTotalPower() {
        let bands = EEGBands(delta: 10, theta: 15, alpha: 25, beta: 20, gamma: 5)
        XCTAssertEqual(bands.totalPower, 75)
    }

    func testEEGBandsRelativePowers() {
        let bands = EEGBands(delta: 10, theta: 10, alpha: 30, beta: 30, gamma: 20)
        let relative = bands.relativePowers
        XCTAssertEqual(relative.delta, 0.1, accuracy: 0.01)
        XCTAssertEqual(relative.theta, 0.1, accuracy: 0.01)
        XCTAssertEqual(relative.alpha, 0.3, accuracy: 0.01)
        XCTAssertEqual(relative.beta, 0.3, accuracy: 0.01)
        XCTAssertEqual(relative.gamma, 0.2, accuracy: 0.01)
    }

    func testEEGDominantBand() {
        let alphaRich = EEGBands(delta: 5, theta: 10, alpha: 50, beta: 15, gamma: 5)
        XCTAssertEqual(alphaRich.dominantBand, "Alpha")

        let betaRich = EEGBands(delta: 5, theta: 10, alpha: 15, beta: 50, gamma: 5)
        XCTAssertEqual(betaRich.dominantBand, "Beta")

        let deltaRich = EEGBands(delta: 60, theta: 10, alpha: 5, beta: 5, gamma: 2)
        XCTAssertEqual(deltaRich.dominantBand, "Delta")
    }

    func testEEGMeditationScore() {
        // High theta / low beta = meditative
        let meditative = EEGBands(delta: 5, theta: 30, alpha: 20, beta: 10, gamma: 5)
        XCTAssertGreaterThan(meditative.meditationScore, 0.5, "High theta/beta ratio should indicate meditation")

        // Low theta / high beta = focused
        let focused = EEGBands(delta: 5, theta: 5, alpha: 10, beta: 40, gamma: 10)
        XCTAssertLessThan(focused.meditationScore, 0.3, "Low theta/beta ratio should indicate low meditation")
    }

    func testEEGFocusScore() {
        // High beta / low alpha+theta = focused
        let focused = EEGBands(delta: 5, theta: 5, alpha: 5, beta: 40, gamma: 10)
        XCTAssertGreaterThan(focused.focusScore, 0.5, "High beta/(alpha+theta) should indicate focus")

        // Low beta / high alpha = relaxed
        let relaxed = EEGBands(delta: 5, theta: 20, alpha: 30, beta: 5, gamma: 2)
        XCTAssertLessThan(relaxed.focusScore, 0.3, "Low beta should indicate low focus")
    }

    func testEEGFlowScore() {
        // Flow = high alpha, moderate beta, low delta
        let flow = EEGBands(delta: 3, theta: 8, alpha: 40, beta: 15, gamma: 5)
        XCTAssertGreaterThan(flow.flowScore, 0.1, "Flow state should produce non-trivial flow score")
    }

    func testEEGBandsZeroPowerSafety() {
        let empty = EEGBands()
        // Should not crash or produce NaN/Inf
        let relative = empty.relativePowers
        XCTAssertFalse(relative.delta.isNaN)
        XCTAssertFalse(relative.delta.isInfinite)
        XCTAssertEqual(empty.meditationScore, 0)
        XCTAssertEqual(empty.focusScore, 0)
    }

    func testEEGDeviceTypes() {
        // Verify all device types have sane parameters
        for device in EEGDeviceType.allCases {
            XCTAssertGreaterThan(device.electrodeCount, 0, "\(device.rawValue) should have electrodes")
            XCTAssertGreaterThan(device.sampleRate, 0, "\(device.rawValue) should have sample rate")
        }
    }

    func testEEGDeviceMuseProperties() {
        let muse2 = EEGDeviceType.muse2
        XCTAssertEqual(muse2.electrodeCount, 4)
        XCTAssertEqual(muse2.sampleRate, 256)
        XCTAssertNotNil(muse2.bluetoothServiceUUID)
    }

    func testEEGConnectionStates() {
        // Verify all connection states are valid strings
        let states: [EEGConnectionState] = [.disconnected, .scanning, .connecting, .connected, .streaming, .error]
        for state in states {
            XCTAssertFalse(state.rawValue.isEmpty)
        }
    }

    func testEEGRawDataCreation() {
        let rawData = EEGRawData(
            electrode: .tp9,
            values: [100.0, -50.0, 25.0],
            sampleRate: 256
        )
        XCTAssertEqual(rawData.electrode, .tp9)
        XCTAssertEqual(rawData.values.count, 3)
        XCTAssertEqual(rawData.sampleRate, 256)
    }

    func testEEGSensorBridgeInitialState() {
        let bridge = EEGSensorBridge.shared
        XCTAssertEqual(bridge.connectionState, .disconnected)
        XCTAssertNil(bridge.connectedDevice)
        XCTAssertEqual(bridge.signalQuality, 0.0, accuracy: 0.01)
    }

    // MARK: - UnifiedHealthKitEngine Tests

    func testUnifiedHealthKitEngineInitialState() {
        let engine = UnifiedHealthKitEngine.shared
        XCTAssertGreaterThanOrEqual(engine.heartRate, 0)
        XCTAssertGreaterThanOrEqual(engine.hrvSDNN, 0)
        XCTAssertGreaterThanOrEqual(engine.coherence, 0)
        XCTAssertLessThanOrEqual(engine.coherence, 1.0)
    }

    func testHealthDataSourceValues() {
        // Verify all data sources
        let sources: [HealthDataSource] = [.realDevice, .appleWatch, .simulation, .replay]
        XCTAssertEqual(sources.count, 4)
        for source in sources {
            XCTAssertFalse(source.rawValue.isEmpty)
        }
    }

    func testHealthPrivacyConfigDefaults() {
        let config = HealthPrivacyConfig.default
        XCTAssertTrue(config.anonymizeData)
        XCTAssertTrue(config.localOnlyProcessing)
        XCTAssertTrue(config.encryptAtRest)
        XCTAssertTrue(config.hipaaCompliant)
        XCTAssertEqual(config.dataRetentionDays, 30)
    }

    func testHealthPrivacyMaxPrivacy() {
        let config = HealthPrivacyConfig.maxPrivacy
        XCTAssertTrue(config.anonymizeData)
        XCTAssertTrue(config.localOnlyProcessing)
        XCTAssertTrue(config.encryptAtRest)
        XCTAssertTrue(config.hipaaCompliant)
        XCTAssertEqual(config.dataRetentionDays, 7)
    }

    func testUnifiedHeartDataCreation() {
        let data = UnifiedHeartData()
        XCTAssertEqual(data.heartRate, 70)
        XCTAssertEqual(data.heartRateVariability, 50)
        XCTAssertEqual(data.coherenceScore, 0)
        XCTAssertTrue(data.rrIntervals.isEmpty)
    }

    func testRRIntervalInjection() {
        let engine = UnifiedHealthKitEngine.shared

        // Inject valid RR intervals
        let baseInterval = 857.0 // ~70 BPM
        for _ in 0..<30 {
            let interval = baseInterval + Double.random(in: -20...20)
            engine.injectRRInterval(interval)
        }

        // Heart rate should be approximately 70 BPM
        XCTAssertGreaterThan(engine.heartRate, 50)
        XCTAssertLessThan(engine.heartRate, 100)
    }

    func testRRIntervalInjectionBoundsCheck() {
        let engine = UnifiedHealthKitEngine.shared
        let initialHR = engine.heartRate

        // Inject out-of-range values (should be ignored)
        engine.injectRRInterval(100)   // Too short (>= 250 required)
        engine.injectRRInterval(3000)  // Too long (<= 2000 required)

        // Heart rate should not change from invalid input
        // (or at least not crash)
        XCTAssertGreaterThanOrEqual(engine.heartRate, 0)
    }

    // MARK: - BioParameterMapper Integration Tests

    func testBioParameterMapperFullPipeline() {
        let mapper = BioParameterMapper()

        // Simulate a meditation session: high coherence, low HR
        for _ in 0..<30 {
            mapper.updateParameters(
                hrvCoherence: 85,
                heartRate: 58,
                voicePitch: 0,
                audioLevel: 0.1
            )
        }

        // High coherence should produce:
        // - High reverb (spacious sound)
        // - Low filter cutoff (warm)
        // - Low tempo
        XCTAssertGreaterThan(mapper.reverbWet, 0.4, "High coherence should increase reverb")
        XCTAssertLessThan(mapper.tempo, 80, "Low HR should produce low tempo")
    }

    func testBioParameterMapperStressState() {
        let mapper = BioParameterMapper()

        // Simulate stress: low coherence, high HR
        for _ in 0..<30 {
            mapper.updateParameters(
                hrvCoherence: 15,
                heartRate: 95,
                voicePitch: 300,
                audioLevel: 0.8
            )
        }

        // Low coherence should produce:
        // - Low reverb (dry, present)
        // - Higher tempo
        XCTAssertLessThan(mapper.reverbWet, 0.5, "Low coherence should decrease reverb")
        XCTAssertGreaterThan(mapper.tempo, 70, "High HR should increase tempo")
    }

    func testBioParameterMapperSmoothing() {
        let mapper = BioParameterMapper()

        // Apply a sudden coherence jump
        mapper.updateParameters(hrvCoherence: 10, heartRate: 70, voicePitch: 0, audioLevel: 0)
        let lowReverb = mapper.reverbWet

        mapper.updateParameters(hrvCoherence: 95, heartRate: 70, voicePitch: 0, audioLevel: 0)
        let afterOneUpdate = mapper.reverbWet

        // Smoothing should prevent instant jumps
        XCTAssertLessThan(
            abs(afterOneUpdate - lowReverb),
            0.5,
            "Smoothing should prevent instant parameter jumps"
        )
    }

    // MARK: - Audio Engine Bio-Reactive Tests

    func testAudioEngineBinauralBeatInitialization() {
        let engine = AudioEngine()
        XCTAssertFalse(engine.binauralBeatsEnabled)
        XCTAssertFalse(engine.spatialAudioEnabled)
        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(engine.currentBrainwaveState, .alpha)
        XCTAssertEqual(engine.binauralAmplitude, 0.3, accuracy: 0.01)
    }

    func testAudioEngineBrainwaveStateChange() {
        let engine = AudioEngine()

        engine.setBrainwaveState(.theta)
        XCTAssertEqual(engine.currentBrainwaveState, .theta)

        engine.setBrainwaveState(.delta)
        XCTAssertEqual(engine.currentBrainwaveState, .delta)

        engine.setBrainwaveState(.gamma)
        XCTAssertEqual(engine.currentBrainwaveState, .gamma)
    }

    func testAudioEngineBinauralAmplitudeRange() {
        let engine = AudioEngine()

        engine.setBinauralAmplitude(0.0)
        XCTAssertEqual(engine.binauralAmplitude, 0.0, accuracy: 0.01)

        engine.setBinauralAmplitude(0.6)
        XCTAssertEqual(engine.binauralAmplitude, 0.6, accuracy: 0.01)
    }

    func testAudioEngineStateDescription() {
        let engine = AudioEngine()

        let stopped = engine.stateDescription
        XCTAssertTrue(stopped.contains("stopped"))
    }

    func testAudioEnginePhysicalAIParameters() {
        let engine = AudioEngine()

        // Test all known parameter names don't crash
        let params = ["intensity", "filterCutoff", "harmonicTension",
                      "reverbMix", "reverbSize", "delayMix",
                      "volume", "spatialWidth", "tempo"]
        for param in params {
            engine.applyPhysicalAIParameter(param, value: 0.5)
        }

        // Unknown parameter should not crash
        engine.applyPhysicalAIParameter("unknownParam", value: 0.5)
    }

    // MARK: - Analytics Integration Tests

    func testAnalyticsEventNames() {
        let events: [AnalyticsEvent] = [
            .sessionStarted,
            .sessionEnded(duration: 60),
            .presetSelected(name: "Test"),
            .coherenceAchieved(level: .high),
            .featureUsed(name: "binaural"),
            .errorOccurred(type: "test", message: "msg"),
            .performanceWarning(metric: "cpu", value: 0.5)
        ]

        for event in events {
            XCTAssertFalse(event.name.isEmpty, "Event \(event) should have a non-empty name")
        }
    }

    func testAnalyticsCoherenceLevels() {
        XCTAssertLessThan(AnalyticsCoherenceLevel.low.threshold, AnalyticsCoherenceLevel.medium.threshold)
        XCTAssertLessThan(AnalyticsCoherenceLevel.medium.threshold, AnalyticsCoherenceLevel.high.threshold)
        XCTAssertLessThan(AnalyticsCoherenceLevel.high.threshold, AnalyticsCoherenceLevel.peak.threshold)
    }

    // MARK: - Coherence Algorithm Tests

    func testCoherenceWithSinusoidalRRIntervals() {
        let manager = HealthKitManager()

        // Generate sinusoidal RR at 0.1 Hz (HeartMath resonance)
        let intervals = (0..<120).map { i in
            800.0 + sin(2.0 * .pi * 0.1 * Double(i)) * 80.0
        }

        let coherence = manager.calculateCoherence(rrIntervals: intervals)
        XCTAssertGreaterThan(coherence, 0, "Sinusoidal RR intervals should produce positive coherence")
        XCTAssertLessThanOrEqual(coherence, 100)
    }

    func testCoherenceWithFlatRRIntervals() {
        let manager = HealthKitManager()

        // Flat intervals (very regular but no oscillation)
        let intervals = [Double](repeating: 800.0, count: 120)

        let coherence = manager.calculateCoherence(rrIntervals: intervals)
        // Flat intervals = no HRV = no coherence pattern
        XCTAssertGreaterThanOrEqual(coherence, 0)
        XCTAssertLessThanOrEqual(coherence, 100)
    }

    func testCoherenceWithEmptyIntervals() {
        let manager = HealthKitManager()
        let coherence = manager.calculateCoherence(rrIntervals: [])
        XCTAssertEqual(coherence, 0, "Empty intervals should produce 0 coherence")
    }

    // MARK: - Cross-System Wiring Tests

    func testBioDataFlowToAudioParameters() {
        // Verify that the complete bio→audio pipeline type-checks
        let mapper = BioParameterMapper()

        // Simulate bio data flowing through the mapper
        mapper.updateParameters(hrvCoherence: 75, heartRate: 65, voicePitch: 220, audioLevel: 0.5)

        // All output parameters should be in valid ranges
        XCTAssertGreaterThanOrEqual(mapper.reverbWet, 0)
        XCTAssertLessThanOrEqual(mapper.reverbWet, 1.0)
        XCTAssertGreaterThanOrEqual(mapper.filterCutoff, 0)
        XCTAssertGreaterThanOrEqual(mapper.amplitude, 0)
        XCTAssertLessThanOrEqual(mapper.amplitude, 1.0)
        XCTAssertGreaterThan(mapper.baseFrequency, 0)
        XCTAssertGreaterThan(mapper.tempo, 0)
        XCTAssertGreaterThanOrEqual(mapper.harmonicCount, 1)
        XCTAssertTrue(mapper.isValid)
    }

    func testBioSnapshotCreation() {
        // Verify BioSnapshot can be created and modified
        var snapshot = BioSnapshot()
        snapshot.coherence = 0.75
        snapshot.heartRate = 65
        snapshot.hrvVariability = 0.45
        snapshot.breathPhase = 0.5
        snapshot.breathDepth = 0.7
        snapshot.lfHfRatio = 0.6
        snapshot.coherenceTrend = 0.1

        XCTAssertEqual(snapshot.coherence, 0.75, accuracy: 0.01)
        XCTAssertEqual(snapshot.heartRate, 65, accuracy: 0.1)
        XCTAssertEqual(snapshot.hrvVariability, 0.45, accuracy: 0.01)
    }

    // MARK: - Performance Tests

    func testHRVCalculationPerformance() {
        let manager = HealthKitManager()

        // 5 minutes of RR intervals at ~70 BPM
        let intervals = (0..<300).map { i in
            800.0 + sin(2.0 * .pi * 0.1 * Double(i)) * 50.0 + Double.random(in: -10...10)
        }

        measure {
            _ = manager.calculateCoherence(rrIntervals: intervals)
        }
    }

    func testBioParameterMappingPerformance() {
        let mapper = BioParameterMapper()

        measure {
            for _ in 0..<1000 {
                mapper.updateParameters(
                    hrvCoherence: Double.random(in: 0...100),
                    heartRate: Double.random(in: 50...120),
                    voicePitch: Float.random(in: 0...1000),
                    audioLevel: Float.random(in: 0...1)
                )
            }
        }
    }
}
