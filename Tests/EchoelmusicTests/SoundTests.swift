#if canImport(AVFoundation)
// SoundTests.swift
// Echoelmusic — Comprehensive unit tests for the Sound module
//
// Tests all testable value types, enums, structs, and pure functions
// from Sources/Echoelmusic/Sound/ without framework dependencies.

import XCTest
import Foundation
@testable import Echoelmusic


// MARK: - BassEngineType Tests

final class BassEngineTypeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(BassEngineType.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(BassEngineType.sub808.rawValue, "808 Sub")
        XCTAssertEqual(BassEngineType.reese.rawValue, "Reese")
        XCTAssertEqual(BassEngineType.moog.rawValue, "Moog")
        XCTAssertEqual(BassEngineType.acid.rawValue, "Acid")
        XCTAssertEqual(BassEngineType.growl.rawValue, "Growl")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(BassEngineType(rawValue: "808 Sub"), .sub808)
        XCTAssertEqual(BassEngineType(rawValue: "Acid"), .acid)
        XCTAssertNil(BassEngineType(rawValue: "nonexistent"))
    }

    func testCodableRoundTrip() throws {
        for engine in BassEngineType.allCases {
            let data = try JSONEncoder().encode(engine)
            let decoded = try JSONDecoder().decode(BassEngineType.self, from: data)
            XCTAssertEqual(engine, decoded)
        }
    }
}

// MARK: - EchoelBassConfig Tests

final class EchoelBassConfigTests: XCTestCase {

    func testDefaultValues() {
        let config = EchoelBassConfig()
        XCTAssertEqual(config.engineA, .sub808)
        XCTAssertEqual(config.engineB, .reese)
        XCTAssertEqual(config.morphPosition, 0.0)
        XCTAssertEqual(config.tuning, 0.0)
        XCTAssertEqual(config.octave, 0)
        XCTAssertEqual(config.subOscMix, 0.0)
        XCTAssertEqual(config.glideEnabled, true)
        XCTAssertEqual(config.glideTime, 0.08)
        XCTAssertEqual(config.filterCutoff, 800.0)
        XCTAssertEqual(config.filterResonance, 0.2)
        XCTAssertEqual(config.attack, 0.005)
        XCTAssertEqual(config.level, 0.8)
    }

    func testClassic808Preset() {
        let preset = EchoelBassConfig.classic808
        XCTAssertEqual(preset.engineA, .sub808)
        XCTAssertEqual(preset.engineB, .reese)
        XCTAssertEqual(preset.morphPosition, 0.0)
        XCTAssertTrue(preset.glideEnabled)
        XCTAssertEqual(preset.glideTime, 0.06)
        XCTAssertEqual(preset.glideRange, -12.0)
        XCTAssertEqual(preset.level, 0.85)
    }

    func testReeseMonsterPreset() {
        let preset = EchoelBassConfig.reeseMonster
        XCTAssertEqual(preset.engineA, .reese)
        XCTAssertEqual(preset.engineB, .growl)
        XCTAssertEqual(preset.reeseDetune, 20.0)
        XCTAssertEqual(preset.reeseVoices, 5)
    }

    func testAcid303Preset() {
        let preset = EchoelBassConfig.acid303
        XCTAssertEqual(preset.engineA, .acid)
        XCTAssertEqual(preset.acidAccent, 0.7)
        XCTAssertTrue(preset.acidSlide)
        XCTAssertEqual(preset.filterResonance, 0.7)
    }

    func testDubstepGrowlPreset() {
        let preset = EchoelBassConfig.dubstepGrowl
        XCTAssertEqual(preset.engineA, .growl)
        XCTAssertEqual(preset.growlFMRatio, 2.0)
        XCTAssertEqual(preset.growlFMDepth, 0.7)
        XCTAssertEqual(preset.growlFold, 0.5)
    }

    func testEquatable() {
        let a = EchoelBassConfig.classic808
        let b = EchoelBassConfig.classic808
        XCTAssertEqual(a, b)

        var c = a
        c.filterCutoff = 9999.0
        XCTAssertNotEqual(a, c)
    }

    func testCodableRoundTrip() throws {
        let config = EchoelBassConfig.acid303
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(EchoelBassConfig.self, from: data)
        XCTAssertEqual(config, decoded)
    }
}

// MARK: - TR808BassConfig Tests

final class TR808BassConfigTests: XCTestCase {

    func testDefaultValues() {
        let config = TR808BassConfig()
        XCTAssertTrue(config.pitchGlideEnabled)
        XCTAssertEqual(config.pitchGlideTime, 0.08)
        XCTAssertEqual(config.pitchGlideRange, -12.0)
        XCTAssertEqual(config.pitchGlideCurve, 0.7)
        XCTAssertEqual(config.tuning, 0.0)
        XCTAssertEqual(config.octave, 0)
        XCTAssertEqual(config.clickAmount, 0.3)
        XCTAssertEqual(config.clickFrequency, 1200.0)
        XCTAssertEqual(config.decay, 1.5)
        XCTAssertEqual(config.sustain, 0.0)
        XCTAssertEqual(config.release, 0.3)
        XCTAssertEqual(config.drive, 0.2)
        XCTAssertEqual(config.filterCutoff, 500.0)
        XCTAssertEqual(config.filterResonance, 0.0)
        XCTAssertEqual(config.level, 0.8)
        XCTAssertEqual(config.stereoWidth, 0.0)
    }

    func testClassic808Preset() {
        let preset = TR808BassConfig.classic808
        XCTAssertTrue(preset.pitchGlideEnabled)
        XCTAssertEqual(preset.pitchGlideTime, 0.06)
        XCTAssertEqual(preset.pitchGlideRange, -12.0)
        XCTAssertEqual(preset.level, 0.85)
    }

    func testHardTrapPreset() {
        let preset = TR808BassConfig.hardTrap
        XCTAssertEqual(preset.pitchGlideRange, -24.0)
        XCTAssertEqual(preset.clickAmount, 0.5)
        XCTAssertEqual(preset.drive, 0.4)
        XCTAssertEqual(preset.level, 0.9)
    }

    func testDeepSubPreset() {
        let preset = TR808BassConfig.deepSub
        XCTAssertEqual(preset.decay, 2.5)
        XCTAssertEqual(preset.filterCutoff, 200.0)
        XCTAssertEqual(preset.drive, 0.1)
    }

    func testDistorted808Preset() {
        let preset = TR808BassConfig.distorted808
        XCTAssertEqual(preset.drive, 0.7)
        XCTAssertEqual(preset.filterCutoff, 800.0)
    }

    func testLongSlidePreset() {
        let preset = TR808BassConfig.longSlide
        XCTAssertEqual(preset.pitchGlideTime, 0.25)
        XCTAssertEqual(preset.pitchGlideRange, -24.0)
        XCTAssertEqual(preset.decay, 3.0)
    }

    func testEquatable() {
        let a = TR808BassConfig.classic808
        let b = TR808BassConfig.classic808
        XCTAssertEqual(a, b)

        var c = a
        c.drive = 0.99
        XCTAssertNotEqual(a, c)
    }

    func testCodableRoundTrip() throws {
        let config = TR808BassConfig.hardTrap
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TR808BassConfig.self, from: data)
        XCTAssertEqual(config, decoded)
    }
}

// MARK: - PresetEngine Tests

final class PresetEngineTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(PresetEngine.ddsp.rawValue, "EchoelDDSP")
        XCTAssertEqual(PresetEngine.modalBank.rawValue, "EchoelModalBank")
        XCTAssertEqual(PresetEngine.cellular.rawValue, "EchoelCellular")
        XCTAssertEqual(PresetEngine.quant.rawValue, "EchoelQuant")
        XCTAssertEqual(PresetEngine.tr808.rawValue, "TR808BassSynth")
        XCTAssertEqual(PresetEngine.breakbeat.rawValue, "BreakbeatChopper")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(PresetEngine(rawValue: "EchoelDDSP"), .ddsp)
        XCTAssertEqual(PresetEngine(rawValue: "TR808BassSynth"), .tr808)
        XCTAssertNil(PresetEngine(rawValue: "invalid"))
    }

    func testCodableRoundTrip() throws {
        let engine = PresetEngine.modalBank
        let data = try JSONEncoder().encode(engine)
        let decoded = try JSONDecoder().decode(PresetEngine.self, from: data)
        XCTAssertEqual(engine, decoded)
    }
}

// MARK: - PresetCategory Tests

final class PresetCategoryTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(PresetCategory.allCases.count, 7)
    }

    func testRawValues() {
        XCTAssertEqual(PresetCategory.drums.rawValue, "ECHOEL_DRUMS")
        XCTAssertEqual(PresetCategory.bass.rawValue, "ECHOEL_BASS")
        XCTAssertEqual(PresetCategory.melodic.rawValue, "ECHOEL_MELODIC")
        XCTAssertEqual(PresetCategory.jungle.rawValue, "ECHOEL_JUNGLE")
        XCTAssertEqual(PresetCategory.textures.rawValue, "ECHOEL_TEXTURES")
        XCTAssertEqual(PresetCategory.fx.rawValue, "ECHOEL_FX")
        XCTAssertEqual(PresetCategory.chords.rawValue, "ECHOEL_CHORDS")
    }

    func testCodableRoundTrip() throws {
        for category in PresetCategory.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(PresetCategory.self, from: data)
            XCTAssertEqual(category, decoded)
        }
    }
}

// MARK: - SynthPreset Tests

final class SynthPresetTests: XCTestCase {

    func testInitialization() {
        let preset = SynthPreset(name: "Test Kick", category: .drums, engine: .modalBank, tags: ["kick", "hard"])
        XCTAssertEqual(preset.name, "Test Kick")
        XCTAssertEqual(preset.category, .drums)
        XCTAssertEqual(preset.engine, .modalBank)
        XCTAssertEqual(preset.tags, ["kick", "hard"])
    }

    func testDefaultParameterValues() {
        let preset = SynthPreset(name: "Default", category: .melodic, engine: .ddsp)
        XCTAssertEqual(preset.frequency, 440)
        XCTAssertEqual(preset.amplitude, 0.8)
        XCTAssertEqual(preset.attack, 0.005)
        XCTAssertEqual(preset.decay, 0.3)
        XCTAssertEqual(preset.sustain, 0.5)
        XCTAssertEqual(preset.release, 0.3)
        XCTAssertEqual(preset.duration, 2.0)
        XCTAssertEqual(preset.harmonicCount, 16)
        XCTAssertEqual(preset.harmonicity, 1.0)
        XCTAssertEqual(preset.noiseLevel, 0.1)
        XCTAssertEqual(preset.brightness, 0.5)
    }

    func testModalBankDefaults() {
        let preset = SynthPreset(name: "Bell", category: .melodic, engine: .modalBank)
        XCTAssertEqual(preset.material, "bell")
        XCTAssertEqual(preset.stiffness, 0.01)
        XCTAssertEqual(preset.damping, 0.001)
        XCTAssertEqual(preset.strikePosition, 0.3)
        XCTAssertEqual(preset.size, 1.0)
    }

    func testCellularDefaults() {
        let preset = SynthPreset(name: "CA", category: .textures, engine: .cellular)
        XCTAssertEqual(preset.caRule, 110)
        XCTAssertEqual(preset.synthMode, "wavetable")
        XCTAssertEqual(preset.evolutionRate, 10)
        XCTAssertEqual(preset.cellCount, 256)
    }

    func testQuantDefaults() {
        let preset = SynthPreset(name: "Quantum", category: .textures, engine: .quant)
        XCTAssertEqual(preset.potentialType, "harmonicOscillator")
        XCTAssertEqual(preset.gridSize, 512)
        XCTAssertEqual(preset.unisonVoices, 1)
        XCTAssertEqual(preset.unisonDetune, 0)
    }

    func testBioReactiveDefaults() {
        let preset = SynthPreset(name: "Bio", category: .melodic, engine: .ddsp)
        XCTAssertEqual(preset.bioCoherenceTarget, "harmonicity")
        XCTAssertEqual(preset.bioHrvTarget, "brightness")
        XCTAssertEqual(preset.bioBreathTarget, "amplitude")
    }

    func testUniqueIDs() {
        let a = SynthPreset(name: "A", category: .drums, engine: .ddsp)
        let b = SynthPreset(name: "B", category: .drums, engine: .ddsp)
        XCTAssertNotEqual(a.id, b.id)
    }

    func testCodableRoundTrip() throws {
        var preset = SynthPreset(name: "CodableTest", category: .bass, engine: .tr808, tags: ["sub", "808"])
        preset.frequency = 55.0
        preset.drive = 0.5
        preset.pitchGlide = 12.0
        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: data)
        XCTAssertEqual(decoded.name, "CodableTest")
        XCTAssertEqual(decoded.category, .bass)
        XCTAssertEqual(decoded.engine, .tr808)
        XCTAssertEqual(decoded.frequency, 55.0)
        XCTAssertEqual(decoded.drive, 0.5)
        XCTAssertEqual(decoded.tags, ["sub", "808"])
    }
}

// MARK: - SamplerConstants Tests

final class SamplerConstantsTests: XCTestCase {

    func testConstants() {
        XCTAssertEqual(SamplerConstants.maxZones, 128)
        XCTAssertEqual(SamplerConstants.maxVelocityLayers, 16)
        XCTAssertEqual(SamplerConstants.maxRoundRobin, 16)
        XCTAssertEqual(SamplerConstants.maxVoices, 64)
        XCTAssertEqual(SamplerConstants.maxModSlots, 8)
        XCTAssertEqual(SamplerConstants.sincTaps, 16)
    }
}

// MARK: - SamplerInterpolation Tests

final class SamplerInterpolationTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(SamplerInterpolation.allCases.count, 3)
    }

    func testRawValues() {
        XCTAssertEqual(SamplerInterpolation.linear.rawValue, "Linear")
        XCTAssertEqual(SamplerInterpolation.hermite.rawValue, "Hermite")
        XCTAssertEqual(SamplerInterpolation.sinc.rawValue, "Sinc")
    }

    func testQualityOrdering() {
        XCTAssertLessThan(SamplerInterpolation.linear.quality, SamplerInterpolation.hermite.quality)
        XCTAssertLessThan(SamplerInterpolation.hermite.quality, SamplerInterpolation.sinc.quality)
    }

    func testQualityValues() {
        XCTAssertEqual(SamplerInterpolation.linear.quality, 1)
        XCTAssertEqual(SamplerInterpolation.hermite.quality, 2)
        XCTAssertEqual(SamplerInterpolation.sinc.quality, 3)
    }
}

// MARK: - SamplerFilterType Tests

final class SamplerFilterTypeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(SamplerFilterType.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(SamplerFilterType.lowpass.rawValue, "Lowpass")
        XCTAssertEqual(SamplerFilterType.highpass.rawValue, "Highpass")
        XCTAssertEqual(SamplerFilterType.bandpass.rawValue, "Bandpass")
        XCTAssertEqual(SamplerFilterType.notch.rawValue, "Notch")
    }
}

// MARK: - ADSREnvelope Tests

final class ADSREnvelopeTests: XCTestCase {

    func testDefaultInit() {
        let env = ADSREnvelope()
        XCTAssertEqual(env.attack, 0.005)
        XCTAssertEqual(env.decay, 0.1)
        XCTAssertEqual(env.sustain, 0.8)
        XCTAssertEqual(env.release, 0.3)
        XCTAssertEqual(env.curve, 1.0)
    }

    func testParameterizedInit() {
        let env = ADSREnvelope(attack: 0.01, decay: 0.5, sustain: 0.6, release: 1.0)
        XCTAssertEqual(env.attack, 0.01)
        XCTAssertEqual(env.decay, 0.5)
        XCTAssertEqual(env.sustain, 0.6)
        XCTAssertEqual(env.release, 1.0)
        XCTAssertEqual(env.curve, 1.0) // curve retains default
    }

    func testMutability() {
        var env = ADSREnvelope()
        env.attack = 0.1
        env.sustain = 0.0
        env.curve = 2.0
        XCTAssertEqual(env.attack, 0.1)
        XCTAssertEqual(env.sustain, 0.0)
        XCTAssertEqual(env.curve, 2.0)
    }
}

// MARK: - EnvelopeState Tests

final class EnvelopeStateTests: XCTestCase {

    func testInitialState() {
        let state = EnvelopeState()
        XCTAssertEqual(state.stage, .idle)
        XCTAssertEqual(state.level, 0)
        XCTAssertEqual(state.sampleCounter, 0)
    }

    func testNoteOnTransitionsToAttack() {
        var state = EnvelopeState()
        state.noteOn()
        XCTAssertEqual(state.stage, .attack)
        XCTAssertEqual(state.sampleCounter, 0)
    }

    func testNoteOffTransitionsToRelease() {
        var state = EnvelopeState()
        state.noteOn()
        state.noteOff()
        XCTAssertEqual(state.stage, .release)
        XCTAssertEqual(state.sampleCounter, 0)
    }

    func testProcessAttackPhase() {
        var state = EnvelopeState()
        state.noteOn()
        let env = ADSREnvelope(attack: 0.01, decay: 0.1, sustain: 0.5, release: 0.3)
        let sampleRate: Float = 44100
        // Process one sample
        let level = state.process(env: env, sampleRate: sampleRate)
        XCTAssertGreaterThanOrEqual(level, 0)
        XCTAssertEqual(state.stage, .attack)
    }

    func testProcessReachesDecayAfterAttack() {
        var state = EnvelopeState()
        state.noteOn()
        let env = ADSREnvelope(attack: 0.001, decay: 0.1, sustain: 0.5, release: 0.3)
        let sampleRate: Float = 44100
        let attackSamples = Int(env.attack * sampleRate) + 1
        for _ in 0..<attackSamples {
            _ = state.process(env: env, sampleRate: sampleRate)
        }
        // Should have transitioned to decay
        XCTAssertEqual(state.stage, .decay)
    }

    func testIdleReturnsZero() {
        var state = EnvelopeState()
        let env = ADSREnvelope()
        let level = state.process(env: env, sampleRate: 44100)
        XCTAssertEqual(level, 0)
    }
}

// MARK: - SampleZone Tests

final class SampleZoneTests: XCTestCase {

    func testDefaultInit() {
        let zone = SampleZone(name: "TestZone", rootNote: 60)
        XCTAssertEqual(zone.name, "TestZone")
        XCTAssertEqual(zone.rootNote, 60)
        XCTAssertEqual(zone.keyRangeLow, 0)
        XCTAssertEqual(zone.keyRangeHigh, 127)
        XCTAssertEqual(zone.velocityLow, 0)
        XCTAssertEqual(zone.velocityHigh, 127)
        XCTAssertTrue(zone.sampleData.isEmpty)
        XCTAssertEqual(zone.sampleRate, 44100)
        XCTAssertFalse(zone.loopEnabled)
        XCTAssertEqual(zone.fineTune, 0)
        XCTAssertEqual(zone.gain, 1.0)
        XCTAssertEqual(zone.pan, 0)
    }

    func testMatchesMIDINoteAndVelocity() {
        var zone = SampleZone(name: "Zone")
        zone.keyRangeLow = 48
        zone.keyRangeHigh = 72
        zone.velocityLow = 64
        zone.velocityHigh = 127

        XCTAssertTrue(zone.matches(note: 60, velocity: 100))
        XCTAssertTrue(zone.matches(note: 48, velocity: 64))   // Lower bounds
        XCTAssertTrue(zone.matches(note: 72, velocity: 127))  // Upper bounds
        XCTAssertFalse(zone.matches(note: 47, velocity: 100)) // Below key range
        XCTAssertFalse(zone.matches(note: 73, velocity: 100)) // Above key range
        XCTAssertFalse(zone.matches(note: 60, velocity: 63))  // Below velocity
        XCTAssertFalse(zone.matches(note: 60, velocity: 0))   // Zero velocity
    }

    func testMatchesFullRange() {
        let zone = SampleZone(name: "Full")
        XCTAssertTrue(zone.matches(note: 0, velocity: 0))
        XCTAssertTrue(zone.matches(note: 127, velocity: 127))
        XCTAssertTrue(zone.matches(note: 60, velocity: 64))
    }

    func testUniqueIDs() {
        let a = SampleZone(name: "A")
        let b = SampleZone(name: "B")
        XCTAssertNotEqual(a.id, b.id)
    }
}

// MARK: - SamplerBioModulation Tests

final class SamplerBioModulationTests: XCTestCase {

    func testDefaultValues() {
        let bio = SamplerBioModulation()
        XCTAssertEqual(bio.hrvToFilterDepth, 0.3)
        XCTAssertEqual(bio.coherenceToResonance, 0.5)
        XCTAssertFalse(bio.heartRateToTempo)
        XCTAssertEqual(bio.breathToVolume, 0.2)
        XCTAssertEqual(bio.flowToComplexity, 0.4)
    }

    func testMutability() {
        var bio = SamplerBioModulation()
        bio.hrvToFilterDepth = 1.0
        bio.heartRateToTempo = true
        XCTAssertEqual(bio.hrvToFilterDepth, 1.0)
        XCTAssertTrue(bio.heartRateToTempo)
    }
}

// MARK: - SamplerLFO Tests

final class SamplerLFOTests: XCTestCase {

    func testDefaultValues() {
        let lfo = SamplerLFO()
        XCTAssertEqual(lfo.shape, .sine)
        XCTAssertEqual(lfo.rate, 1.0)
        XCTAssertEqual(lfo.depth, 0.5)
        XCTAssertFalse(lfo.tempoSync)
    }

    func testShapeAllCases() {
        XCTAssertEqual(SamplerLFO.Shape.allCases.count, 5)
        let cases: [SamplerLFO.Shape] = [.sine, .triangle, .saw, .square, .random]
        XCTAssertEqual(SamplerLFO.Shape.allCases, cases)
    }

    func testProcessOutputRange() {
        var lfo = SamplerLFO()
        lfo.depth = 1.0
        let sampleRate: Float = 44100
        for _ in 0..<1000 {
            let value = lfo.process(sampleRate: sampleRate)
            XCTAssertGreaterThanOrEqual(value, -1.0)
            XCTAssertLessThanOrEqual(value, 1.0)
        }
    }

    func testZeroDepthProducesZeroOrNear() {
        var lfo = SamplerLFO()
        lfo.depth = 0.0
        let value = lfo.process(sampleRate: 44100)
        XCTAssertEqual(value, 0.0, accuracy: 0.0001)
    }

    func testSquareWaveValues() {
        var lfo = SamplerLFO()
        lfo.shape = .square
        lfo.depth = 1.0
        lfo.rate = 1.0
        let val = lfo.process(sampleRate: 44100)
        // Square wave should be exactly 1.0 or -1.0 (times depth)
        XCTAssertTrue(abs(val) <= 1.0)
    }
}

// MARK: - EchoelSampler Tests

final class EchoelSamplerTests: XCTestCase {

    func testInitialization() {
        let sampler = EchoelSampler(sampleRate: 48000)
        XCTAssertTrue(sampler.zones.isEmpty)
        XCTAssertEqual(sampler.masterVolume, 0.8)
        XCTAssertEqual(sampler.filterCutoff, 8000)
        XCTAssertEqual(sampler.filterResonance, 0)
        XCTAssertEqual(sampler.filterType, .lowpass)
        XCTAssertEqual(sampler.interpolation, .hermite)
    }

    func testAddZone() {
        let sampler = EchoelSampler()
        var zone = SampleZone(name: "Kick", rootNote: 36)
        zone.sampleData = [Float](repeating: 0.5, count: 100)
        sampler.addZone(zone)
        XCTAssertEqual(sampler.zones.count, 1)
        XCTAssertEqual(sampler.zones[0].name, "Kick")
        // loopEnd should be auto-set to sampleData.count when it was 0
        XCTAssertEqual(sampler.zones[0].loopEnd, 100)
    }

    func testRemoveZone() {
        let sampler = EchoelSampler()
        sampler.addZone(SampleZone(name: "A"))
        sampler.addZone(SampleZone(name: "B"))
        XCTAssertEqual(sampler.zones.count, 2)
        sampler.removeZone(at: 0)
        XCTAssertEqual(sampler.zones.count, 1)
        XCTAssertEqual(sampler.zones[0].name, "B")
    }

    func testRemoveZoneOutOfBounds() {
        let sampler = EchoelSampler()
        sampler.addZone(SampleZone(name: "A"))
        sampler.removeZone(at: 5) // Should not crash
        XCTAssertEqual(sampler.zones.count, 1)
    }

    func testLoadSample() {
        let sampler = EchoelSampler()
        let data: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        let index = sampler.loadSample(data: data, sampleRate: 44100, rootNote: 60, name: "Test")
        XCTAssertEqual(index, 0)
        XCTAssertEqual(sampler.zones.count, 1)
        XCTAssertEqual(sampler.zones[0].name, "Test")
        XCTAssertEqual(sampler.zones[0].rootNote, 60)
        XCTAssertEqual(sampler.zones[0].sampleData.count, 5)
    }

    func testCreateDrumKit() {
        let kit = EchoelSampler.createDrumKit(sampleRate: 48000)
        XCTAssertEqual(kit.ampEnvelope.attack, 0.001)
        XCTAssertEqual(kit.ampEnvelope.decay, 0.3)
        XCTAssertEqual(kit.ampEnvelope.sustain, 0)
        XCTAssertEqual(kit.filterCutoff, 12000)
        XCTAssertEqual(kit.interpolation, .hermite)
    }

    func testCreateMelodic() {
        let melodic = EchoelSampler.createMelodic(sampleRate: 48000)
        XCTAssertEqual(melodic.ampEnvelope.attack, 0.05)
        XCTAssertEqual(melodic.ampEnvelope.sustain, 0.7)
        XCTAssertEqual(melodic.filterCutoff, 6000)
        XCTAssertEqual(melodic.filterResonance, 0.2)
        XCTAssertEqual(melodic.filterEnvelopeDepth, 0.4)
        XCTAssertEqual(melodic.interpolation, .sinc)
    }

    func testRenderSilenceWithNoZones() {
        let sampler = EchoelSampler()
        let output = sampler.render(frameCount: 256)
        XCTAssertEqual(output.count, 256)
        for sample in output {
            XCTAssertEqual(sample, 0.0)
        }
    }

    func testNoteOnNoteOff() {
        let sampler = EchoelSampler()
        let sineData = (0..<4410).map { Float(sin(Double($0) / 44100.0 * 440.0 * 2.0 * .pi)) }
        _ = sampler.loadSample(data: sineData, sampleRate: 44100, rootNote: 60, name: "Sine")
        sampler.noteOn(note: 60, velocity: 100)
        // Should not crash
        sampler.noteOff(note: 60)
        sampler.allNotesOff()
    }

    func testUpdateBioData() {
        let sampler = EchoelSampler()
        sampler.updateBioData(hrv: 80, coherence: 0.9, heartRate: 75, breathPhase: 0.7, flow: 0.6)
        XCTAssertEqual(sampler.hrvMs, 80)
        XCTAssertEqual(sampler.coherence, 0.9)
        XCTAssertEqual(sampler.heartRate, 75)
        XCTAssertEqual(sampler.breathPhase, 0.7)
        XCTAssertEqual(sampler.flowScore, 0.6)
    }

    func testSamplerErrorDescriptions() {
        XCTAssertNotNil(EchoelSampler.SamplerError.bufferCreationFailed.errorDescription)
        XCTAssertNotNil(EchoelSampler.SamplerError.noAudioData.errorDescription)
        XCTAssertNotNil(EchoelSampler.SamplerError.fileNotFound.errorDescription)
        XCTAssertNotNil(EchoelSampler.SamplerError.unsupportedFormat.errorDescription)
        XCTAssertEqual(EchoelSampler.SamplerError.bufferCreationFailed.errorDescription, "Failed to create audio buffer")
        XCTAssertEqual(EchoelSampler.SamplerError.noAudioData.errorDescription, "No audio data in file")
    }

    func testFreezeSynthToZone() {
        let sampler = EchoelSampler(sampleRate: 44100)
        let index = sampler.freezeSynthToZone(
            render: { frameCount in [Float](repeating: 0.5, count: frameCount) },
            duration: 0.1,
            rootNote: 60,
            name: "Frozen",
            loopEnabled: false
        )
        XCTAssertEqual(index, 0)
        XCTAssertEqual(sampler.zones.count, 1)
        XCTAssertEqual(sampler.zones[0].name, "Frozen")
        XCTAssertEqual(sampler.zones[0].rootNote, 60)
        XCTAssertFalse(sampler.zones[0].loopEnabled)
    }
}

// MARK: - DrumSlot Tests

final class DrumSlotTests: XCTestCase {

    func testInitialization() {
        let slot = DrumSlot(name: "Kick", audioData: [0.1, 0.2, 0.3], sampleRate: 44100, midiNote: 36, category: "drums")
        XCTAssertEqual(slot.name, "Kick")
        XCTAssertEqual(slot.audioData, [0.1, 0.2, 0.3])
        XCTAssertEqual(slot.sampleRate, 44100)
        XCTAssertEqual(slot.midiNote, 36)
        XCTAssertEqual(slot.category, "drums")
    }

    func testDefaultCategory() {
        let slot = DrumSlot(name: "Snare", audioData: [], sampleRate: 48000, midiNote: 38)
        XCTAssertEqual(slot.category, "")
    }

    func testUniqueIDs() {
        let a = DrumSlot(name: "A", audioData: [], sampleRate: 44100, midiNote: 36)
        let b = DrumSlot(name: "B", audioData: [], sampleRate: 44100, midiNote: 37)
        XCTAssertNotEqual(a.id, b.id)
    }
}

// MARK: - BeatStep Tests

final class BeatStepTests: XCTestCase {

    func testDefaultInit() {
        let step = BeatStep()
        XCTAssertFalse(step.isActive)
        XCTAssertEqual(step.velocity, 0.8)
        XCTAssertEqual(step.probability, 1.0)
    }

    func testParameterizedInit() {
        let step = BeatStep(isActive: true, velocity: 0.5, probability: 0.75)
        XCTAssertTrue(step.isActive)
        XCTAssertEqual(step.velocity, 0.5)
        XCTAssertEqual(step.probability, 0.75)
    }

    func testCodableRoundTrip() throws {
        let step = BeatStep(isActive: true, velocity: 0.9, probability: 0.5)
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(BeatStep.self, from: data)
        XCTAssertEqual(decoded.isActive, true)
        XCTAssertEqual(decoded.velocity, 0.9)
        XCTAssertEqual(decoded.probability, 0.5)
    }
}

// MARK: - BeatPattern Tests

final class BeatPatternTests: XCTestCase {

    func testDefaultInit() {
        let pattern = BeatPattern(name: "Test", trackCount: 4, stepCount: 16)
        XCTAssertEqual(pattern.name, "Test")
        XCTAssertEqual(pattern.stepCount, 16)
        XCTAssertEqual(pattern.tracks.count, 4)
        for track in pattern.tracks {
            XCTAssertEqual(track.count, 16)
            for step in track {
                XCTAssertFalse(step.isActive)
            }
        }
    }

    func testToggle() {
        var pattern = BeatPattern(name: "Toggle", trackCount: 2, stepCount: 8)
        XCTAssertFalse(pattern.tracks[0][0].isActive)
        pattern.toggle(track: 0, step: 0)
        XCTAssertTrue(pattern.tracks[0][0].isActive)
        pattern.toggle(track: 0, step: 0)
        XCTAssertFalse(pattern.tracks[0][0].isActive)
    }

    func testToggleOutOfBounds() {
        var pattern = BeatPattern(name: "Bounds", trackCount: 2, stepCount: 4)
        // Should not crash
        pattern.toggle(track: 10, step: 0)
        pattern.toggle(track: 0, step: 100)
    }

    func testFourOnFloorPattern() {
        let pattern = BeatPattern.fourOnFloor(trackCount: 3)
        // Kick on 0, 4, 8, 12
        XCTAssertTrue(pattern.tracks[0][0].isActive)
        XCTAssertTrue(pattern.tracks[0][4].isActive)
        XCTAssertTrue(pattern.tracks[0][8].isActive)
        XCTAssertTrue(pattern.tracks[0][12].isActive)
        XCTAssertFalse(pattern.tracks[0][1].isActive)
        // Snare on 4, 12
        XCTAssertTrue(pattern.tracks[1][4].isActive)
        XCTAssertTrue(pattern.tracks[1][12].isActive)
        XCTAssertFalse(pattern.tracks[1][0].isActive)
        // Hi-hat on even steps
        for step in stride(from: 0, to: 16, by: 2) {
            XCTAssertTrue(pattern.tracks[2][step].isActive)
        }
    }

    func testBreakbeatPattern() {
        let pattern = BeatPattern.breakbeat(trackCount: 3)
        XCTAssertTrue(pattern.tracks[0][0].isActive)
        XCTAssertTrue(pattern.tracks[0][6].isActive)
        XCTAssertTrue(pattern.tracks[0][10].isActive)
        XCTAssertTrue(pattern.tracks[1][4].isActive)
        XCTAssertTrue(pattern.tracks[1][12].isActive)
    }

    func testTrapPattern() {
        let pattern = BeatPattern.trap(trackCount: 3)
        XCTAssertTrue(pattern.tracks[0][0].isActive)
        XCTAssertTrue(pattern.tracks[0][7].isActive)
        XCTAssertTrue(pattern.tracks[0][10].isActive)
        // Hi-hat velocity alternation
        XCTAssertEqual(pattern.tracks[2][0].velocity, 0.9)
        XCTAssertEqual(pattern.tracks[2][1].velocity, 0.5)
    }

    func testDnbRollerPattern() {
        let pattern = BeatPattern.dnbRoller(trackCount: 3)
        XCTAssertTrue(pattern.tracks[0][0].isActive)
        XCTAssertTrue(pattern.tracks[0][10].isActive)
        // All hi-hats active
        for step in 0..<16 {
            XCTAssertTrue(pattern.tracks[2][step].isActive)
        }
    }

    func testUniqueIDs() {
        let a = BeatPattern(name: "A")
        let b = BeatPattern(name: "B")
        XCTAssertNotEqual(a.id, b.id)
    }
}

// MARK: - HiHatMode Tests

final class HiHatModeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(HiHatMode.allCases.count, 3)
    }

    func testRawValues() {
        XCTAssertEqual(HiHatMode.closed.rawValue, "Closed")
        XCTAssertEqual(HiHatMode.open.rawValue, "Open")
        XCTAssertEqual(HiHatMode.pedal.rawValue, "Pedal")
    }

    func testDecayTimes() {
        XCTAssertEqual(HiHatMode.closed.decayTime, 0.05)
        XCTAssertEqual(HiHatMode.open.decayTime, 0.4)
        XCTAssertEqual(HiHatMode.pedal.decayTime, 0.12)
    }

    func testDecayTimeOrdering() {
        XCTAssertLessThan(HiHatMode.closed.decayTime, HiHatMode.pedal.decayTime)
        XCTAssertLessThan(HiHatMode.pedal.decayTime, HiHatMode.open.decayTime)
    }
}

// MARK: - RollDivision Tests

final class RollDivisionTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(RollDivision.allCases.count, 7)
    }

    func testRawValues() {
        XCTAssertEqual(RollDivision.eighth.rawValue, "1/8")
        XCTAssertEqual(RollDivision.sixteenth.rawValue, "1/16")
        XCTAssertEqual(RollDivision.thirtysecond.rawValue, "1/32")
        XCTAssertEqual(RollDivision.sixtyfourth.rawValue, "1/64")
        XCTAssertEqual(RollDivision.eighthTriplet.rawValue, "1/8T")
        XCTAssertEqual(RollDivision.sixteenthTriplet.rawValue, "1/16T")
        XCTAssertEqual(RollDivision.thirtysecondTriplet.rawValue, "1/32T")
    }

    func testStepsPerBeat() {
        XCTAssertEqual(RollDivision.eighth.stepsPerBeat, 2.0)
        XCTAssertEqual(RollDivision.sixteenth.stepsPerBeat, 4.0)
        XCTAssertEqual(RollDivision.thirtysecond.stepsPerBeat, 8.0)
        XCTAssertEqual(RollDivision.sixtyfourth.stepsPerBeat, 16.0)
        XCTAssertEqual(RollDivision.eighthTriplet.stepsPerBeat, 3.0)
        XCTAssertEqual(RollDivision.sixteenthTriplet.stepsPerBeat, 6.0)
        XCTAssertEqual(RollDivision.thirtysecondTriplet.stepsPerBeat, 12.0)
    }

    func testStepsPerBeatIncreaseWithFinerDivisions() {
        XCTAssertLessThan(RollDivision.eighth.stepsPerBeat, RollDivision.sixteenth.stepsPerBeat)
        XCTAssertLessThan(RollDivision.sixteenth.stepsPerBeat, RollDivision.thirtysecond.stepsPerBeat)
        XCTAssertLessThan(RollDivision.thirtysecond.stepsPerBeat, RollDivision.sixtyfourth.stepsPerBeat)
    }

    func testTripletStepsPerBeatValues() {
        // Triplet eighth should be between straight eighth and straight sixteenth
        XCTAssertGreaterThan(RollDivision.eighthTriplet.stepsPerBeat, RollDivision.eighth.stepsPerBeat)
        XCTAssertLessThan(RollDivision.eighthTriplet.stepsPerBeat, RollDivision.sixteenth.stepsPerBeat)
    }
}

// MARK: - UniversalSoundLibrary Nested Type Tests

final class UniversalSoundLibraryTypeTests: XCTestCase {

    func testInstrumentCategoryAllCases() {
        XCTAssertEqual(UniversalSoundLibrary.Instrument.InstrumentCategory.allCases.count, 7)
    }

    func testInstrumentCategoryRawValues() {
        XCTAssertEqual(UniversalSoundLibrary.Instrument.InstrumentCategory.electronic.rawValue, "Electronic")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.InstrumentCategory.string.rawValue, "String")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.InstrumentCategory.wind.rawValue, "Wind")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.InstrumentCategory.percussion.rawValue, "Percussion")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.InstrumentCategory.vocal.rawValue, "Vocal")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.InstrumentCategory.keyboard.rawValue, "Keyboard")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.InstrumentCategory.special.rawValue, "Special/Experimental")
    }

    func testNoteRangeDisplayName() {
        let range = UniversalSoundLibrary.Instrument.NoteRange(lowestMIDI: 48, highestMIDI: 84)
        XCTAssertEqual(range.displayName, "MIDI 48-84")
    }

    func testNoteRangeFullRange() {
        let range = UniversalSoundLibrary.Instrument.NoteRange(lowestMIDI: 0, highestMIDI: 127)
        XCTAssertEqual(range.displayName, "MIDI 0-127")
    }

    func testTuningSystemRawValues() {
        XCTAssertEqual(UniversalSoundLibrary.Instrument.TuningSystem.equalTemperament.rawValue, "12-TET (Equal Temperament)")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.TuningSystem.justIntonation.rawValue, "Just Intonation")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.TuningSystem.quarterTone.rawValue, "Quarter-Tone (24-TET)")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.TuningSystem.slendro.rawValue, "Slendro (Gamelan)")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.TuningSystem.pelog.rawValue, "Pelog (Gamelan)")
    }

    func testHarmonicProfileRawValues() {
        XCTAssertEqual(UniversalSoundLibrary.Instrument.AudioCharacteristics.HarmonicProfile.pure.rawValue, "Pure (sine-like)")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.AudioCharacteristics.HarmonicProfile.odd.rawValue, "Odd harmonics (clarinet-like)")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.AudioCharacteristics.HarmonicProfile.full.rawValue, "Full spectrum (sawtooth-like)")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.AudioCharacteristics.HarmonicProfile.inharmonic.rawValue, "Inharmonic (bell-like)")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.AudioCharacteristics.HarmonicProfile.noise.rawValue, "Noise-based")
    }

    func testSynthTypeAllCases() {
        XCTAssertEqual(UniversalSoundLibrary.SynthEngine.SynthType.allCases.count, 10)
    }

    func testSynthTypeRawValues() {
        XCTAssertEqual(UniversalSoundLibrary.SynthEngine.SynthType.subtractive.rawValue, "Subtractive")
        XCTAssertEqual(UniversalSoundLibrary.SynthEngine.SynthType.fm.rawValue, "FM Synthesis")
        XCTAssertEqual(UniversalSoundLibrary.SynthEngine.SynthType.wavetable.rawValue, "Wavetable")
        XCTAssertEqual(UniversalSoundLibrary.SynthEngine.SynthType.granular.rawValue, "Granular")
        XCTAssertEqual(UniversalSoundLibrary.SynthEngine.SynthType.physicalModeling.rawValue, "Physical Modeling")
    }

    func testPresetCategoryAllCases() {
        XCTAssertEqual(UniversalSoundLibrary.SoundPreset.PresetCategory.allCases.count, 8)
    }

    func testPresetCategoryRawValues() {
        XCTAssertEqual(UniversalSoundLibrary.SoundPreset.PresetCategory.pad.rawValue, "Pad")
        XCTAssertEqual(UniversalSoundLibrary.SoundPreset.PresetCategory.lead.rawValue, "Lead")
        XCTAssertEqual(UniversalSoundLibrary.SoundPreset.PresetCategory.bass.rawValue, "Bass")
        XCTAssertEqual(UniversalSoundLibrary.SoundPreset.PresetCategory.pluck.rawValue, "Pluck")
        XCTAssertEqual(UniversalSoundLibrary.SoundPreset.PresetCategory.sfx.rawValue, "Sound FX")
        XCTAssertEqual(UniversalSoundLibrary.SoundPreset.PresetCategory.cinematic.rawValue, "Cinematic")
        XCTAssertEqual(UniversalSoundLibrary.SoundPreset.PresetCategory.experimental.rawValue, "Experimental")
    }

    func testInstrumentFamilyRawValues() {
        XCTAssertEqual(UniversalSoundLibrary.Instrument.InstrumentFamily.analogSynth.rawValue, "Analog Synthesizer")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.InstrumentFamily.pluckedString.rawValue, "Plucked String")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.InstrumentFamily.bowedString.rawValue, "Bowed String")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.InstrumentFamily.flute.rawValue, "Flute")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.InstrumentFamily.brass.rawValue, "Brass")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.InstrumentFamily.membrane.rawValue, "Membrane (Drum)")
        XCTAssertEqual(UniversalSoundLibrary.Instrument.InstrumentFamily.idiophone.rawValue, "Idiophone (Metal/Wood)")
    }
}

// MARK: - InstrumentOrchestrator.DrumType Tests

final class DrumTypeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(InstrumentOrchestrator.DrumType.allCases.count, 12)
    }

    func testRawValues() {
        XCTAssertEqual(InstrumentOrchestrator.DrumType.kick.rawValue, "kick")
        XCTAssertEqual(InstrumentOrchestrator.DrumType.snare.rawValue, "snare")
        XCTAssertEqual(InstrumentOrchestrator.DrumType.hiHatClosed.rawValue, "hiHatClosed")
        XCTAssertEqual(InstrumentOrchestrator.DrumType.hiHatOpen.rawValue, "hiHatOpen")
        XCTAssertEqual(InstrumentOrchestrator.DrumType.crash.rawValue, "crash")
        XCTAssertEqual(InstrumentOrchestrator.DrumType.ride.rawValue, "ride")
    }
}
#endif
