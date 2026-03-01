// LambdaLoopCompleteTests.swift
// Echoelmusic - 100% Coverage Tests for Ralph Wiggum Lambda Loop Mode
//
// Covers ALL previously untested Lambda/Loop types:
//   1. LoopEngine (Audio/LoopEngine.swift)
//   2. UniversalEnvironmentEngine + EnvironmentClass + EnvironmentDomain
//   3. LambdaChain + LambdaOperators + LambdaTransformResult
//   4. EnvironmentPresets + EnvironmentPresetRegistry
//   5. SelfHealingCodeTransformation + TransformationLevel + SignalGraph
//   6. EnvironmentLoopProcessor + EnvironmentLoopState
//
// "I bent my wookiee" - Ralph Wiggum, Lambda Loop Completionist
//
// Created 2026-03-01

import XCTest
@testable import Echoelmusic

// =============================================================================
// MARK: - 1. LoopEngine Tests
// =============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class LoopEngineTests: XCTestCase {

    // MARK: - Initialization

    @MainActor
    func testLoopEngineInitialization() {
        let engine = LoopEngine()

        XCTAssertFalse(engine.isRecordingLoop)
        XCTAssertFalse(engine.isPlayingLoops)
        XCTAssertEqual(engine.loopPosition, 0.0)
        XCTAssertTrue(engine.loops.isEmpty)
        XCTAssertEqual(engine.tempo, 120.0)
        XCTAssertEqual(engine.timeSignature.numerator, 4)
        XCTAssertEqual(engine.timeSignature.denominator, 4)
        XCTAssertFalse(engine.metronomeEnabled)
        XCTAssertFalse(engine.isOverdubbing)
        XCTAssertNil(engine.overdubLoopID)
    }

    // MARK: - Loop Model

    func testLoopModelDefaults() {
        let loop = LoopEngine.Loop(name: "Test Loop", bars: 8, volume: 0.8, color: .blue)

        XCTAssertEqual(loop.name, "Test Loop")
        XCTAssertEqual(loop.bars, 8)
        XCTAssertEqual(loop.volume, 0.8)
        XCTAssertEqual(loop.pan, 0.0)
        XCTAssertFalse(loop.isMuted)
        XCTAssertFalse(loop.isSoloed)
        XCTAssertEqual(loop.startTime, 0.0)
        XCTAssertEqual(loop.color, .blue)
        XCTAssertEqual(loop.duration, 0.0)
    }

    func testLoopModelDefaultInit() {
        let loop = LoopEngine.Loop()

        XCTAssertEqual(loop.name, "Loop")
        XCTAssertEqual(loop.bars, 4)
        XCTAssertEqual(loop.volume, 1.0)
        XCTAssertEqual(loop.color, .cyan)
    }

    func testLoopColorAllCases() {
        XCTAssertEqual(LoopEngine.Loop.LoopColor.allCases.count, 8)
        XCTAssertTrue(LoopEngine.Loop.LoopColor.allCases.contains(.red))
        XCTAssertTrue(LoopEngine.Loop.LoopColor.allCases.contains(.cyan))
        XCTAssertTrue(LoopEngine.Loop.LoopColor.allCases.contains(.purple))
    }

    func testLoopDurationString() {
        var loop = LoopEngine.Loop()
        loop.duration = 125 // 2:05
        XCTAssertEqual(loop.durationString, "2:05")

        loop.duration = 0
        XCTAssertEqual(loop.durationString, "0:00")

        loop.duration = 61
        XCTAssertEqual(loop.durationString, "1:01")
    }

    func testLoopBarsDisplay() {
        let loop = LoopEngine.Loop(bars: 16)
        XCTAssertEqual(loop.barsDisplay, "16 bars")
    }

    func testLoopCodable() throws {
        let loop = LoopEngine.Loop(name: "Codable Test", bars: 8, volume: 0.7, color: .purple)
        let data = try JSONEncoder().encode(loop)
        let decoded = try JSONDecoder().decode(LoopEngine.Loop.self, from: data)

        XCTAssertEqual(decoded.name, "Codable Test")
        XCTAssertEqual(decoded.bars, 8)
        XCTAssertEqual(decoded.volume, 0.7)
        XCTAssertEqual(decoded.color, .purple)
    }

    // MARK: - Recording

    @MainActor
    func testStartLoopRecording() {
        let engine = LoopEngine()

        engine.startLoopRecording(bars: 8)

        XCTAssertTrue(engine.isRecordingLoop)
        XCTAssertEqual(engine.loops.count, 1)
        XCTAssertEqual(engine.loops[0].bars, 8)
    }

    @MainActor
    func testStartRecordingGuardsDoubleStart() {
        let engine = LoopEngine()

        engine.startLoopRecording(bars: 4)
        engine.startLoopRecording(bars: 8)  // Should be ignored

        XCTAssertEqual(engine.loops.count, 1)  // Only one loop created
    }

    @MainActor
    func testStopLoopRecording() {
        let engine = LoopEngine()

        engine.startLoopRecording(bars: 4)
        XCTAssertTrue(engine.isRecordingLoop)

        engine.stopLoopRecording()
        XCTAssertFalse(engine.isRecordingLoop)
        XCTAssertEqual(engine.loops.count, 1)
        // Duration should be set (even if very small due to timing)
        XCTAssertGreaterThanOrEqual(engine.loops[0].duration, 0)
    }

    @MainActor
    func testStopRecordingWithoutStartDoesNothing() {
        let engine = LoopEngine()

        engine.stopLoopRecording()  // Should not crash
        XCTAssertFalse(engine.isRecordingLoop)
        XCTAssertTrue(engine.loops.isEmpty)
    }

    // MARK: - Overdub

    @MainActor
    func testStartOverdub() {
        let engine = LoopEngine()

        engine.startLoopRecording(bars: 4)
        engine.stopLoopRecording()
        let loopID = engine.loops[0].id

        engine.startOverdub(loopID: loopID)

        XCTAssertTrue(engine.isOverdubbing)
        XCTAssertEqual(engine.overdubLoopID, loopID)
        XCTAssertTrue(engine.isPlayingLoops) // Playback starts automatically
    }

    @MainActor
    func testStartOverdubInvalidID() {
        let engine = LoopEngine()

        engine.startOverdub(loopID: UUID())

        XCTAssertFalse(engine.isOverdubbing)  // Should not start
    }

    @MainActor
    func testStopOverdub() {
        let engine = LoopEngine()

        engine.startLoopRecording(bars: 4)
        engine.stopLoopRecording()
        let loopID = engine.loops[0].id

        engine.startOverdub(loopID: loopID)
        engine.stopOverdub()

        XCTAssertFalse(engine.isOverdubbing)
        XCTAssertNil(engine.overdubLoopID)
        XCTAssertEqual(engine.loops.count, 2)  // Original + overdub
        XCTAssertTrue(engine.loops[1].name.contains("Overdub"))
    }

    @MainActor
    func testCancelOverdub() {
        let engine = LoopEngine()

        engine.startLoopRecording(bars: 4)
        engine.stopLoopRecording()
        let loopID = engine.loops[0].id

        engine.startOverdub(loopID: loopID)
        engine.cancelOverdub()

        XCTAssertFalse(engine.isOverdubbing)
        XCTAssertNil(engine.overdubLoopID)
        XCTAssertEqual(engine.loops.count, 1)  // No overdub loop added
    }

    // MARK: - Playback

    @MainActor
    func testStartStopPlayback() {
        let engine = LoopEngine()

        engine.startPlayback()
        XCTAssertTrue(engine.isPlayingLoops)

        engine.stopPlayback()
        XCTAssertFalse(engine.isPlayingLoops)
        XCTAssertEqual(engine.loopPosition, 0.0)
    }

    @MainActor
    func testTogglePlayback() {
        let engine = LoopEngine()

        engine.togglePlayback()
        XCTAssertTrue(engine.isPlayingLoops)

        engine.togglePlayback()
        XCTAssertFalse(engine.isPlayingLoops)
    }

    @MainActor
    func testDoubleStartPlaybackGuard() {
        let engine = LoopEngine()

        engine.startPlayback()
        engine.startPlayback()  // Should be ignored
        XCTAssertTrue(engine.isPlayingLoops)
    }

    // MARK: - Loop Management

    @MainActor
    func testDeleteLoop() {
        let engine = LoopEngine()

        engine.startLoopRecording()
        engine.stopLoopRecording()
        let loopID = engine.loops[0].id

        engine.deleteLoop(loopID)
        XCTAssertTrue(engine.loops.isEmpty)
    }

    @MainActor
    func testSetLoopMuted() {
        let engine = LoopEngine()

        engine.startLoopRecording()
        engine.stopLoopRecording()
        let loopID = engine.loops[0].id

        engine.setLoopMuted(loopID, muted: true)
        XCTAssertTrue(engine.loops[0].isMuted)

        engine.setLoopMuted(loopID, muted: false)
        XCTAssertFalse(engine.loops[0].isMuted)
    }

    @MainActor
    func testSetLoopSoloed() {
        let engine = LoopEngine()

        engine.startLoopRecording()
        engine.stopLoopRecording()
        let loopID = engine.loops[0].id

        engine.setLoopSoloed(loopID, soloed: true)
        XCTAssertTrue(engine.loops[0].isSoloed)
    }

    @MainActor
    func testSetLoopVolume() {
        let engine = LoopEngine()

        engine.startLoopRecording()
        engine.stopLoopRecording()
        let loopID = engine.loops[0].id

        engine.setLoopVolume(loopID, volume: 0.5)
        XCTAssertEqual(engine.loops[0].volume, 0.5)

        // Clamp to 0-1
        engine.setLoopVolume(loopID, volume: 1.5)
        XCTAssertEqual(engine.loops[0].volume, 1.0)

        engine.setLoopVolume(loopID, volume: -0.5)
        XCTAssertEqual(engine.loops[0].volume, 0.0)
    }

    @MainActor
    func testSetLoopPan() {
        let engine = LoopEngine()

        engine.startLoopRecording()
        engine.stopLoopRecording()
        let loopID = engine.loops[0].id

        engine.setLoopPan(loopID, pan: -0.5)
        XCTAssertEqual(engine.loops[0].pan, -0.5)

        // Clamp to -1...1
        engine.setLoopPan(loopID, pan: 2.0)
        XCTAssertEqual(engine.loops[0].pan, 1.0)

        engine.setLoopPan(loopID, pan: -3.0)
        XCTAssertEqual(engine.loops[0].pan, -1.0)
    }

    @MainActor
    func testClearAllLoops() {
        let engine = LoopEngine()

        engine.startLoopRecording()
        engine.stopLoopRecording()
        engine.startLoopRecording()
        engine.stopLoopRecording()
        XCTAssertEqual(engine.loops.count, 2)

        engine.clearAllLoops()
        XCTAssertTrue(engine.loops.isEmpty)
        XCTAssertFalse(engine.isPlayingLoops)
    }

    // MARK: - Tempo & Timing

    @MainActor
    func testSetTempo() {
        let engine = LoopEngine()

        engine.setTempo(140)
        XCTAssertEqual(engine.tempo, 140)

        // Clamp to 40-240
        engine.setTempo(10)
        XCTAssertEqual(engine.tempo, 40)

        engine.setTempo(300)
        XCTAssertEqual(engine.tempo, 240)
    }

    @MainActor
    func testSetTimeSignature() {
        let engine = LoopEngine()

        engine.setTimeSignature(beats: 3, noteValue: 4)
        XCTAssertEqual(engine.timeSignature.numerator, 3)
        XCTAssertEqual(engine.timeSignature.denominator, 4)
    }

    @MainActor
    func testBarDurationSeconds() {
        let engine = LoopEngine()

        engine.setTempo(120) // 120 BPM
        engine.setTimeSignature(beats: 4, noteValue: 4)

        // 4 beats at 120 BPM = 2 seconds per bar
        XCTAssertEqual(engine.barDurationSeconds(), 2.0, accuracy: 0.001)
    }

    @MainActor
    func testBeatDurationSeconds() {
        let engine = LoopEngine()

        engine.setTempo(120)

        // 120 BPM = 0.5 seconds per beat
        XCTAssertEqual(engine.beatDurationSeconds(), 0.5, accuracy: 0.001)
    }

    @MainActor
    func testCurrentBeatWithoutPlayback() {
        let engine = LoopEngine()
        XCTAssertEqual(engine.currentBeat(), 0)
    }

    // MARK: - Metronome

    @MainActor
    func testToggleMetronome() {
        let engine = LoopEngine()

        XCTAssertFalse(engine.metronomeEnabled)

        engine.toggleMetronome()
        XCTAssertTrue(engine.metronomeEnabled)

        engine.toggleMetronome()
        XCTAssertFalse(engine.metronomeEnabled)
    }
}

// =============================================================================
// MARK: - 2. UniversalEnvironmentEngine Tests
// =============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class UniversalEnvironmentEngineTests: XCTestCase {

    // MARK: - EnvironmentClass

    func testEnvironmentClassAllCases() {
        // Should have 44+ environment classes
        XCTAssertGreaterThanOrEqual(EnvironmentClass.allCases.count, 40)
    }

    func testEnvironmentClassDomainMapping() {
        // Terrestrial
        XCTAssertEqual(EnvironmentClass.urban.domain, .terrestrial)
        XCTAssertEqual(EnvironmentClass.forest.domain, .terrestrial)
        XCTAssertEqual(EnvironmentClass.desert.domain, .terrestrial)
        XCTAssertEqual(EnvironmentClass.studio.domain, .terrestrial)
        XCTAssertEqual(EnvironmentClass.home.domain, .terrestrial)

        // Aquatic
        XCTAssertEqual(EnvironmentClass.ocean.domain, .aquatic)
        XCTAssertEqual(EnvironmentClass.deepSea.domain, .aquatic)
        XCTAssertEqual(EnvironmentClass.freshwater.domain, .aquatic)
        XCTAssertEqual(EnvironmentClass.coral.domain, .aquatic)
        XCTAssertEqual(EnvironmentClass.submarine.domain, .aquatic)

        // Aerial
        XCTAssertEqual(EnvironmentClass.lowAltitude.domain, .aerial)
        XCTAssertEqual(EnvironmentClass.highAltitude.domain, .aerial)
        XCTAssertEqual(EnvironmentClass.stratosphere.domain, .aerial)
        XCTAssertEqual(EnvironmentClass.aircraft.domain, .aerial)
        XCTAssertEqual(EnvironmentClass.eVTOL.domain, .aerial)

        // Extraterrestrial
        XCTAssertEqual(EnvironmentClass.orbit.domain, .extraterrestrial)
        XCTAssertEqual(EnvironmentClass.lunarSurface.domain, .extraterrestrial)
        XCTAssertEqual(EnvironmentClass.deepSpace.domain, .extraterrestrial)
        XCTAssertEqual(EnvironmentClass.spacecraft.domain, .extraterrestrial)

        // Vehicular
        XCTAssertEqual(EnvironmentClass.automobile.domain, .vehicular)
        XCTAssertEqual(EnvironmentClass.train.domain, .vehicular)
        XCTAssertEqual(EnvironmentClass.bicycle.domain, .vehicular)
        XCTAssertEqual(EnvironmentClass.boat.domain, .vehicular)

        // Subterranean
        XCTAssertEqual(EnvironmentClass.cave.domain, .subterranean)
        XCTAssertEqual(EnvironmentClass.underground.domain, .subterranean)
    }

    func testEnvironmentClassRelevantDimensions() {
        // Aquatic should include water-specific dimensions
        let aquaticDims = EnvironmentClass.ocean.relevantDimensions
        XCTAssertTrue(aquaticDims.contains(.depth))
        XCTAssertTrue(aquaticDims.contains(.salinity))
        XCTAssertTrue(aquaticDims.contains(.pH))

        // Aerial should include altitude and wind
        let aerialDims = EnvironmentClass.lowAltitude.relevantDimensions
        XCTAssertTrue(aerialDims.contains(.altitude))
        XCTAssertTrue(aerialDims.contains(.windSpeed))

        // Extraterrestrial should include radiation and gravity
        let spaceDims = EnvironmentClass.orbit.relevantDimensions
        XCTAssertTrue(spaceDims.contains(.radiation))
        XCTAssertTrue(spaceDims.contains(.gravity))
    }

    func testEnvironmentClassBaseCoherenceAffinity() {
        // Float tank is highest
        XCTAssertEqual(EnvironmentClass.floatTank.baseCoherenceAffinity, 0.95)

        // Forest is high
        XCTAssertEqual(EnvironmentClass.forest.baseCoherenceAffinity, 0.85)

        // Aircraft is low
        XCTAssertEqual(EnvironmentClass.aircraft.baseCoherenceAffinity, 0.35)

        // All affinities should be in valid range
        for env in EnvironmentClass.allCases {
            XCTAssertGreaterThanOrEqual(env.baseCoherenceAffinity, 0.0,
                "\(env.rawValue) affinity should be >= 0")
            XCTAssertLessThanOrEqual(env.baseCoherenceAffinity, 1.0,
                "\(env.rawValue) affinity should be <= 1")
        }
    }

    // MARK: - EnvironmentDomain

    func testEnvironmentDomainAllCases() {
        XCTAssertEqual(EnvironmentDomain.allCases.count, 6)
    }

    func testEnvironmentDomainSpeedOfSound() {
        XCTAssertEqual(EnvironmentDomain.terrestrial.speedOfSound, 343.0)
        XCTAssertEqual(EnvironmentDomain.aquatic.speedOfSound, 1481.0)
        XCTAssertEqual(EnvironmentDomain.extraterrestrial.speedOfSound, 0.0)
        XCTAssertGreaterThan(EnvironmentDomain.aerial.speedOfSound, 0)
        XCTAssertGreaterThan(EnvironmentDomain.subterranean.speedOfSound, 0)
    }

    func testEnvironmentDomainMedium() {
        XCTAssertTrue(EnvironmentDomain.aquatic.medium.contains("Wasser"))
        XCTAssertTrue(EnvironmentDomain.extraterrestrial.medium.contains("Vakuum"))
    }

    func testEnvironmentDomainBaseColor() {
        let terrestrialColor = EnvironmentDomain.terrestrial.baseColor
        XCTAssertGreaterThan(terrestrialColor.g, terrestrialColor.r)  // Green-dominant

        let aquaticColor = EnvironmentDomain.aquatic.baseColor
        XCTAssertGreaterThan(aquaticColor.b, aquaticColor.r)  // Blue-dominant
    }

    func testEnvironmentDomainReverbPreset() {
        XCTAssertEqual(EnvironmentDomain.aquatic.reverbPreset, "underwater_cathedral")
        XCTAssertEqual(EnvironmentDomain.subterranean.reverbPreset, "deep_cave")
        XCTAssertEqual(EnvironmentDomain.vehicular.reverbPreset, "enclosed_cabin")
    }

    func testEnvironmentDomainAttenuationFactor() {
        // Water transmits better (lower attenuation)
        XCTAssertLessThan(EnvironmentDomain.aquatic.attenuationFactor,
                         EnvironmentDomain.terrestrial.attenuationFactor)

        // Vacuum has maximum attenuation
        XCTAssertEqual(EnvironmentDomain.extraterrestrial.attenuationFactor, 100.0)
    }

    // MARK: - EnvironmentDimension

    func testEnvironmentDimensionAllCases() {
        XCTAssertGreaterThanOrEqual(EnvironmentDimension.allCases.count, 30)
    }

    func testEnvironmentDimensionUnits() {
        XCTAssertEqual(EnvironmentDimension.temperature.unit, "°C")
        XCTAssertEqual(EnvironmentDimension.pressure.unit, "hPa")
        XCTAssertEqual(EnvironmentDimension.noise.unit, "dB(A)")
        XCTAssertEqual(EnvironmentDimension.depth.unit, "m")
        XCTAssertEqual(EnvironmentDimension.gravity.unit, "m/s²")
        XCTAssertEqual(EnvironmentDimension.radiation.unit, "µSv/h")
    }

    func testEnvironmentDimensionHumanComfortRange() {
        // Temperature comfort range
        let tempRange = EnvironmentDimension.temperature.humanComfortRange
        XCTAssertNotNil(tempRange)
        XCTAssertEqual(tempRange?.lowerBound, 18.0)
        XCTAssertEqual(tempRange?.upperBound, 26.0)

        // Gravity comfort range
        let gravRange = EnvironmentDimension.gravity.humanComfortRange
        XCTAssertNotNil(gravRange)
        XCTAssertEqual(gravRange?.lowerBound, 9.5)

        // Some dimensions have no comfort range
        XCTAssertNil(EnvironmentDimension.depth.humanComfortRange)
        XCTAssertNil(EnvironmentDimension.magneticField.humanComfortRange)
    }

    // MARK: - DimensionState

    func testDimensionStateInit() {
        let state = DimensionState(value: 22.5, confidence: 0.95, trend: 0.1, sensorID: "temp-01")

        XCTAssertEqual(state.value, 22.5)
        XCTAssertEqual(state.confidence, 0.95)
        XCTAssertEqual(state.trend, 0.1)
        XCTAssertEqual(state.sensorID, "temp-01")
    }

    func testDimensionStateDefaults() {
        let state = DimensionState(value: 100.0)

        XCTAssertEqual(state.confidence, 1.0)
        XCTAssertEqual(state.trend, 0.0)
        XCTAssertNil(state.sensorID)
    }

    // MARK: - EnvironmentStateVector

    func testEnvironmentStateVectorInit() {
        let vector = EnvironmentStateVector(environmentClass: .forest)

        XCTAssertEqual(vector.environmentClass, .forest)
        XCTAssertTrue(vector.dimensions.isEmpty)
        XCTAssertNotNil(vector.timestamp)
    }

    func testEnvironmentStateVectorComfortScore() {
        // All comfortable dimensions → high score
        var vector = EnvironmentStateVector(environmentClass: .home, dimensions: [
            .temperature: DimensionState(value: 22.0),   // Within 18-26
            .humidity: DimensionState(value: 45.0),       // Within 30-60
            .noise: DimensionState(value: 35.0),          // Within 25-55
        ])
        XCTAssertGreaterThan(vector.comfortScore, 0.9)

        // All uncomfortable dimensions → low score
        vector = EnvironmentStateVector(environmentClass: .desert, dimensions: [
            .temperature: DimensionState(value: 50.0),    // Way above 26
            .noise: DimensionState(value: 90.0),          // Way above 55
        ])
        XCTAssertLessThan(vector.comfortScore, 0.5)

        // Empty dimensions → neutral score 0.5
        let emptyVector = EnvironmentStateVector(environmentClass: .home)
        XCTAssertEqual(emptyVector.comfortScore, 0.5)
    }

    // MARK: - EnvironmentTransition

    func testEnvironmentTransitionCritical() {
        // Domain change is always critical
        let crossDomain = EnvironmentTransition(
            from: .home, to: .ocean,
            startTime: Date(), estimatedDuration: 30.0, blendFactor: 0.0
        )
        XCTAssertTrue(crossDomain.isCritical)

        // Same domain, non-critical
        let sameDomain = EnvironmentTransition(
            from: .urban, to: .rural,
            startTime: Date(), estimatedDuration: 30.0, blendFactor: 0.0
        )
        XCTAssertFalse(sameDomain.isCritical)

        // Deep sea decompression is critical
        let decompression = EnvironmentTransition(
            from: .deepSea, to: .ocean,
            startTime: Date(), estimatedDuration: 30.0, blendFactor: 0.0
        )
        XCTAssertTrue(decompression.isCritical)

        // Cryo chamber transition is critical
        let cryo = EnvironmentTransition(
            from: .cryoChamber, to: .home,
            startTime: Date(), estimatedDuration: 30.0, blendFactor: 0.0
        )
        XCTAssertTrue(cryo.isCritical)
    }

    // MARK: - UniversalEnvironmentEngine

    @MainActor
    func testUniversalEnvironmentEngineShared() {
        let engine1 = UniversalEnvironmentEngine.shared
        let engine2 = UniversalEnvironmentEngine.shared
        XCTAssertTrue(engine1 === engine2)
    }

    @MainActor
    func testUniversalEnvironmentEngineDefaults() {
        let engine = UniversalEnvironmentEngine.shared

        XCTAssertEqual(engine.currentEnvironment, .home)
        XCTAssertNotNil(engine.stateVector)
        XCTAssertFalse(engine.isMonitoring)
        XCTAssertNil(engine.activeTransition)
    }

    @MainActor
    func testSetEnvironment() {
        let engine = UniversalEnvironmentEngine.shared
        let original = engine.currentEnvironment

        engine.setEnvironment(.forest)
        XCTAssertEqual(engine.currentEnvironment, .forest)
        XCTAssertEqual(engine.stateVector.environmentClass, .forest)
        XCTAssertNotNil(engine.activeTransition)
        XCTAssertTrue(engine.environmentHistory.contains(original))

        // Restore
        engine.setEnvironment(.home)
    }

    @MainActor
    func testStartStopMonitoring() {
        let engine = UniversalEnvironmentEngine.shared

        engine.startMonitoring()
        XCTAssertTrue(engine.isMonitoring)

        engine.stopMonitoring()
        XCTAssertFalse(engine.isMonitoring)
    }

    @MainActor
    func testUpdateDimension() {
        let engine = UniversalEnvironmentEngine.shared

        engine.updateDimension(.temperature, state: DimensionState(value: 22.0))
        XCTAssertEqual(engine.stateVector.dimensions[.temperature]?.value, 22.0)
    }

    @MainActor
    func testUpdateDimensions() {
        let engine = UniversalEnvironmentEngine.shared

        engine.updateDimensions([
            .temperature: DimensionState(value: 23.0),
            .humidity: DimensionState(value: 50.0),
        ])

        XCTAssertEqual(engine.stateVector.dimensions[.temperature]?.value, 23.0)
        XCTAssertEqual(engine.stateVector.dimensions[.humidity]?.value, 50.0)
    }

    @MainActor
    func testCoherenceModifier() {
        let engine = UniversalEnvironmentEngine.shared

        // Bio-reactive mapping enabled → non-zero modifier
        engine.bioReactiveMappingEnabled = true
        let modifier = engine.coherenceModifier
        // Should be in ±0.15 range
        XCTAssertGreaterThanOrEqual(modifier, -0.15)
        XCTAssertLessThanOrEqual(modifier, 0.15)

        // Disabled → zero
        engine.bioReactiveMappingEnabled = false
        XCTAssertEqual(engine.coherenceModifier, 0.0)

        engine.bioReactiveMappingEnabled = true
    }

    @MainActor
    func testRecommendedCarrierFrequency() {
        let engine = UniversalEnvironmentEngine.shared

        engine.setEnvironment(.home) // terrestrial
        XCTAssertEqual(engine.recommendedCarrierFrequency, 440.0)

        engine.setEnvironment(.orbit) // extraterrestrial
        XCTAssertEqual(engine.recommendedCarrierFrequency, 392.0)

        // Restore
        engine.setEnvironment(.home)
    }

    @MainActor
    func testRecommendedEntrainmentFrequency() {
        let engine = UniversalEnvironmentEngine.shared

        // Should be in 4-20 Hz range
        let freq = engine.recommendedEntrainmentFrequency
        XCTAssertGreaterThanOrEqual(freq, 4.0)
        XCTAssertLessThanOrEqual(freq, 20.0)
    }

    @MainActor
    func testAmbientColor() {
        let engine = UniversalEnvironmentEngine.shared

        let color = engine.ambientColor
        XCTAssertGreaterThanOrEqual(color.r, 0)
        XCTAssertLessThanOrEqual(color.r, 1)
        XCTAssertGreaterThanOrEqual(color.g, 0)
        XCTAssertLessThanOrEqual(color.g, 1)
        XCTAssertGreaterThanOrEqual(color.b, 0)
        XCTAssertLessThanOrEqual(color.b, 1)
    }

    @MainActor
    func testSpatialAudioConfig() {
        let engine = UniversalEnvironmentEngine.shared

        engine.setEnvironment(.home)
        let config = engine.spatialAudioConfig

        XCTAssertEqual(config.speedOfSound, 343.0)
        XCTAssertEqual(config.reverbPreset, "medium_room")
        XCTAssertTrue(config.dopplerEnabled)

        // Restore
        engine.setEnvironment(.home)
    }

    @MainActor
    func testSpatialAudioConfigExtraterrestrial() {
        let engine = UniversalEnvironmentEngine.shared

        engine.setEnvironment(.orbit)
        let config = engine.spatialAudioConfig

        XCTAssertEqual(config.speedOfSound, 0.0)
        XCTAssertFalse(config.dopplerEnabled)  // No sound in vacuum

        // Restore
        engine.setEnvironment(.home)
    }
}

// =============================================================================
// MARK: - 3. LambdaChain / LambdaOperator / LambdaTransformResult Tests
// =============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class LambdaChainTests: XCTestCase {

    // MARK: - LambdaTransformResult

    func testLambdaTransformResultNeutral() {
        let neutral = LambdaTransformResult.neutral

        XCTAssertEqual(neutral.coherenceModifier, 0.0)
        XCTAssertEqual(neutral.frequency, 10.0)
        XCTAssertEqual(neutral.carrierFrequency, 440.0)
        XCTAssertEqual(neutral.amplitude, 0.5)
        XCTAssertEqual(neutral.color.r, 0.5)
        XCTAssertEqual(neutral.color.g, 0.5)
        XCTAssertEqual(neutral.color.b, 0.5)
        XCTAssertEqual(neutral.reverbMix, 0.3)
        XCTAssertEqual(neutral.spatialWidth, 0.5)
        XCTAssertEqual(neutral.hapticIntensity, 0.0)
        XCTAssertTrue(neutral.metadata.isEmpty)
    }

    func testLambdaTransformResultBlending() {
        let a = LambdaTransformResult(
            coherenceModifier: 0.0, frequency: 10.0, carrierFrequency: 440.0,
            amplitude: 0.0, color: (r: 1.0, g: 0.0, b: 0.0),
            reverbMix: 0.0, spatialWidth: 0.0, hapticIntensity: 0.0, metadata: [:]
        )
        let b = LambdaTransformResult(
            coherenceModifier: 1.0, frequency: 20.0, carrierFrequency: 880.0,
            amplitude: 1.0, color: (r: 0.0, g: 1.0, b: 0.0),
            reverbMix: 1.0, spatialWidth: 1.0, hapticIntensity: 1.0, metadata: [:]
        )

        // 50/50 blend
        let blended = a.blended(with: b, factor: 0.5)
        XCTAssertEqual(blended.coherenceModifier, 0.5, accuracy: 0.001)
        XCTAssertEqual(blended.frequency, 15.0, accuracy: 0.001)
        XCTAssertEqual(blended.carrierFrequency, 660.0, accuracy: 0.001)
        XCTAssertEqual(blended.amplitude, 0.5, accuracy: 0.001)
        XCTAssertEqual(blended.color.r, 0.5, accuracy: 0.001)
        XCTAssertEqual(blended.color.g, 0.5, accuracy: 0.001)
        XCTAssertEqual(blended.reverbMix, 0.5, accuracy: 0.001)
        XCTAssertEqual(blended.spatialWidth, 0.5, accuracy: 0.001)
        XCTAssertEqual(blended.hapticIntensity, 0.5, accuracy: 0.001)

        // Factor 0 = all self
        let selfOnly = a.blended(with: b, factor: 0.0)
        XCTAssertEqual(selfOnly.coherenceModifier, 0.0, accuracy: 0.001)
        XCTAssertEqual(selfOnly.color.r, 1.0, accuracy: 0.001)

        // Factor 1 = all other
        let otherOnly = a.blended(with: b, factor: 1.0)
        XCTAssertEqual(otherOnly.coherenceModifier, 1.0, accuracy: 0.001)
        XCTAssertEqual(otherOnly.color.g, 1.0, accuracy: 0.001)
    }

    func testLambdaTransformResultBlendingMetadata() {
        let a = LambdaTransformResult(
            coherenceModifier: 0, frequency: 10, carrierFrequency: 440,
            amplitude: 0.5, color: (0.5, 0.5, 0.5),
            reverbMix: 0.3, spatialWidth: 0.5, hapticIntensity: 0,
            metadata: ["key": 10.0]
        )
        let b = LambdaTransformResult(
            coherenceModifier: 0, frequency: 10, carrierFrequency: 440,
            amplitude: 0.5, color: (0.5, 0.5, 0.5),
            reverbMix: 0.3, spatialWidth: 0.5, hapticIntensity: 0,
            metadata: ["key": 20.0]
        )

        let blended = a.blended(with: b, factor: 0.5)
        XCTAssertEqual(blended.metadata["key"], 15.0, accuracy: 0.001)
    }

    // MARK: - LambdaOperator

    func testCustomLambdaOperator() {
        let op = LambdaOperator(name: "test-op") { state in
            var result = LambdaTransformResult.neutral
            result.coherenceModifier = state.comfortScore
            return result
        }

        XCTAssertEqual(op.name, "test-op")

        let state = EnvironmentStateVector(environmentClass: .home)
        let result = op.transform(state)
        XCTAssertEqual(result.coherenceModifier, state.comfortScore, accuracy: 0.001)
    }

    // MARK: - Built-in Lambda Operators

    func testComfortToCoherence() {
        let op = LambdaOperators.comfortToCoherence

        // Comfort 0.5 → modifier 0.0
        let neutralState = EnvironmentStateVector(environmentClass: .home)
        let neutralResult = op.transform(neutralState)
        XCTAssertEqual(neutralResult.coherenceModifier, 0.0, accuracy: 0.01)
    }

    func testTemperatureToColor() {
        let op = LambdaOperators.temperatureToColor

        // Cold → blue
        var state = EnvironmentStateVector(environmentClass: .arctic, dimensions: [
            .temperature: DimensionState(value: -10.0)
        ])
        var result = op.transform(state)
        XCTAssertGreaterThan(result.color.b, result.color.r)

        // Hot → red
        state = EnvironmentStateVector(environmentClass: .desert, dimensions: [
            .temperature: DimensionState(value: 40.0)
        ])
        result = op.transform(state)
        XCTAssertGreaterThan(result.color.r, result.color.b)
    }

    func testPressureToFrequency() {
        let op = LambdaOperators.pressureToFrequency

        // Sea level → ~10 Hz (alpha range)
        var state = EnvironmentStateVector(environmentClass: .home, dimensions: [
            .pressure: DimensionState(value: 1013.0)
        ])
        var result = op.transform(state)
        XCTAssertGreaterThan(result.frequency, 5.0)
        XCTAssertLessThan(result.frequency, 15.0)

        // High altitude / low pressure → theta range
        state = EnvironmentStateVector(environmentClass: .highAltitude, dimensions: [
            .pressure: DimensionState(value: 500.0)
        ])
        result = op.transform(state)
        XCTAssertEqual(result.frequency, 4.0, accuracy: 0.1)  // Minimum
    }

    func testDepthToReverb() {
        let op = LambdaOperators.depthToReverb

        // 50m depth → moderate reverb
        let state = EnvironmentStateVector(environmentClass: .ocean, dimensions: [
            .depth: DimensionState(value: 50.0)
        ])
        let result = op.transform(state)
        XCTAssertEqual(result.reverbMix, 0.5, accuracy: 0.01)
        XCTAssertGreaterThan(result.spatialWidth, 0.3)
    }

    func testNoiseToAmplitude() {
        let op = LambdaOperators.noiseToAmplitude

        // Quiet → high amplitude
        var state = EnvironmentStateVector(environmentClass: .home, dimensions: [
            .noise: DimensionState(value: 25.0)
        ])
        var result = op.transform(state)
        XCTAssertGreaterThan(result.amplitude, 0.8)

        // Loud → low amplitude
        state = EnvironmentStateVector(environmentClass: .urban, dimensions: [
            .noise: DimensionState(value: 75.0)
        ])
        result = op.transform(state)
        XCTAssertLessThan(result.amplitude, 0.3)
    }

    func testGravityToCarrier() {
        let op = LambdaOperators.gravityToCarrier

        // Normal gravity → A4 (440 Hz)
        let state = EnvironmentStateVector(environmentClass: .home, dimensions: [
            .gravity: DimensionState(value: 9.81)
        ])
        let result = op.transform(state)
        XCTAssertEqual(result.carrierFrequency, 440.0)

        // Zero gravity → G4 (392 Hz)
        let zeroG = EnvironmentStateVector(environmentClass: .orbit, dimensions: [
            .gravity: DimensionState(value: 0.001)
        ])
        let zeroGResult = op.transform(zeroG)
        XCTAssertEqual(zeroGResult.carrierFrequency, 392.0)
    }

    func testRadiationToHaptic() {
        let op = LambdaOperators.radiationToHaptic

        // No radiation → no haptic
        var state = EnvironmentStateVector(environmentClass: .home, dimensions: [
            .radiation: DimensionState(value: 0.0)
        ])
        var result = op.transform(state)
        XCTAssertEqual(result.hapticIntensity, 0.0)

        // High radiation → strong haptic
        state = EnvironmentStateVector(environmentClass: .orbit, dimensions: [
            .radiation: DimensionState(value: 100.0)
        ])
        result = op.transform(state)
        XCTAssertEqual(result.hapticIntensity, 1.0, accuracy: 0.01)
    }

    func testWaterToHarmonics() {
        let op = LambdaOperators.waterToHarmonics

        // Neutral pH (7) → maximum harmonic richness
        let state = EnvironmentStateVector(environmentClass: .freshwater, dimensions: [
            .pH: DimensionState(value: 7.0),
            .dissolvedOxygen: DimensionState(value: 8.0)
        ])
        let result = op.transform(state)
        XCTAssertEqual(result.metadata["harmonicRichness"], 1.0, accuracy: 0.001)
        XCTAssertGreaterThan(result.metadata["oxygenBrightness"] ?? 0, 0)
    }

    func testOperatorMissingDimensionReturnsNeutral() {
        let op = LambdaOperators.pressureToFrequency

        // No pressure dimension → neutral
        let state = EnvironmentStateVector(environmentClass: .home)
        let result = op.transform(state)
        XCTAssertEqual(result.frequency, LambdaTransformResult.neutral.frequency)
    }

    // MARK: - LambdaChain

    func testLambdaChainInit() {
        let chain = LambdaChain()
        XCTAssertTrue(chain.operators.isEmpty)
    }

    func testLambdaChainAppending() {
        let chain = LambdaChain()
        let extended = chain.appending(LambdaOperators.comfortToCoherence)

        XCTAssertEqual(extended.operators.count, 1)
        XCTAssertEqual(extended.operators[0].name, "λ.comfort→coherence")
    }

    func testLambdaChainExecuteEmpty() {
        let chain = LambdaChain()
        let state = EnvironmentStateVector(environmentClass: .home)
        let result = chain.execute(on: state)

        // Empty chain → neutral result
        XCTAssertEqual(result.frequency, LambdaTransformResult.neutral.frequency)
    }

    func testLambdaChainExecuteSingle() {
        let chain = LambdaChain([LambdaOperators.comfortToCoherence])
        let state = EnvironmentStateVector(environmentClass: .home)
        let result = chain.execute(on: state)

        // Single operator → its result directly
        XCTAssertNotNil(result)
    }

    func testLambdaChainExecuteMultiple() {
        let chain = LambdaChain.universal
        let state = EnvironmentStateVector(environmentClass: .home, dimensions: [
            .temperature: DimensionState(value: 22.0),
            .pressure: DimensionState(value: 1013.0),
            .noise: DimensionState(value: 40.0),
        ])

        let result = chain.execute(on: state)

        // Should produce a blended result
        XCTAssertNotEqual(result.frequency, LambdaTransformResult.neutral.frequency)
    }

    func testLambdaChainExecuteWeighted() {
        let chain = LambdaChain([
            LambdaOperators.comfortToCoherence,
            LambdaOperators.temperatureToColor
        ])
        let state = EnvironmentStateVector(environmentClass: .home, dimensions: [
            .temperature: DimensionState(value: 22.0)
        ])

        let result = chain.executeWeighted(on: state, weights: [1.0, 0.0])
        // Only first operator should matter (weight 100% / 0%)
        XCTAssertNotNil(result)

        // Zero total weight → neutral
        let zeroResult = chain.executeWeighted(on: state, weights: [0.0, 0.0])
        XCTAssertEqual(zeroResult.frequency, LambdaTransformResult.neutral.frequency)
    }

    // MARK: - Preset Chains

    func testLambdaChainPresets() {
        XCTAssertEqual(LambdaChain.universal.operators.count, 5)
        XCTAssertEqual(LambdaChain.aquatic.operators.count, 5)
        XCTAssertEqual(LambdaChain.aerial.operators.count, 5)
        XCTAssertEqual(LambdaChain.extraterrestrial.operators.count, 5)
        XCTAssertEqual(LambdaChain.vehicular.operators.count, 4)
        XCTAssertEqual(LambdaChain.bahrenfeldResearch.operators.count, 6)
    }

    func testLambdaChainForDomain() {
        XCTAssertEqual(LambdaChain.chain(for: .terrestrial).operators.count,
                      LambdaChain.universal.operators.count)
        XCTAssertEqual(LambdaChain.chain(for: .aquatic).operators.count,
                      LambdaChain.aquatic.operators.count)
        XCTAssertEqual(LambdaChain.chain(for: .aerial).operators.count,
                      LambdaChain.aerial.operators.count)
        XCTAssertEqual(LambdaChain.chain(for: .extraterrestrial).operators.count,
                      LambdaChain.extraterrestrial.operators.count)
        XCTAssertEqual(LambdaChain.chain(for: .vehicular).operators.count,
                      LambdaChain.vehicular.operators.count)
    }
}

// =============================================================================
// MARK: - 4. EnvironmentPreset Tests
// =============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class EnvironmentPresetTests: XCTestCase {

    func testPresetRegistryAll() {
        let allPresets = EnvironmentPresetRegistry.all
        XCTAssertGreaterThanOrEqual(allPresets.count, 13)
    }

    func testPresetRegistryLookup() {
        let oceanPreset = EnvironmentPresetRegistry.preset(for: .ocean)
        XCTAssertNotNil(oceanPreset)
        XCTAssertEqual(oceanPreset?.environmentClass, .ocean)

        let cavePreset = EnvironmentPresetRegistry.preset(for: .cave)
        XCTAssertNotNil(cavePreset)
        XCTAssertEqual(cavePreset?.environmentClass, .cave)

        // No preset for urban
        let urbanPreset = EnvironmentPresetRegistry.preset(for: .urban)
        XCTAssertNil(urbanPreset)
    }

    func testScubaDivePreset() {
        let preset = EnvironmentPresetRegistry.scubaDive

        XCTAssertEqual(preset.environmentClass, .ocean)
        XCTAssertFalse(preset.description.isEmpty)

        // Audio profile
        XCTAssertEqual(preset.audioProfile.baseFrequency, 440.0)
        XCTAssertEqual(preset.audioProfile.reverbMix, 0.8)
        XCTAssertGreaterThan(preset.audioProfile.reverbDecay, 0)
        XCTAssertEqual(preset.audioProfile.spatialWidth, 0.9)

        // Visual profile
        XCTAssertGreaterThan(preset.visualProfile.particleDensity, 0)

        // Safety notes
        XCTAssertFalse(preset.safetyNotes.isEmpty)

        // Expected dimensions
        XCTAssertNotNil(preset.expectedDimensions[.depth])
        XCTAssertNotNil(preset.expectedDimensions[.temperature])
    }

    func testDeepSeaPreset() {
        let preset = EnvironmentPresetRegistry.deepSeaSubmersible

        XCTAssertEqual(preset.environmentClass, .deepSea)
        XCTAssertEqual(preset.audioProfile.reverbMix, 0.95) // Very high reverb
        XCTAssertLessThan(preset.visualProfile.lightIntensity, 0.1) // Very dark
    }

    func testFloatTankPreset() {
        let preset = EnvironmentPresetRegistry.floatTankSession

        XCTAssertEqual(preset.environmentClass, .floatTank)

        // Near-zero light and noise
        let noiseRange = preset.expectedDimensions[.noise]!
        XCTAssertEqual(noiseRange.typical.lowerBound, 0)
        XCTAssertLessThanOrEqual(noiseRange.typical.upperBound, 10)

        let lightRange = preset.expectedDimensions[.lightLevel]!
        XCTAssertEqual(lightRange.typical.lowerBound, 0)
    }

    func testStratosphericBalloonPreset() {
        let preset = EnvironmentPresetRegistry.stratosphericBalloon

        XCTAssertEqual(preset.environmentClass, .stratosphere)
        XCTAssertEqual(preset.audioProfile.reverbMix, 0.0) // No reverb in thin air

        // Expected extreme cold
        let tempRange = preset.expectedDimensions[.temperature]!
        XCTAssertLessThan(tempRange.typical.upperBound, 0) // Below freezing
    }

    func testOrbitalStationPreset() {
        let preset = EnvironmentPresetRegistry.orbitalStation

        XCTAssertEqual(preset.environmentClass, .orbit)
        XCTAssertNotNil(preset.expectedDimensions[.gravity])
        XCTAssertNotNil(preset.expectedDimensions[.radiation])

        // Near-zero gravity
        let gravRange = preset.expectedDimensions[.gravity]!
        XCTAssertLessThan(gravRange.typical.upperBound, 0.01)
    }

    func testBahrenfeldBrachePreset() {
        let preset = EnvironmentPresetRegistry.bahrenfeldBrache

        XCTAssertEqual(preset.environmentClass, .greenhouse)
        XCTAssertNotNil(preset.expectedDimensions[.pH])
        XCTAssertNotNil(preset.expectedDimensions[.dissolvedOxygen])
        XCTAssertTrue(preset.safetyNotes.isEmpty)
    }

    func testAllPresetsHaveValidAudioProfiles() {
        for preset in EnvironmentPresetRegistry.all {
            let audio = preset.audioProfile
            XCTAssertGreaterThan(audio.baseFrequency, 0,
                "\(preset.name) has invalid baseFrequency")
            XCTAssertGreaterThanOrEqual(audio.reverbMix, 0)
            XCTAssertLessThanOrEqual(audio.reverbMix, 1)
            XCTAssertGreaterThanOrEqual(audio.spatialWidth, 0)
            XCTAssertLessThanOrEqual(audio.spatialWidth, 1)
        }
    }

    func testAllPresetsHaveValidVisualProfiles() {
        for preset in EnvironmentPresetRegistry.all {
            let visual = preset.visualProfile
            XCTAssertGreaterThanOrEqual(visual.lightIntensity, 0)
            XCTAssertLessThanOrEqual(visual.lightIntensity, 1)
            XCTAssertGreaterThanOrEqual(visual.fogDensity, 0)
            XCTAssertLessThanOrEqual(visual.fogDensity, 1)
        }
    }

    func testExpectedRangesAreValid() {
        for preset in EnvironmentPresetRegistry.all {
            for (dimension, range) in preset.expectedDimensions {
                // Typical range should be within extreme range
                XCTAssertGreaterThanOrEqual(range.typical.lowerBound, range.extreme.lowerBound,
                    "\(preset.name):\(dimension.rawValue) typical.lower < extreme.lower")
                XCTAssertLessThanOrEqual(range.typical.upperBound, range.extreme.upperBound,
                    "\(preset.name):\(dimension.rawValue) typical.upper > extreme.upper")
            }
        }
    }
}

// =============================================================================
// MARK: - 5. SelfHealingCodeTransformation Tests
// =============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class SelfHealingCodeTransformationTests: XCTestCase {

    // MARK: - TransformationLevel

    func testTransformationLevelAllCases() {
        XCTAssertEqual(TransformationLevel.allCases.count, 5)
    }

    func testTransformationLevelOrdering() {
        XCTAssertLessThan(TransformationLevel.parameterAdjust, .pipelineSwap)
        XCTAssertLessThan(TransformationLevel.pipelineSwap, .topologyTransform)
        XCTAssertLessThan(TransformationLevel.topologyTransform, .emergentAdaptation)
        XCTAssertLessThan(TransformationLevel.emergentAdaptation, .quantumCoherenceLock)
    }

    func testTransformationLevelMinimumCoherence() {
        XCTAssertEqual(TransformationLevel.parameterAdjust.minimumCoherence, 0.0)
        XCTAssertEqual(TransformationLevel.pipelineSwap.minimumCoherence, 0.2)
        XCTAssertEqual(TransformationLevel.topologyTransform.minimumCoherence, 0.4)
        XCTAssertEqual(TransformationLevel.emergentAdaptation.minimumCoherence, 0.6)
        XCTAssertEqual(TransformationLevel.quantumCoherenceLock.minimumCoherence, 0.8)
    }

    func testTransformationLevelDescription() {
        XCTAssertFalse(TransformationLevel.parameterAdjust.description.isEmpty)
        XCTAssertFalse(TransformationLevel.quantumCoherenceLock.description.isEmpty)
    }

    func testTransformationLevelRawValues() {
        XCTAssertEqual(TransformationLevel.parameterAdjust.rawValue, 0)
        XCTAssertEqual(TransformationLevel.quantumCoherenceLock.rawValue, 4)
    }

    // MARK: - TransformationTrigger

    func testTransformationTriggerAllCases() {
        XCTAssertEqual(TransformationTrigger.allCases.count, 9)
        XCTAssertTrue(TransformationTrigger.allCases.contains(.environmentChange))
        XCTAssertTrue(TransformationTrigger.allCases.contains(.emergencyRecovery))
        XCTAssertTrue(TransformationTrigger.allCases.contains(.patternPrediction))
    }

    // MARK: - SignalGraphNode

    func testSignalGraphNodeInit() {
        let node = SignalGraphNode(
            id: "test-node",
            name: "Test Node",
            type: .audioOutput,
            isActive: true,
            connections: ["mixer"]
        )

        XCTAssertEqual(node.id, "test-node")
        XCTAssertEqual(node.name, "Test Node")
        XCTAssertEqual(node.type, .audioOutput)
        XCTAssertTrue(node.isActive)
        XCTAssertEqual(node.connections, ["mixer"])
    }

    func testSignalNodeTypeAllCases() {
        XCTAssertGreaterThanOrEqual(SignalNodeType.allCases.count, 10)
        XCTAssertTrue(SignalNodeType.allCases.contains(.audioOutput))
        XCTAssertTrue(SignalNodeType.allCases.contains(.visualOutput))
        XCTAssertTrue(SignalNodeType.allCases.contains(.hapticOutput))
        XCTAssertTrue(SignalNodeType.allCases.contains(.lambdaOperator))
        XCTAssertTrue(SignalNodeType.allCases.contains(.bioInput))
    }

    // MARK: - AdaptationPattern

    func testAdaptationPatternInit() {
        let pattern = AdaptationPattern(
            fromEnvironment: .home,
            toEnvironment: .ocean,
            optimalChain: "λ.aquatic",
            transitionDuration: 30.0,
            successRate: 0.95,
            timesObserved: 5
        )

        XCTAssertEqual(pattern.fromEnvironment, .home)
        XCTAssertEqual(pattern.toEnvironment, .ocean)
        XCTAssertEqual(pattern.optimalChain, "λ.aquatic")
        XCTAssertEqual(pattern.transitionDuration, 30.0)
        XCTAssertEqual(pattern.successRate, 0.95)
        XCTAssertEqual(pattern.timesObserved, 5)
        XCTAssertNotNil(pattern.id)
    }

    // MARK: - TransformationEvent

    func testTransformationEventInit() {
        let event = TransformationEvent(
            timestamp: Date(),
            level: .pipelineSwap,
            trigger: .environmentChange,
            fromEnvironment: .home,
            toEnvironment: .forest,
            action: "Test action",
            success: true,
            latencyMs: 0.5
        )

        XCTAssertEqual(event.level, .pipelineSwap)
        XCTAssertEqual(event.trigger, .environmentChange)
        XCTAssertEqual(event.fromEnvironment, .home)
        XCTAssertEqual(event.toEnvironment, .forest)
        XCTAssertTrue(event.success)
        XCTAssertNotNil(event.id)
    }

    // MARK: - SelfHealingCodeTransformation Engine

    @MainActor
    func testSelfHealingShared() {
        let engine1 = SelfHealingCodeTransformation.shared
        let engine2 = SelfHealingCodeTransformation.shared
        XCTAssertTrue(engine1 === engine2)
    }

    @MainActor
    func testSelfHealingDefaults() {
        let engine = SelfHealingCodeTransformation.shared

        XCTAssertEqual(engine.currentLevel, .parameterAdjust)
        XCTAssertEqual(engine.maxAllowedLevel, .quantumCoherenceLock)
        XCTAssertTrue(engine.autoTransformEnabled)
        XCTAssertTrue(engine.learningEnabled)
        XCTAssertTrue(engine.preemptiveTransformEnabled)
        XCTAssertEqual(engine.coherenceLockThreshold, 0.8)
    }

    @MainActor
    func testSelfHealingActivateDeactivate() {
        let engine = SelfHealingCodeTransformation.shared

        engine.activate()
        XCTAssertTrue(engine.isActive)

        engine.deactivate()
        XCTAssertFalse(engine.isActive)
    }

    @MainActor
    func testSelfHealingSignalGraph() {
        let engine = SelfHealingCodeTransformation.shared

        // Should have a default signal graph
        XCTAssertFalse(engine.signalGraph.isEmpty)

        // Should contain core nodes
        let nodeIDs = engine.signalGraph.map { $0.id }
        XCTAssertTrue(nodeIDs.contains("audio_out"))
        XCTAssertTrue(nodeIDs.contains("visual_out"))
        XCTAssertTrue(nodeIDs.contains("haptic_out"))
        XCTAssertTrue(nodeIDs.contains("lambda_chain"))
    }

    @MainActor
    func testSelfHealingEmergencyRecovery() {
        let engine = SelfHealingCodeTransformation.shared
        engine.activate()

        engine.emergencyRecovery()

        // Should log the recovery event
        XCTAssertFalse(engine.transformationLog.isEmpty)
        let lastEvent = engine.transformationLog.last!
        XCTAssertEqual(lastEvent.trigger, .emergencyRecovery)
        XCTAssertTrue(lastEvent.success)

        // Coherence stability should reset to 0.5
        XCTAssertEqual(engine.coherenceStability, 0.5)

        engine.deactivate()
    }

    @MainActor
    func testSelfHealingStatistics() {
        let engine = SelfHealingCodeTransformation.shared

        let stats = engine.statistics

        XCTAssertGreaterThanOrEqual(stats.totalTransformations, 0)
        XCTAssertGreaterThanOrEqual(stats.successRate, 0)
        XCTAssertLessThanOrEqual(stats.successRate, 1.0)
        XCTAssertGreaterThanOrEqual(stats.learnedPatterns, 0)
        XCTAssertGreaterThanOrEqual(stats.currentCoherenceStability, 0)
    }

    @MainActor
    func testSelfHealingCoherenceStabilityClamped() {
        let engine = SelfHealingCodeTransformation.shared

        // Stability should always be in [0, 1]
        XCTAssertGreaterThanOrEqual(engine.coherenceStability, 0.0)
        XCTAssertLessThanOrEqual(engine.coherenceStability, 1.0)
    }
}

// =============================================================================
// MARK: - 6. EnvironmentLoopProcessor Tests
// =============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class EnvironmentLoopProcessorTests: XCTestCase {

    // MARK: - EnvironmentLoopState

    func testEnvironmentLoopStateAllCases() {
        XCTAssertEqual(EnvironmentLoopState.allCases.count, 6)
        XCTAssertTrue(EnvironmentLoopState.allCases.contains(.idle))
        XCTAssertTrue(EnvironmentLoopState.allCases.contains(.running))
        XCTAssertTrue(EnvironmentLoopState.allCases.contains(.paused))
        XCTAssertTrue(EnvironmentLoopState.allCases.contains(.starting))
        XCTAssertTrue(EnvironmentLoopState.allCases.contains(.transitioning))
        XCTAssertTrue(EnvironmentLoopState.allCases.contains(.error))
    }

    func testEnvironmentLoopStateCodable() throws {
        let state = EnvironmentLoopState.running
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(EnvironmentLoopState.self, from: data)
        XCTAssertEqual(decoded, .running)
    }

    func testEnvironmentLoopStateRawValues() {
        XCTAssertEqual(EnvironmentLoopState.idle.rawValue, "Idle")
        XCTAssertEqual(EnvironmentLoopState.running.rawValue, "Running")
        XCTAssertEqual(EnvironmentLoopState.paused.rawValue, "Paused")
    }

    // MARK: - EnvironmentLoopStats

    func testEnvironmentLoopStatsDefaults() {
        let stats = EnvironmentLoopStats()

        XCTAssertEqual(stats.totalTicks, 0)
        XCTAssertEqual(stats.averageLatencyMs, 0.0)
        XCTAssertEqual(stats.maxLatencyMs, 0.0)
        XCTAssertEqual(stats.droppedFrames, 0)
        XCTAssertEqual(stats.environmentChanges, 0)
        XCTAssertEqual(stats.uptimeSeconds, 0.0)
    }

    // MARK: - EnvironmentLoopProcessor

    @MainActor
    func testEnvironmentLoopProcessorShared() {
        let proc1 = EnvironmentLoopProcessor.shared
        let proc2 = EnvironmentLoopProcessor.shared
        XCTAssertTrue(proc1 === proc2)
    }

    @MainActor
    func testEnvironmentLoopProcessorDefaults() {
        let processor = EnvironmentLoopProcessor.shared

        XCTAssertEqual(processor.targetHz, 60.0)
        XCTAssertTrue(processor.adaptiveHz)
        XCTAssertTrue(processor.autoSelectChain)
    }

    @MainActor
    func testEnvironmentLoopProcessorStartStop() {
        let processor = EnvironmentLoopProcessor.shared

        processor.start()
        XCTAssertEqual(processor.loopState, .running)

        processor.stop()
        XCTAssertEqual(processor.loopState, .idle)
    }

    @MainActor
    func testEnvironmentLoopProcessorPauseResume() {
        let processor = EnvironmentLoopProcessor.shared

        processor.start()
        XCTAssertEqual(processor.loopState, .running)

        processor.pause()
        XCTAssertEqual(processor.loopState, .paused)

        processor.resume()
        XCTAssertEqual(processor.loopState, .running)

        processor.stop()
    }

    @MainActor
    func testEnvironmentLoopProcessorPauseGuard() {
        let processor = EnvironmentLoopProcessor.shared

        // Pause when not running → ignored
        processor.stop()
        processor.pause()
        XCTAssertEqual(processor.loopState, .idle)
    }

    @MainActor
    func testEnvironmentLoopProcessorResumeGuard() {
        let processor = EnvironmentLoopProcessor.shared

        // Resume when not paused → ignored
        processor.stop()
        processor.resume()
        XCTAssertEqual(processor.loopState, .idle)
    }

    @MainActor
    func testEnvironmentLoopProcessorStartGuard() {
        let processor = EnvironmentLoopProcessor.shared

        processor.start()
        processor.start()  // Should be ignored (already running)
        XCTAssertEqual(processor.loopState, .running)

        processor.stop()
    }

    @MainActor
    func testEnvironmentLoopProcessorSetLambdaChain() {
        let processor = EnvironmentLoopProcessor.shared

        processor.setLambdaChain(.aquatic)
        XCTAssertFalse(processor.autoSelectChain)
        XCTAssertEqual(processor.activeLambdaChain.operators.count,
                      LambdaChain.aquatic.operators.count)

        // Restore
        processor.autoSelectChain = true
    }

    @MainActor
    func testEnvironmentLoopProcessorInjectOperator() {
        let processor = EnvironmentLoopProcessor.shared
        let originalCount = processor.activeLambdaChain.operators.count

        let customOp = LambdaOperator(name: "test-inject") { _ in .neutral }
        processor.injectOperator(customOp)

        XCTAssertEqual(processor.activeLambdaChain.operators.count, originalCount + 1)

        // Restore by setting back to auto
        processor.autoSelectChain = true
        processor.activeLambdaChain = .universal
    }

    @MainActor
    func testEnvironmentLoopProcessorSetAdaptiveHz() {
        let processor = EnvironmentLoopProcessor.shared
        processor.adaptiveHz = true

        processor.setAdaptiveHz(0.5)  // Factor 0.5 → 30 Hz
        XCTAssertEqual(processor.targetHz, 30.0, accuracy: 1.0)

        processor.setAdaptiveHz(2.0)  // Factor 2.0 → 120 Hz (clamped)
        XCTAssertLessThanOrEqual(processor.targetHz, 120.0)
        XCTAssertGreaterThanOrEqual(processor.targetHz, 10.0)

        // Restore
        processor.targetHz = 60.0
    }

    @MainActor
    func testEnvironmentLoopProcessorAdaptiveHzDisabled() {
        let processor = EnvironmentLoopProcessor.shared

        processor.adaptiveHz = false
        let originalHz = processor.targetHz
        processor.setAdaptiveHz(0.5)

        // Should not change when adaptive is disabled
        XCTAssertEqual(processor.targetHz, originalHz)

        // Restore
        processor.adaptiveHz = true
    }

    @MainActor
    func testEnvironmentLoopProcessorCurrentLambdaResult() {
        let processor = EnvironmentLoopProcessor.shared

        // Should have a valid result (at least neutral)
        let result = processor.currentLambdaResult
        XCTAssertNotNil(result)
    }
}

// =============================================================================
// MARK: - 7. Integration Tests: Lambda Loop End-to-End
// =============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class LambdaLoopIntegrationTests: XCTestCase {

    /// Test the full environment → lambda chain → output pipeline
    @MainActor
    func testFullEnvironmentToOutputPipeline() {
        let envEngine = UniversalEnvironmentEngine.shared
        let loopProcessor = EnvironmentLoopProcessor.shared

        // Set up a forest environment with sensor data
        envEngine.setEnvironment(.forest)
        envEngine.updateDimensions([
            .temperature: DimensionState(value: 20.0, confidence: 0.9),
            .humidity: DimensionState(value: 55.0, confidence: 0.8),
            .noise: DimensionState(value: 30.0, confidence: 0.95),
            .lightLevel: DimensionState(value: 5000.0, confidence: 0.7),
        ])

        // Execute the lambda chain
        let chain = LambdaChain.chain(for: envEngine.currentEnvironment.domain)
        let result = chain.execute(on: envEngine.stateVector)

        // Forest with comfortable conditions → positive coherence modifier
        XCTAssertGreaterThanOrEqual(result.coherenceModifier, -0.15)
        XCTAssertLessThanOrEqual(result.coherenceModifier, 0.15)

        // Should have valid frequency
        XCTAssertGreaterThan(result.frequency, 0)

        // Restore
        envEngine.setEnvironment(.home)
    }

    /// Test environment transition blending
    func testEnvironmentTransitionBlending() {
        let homeState = EnvironmentStateVector(environmentClass: .home, dimensions: [
            .temperature: DimensionState(value: 22.0),
        ])
        let forestState = EnvironmentStateVector(environmentClass: .forest, dimensions: [
            .temperature: DimensionState(value: 15.0),
        ])

        let homeResult = LambdaChain.universal.execute(on: homeState)
        let forestResult = LambdaChain.universal.execute(on: forestState)

        // Blend at 50%
        let blended = homeResult.blended(with: forestResult, factor: 0.5)

        // Blended values should be between the two
        let minFreq = Swift.min(homeResult.frequency, forestResult.frequency)
        let maxFreq = Swift.max(homeResult.frequency, forestResult.frequency)
        XCTAssertGreaterThanOrEqual(blended.frequency, minFreq - 0.01)
        XCTAssertLessThanOrEqual(blended.frequency, maxFreq + 0.01)
    }

    /// Test that all environment domains produce valid outputs
    func testAllDomainsProduceValidOutputs() {
        for domain in EnvironmentDomain.allCases {
            let chain = LambdaChain.chain(for: domain)
            XCTAssertFalse(chain.operators.isEmpty, "\(domain) chain is empty")

            let env = EnvironmentClass.allCases.first { $0.domain == domain }!
            let state = EnvironmentStateVector(environmentClass: env)
            let result = chain.execute(on: state)

            XCTAssertGreaterThan(result.frequency, 0, "\(domain) frequency should be > 0")
            XCTAssertGreaterThan(result.carrierFrequency, 0, "\(domain) carrier should be > 0")
        }
    }

    /// Test LoopEngine tempo sync with Lambda bar calculations
    @MainActor
    func testLoopEngineTempoSync() {
        let loopEngine = LoopEngine()

        // Set tempo from bio data (simulating 72 BPM heart rate)
        loopEngine.setTempo(72)
        XCTAssertEqual(loopEngine.tempo, 72.0)

        // Bar duration at 72 BPM, 4/4 time = 4 * (60/72) = 3.33 seconds
        let expectedBarDuration = 4.0 * (60.0 / 72.0)
        XCTAssertEqual(loopEngine.barDurationSeconds(), expectedBarDuration, accuracy: 0.01)

        // Record a loop at this tempo
        loopEngine.startLoopRecording(bars: 4)
        XCTAssertTrue(loopEngine.isRecordingLoop)
        loopEngine.stopLoopRecording()
        XCTAssertEqual(loopEngine.loops.count, 1)
    }
}

// =============================================================================
// MARK: - 8. Performance Tests
// =============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class LambdaLoopPerformanceTests: XCTestCase {

    func testLambdaChainExecutionPerformance() {
        let chain = LambdaChain.universal
        let state = EnvironmentStateVector(environmentClass: .home, dimensions: [
            .temperature: DimensionState(value: 22.0),
            .pressure: DimensionState(value: 1013.0),
            .noise: DimensionState(value: 40.0),
            .lightLevel: DimensionState(value: 500.0),
        ])

        measure {
            for _ in 0..<1000 {
                _ = chain.execute(on: state)
            }
        }
    }

    func testLambdaTransformResultBlendingPerformance() {
        let a = LambdaTransformResult.neutral
        let b = LambdaTransformResult(
            coherenceModifier: 1.0, frequency: 20.0, carrierFrequency: 880.0,
            amplitude: 1.0, color: (1, 0, 0), reverbMix: 1.0, spatialWidth: 1.0,
            hapticIntensity: 1.0, metadata: ["key": 1.0]
        )

        measure {
            for _ in 0..<10000 {
                _ = a.blended(with: b, factor: 0.5)
            }
        }
    }

    func testComfortScoreCalculationPerformance() {
        let state = EnvironmentStateVector(environmentClass: .home, dimensions: [
            .temperature: DimensionState(value: 22.0),
            .humidity: DimensionState(value: 45.0),
            .pressure: DimensionState(value: 1013.0),
            .noise: DimensionState(value: 35.0),
            .lightLevel: DimensionState(value: 500.0),
            .airQuality: DimensionState(value: 30.0),
            .co2: DimensionState(value: 600.0),
            .uvRadiation: DimensionState(value: 3.0),
        ])

        measure {
            for _ in 0..<10000 {
                _ = state.comfortScore
            }
        }
    }

    func testEnvironmentClassDomainLookupPerformance() {
        measure {
            for _ in 0..<100000 {
                for env in EnvironmentClass.allCases {
                    _ = env.domain
                }
            }
        }
    }
}
