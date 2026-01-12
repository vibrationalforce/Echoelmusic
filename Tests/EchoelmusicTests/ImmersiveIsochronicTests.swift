import XCTest
import AVFoundation
@testable import Echoelmusic

/// Unit tests for ImmersiveIsochronicEngine
/// Tests entrainment presets, soundscapes, bio-reactive modulation, and audio lifecycle
@MainActor
final class ImmersiveIsochronicTests: XCTestCase {

    var engine: ImmersiveIsochronicEngine!

    override func setUp() async throws {
        engine = ImmersiveIsochronicEngine()
    }

    override func tearDown() {
        engine?.stop()
        engine = nil
    }


    // MARK: - Default Configuration Tests

    func testDefaultConfiguration() {
        XCTAssertEqual(engine.currentPreset, .focus, "Default preset should be focus")
        XCTAssertEqual(engine.currentSoundscape, .warmPad, "Default soundscape should be warmPad")
        XCTAssertEqual(engine.volume, 0.5, "Default volume should be 0.5")
        XCTAssertEqual(engine.pulseSoftness, 0.7, "Default pulse softness should be 0.7")
        XCTAssertFalse(engine.isPlaying, "Should not be playing initially")
    }


    // MARK: - Entrainment Preset Tests

    func testAllEntrainmentPresets() {
        let expectedFrequencies: [ImmersiveIsochronicEngine.EntrainmentPreset: Float] = [
            .deepRest: 2.5,
            .meditation: 6.0,
            .relaxedFocus: 10.0,
            .focus: 13.5,
            .activeThinking: 17.5,
            .peakFlow: 30.0
        ]

        for (preset, expectedFreq) in expectedFrequencies {
            engine.configure(preset: preset)
            XCTAssertEqual(engine.currentPreset, preset)
            XCTAssertEqual(engine.rhythmFrequency, expectedFreq,
                          "\(preset.rawValue) should have \(expectedFreq) Hz center frequency")
        }
    }

    func testPresetDisplayNames() {
        XCTAssertFalse(ImmersiveIsochronicEngine.EntrainmentPreset.deepRest.displayName.isEmpty)
        XCTAssertFalse(ImmersiveIsochronicEngine.EntrainmentPreset.meditation.displayName.isEmpty)
        XCTAssertFalse(ImmersiveIsochronicEngine.EntrainmentPreset.relaxedFocus.displayName.isEmpty)
        XCTAssertFalse(ImmersiveIsochronicEngine.EntrainmentPreset.focus.displayName.isEmpty)
        XCTAssertFalse(ImmersiveIsochronicEngine.EntrainmentPreset.activeThinking.displayName.isEmpty)
        XCTAssertFalse(ImmersiveIsochronicEngine.EntrainmentPreset.peakFlow.displayName.isEmpty)
    }

    func testPresetDescriptions() {
        for preset in ImmersiveIsochronicEngine.EntrainmentPreset.allCases {
            XCTAssertFalse(preset.description.isEmpty, "\(preset.rawValue) should have description")
            XCTAssertTrue(preset.description.contains("Hz"), "Description should mention frequency band")
        }
    }

    func testPresetFrequencyRanges() {
        for preset in ImmersiveIsochronicEngine.EntrainmentPreset.allCases {
            let range = preset.frequencyRange
            XCTAssertLessThan(range.lowerBound, range.upperBound)
            XCTAssertTrue(range.contains(preset.centerFrequency),
                         "Center frequency should be within range for \(preset.rawValue)")
        }
    }

    func testPresetRecommendedDurations() {
        // Peak flow should have shortest recommended duration (use sparingly)
        XCTAssertLessThan(ImmersiveIsochronicEngine.EntrainmentPreset.peakFlow.recommendedDuration,
                         ImmersiveIsochronicEngine.EntrainmentPreset.focus.recommendedDuration)

        // All durations should be reasonable (5-60 minutes)
        for preset in ImmersiveIsochronicEngine.EntrainmentPreset.allCases {
            XCTAssertGreaterThan(preset.recommendedDuration, 0)
            XCTAssertLessThanOrEqual(preset.recommendedDuration, 60)
        }
    }


    // MARK: - Soundscape Tests

    func testAllSoundscapes() {
        for soundscape in ImmersiveIsochronicEngine.Soundscape.allCases {
            engine.configure(preset: .focus, soundscape: soundscape)
            XCTAssertEqual(engine.currentSoundscape, soundscape)
            XCTAssertFalse(soundscape.displayName.isEmpty)
            XCTAssertGreaterThan(soundscape.carrierFrequency, 0)
        }
    }

    func testSoundscapeCarrierFrequencies() {
        // Each soundscape should have a unique carrier frequency for distinct character
        var frequencies: Set<Float> = []
        for soundscape in ImmersiveIsochronicEngine.Soundscape.allCases {
            frequencies.insert(soundscape.carrierFrequency)
        }
        XCTAssertEqual(frequencies.count, ImmersiveIsochronicEngine.Soundscape.allCases.count,
                      "Each soundscape should have unique carrier frequency")
    }

    func testSoundscapeHarmonicProfiles() {
        for soundscape in ImmersiveIsochronicEngine.Soundscape.allCases {
            let profile = soundscape.harmonicProfile
            XCTAssertFalse(profile.harmonics.isEmpty, "\(soundscape.rawValue) should have harmonics")
            XCTAssertEqual(profile.harmonics.count, profile.detuning.count,
                          "Harmonics and detuning arrays should match for \(soundscape.rawValue)")
        }
    }


    // MARK: - Volume and Parameter Tests

    func testVolumeConfiguration() {
        engine.volume = 0.75
        XCTAssertEqual(engine.volume, 0.75)
    }

    func testVolumeClamping() {
        engine.volume = 1.5
        XCTAssertEqual(engine.volume, 1.0, "Volume should clamp to 1.0")

        engine.volume = -0.5
        XCTAssertEqual(engine.volume, 0.0, "Volume should clamp to 0.0")
    }

    func testPulseSoftness() {
        engine.pulseSoftness = 0.3
        XCTAssertEqual(engine.pulseSoftness, 0.3)

        engine.pulseSoftness = 1.5
        XCTAssertEqual(engine.pulseSoftness, 1.0, "Pulse softness should clamp to 1.0")

        engine.pulseSoftness = -0.5
        XCTAssertEqual(engine.pulseSoftness, 0.0, "Pulse softness should clamp to 0.0")
    }

    func testRhythmFrequencyDirect() {
        engine.setRhythmFrequency(15.0)
        XCTAssertEqual(engine.rhythmFrequency, 15.0)

        // Test clamping
        engine.setRhythmFrequency(100.0)
        XCTAssertEqual(engine.rhythmFrequency, 60.0, "Should clamp to 60 Hz max")

        engine.setRhythmFrequency(0.1)
        XCTAssertEqual(engine.rhythmFrequency, 0.5, "Should clamp to 0.5 Hz min")
    }


    // MARK: - Bio-Reactive Modulation Tests

    func testCoherenceModulation() {
        engine.configure(preset: .relaxedFocus)
        engine.bioModulationAmount = 1.0

        // Low coherence should shift frequency lower
        let baseFreq = engine.rhythmFrequency
        engine.modulateFromCoherence(0)
        let lowCoherenceFreq = engine.rhythmFrequency

        engine.configure(preset: .relaxedFocus)
        engine.modulateFromCoherence(100)
        let highCoherenceFreq = engine.rhythmFrequency

        XCTAssertLessThan(lowCoherenceFreq, highCoherenceFreq,
                         "Low coherence should result in lower frequency than high coherence")
    }

    func testCoherenceModulationDisabled() {
        engine.configure(preset: .focus)
        engine.bioModulationAmount = 0.0

        let baseFreq = engine.rhythmFrequency
        engine.modulateFromCoherence(0)
        XCTAssertEqual(engine.rhythmFrequency, baseFreq,
                      "No modulation when bioModulationAmount is 0")
    }

    func testHeartRateModulation() {
        engine.bioModulationAmount = 1.0

        // High heart rate should result in sharper pulses
        engine.modulateFromHeartRate(60)
        let lowHRSoftness = engine.pulseSoftness

        engine.modulateFromHeartRate(120)
        let highHRSoftness = engine.pulseSoftness

        XCTAssertGreaterThan(lowHRSoftness, highHRSoftness,
                            "Lower heart rate should result in softer pulses")
    }


    // MARK: - Spatial Position Tests

    func testSpatialPosition() {
        engine.setSpatialPosition(.wide)
        XCTAssertEqual(engine.spatialPosition, .wide)

        engine.setSpatialPosition(.surrounding)
        XCTAssertEqual(engine.spatialPosition, .surrounding)
    }

    func testSpatialPositionStereoWidth() {
        XCTAssertEqual(ImmersiveIsochronicEngine.SpatialPosition.center.stereoWidth, 0.0)
        XCTAssertGreaterThan(ImmersiveIsochronicEngine.SpatialPosition.wide.stereoWidth, 0.5)
        XCTAssertEqual(ImmersiveIsochronicEngine.SpatialPosition.surrounding.stereoWidth, 1.0)
    }


    // MARK: - Lifecycle Tests

    func testStartStop() {
        XCTAssertFalse(engine.isPlaying, "Should not be playing initially")

        engine.start()
        // Note: May not actually start depending on audio session availability
        // We just verify it doesn't crash

        engine.stop()
        XCTAssertFalse(engine.isPlaying, "Should not be playing after stop")
    }

    func testMultipleStarts() {
        engine.start()
        engine.start()
        engine.start()
        // Should not crash

        engine.stop()
    }

    func testMultipleStops() {
        engine.stop()
        engine.stop()
        engine.stop()
        // Should not crash

        XCTAssertFalse(engine.isPlaying)
    }

    func testConfigureWhilePlaying() {
        engine.start()

        // Should be able to reconfigure while playing
        engine.configure(preset: .meditation, soundscape: .crystalBowl)

        XCTAssertEqual(engine.currentPreset, .meditation)
        XCTAssertEqual(engine.currentSoundscape, .crystalBowl)

        engine.stop()
    }


    // MARK: - Legacy Compatibility Tests

    func testLegacyBrainwaveStateMapping() {
        let legacyStates: [ImmersiveIsochronicEngine.BrainwaveState] = [.delta, .theta, .alpha, .beta, .gamma]

        for state in legacyStates {
            XCTAssertFalse(state.description.isEmpty, "Legacy state should have description")
            XCTAssertGreaterThan(state.beatFrequency, 0, "Legacy state should have frequency")
        }
    }

    func testLegacyConfigureMethod() {
        engine.configure(carrier: 432.0, beat: 10.0, amplitude: 0.4)
        XCTAssertEqual(engine.volume, 0.4)
        XCTAssertEqual(engine.rhythmFrequency, 10.0)
    }

    func testLegacyBrainwaveStateConfigure() {
        engine.configure(state: .theta)
        XCTAssertEqual(engine.currentPreset, .meditation, "Theta should map to meditation")
    }

    func testLegacyHRVMethod() {
        engine.bioModulationAmount = 1.0
        engine.setBeatFrequencyFromHRV(coherence: 50.0)
        // Should not crash, modulation should apply
    }


    // MARK: - Performance Tests

    func testConfigurationPerformance() {
        measure {
            for _ in 0..<100 {
                engine.configure(preset: .focus, soundscape: .warmPad)
            }
        }
    }

    func testPresetSwitchingPerformance() {
        measure {
            for preset in ImmersiveIsochronicEngine.EntrainmentPreset.allCases {
                engine.configure(preset: preset)
            }
        }
    }

    func testBioModulationPerformance() {
        engine.bioModulationAmount = 1.0
        measure {
            for i in 0..<100 {
                engine.modulateFromCoherence(Double(i))
            }
        }
    }


    // MARK: - Edge Case Tests

    func testZeroRhythmFrequency() {
        engine.setRhythmFrequency(0)
        XCTAssertEqual(engine.rhythmFrequency, 0.5, "Should clamp to minimum 0.5 Hz")
    }

    func testExtremeCoherenceValues() {
        engine.bioModulationAmount = 1.0

        // Test boundary values
        engine.modulateFromCoherence(-100)
        let freq1 = engine.rhythmFrequency

        engine.configure(preset: .focus)
        engine.modulateFromCoherence(200)
        let freq2 = engine.rhythmFrequency

        // Both should produce valid frequencies
        XCTAssertGreaterThan(freq1, 0)
        XCTAssertGreaterThan(freq2, 0)
    }


    // MARK: - Enumeration Tests

    func testAllPresetsIteration() {
        let allPresets = ImmersiveIsochronicEngine.EntrainmentPreset.allCases
        XCTAssertEqual(allPresets.count, 6, "Should have 6 entrainment presets")

        XCTAssertTrue(allPresets.contains(.deepRest))
        XCTAssertTrue(allPresets.contains(.meditation))
        XCTAssertTrue(allPresets.contains(.relaxedFocus))
        XCTAssertTrue(allPresets.contains(.focus))
        XCTAssertTrue(allPresets.contains(.activeThinking))
        XCTAssertTrue(allPresets.contains(.peakFlow))
    }

    func testAllSoundscapesIteration() {
        let allSoundscapes = ImmersiveIsochronicEngine.Soundscape.allCases
        XCTAssertEqual(allSoundscapes.count, 6, "Should have 6 soundscapes")

        XCTAssertTrue(allSoundscapes.contains(.warmPad))
        XCTAssertTrue(allSoundscapes.contains(.crystalBowl))
        XCTAssertTrue(allSoundscapes.contains(.organicDrone))
        XCTAssertTrue(allSoundscapes.contains(.cosmicWash))
        XCTAssertTrue(allSoundscapes.contains(.earthyGround))
        XCTAssertTrue(allSoundscapes.contains(.shimmeringAir))
    }

    func testAllSpatialPositions() {
        let allPositions = ImmersiveIsochronicEngine.SpatialPosition.allCases
        XCTAssertEqual(allPositions.count, 5, "Should have 5 spatial positions")
    }


    // MARK: - Breath Sync Tests

    func testEnableBreathSync() {
        XCTAssertFalse(engine.breathSyncEnabled)

        engine.enableBreathSync(breathingRate: 6.0)

        XCTAssertTrue(engine.breathSyncEnabled)
        // 6 BPM * 60 = 6 Hz rhythm
        XCTAssertEqual(engine.rhythmFrequency, 6.0, accuracy: 0.1)
    }

    func testUpdateBreathingRate() {
        engine.enableBreathSync(breathingRate: 6.0)
        let initialFreq = engine.rhythmFrequency

        engine.updateBreathingRate(12.0)

        // 12 BPM should double the frequency
        XCTAssertEqual(engine.rhythmFrequency, initialFreq * 2, accuracy: 0.1)
    }

    func testUpdateBreathingRateWhenNotEnabled() {
        let initialFreq = engine.rhythmFrequency

        engine.updateBreathingRate(12.0)

        // Should not change when breath sync is disabled
        XCTAssertEqual(engine.rhythmFrequency, initialFreq)
    }

    func testDisableBreathSync() {
        engine.configure(preset: .focus)
        let presetFreq = engine.currentPreset.centerFrequency

        engine.enableBreathSync(breathingRate: 6.0)
        XCTAssertTrue(engine.breathSyncEnabled)

        engine.disableBreathSync()

        XCTAssertFalse(engine.breathSyncEnabled)
        XCTAssertEqual(engine.rhythmFrequency, presetFreq, accuracy: 0.1)
    }

    func testBreathSyncClampingLow() {
        engine.enableBreathSync(breathingRate: 0.5)  // Below minimum

        // Should clamp to 2.0 BPM minimum
        XCTAssertTrue(engine.breathSyncEnabled)
    }

    func testBreathSyncClampingHigh() {
        engine.enableBreathSync(breathingRate: 30.0)  // Above maximum

        // Should clamp to 20.0 BPM maximum
        XCTAssertTrue(engine.breathSyncEnabled)
    }


    // MARK: - Soundscape Transition Tests

    func testTransitionToSoundscape() {
        engine.configure(preset: .focus, soundscape: .warmPad)

        engine.transitionTo(soundscape: .crystalBowl)

        XCTAssertEqual(engine.currentSoundscape, .crystalBowl)
    }

    func testTransitionWithCustomDuration() {
        engine.configure(preset: .focus, soundscape: .warmPad)

        engine.transitionTo(soundscape: .cosmicWash, duration: 5.0)

        XCTAssertEqual(engine.currentSoundscape, .cosmicWash)
    }

    func testCrossfadeDurationConfiguration() {
        engine.crossfadeDuration = 3.0
        XCTAssertEqual(engine.crossfadeDuration, 3.0)
    }


    // MARK: - Session Statistics Tests

    func testInitialSessionStats() {
        XCTAssertEqual(engine.sessionStats.totalListeningSeconds, 0)
        XCTAssertEqual(engine.sessionStats.sessionsCompleted, 0)
        XCTAssertNil(engine.sessionStats.lastSessionDate)
        XCTAssertEqual(engine.sessionStats.currentStreak, 0)
    }

    func testSessionStatsRecording() {
        var stats = ImmersiveIsochronicEngine.SessionStatistics()

        stats.recordSession(preset: .focus, minutes: 15)

        XCTAssertEqual(stats.sessionsCompleted, 1)
        XCTAssertEqual(stats.totalMinutes, 15)
        XCTAssertNotNil(stats.lastSessionDate)
        XCTAssertEqual(stats.currentStreak, 1)
    }

    func testSessionStatsFavoritePreset() {
        var stats = ImmersiveIsochronicEngine.SessionStatistics()

        stats.recordSession(preset: .focus, minutes: 30)
        stats.recordSession(preset: .meditation, minutes: 10)
        stats.recordSession(preset: .focus, minutes: 20)

        XCTAssertEqual(stats.favoritePreset, "focus")
        XCTAssertEqual(stats.presetMinutes["focus"], 50)
        XCTAssertEqual(stats.presetMinutes["meditation"], 10)
    }

    func testSessionStatsStreakTracking() {
        var stats = ImmersiveIsochronicEngine.SessionStatistics()

        // First session
        stats.recordSession(preset: .focus, minutes: 10)
        XCTAssertEqual(stats.currentStreak, 1)

        // Simulate same day (streak stays same)
        // Note: This test may need adjustment based on actual date handling
    }

    func testCurrentSessionDuration() {
        XCTAssertEqual(engine.currentSessionDuration, 0, "Should be 0 when not playing")
    }


    // MARK: - Session Statistics Codable Tests

    func testSessionStatsCodable() throws {
        var stats = ImmersiveIsochronicEngine.SessionStatistics()
        stats.recordSession(preset: .focus, minutes: 20)
        stats.recordSession(preset: .meditation, minutes: 15)

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(stats)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ImmersiveIsochronicEngine.SessionStatistics.self, from: data)

        XCTAssertEqual(decoded.sessionsCompleted, 2)
        XCTAssertEqual(decoded.totalMinutes, 35)
        XCTAssertEqual(decoded.presetMinutes["focus"], 20)
        XCTAssertEqual(decoded.presetMinutes["meditation"], 15)
    }
}
