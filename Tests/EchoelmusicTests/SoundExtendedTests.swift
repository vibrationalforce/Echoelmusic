#if canImport(AVFoundation)
//
//  SoundExtendedTests.swift
//  EchoelmusicTests
//
//  Created: March 2026
//  Tests for all untested Sound module types:
//  VelocityRamp, PitchRamp, DirtyDelayConfig, TrapPreset
//  Plus extended coverage for BassEngineType, EchoelBassConfig,
//  TR808BassConfig, PresetEngine, PresetCategory, SynthPreset,
//  DrumSlot, BeatStep, BeatPattern, HiHatMode, RollDivision,
//  SamplerInterpolation, SamplerFilterType, ADSREnvelope,
//  SamplerLFO, SampleZone, SamplerBioModulation, SamplerConstants,
//  EnvelopeState, EchoelSampler, SynthPresetLibrary
//

import XCTest
@testable import Echoelmusic

// MARK: - VelocityRamp Tests

final class VelocityRampTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(VelocityRamp.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(VelocityRamp.flat.rawValue, "Flat")
        XCTAssertEqual(VelocityRamp.crescendo.rawValue, "Crescendo")
        XCTAssertEqual(VelocityRamp.decrescendo.rawValue, "Decrescendo")
        XCTAssertEqual(VelocityRamp.vShape.rawValue, "V-Shape")
        XCTAssertEqual(VelocityRamp.random.rawValue, "Random")
    }

    func testRawValueInit() {
        XCTAssertEqual(VelocityRamp(rawValue: "Flat"), .flat)
        XCTAssertEqual(VelocityRamp(rawValue: "Crescendo"), .crescendo)
        XCTAssertEqual(VelocityRamp(rawValue: "V-Shape"), .vShape)
        XCTAssertNil(VelocityRamp(rawValue: "invalid"))
    }

    func testFlatReturnsConstant() {
        let v0 = VelocityRamp.flat.velocity(at: 0.0)
        let v5 = VelocityRamp.flat.velocity(at: 0.5)
        let v1 = VelocityRamp.flat.velocity(at: 1.0)
        XCTAssertEqual(v0, 0.8)
        XCTAssertEqual(v5, 0.8)
        XCTAssertEqual(v1, 0.8)
    }

    func testCrescendoIncreasesOverTime() {
        let start = VelocityRamp.crescendo.velocity(at: 0.0)
        let mid = VelocityRamp.crescendo.velocity(at: 0.5)
        let end = VelocityRamp.crescendo.velocity(at: 1.0)
        XCTAssertLessThan(start, mid)
        XCTAssertLessThan(mid, end)
        XCTAssertEqual(start, 0.3, accuracy: 0.001)
        XCTAssertEqual(end, 1.0, accuracy: 0.001)
    }

    func testDecrescendoDecreasesOverTime() {
        let start = VelocityRamp.decrescendo.velocity(at: 0.0)
        let mid = VelocityRamp.decrescendo.velocity(at: 0.5)
        let end = VelocityRamp.decrescendo.velocity(at: 1.0)
        XCTAssertGreaterThan(start, mid)
        XCTAssertGreaterThan(mid, end)
        XCTAssertEqual(start, 1.0, accuracy: 0.001)
        XCTAssertEqual(end, 0.3, accuracy: 0.001)
    }

    func testVShapeSymmetry() {
        let start = VelocityRamp.vShape.velocity(at: 0.0)
        let mid = VelocityRamp.vShape.velocity(at: 0.5)
        let end = VelocityRamp.vShape.velocity(at: 1.0)
        // V-shape: high at edges, low in middle
        XCTAssertGreaterThan(start, mid)
        XCTAssertGreaterThan(end, mid)
        XCTAssertEqual(start, end, accuracy: 0.001)
    }

    func testVShapeMidpointIsLowest() {
        let mid = VelocityRamp.vShape.velocity(at: 0.5)
        XCTAssertEqual(mid, 0.3, accuracy: 0.001)
    }

    func testRandomAlwaysInRange() {
        for _ in 0..<100 {
            let v = VelocityRamp.random.velocity(at: Float.random(in: 0...1))
            XCTAssertGreaterThanOrEqual(v, 0.4)
            XCTAssertLessThanOrEqual(v, 1.0)
        }
    }

    func testAllRampsReturnPositiveValues() {
        for ramp in VelocityRamp.allCases {
            for pos in stride(from: Float(0), through: 1.0, by: 0.1) {
                let v = ramp.velocity(at: pos)
                XCTAssertGreaterThan(v, 0, "\(ramp.rawValue) at \(pos) returned non-positive: \(v)")
                XCTAssertLessThanOrEqual(v, 1.0, "\(ramp.rawValue) at \(pos) exceeded 1.0: \(v)")
            }
        }
    }
}

// MARK: - PitchRamp Tests

final class PitchRampTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(PitchRamp.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(PitchRamp.none.rawValue, "None")
        XCTAssertEqual(PitchRamp.rising.rawValue, "Rising")
        XCTAssertEqual(PitchRamp.falling.rawValue, "Falling")
        XCTAssertEqual(PitchRamp.riseAndFall.rawValue, "Rise+Fall")
    }

    func testRawValueInit() {
        XCTAssertEqual(PitchRamp(rawValue: "None"), .none)
        XCTAssertEqual(PitchRamp(rawValue: "Rising"), .rising)
        XCTAssertEqual(PitchRamp(rawValue: "Falling"), .falling)
        XCTAssertEqual(PitchRamp(rawValue: "Rise+Fall"), .riseAndFall)
        XCTAssertNil(PitchRamp(rawValue: "invalid"))
    }

    func testNoneReturnsUnity() {
        XCTAssertEqual(PitchRamp.none.multiplier(at: 0.0), 1.0)
        XCTAssertEqual(PitchRamp.none.multiplier(at: 0.5), 1.0)
        XCTAssertEqual(PitchRamp.none.multiplier(at: 1.0), 1.0)
    }

    func testRisingIncreasesOverTime() {
        let start = PitchRamp.rising.multiplier(at: 0.0)
        let mid = PitchRamp.rising.multiplier(at: 0.5)
        let end = PitchRamp.rising.multiplier(at: 1.0)
        XCTAssertLessThan(start, mid)
        XCTAssertLessThan(mid, end)
        XCTAssertEqual(start, 0.8, accuracy: 0.001)
        XCTAssertEqual(end, 1.5, accuracy: 0.001)
    }

    func testFallingDecreasesOverTime() {
        let start = PitchRamp.falling.multiplier(at: 0.0)
        let mid = PitchRamp.falling.multiplier(at: 0.5)
        let end = PitchRamp.falling.multiplier(at: 1.0)
        XCTAssertGreaterThan(start, mid)
        XCTAssertGreaterThan(mid, end)
        XCTAssertEqual(start, 1.5, accuracy: 0.001)
        XCTAssertEqual(end, 0.8, accuracy: 0.001)
    }

    func testRiseAndFallPeaksAtMidpoint() {
        let start = PitchRamp.riseAndFall.multiplier(at: 0.0)
        let mid = PitchRamp.riseAndFall.multiplier(at: 0.5)
        let end = PitchRamp.riseAndFall.multiplier(at: 1.0)
        XCTAssertLessThan(start, mid)
        XCTAssertGreaterThan(mid, end)
        XCTAssertEqual(start, end, accuracy: 0.001)
    }

    func testRiseAndFallSymmetry() {
        let at025 = PitchRamp.riseAndFall.multiplier(at: 0.25)
        let at075 = PitchRamp.riseAndFall.multiplier(at: 0.75)
        XCTAssertEqual(at025, at075, accuracy: 0.001)
    }

    func testRiseAndFallStartEndValues() {
        let start = PitchRamp.riseAndFall.multiplier(at: 0.0)
        let peak = PitchRamp.riseAndFall.multiplier(at: 0.5)
        XCTAssertEqual(start, 0.8, accuracy: 0.001)
        XCTAssertEqual(peak, 1.5, accuracy: 0.001)
    }

    func testAllRampsReturnPositiveMultipliers() {
        for ramp in PitchRamp.allCases {
            for pos in stride(from: Float(0), through: 1.0, by: 0.1) {
                let m = ramp.multiplier(at: pos)
                XCTAssertGreaterThan(m, 0, "\(ramp.rawValue) at \(pos) returned non-positive: \(m)")
            }
        }
    }
}

// MARK: - DirtyDelayConfig Tests

final class DirtyDelayConfigTests: XCTestCase {

    func testDefaultInit() {
        let config = DirtyDelayConfig()
        XCTAssertEqual(config.delayTime, 0.188, accuracy: 0.001)
        XCTAssertEqual(config.feedback, 0.45)
        XCTAssertEqual(config.saturation, 0.3)
        XCTAssertEqual(config.filterCutoff, 4000)
        XCTAssertEqual(config.mix, 0.25)
        XCTAssertFalse(config.isEnabled)
    }

    func testCleanPreset() {
        let config = DirtyDelayConfig.clean
        XCTAssertEqual(config.delayTime, 0.188, accuracy: 0.001)
        XCTAssertEqual(config.feedback, 0.35)
        XCTAssertEqual(config.saturation, 0.1)
        XCTAssertEqual(config.filterCutoff, 6000)
        XCTAssertEqual(config.mix, 0.2)
        XCTAssertTrue(config.isEnabled)
    }

    func testDirtyPreset() {
        let config = DirtyDelayConfig.dirty
        XCTAssertEqual(config.delayTime, 0.214, accuracy: 0.001)
        XCTAssertEqual(config.feedback, 0.55)
        XCTAssertEqual(config.saturation, 0.6)
        XCTAssertEqual(config.filterCutoff, 3000)
        XCTAssertEqual(config.mix, 0.3)
        XCTAssertTrue(config.isEnabled)
    }

    func testHeavyPreset() {
        let config = DirtyDelayConfig.heavy
        XCTAssertEqual(config.delayTime, 0.25)
        XCTAssertEqual(config.feedback, 0.7)
        XCTAssertEqual(config.saturation, 0.8)
        XCTAssertEqual(config.filterCutoff, 2000)
        XCTAssertEqual(config.mix, 0.4)
        XCTAssertTrue(config.isEnabled)
    }

    func testPresetFeedbackOrdering() {
        XCTAssertLessThan(DirtyDelayConfig.clean.feedback, DirtyDelayConfig.dirty.feedback)
        XCTAssertLessThan(DirtyDelayConfig.dirty.feedback, DirtyDelayConfig.heavy.feedback)
    }

    func testPresetSaturationOrdering() {
        XCTAssertLessThan(DirtyDelayConfig.clean.saturation, DirtyDelayConfig.dirty.saturation)
        XCTAssertLessThan(DirtyDelayConfig.dirty.saturation, DirtyDelayConfig.heavy.saturation)
    }

    func testPresetFilterCutoffOrdering() {
        // Higher quality (clean) = higher cutoff, heavier = more filtered
        XCTAssertGreaterThan(DirtyDelayConfig.clean.filterCutoff, DirtyDelayConfig.dirty.filterCutoff)
        XCTAssertGreaterThan(DirtyDelayConfig.dirty.filterCutoff, DirtyDelayConfig.heavy.filterCutoff)
    }

    func testCodableRoundTrip() throws {
        let config = DirtyDelayConfig.dirty
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(DirtyDelayConfig.self, from: data)
        XCTAssertEqual(decoded.delayTime, config.delayTime)
        XCTAssertEqual(decoded.feedback, config.feedback)
        XCTAssertEqual(decoded.saturation, config.saturation)
        XCTAssertEqual(decoded.filterCutoff, config.filterCutoff)
        XCTAssertEqual(decoded.mix, config.mix)
        XCTAssertEqual(decoded.isEnabled, config.isEnabled)
    }

    func testCodableDefaultRoundTrip() throws {
        let config = DirtyDelayConfig()
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(DirtyDelayConfig.self, from: data)
        XCTAssertEqual(decoded.delayTime, config.delayTime)
        XCTAssertEqual(decoded.isEnabled, false)
    }

    func testMutability() {
        var config = DirtyDelayConfig()
        config.delayTime = 0.5
        config.feedback = 0.9
        config.isEnabled = true
        XCTAssertEqual(config.delayTime, 0.5)
        XCTAssertEqual(config.feedback, 0.9)
        XCTAssertTrue(config.isEnabled)
    }

    func testAllPresetsEnabled() {
        XCTAssertTrue(DirtyDelayConfig.clean.isEnabled)
        XCTAssertTrue(DirtyDelayConfig.dirty.isEnabled)
        XCTAssertTrue(DirtyDelayConfig.heavy.isEnabled)
    }

    func testDefaultIsDisabled() {
        XCTAssertFalse(DirtyDelayConfig().isEnabled)
    }

    func testFeedbackBelowOne() {
        // Feedback >= 1 causes infinite delay — all presets must be below 1
        XCTAssertLessThan(DirtyDelayConfig.clean.feedback, 1.0)
        XCTAssertLessThan(DirtyDelayConfig.dirty.feedback, 1.0)
        XCTAssertLessThan(DirtyDelayConfig.heavy.feedback, 1.0)
        XCTAssertLessThan(DirtyDelayConfig().feedback, 1.0)
    }
}

// MARK: - TrapPreset Tests

final class TrapPresetTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(TrapPreset.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(TrapPreset.metroBoomin.rawValue, "Metro Boomin")
        XCTAssertEqual(TrapPreset.southside.rawValue, "Southside")
        XCTAssertEqual(TrapPreset.londonOnDaTrack.rawValue, "London On Da Track")
        XCTAssertEqual(TrapPreset.piWon.rawValue, "Pi'erre Bourne")
        XCTAssertEqual(TrapPreset.wheezy.rawValue, "Wheezy")
    }

    func testRawValueInit() {
        XCTAssertEqual(TrapPreset(rawValue: "Metro Boomin"), .metroBoomin)
        XCTAssertEqual(TrapPreset(rawValue: "Southside"), .southside)
        XCTAssertEqual(TrapPreset(rawValue: "Pi'erre Bourne"), .piWon)
        XCTAssertNil(TrapPreset(rawValue: "invalid"))
    }

    func testBPMValues() {
        XCTAssertEqual(TrapPreset.metroBoomin.bpm, 140)
        XCTAssertEqual(TrapPreset.southside.bpm, 138)
        XCTAssertEqual(TrapPreset.londonOnDaTrack.bpm, 142)
        XCTAssertEqual(TrapPreset.piWon.bpm, 150)
        XCTAssertEqual(TrapPreset.wheezy.bpm, 136)
    }

    func testBPMInTrapRange() {
        // Trap BPM typically 130-160
        for preset in TrapPreset.allCases {
            XCTAssertGreaterThanOrEqual(preset.bpm, 130, "\(preset.rawValue) BPM too low")
            XCTAssertLessThanOrEqual(preset.bpm, 160, "\(preset.rawValue) BPM too high")
        }
    }

    func testRollDivisions() {
        XCTAssertEqual(TrapPreset.metroBoomin.rollDivision, .sixteenth)
        XCTAssertEqual(TrapPreset.southside.rollDivision, .thirtysecond)
        XCTAssertEqual(TrapPreset.londonOnDaTrack.rollDivision, .sixteenth)
        XCTAssertEqual(TrapPreset.piWon.rollDivision, .thirtysecond)
        XCTAssertEqual(TrapPreset.wheezy.rollDivision, .sixtyfourth)
    }

    func testVelocityRamps() {
        XCTAssertEqual(TrapPreset.metroBoomin.velocityRamp, .crescendo)
        XCTAssertEqual(TrapPreset.southside.velocityRamp, .flat)
        XCTAssertEqual(TrapPreset.londonOnDaTrack.velocityRamp, .crescendo)
        XCTAssertEqual(TrapPreset.piWon.velocityRamp, .decrescendo)
        XCTAssertEqual(TrapPreset.wheezy.velocityRamp, .crescendo)
    }

    func testPitchRamps() {
        XCTAssertEqual(TrapPreset.metroBoomin.pitchRamp, .none)
        XCTAssertEqual(TrapPreset.southside.pitchRamp, .none)
        XCTAssertEqual(TrapPreset.londonOnDaTrack.pitchRamp, .rising)
        XCTAssertEqual(TrapPreset.piWon.pitchRamp, .falling)
        XCTAssertEqual(TrapPreset.wheezy.pitchRamp, .rising)
    }

    func testDelayConfigs() {
        let metro = TrapPreset.metroBoomin.delay
        XCTAssertTrue(metro.isEnabled)
        XCTAssertEqual(metro.feedback, DirtyDelayConfig.clean.feedback)

        let south = TrapPreset.southside.delay
        XCTAssertTrue(south.isEnabled)
        XCTAssertEqual(south.feedback, DirtyDelayConfig.dirty.feedback)

        let wheezy = TrapPreset.wheezy.delay
        XCTAssertTrue(wheezy.isEnabled)
        XCTAssertEqual(wheezy.feedback, DirtyDelayConfig.heavy.feedback)
    }

    func testPiWonDelayIsCustom() {
        let delay = TrapPreset.piWon.delay
        XCTAssertTrue(delay.isEnabled)
        XCTAssertEqual(delay.delayTime, 0.15)
        XCTAssertEqual(delay.feedback, 0.3)
        XCTAssertEqual(delay.saturation, 0.15)
        XCTAssertEqual(delay.filterCutoff, 5000)
        XCTAssertEqual(delay.mix, 0.2)
    }

    func testAllPresetsHaveEnabledDelay() {
        for preset in TrapPreset.allCases {
            XCTAssertTrue(preset.delay.isEnabled, "\(preset.rawValue) delay should be enabled")
        }
    }

    func testSwingValues() {
        XCTAssertEqual(TrapPreset.metroBoomin.swing, 0)
        XCTAssertEqual(TrapPreset.southside.swing, 0)
        XCTAssertEqual(TrapPreset.londonOnDaTrack.swing, 15)
        XCTAssertEqual(TrapPreset.piWon.swing, 5)
        XCTAssertEqual(TrapPreset.wheezy.swing, 0)
    }

    func testSwingNonNegative() {
        for preset in TrapPreset.allCases {
            XCTAssertGreaterThanOrEqual(preset.swing, 0, "\(preset.rawValue) swing is negative")
        }
    }

    func testHiHatDecayMultipliers() {
        XCTAssertEqual(TrapPreset.metroBoomin.hihatDecayMultiplier, 0.8)
        XCTAssertEqual(TrapPreset.southside.hihatDecayMultiplier, 1.2)
        XCTAssertEqual(TrapPreset.londonOnDaTrack.hihatDecayMultiplier, 1.0)
        XCTAssertEqual(TrapPreset.piWon.hihatDecayMultiplier, 0.7)
        XCTAssertEqual(TrapPreset.wheezy.hihatDecayMultiplier, 1.5)
    }

    func testHiHatDecayMultipliersPositive() {
        for preset in TrapPreset.allCases {
            XCTAssertGreaterThan(preset.hihatDecayMultiplier, 0,
                                 "\(preset.rawValue) hihat decay must be positive")
        }
    }

    func testWheezyHasFastestRolls() {
        // Wheezy uses 1/64 — the fastest roll division
        XCTAssertEqual(TrapPreset.wheezy.rollDivision, .sixtyfourth)
        for preset in TrapPreset.allCases where preset != .wheezy {
            XCTAssertLessThanOrEqual(
                preset.rollDivision.stepsPerBeat,
                TrapPreset.wheezy.rollDivision.stepsPerBeat
            )
        }
    }

    func testPiWonHasFastestBPM() {
        for preset in TrapPreset.allCases {
            XCTAssertLessThanOrEqual(preset.bpm, TrapPreset.piWon.bpm)
        }
    }
}

// MARK: - Extended BassEngineType Tests

final class BassEngineTypeExtendedTests: XCTestCase {

    func testAllCasesOrdered() {
        let cases: [BassEngineType] = [.sub808, .reese, .moog, .acid, .growl]
        XCTAssertEqual(BassEngineType.allCases, cases)
    }

    func testRawValueRoundTripForAllCases() {
        for engine in BassEngineType.allCases {
            XCTAssertEqual(BassEngineType(rawValue: engine.rawValue), engine)
        }
    }

    func testCodableRoundTripAllCases() throws {
        for engine in BassEngineType.allCases {
            let data = try JSONEncoder().encode(engine)
            let decoded = try JSONDecoder().decode(BassEngineType.self, from: data)
            XCTAssertEqual(decoded, engine)
        }
    }

    func testInvalidRawValueReturnsNil() {
        XCTAssertNil(BassEngineType(rawValue: ""))
        XCTAssertNil(BassEngineType(rawValue: "808"))
        XCTAssertNil(BassEngineType(rawValue: "sub808"))
    }
}

// MARK: - Extended EchoelBassConfig Tests

final class EchoelBassConfigExtendedTests: XCTestCase {

    func testMoogBassPreset() {
        let preset = EchoelBassConfig.moogBass
        XCTAssertEqual(preset.engineA, .moog)
        XCTAssertEqual(preset.engineB, .sub808)
        XCTAssertEqual(preset.moogDrive, 0.5)
        XCTAssertEqual(preset.filterResonance, 0.5)
    }

    func testDubstepGrowlPreset() {
        let preset = EchoelBassConfig.dubstepGrowl
        XCTAssertEqual(preset.engineA, .growl)
        XCTAssertEqual(preset.growlFMRatio, 2.0)
        XCTAssertEqual(preset.growlFMDepth, 0.7)
        XCTAssertEqual(preset.growlFold, 0.5)
    }

    func testMorphSweepPreset() {
        let preset = EchoelBassConfig.morphSweep
        XCTAssertEqual(preset.morphPosition, 0.5)
        XCTAssertEqual(preset.engineA, .sub808)
        XCTAssertEqual(preset.engineB, .growl)
        XCTAssertTrue(preset.glideEnabled)
    }

    func testBioReactivePreset() {
        let preset = EchoelBassConfig.bioReactive
        XCTAssertEqual(preset.engineA, .moog)
        XCTAssertEqual(preset.engineB, .reese)
        XCTAssertEqual(preset.morphPosition, 0.5)
        XCTAssertEqual(preset.vibratoRate, 5.0)
        XCTAssertEqual(preset.vibratoDepth, 0.1)
    }

    func testDefaultMorphIsFullA() {
        let config = EchoelBassConfig()
        XCTAssertEqual(config.morphPosition, 0.0)
    }

    func testDefaultEngines() {
        let config = EchoelBassConfig()
        XCTAssertEqual(config.engineA, .sub808)
        XCTAssertEqual(config.engineB, .reese)
    }

    func testDefaultFilterValues() {
        let config = EchoelBassConfig()
        XCTAssertEqual(config.filterCutoff, 800.0)
        XCTAssertEqual(config.filterResonance, 0.2)
        XCTAssertEqual(config.filterEnvAmount, 2000.0)
        XCTAssertEqual(config.filterEnvDecay, 0.3)
        XCTAssertEqual(config.filterKeyTrack, 0.5)
    }

    func testDefaultEffects() {
        let config = EchoelBassConfig()
        XCTAssertEqual(config.drive, 0.2)
        XCTAssertEqual(config.level, 0.8)
        XCTAssertEqual(config.stereoWidth, 0.0)
        XCTAssertEqual(config.vibratoRate, 5.0)
        XCTAssertEqual(config.vibratoDepth, 0.0)
    }

    func testDefaultReeseParams() {
        let config = EchoelBassConfig()
        XCTAssertEqual(config.reeseDetune, 15.0)
        XCTAssertEqual(config.reeseVoices, 3)
        XCTAssertEqual(config.reeseDrift, 0.2)
    }

    func testDefaultAcidParams() {
        let config = EchoelBassConfig()
        XCTAssertEqual(config.acidAccent, 0.6)
        XCTAssertTrue(config.acidSlide)
        XCTAssertEqual(config.acidWaveform, 0.0)
    }

    func testDefaultGrowlParams() {
        let config = EchoelBassConfig()
        XCTAssertEqual(config.growlFMRatio, 1.5)
        XCTAssertEqual(config.growlFMDepth, 0.5)
        XCTAssertEqual(config.growlFold, 0.3)
        XCTAssertEqual(config.growlFormant, 0.0)
    }

    func testEquatableSamePresets() {
        XCTAssertEqual(EchoelBassConfig.moogBass, EchoelBassConfig.moogBass)
        XCTAssertEqual(EchoelBassConfig.morphSweep, EchoelBassConfig.morphSweep)
    }

    func testEquatableDifferentPresets() {
        XCTAssertNotEqual(EchoelBassConfig.classic808, EchoelBassConfig.acid303)
        XCTAssertNotEqual(EchoelBassConfig.moogBass, EchoelBassConfig.dubstepGrowl)
    }

    func testCodableAllPresets() throws {
        let presets: [EchoelBassConfig] = [
            .classic808, .reeseMonster, .moogBass, .acid303,
            .dubstepGrowl, .morphSweep, .bioReactive
        ]
        for preset in presets {
            let data = try JSONEncoder().encode(preset)
            let decoded = try JSONDecoder().decode(EchoelBassConfig.self, from: data)
            XCTAssertEqual(decoded, preset)
        }
    }

    func testMutability() {
        var config = EchoelBassConfig()
        config.engineA = .growl
        config.morphPosition = 0.75
        config.growlFormant = 0.8
        XCTAssertEqual(config.engineA, .growl)
        XCTAssertEqual(config.morphPosition, 0.75)
        XCTAssertEqual(config.growlFormant, 0.8)
    }
}

// MARK: - Extended TR808BassConfig Tests

final class TR808BassConfigExtendedTests: XCTestCase {

    func testAllStaticPresets() {
        let presets = [
            TR808BassConfig.classic808,
            TR808BassConfig.hardTrap,
            TR808BassConfig.deepSub,
            TR808BassConfig.distorted808,
            TR808BassConfig.longSlide
        ]
        // All presets should have pitch glide enabled
        for preset in presets {
            XCTAssertTrue(preset.pitchGlideEnabled)
        }
    }

    func testLongSlideHasLongestGlideTime() throws {
        let presets = [
            TR808BassConfig.classic808,
            TR808BassConfig.hardTrap,
            TR808BassConfig.deepSub,
            TR808BassConfig.distorted808,
            TR808BassConfig.longSlide
        ]
        let maxGlide = try XCTUnwrap(presets.map(\.pitchGlideTime).max())
        XCTAssertEqual(maxGlide, TR808BassConfig.longSlide.pitchGlideTime)
    }

    func testDeepSubHasLowestFilterCutoff() throws {
        let presets = [
            TR808BassConfig.classic808,
            TR808BassConfig.hardTrap,
            TR808BassConfig.deepSub,
            TR808BassConfig.distorted808,
            TR808BassConfig.longSlide
        ]
        let minCutoff = try XCTUnwrap(presets.map(\.filterCutoff).min())
        XCTAssertEqual(minCutoff, TR808BassConfig.deepSub.filterCutoff)
    }

    func testDistorted808HasHighestDrive() throws {
        let presets = [
            TR808BassConfig.classic808,
            TR808BassConfig.hardTrap,
            TR808BassConfig.deepSub,
            TR808BassConfig.distorted808,
            TR808BassConfig.longSlide
        ]
        let maxDrive = try XCTUnwrap(presets.map(\.drive).max())
        XCTAssertEqual(maxDrive, TR808BassConfig.distorted808.drive)
    }

    func testDefaultPitchEnvelopeValues() {
        let config = TR808BassConfig()
        XCTAssertEqual(config.pitchEnvAmount, 0.0)
        XCTAssertEqual(config.pitchEnvDecay, 0.1)
    }

    func testDefaultOscillatorValues() {
        let config = TR808BassConfig()
        XCTAssertEqual(config.tuning, 0.0)
        XCTAssertEqual(config.octave, 0)
        XCTAssertEqual(config.subOscMix, 0.0)
    }

    func testDefaultStereoWidth() {
        let config = TR808BassConfig()
        XCTAssertEqual(config.stereoWidth, 0.0) // mono by default for bass
    }

    func testCodableAllPresets() throws {
        let presets = [
            TR808BassConfig.classic808,
            TR808BassConfig.hardTrap,
            TR808BassConfig.deepSub,
            TR808BassConfig.distorted808,
            TR808BassConfig.longSlide
        ]
        for preset in presets {
            let data = try JSONEncoder().encode(preset)
            let decoded = try JSONDecoder().decode(TR808BassConfig.self, from: data)
            XCTAssertEqual(decoded, preset)
        }
    }

    func testMutability() {
        var config = TR808BassConfig()
        config.pitchGlideEnabled = false
        config.drive = 0.9
        config.filterCutoff = 100.0
        XCTAssertFalse(config.pitchGlideEnabled)
        XCTAssertEqual(config.drive, 0.9)
        XCTAssertEqual(config.filterCutoff, 100.0)
    }
}

// MARK: - Extended PresetEngine Tests

final class PresetEngineExtendedTests: XCTestCase {

    func testAllRawValues() {
        let expected: [(PresetEngine, String)] = [
            (.ddsp, "EchoelDDSP"),
            (.modalBank, "EchoelModalBank"),
            (.cellular, "EchoelCellular"),
            (.quant, "EchoelQuant"),
            (.tr808, "TR808BassSynth"),
            (.breakbeat, "BreakbeatChopper")
        ]
        for (engine, raw) in expected {
            XCTAssertEqual(engine.rawValue, raw)
        }
    }

    func testRawValueRoundTrip() {
        let engines: [PresetEngine] = [.ddsp, .modalBank, .cellular, .quant, .tr808, .breakbeat]
        for engine in engines {
            XCTAssertEqual(PresetEngine(rawValue: engine.rawValue), engine)
        }
    }

    func testCodableRoundTrip() throws {
        let engines: [PresetEngine] = [.ddsp, .modalBank, .cellular, .quant, .tr808, .breakbeat]
        for engine in engines {
            let data = try JSONEncoder().encode(engine)
            let decoded = try JSONDecoder().decode(PresetEngine.self, from: data)
            XCTAssertEqual(decoded, engine)
        }
    }

    func testInvalidRawValues() {
        XCTAssertNil(PresetEngine(rawValue: ""))
        XCTAssertNil(PresetEngine(rawValue: "ddsp"))
        XCTAssertNil(PresetEngine(rawValue: "DDSP"))
    }
}

// MARK: - Extended SynthPreset Tests

final class SynthPresetExtendedTests: XCTestCase {

    func testInitSetsAllDefaults() {
        let preset = SynthPreset(name: "Test", category: .drums, engine: .ddsp)
        XCTAssertEqual(preset.frequency, 440)
        XCTAssertEqual(preset.amplitude, 0.8)
        XCTAssertEqual(preset.attack, 0.005)
        XCTAssertEqual(preset.decay, 0.3)
        XCTAssertEqual(preset.sustain, 0.5)
        XCTAssertEqual(preset.release, 0.3)
        XCTAssertEqual(preset.duration, 2.0)
        XCTAssertEqual(preset.harmonicCount, 16)
        XCTAssertEqual(preset.harmonicity, 1.0)
        XCTAssertEqual(preset.spectralShape, "natural")
        XCTAssertEqual(preset.noiseColor, "pink")
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
        let preset = SynthPreset(name: "Q", category: .textures, engine: .quant)
        XCTAssertEqual(preset.potentialType, "harmonicOscillator")
        XCTAssertEqual(preset.gridSize, 512)
        XCTAssertEqual(preset.unisonVoices, 1)
        XCTAssertEqual(preset.unisonDetune, 0)
    }

    func testTR808Defaults() {
        let preset = SynthPreset(name: "808", category: .bass, engine: .tr808)
        XCTAssertEqual(preset.pitchGlide, 0)
        XCTAssertEqual(preset.pitchGlideTime, 0.1)
        XCTAssertEqual(preset.clickAmount, 0)
        XCTAssertEqual(preset.drive, 0)
        XCTAssertEqual(preset.filterCutoff, 2000)
    }

    func testBreakbeatDefaults() {
        let preset = SynthPreset(name: "Break", category: .jungle, engine: .breakbeat)
        XCTAssertEqual(preset.bpm, 170)
        XCTAssertTrue(preset.patternIndices.isEmpty)
        XCTAssertEqual(preset.swing, 0)
        XCTAssertEqual(preset.sliceCount, 8)
    }

    func testBioReactiveDefaults() {
        let preset = SynthPreset(name: "Bio", category: .melodic, engine: .ddsp)
        XCTAssertEqual(preset.bioCoherenceTarget, "harmonicity")
        XCTAssertEqual(preset.bioHrvTarget, "brightness")
        XCTAssertEqual(preset.bioBreathTarget, "amplitude")
    }

    func testUniqueIDsAcrossPresets() {
        let a = SynthPreset(name: "A", category: .drums, engine: .ddsp)
        let b = SynthPreset(name: "B", category: .drums, engine: .ddsp)
        let c = SynthPreset(name: "C", category: .drums, engine: .ddsp)
        XCTAssertNotEqual(a.id, b.id)
        XCTAssertNotEqual(b.id, c.id)
        XCTAssertNotEqual(a.id, c.id)
    }

    func testCodableWithTags() throws {
        let preset = SynthPreset(name: "Tagged", category: .fx, engine: .quant, tags: ["riser", "sweep", "cinematic"])
        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: data)
        XCTAssertEqual(decoded.name, "Tagged")
        XCTAssertEqual(decoded.tags, ["riser", "sweep", "cinematic"])
        XCTAssertEqual(decoded.category, .fx)
        XCTAssertEqual(decoded.engine, .quant)
    }

    func testMutability() {
        var preset = SynthPreset(name: "Mutable", category: .bass, engine: .ddsp)
        preset.frequency = 110
        preset.harmonicity = 0.3
        preset.brightness = 0.9
        XCTAssertEqual(preset.frequency, 110)
        XCTAssertEqual(preset.harmonicity, 0.3)
        XCTAssertEqual(preset.brightness, 0.9)
    }
}

// MARK: - SynthPresetLibrary Tests

final class SynthPresetLibraryExtendedTests: XCTestCase {

    func testSharedInstanceNotEmpty() {
        let library = SynthPresetLibrary.shared
        XCTAssertFalse(library.presets.isEmpty)
    }

    func testSharedIsSingleton() {
        let a = SynthPresetLibrary.shared
        let b = SynthPresetLibrary.shared
        XCTAssertTrue(a === b)
    }

    func testPresetsForCategory() {
        let library = SynthPresetLibrary.shared
        for category in PresetCategory.allCases {
            let categoryPresets = library.presets(for: category)
            for preset in categoryPresets {
                XCTAssertEqual(preset.category, category)
            }
        }
    }

    func testPresetsForEngine() {
        let library = SynthPresetLibrary.shared
        let ddspPresets = library.presets(for: .ddsp)
        for preset in ddspPresets {
            XCTAssertEqual(preset.engine, .ddsp)
        }
    }

    func testSearchByName() {
        let library = SynthPresetLibrary.shared
        // Search for something that should exist in factory presets
        let allPresets = library.presets
        guard let first = allPresets.first else { return }
        let results = library.search(first.name)
        XCTAssertFalse(results.isEmpty)
    }

    func testSearchCaseInsensitive() {
        let library = SynthPresetLibrary.shared
        let allPresets = library.presets
        guard let first = allPresets.first else { return }
        let upper = library.search(first.name.uppercased())
        let lower = library.search(first.name.lowercased())
        XCTAssertEqual(upper.count, lower.count)
    }

    func testSearchNoResults() {
        let library = SynthPresetLibrary.shared
        let results = library.search("zzzznonexistentzzzz")
        XCTAssertTrue(results.isEmpty)
    }

    func testAllCategoriesHavePresets() {
        let library = SynthPresetLibrary.shared
        for category in PresetCategory.allCases {
            let presets = library.presets(for: category)
            XCTAssertFalse(presets.isEmpty, "Category \(category.rawValue) has no presets")
        }
    }
}

// MARK: - Extended EchoelSampler Tests

final class EchoelSamplerExtendedTests: XCTestCase {

    func testDefaultSampleRate() {
        let sampler = EchoelSampler()
        // Default bio values
        XCTAssertEqual(sampler.hrvMs, 50)
        XCTAssertEqual(sampler.coherence, 0.5)
        XCTAssertEqual(sampler.heartRate, 70)
        XCTAssertEqual(sampler.breathPhase, 0.5)
        XCTAssertEqual(sampler.flowScore, 0)
    }

    func testDefaultAudioProperties() {
        let sampler = EchoelSampler()
        XCTAssertEqual(sampler.masterVolume, 0.8)
        XCTAssertEqual(sampler.filterCutoff, 8000)
        XCTAssertEqual(sampler.filterResonance, 0)
        XCTAssertEqual(sampler.filterType, .lowpass)
        XCTAssertEqual(sampler.filterEnvelopeDepth, 0)
        XCTAssertEqual(sampler.interpolation, .hermite)
    }

    func testUpdateBioData() {
        let sampler = EchoelSampler()
        sampler.updateBioData(hrv: 80, coherence: 0.9, heartRate: 120, breathPhase: 0.7, flow: 0.6)
        XCTAssertEqual(sampler.hrvMs, 80)
        XCTAssertEqual(sampler.coherence, 0.9)
        XCTAssertEqual(sampler.heartRate, 120)
        XCTAssertEqual(sampler.breathPhase, 0.7)
        XCTAssertEqual(sampler.flowScore, 0.6)
    }

    func testLoadSampleReturnsIndex() {
        let sampler = EchoelSampler()
        let data: [Float] = [0.1, 0.2, 0.3, 0.4]
        let idx = sampler.loadSample(data: data, sampleRate: 44100, rootNote: 60, name: "TestSample")
        XCTAssertEqual(idx, 0)
        XCTAssertEqual(sampler.zones.count, 1)
        XCTAssertEqual(sampler.zones[0].name, "TestSample")
    }

    func testLoadMultipleSamples() {
        let sampler = EchoelSampler()
        let idx1 = sampler.loadSample(data: [0.1], sampleRate: 44100, rootNote: 60, name: "A")
        let idx2 = sampler.loadSample(data: [0.2], sampleRate: 44100, rootNote: 72, name: "B")
        XCTAssertEqual(idx1, 0)
        XCTAssertEqual(idx2, 1)
        XCTAssertEqual(sampler.zones.count, 2)
    }

    func testRenderEmptySamplerProducesSilence() {
        let sampler = EchoelSampler()
        let output = sampler.render(frameCount: 256)
        XCTAssertEqual(output.count, 256)
        for sample in output {
            XCTAssertEqual(sample, 0.0)
        }
    }

    func testNoteOnWithNoZonesDoesNotCrash() {
        let sampler = EchoelSampler()
        sampler.noteOn(note: 60, velocity: 100)
        // Should not crash — just no matching zones
        let output = sampler.render(frameCount: 128)
        XCTAssertEqual(output.count, 128)
    }

    func testAllNotesOff() {
        let sampler = EchoelSampler()
        let data = [Float](repeating: 0.5, count: 44100)
        _ = sampler.loadSample(data: data, sampleRate: 44100, rootNote: 60)
        sampler.noteOn(note: 60, velocity: 100)
        sampler.allNotesOff()
        // After all notes off, voices should be releasing
        // Render enough frames for release to complete
        _ = sampler.render(frameCount: 44100)
    }

    func testCreateDrumKitProperties() {
        let kit = EchoelSampler.createDrumKit()
        XCTAssertEqual(kit.ampEnvelope.attack, 0.001, accuracy: 0.0001)
        XCTAssertEqual(kit.ampEnvelope.decay, 0.3)
        XCTAssertEqual(kit.ampEnvelope.sustain, 0)
        XCTAssertEqual(kit.ampEnvelope.release, 0.05)
        XCTAssertEqual(kit.filterCutoff, 12000)
        XCTAssertEqual(kit.interpolation, .hermite)
    }

    func testCreateMelodicProperties() {
        let melodic = EchoelSampler.createMelodic()
        XCTAssertEqual(melodic.ampEnvelope.attack, 0.05)
        XCTAssertEqual(melodic.ampEnvelope.sustain, 0.7)
        XCTAssertEqual(melodic.ampEnvelope.release, 1.0)
        XCTAssertEqual(melodic.filterCutoff, 6000)
        XCTAssertEqual(melodic.filterResonance, 0.2)
        XCTAssertEqual(melodic.filterEnvelopeDepth, 0.4)
        XCTAssertEqual(melodic.interpolation, .sinc)
    }

    func testFreezeSynthToZone() {
        let sampler = EchoelSampler()
        let idx = sampler.freezeSynthToZone(
            render: { frameCount in [Float](repeating: 0.3, count: frameCount) },
            duration: 0.1,
            rootNote: 48,
            name: "Frozen",
            loopEnabled: false
        )
        XCTAssertEqual(idx, 0)
        XCTAssertEqual(sampler.zones.count, 1)
        XCTAssertEqual(sampler.zones[0].name, "Frozen")
        XCTAssertEqual(sampler.zones[0].rootNote, 48)
        XCTAssertFalse(sampler.zones[0].loopEnabled)
    }

    func testRemoveZone() {
        let sampler = EchoelSampler()
        _ = sampler.loadSample(data: [0.1], sampleRate: 44100, rootNote: 60, name: "A")
        _ = sampler.loadSample(data: [0.2], sampleRate: 44100, rootNote: 72, name: "B")
        XCTAssertEqual(sampler.zones.count, 2)
        sampler.removeZone(at: 0)
        XCTAssertEqual(sampler.zones.count, 1)
        XCTAssertEqual(sampler.zones[0].name, "B")
    }

    func testRemoveZoneOutOfBounds() {
        let sampler = EchoelSampler()
        _ = sampler.loadSample(data: [0.1], sampleRate: 44100, rootNote: 60, name: "A")
        sampler.removeZone(at: 99) // Should not crash
        XCTAssertEqual(sampler.zones.count, 1)
    }

    func testSamplerErrorDescriptions() {
        XCTAssertEqual(EchoelSampler.SamplerError.bufferCreationFailed.errorDescription, "Failed to create audio buffer")
        XCTAssertEqual(EchoelSampler.SamplerError.noAudioData.errorDescription, "No audio data in file")
        XCTAssertEqual(EchoelSampler.SamplerError.fileNotFound.errorDescription, "Audio file not found")
        XCTAssertEqual(EchoelSampler.SamplerError.unsupportedFormat.errorDescription, "Unsupported audio format")
    }

    func testBioModulationHeartRateToTempo() {
        let sampler = EchoelSampler()
        sampler.bioModulation.heartRateToTempo = true
        sampler.updateBioData(hrv: 50, coherence: 0.5, heartRate: 90, breathPhase: 0.5, flow: 0)
        XCTAssertEqual(sampler.heartRate, 90)
    }
}

// MARK: - Extended BeatPattern Tests

final class BeatPatternExtendedTests: XCTestCase {

    func testFourOnFloorKickPattern() {
        let pattern = BeatPattern.fourOnFloor(trackCount: 4)
        // Kick on beats 0, 4, 8, 12
        XCTAssertTrue(pattern.tracks[0][0].isActive)
        XCTAssertTrue(pattern.tracks[0][4].isActive)
        XCTAssertTrue(pattern.tracks[0][8].isActive)
        XCTAssertTrue(pattern.tracks[0][12].isActive)
        // Off-beats should be inactive
        XCTAssertFalse(pattern.tracks[0][1].isActive)
        XCTAssertFalse(pattern.tracks[0][2].isActive)
    }

    func testFourOnFloorSnarePattern() {
        let pattern = BeatPattern.fourOnFloor(trackCount: 4)
        // Snare on beats 4 and 12
        XCTAssertTrue(pattern.tracks[1][4].isActive)
        XCTAssertTrue(pattern.tracks[1][12].isActive)
        XCTAssertFalse(pattern.tracks[1][0].isActive)
    }

    func testFourOnFloorHiHatPattern() {
        let pattern = BeatPattern.fourOnFloor(trackCount: 4)
        // HiHat on even steps
        for step in stride(from: 0, to: 16, by: 2) {
            XCTAssertTrue(pattern.tracks[2][step].isActive)
        }
    }

    func testTrapPatternVelocities() {
        let pattern = BeatPattern.trap(trackCount: 3)
        // HiHat alternating velocities
        for step in 0..<16 {
            XCTAssertTrue(pattern.tracks[2][step].isActive)
            if step % 2 == 0 {
                XCTAssertEqual(pattern.tracks[2][step].velocity, 0.9)
            } else {
                XCTAssertEqual(pattern.tracks[2][step].velocity, 0.5)
            }
        }
    }

    func testDnbRollerAllHiHats() {
        let pattern = BeatPattern.dnbRoller(trackCount: 3)
        for step in 0..<16 {
            XCTAssertTrue(pattern.tracks[2][step].isActive)
        }
    }

    func testToggleBoundsChecking() {
        var pattern = BeatPattern(name: "Test", trackCount: 2, stepCount: 4)
        // Out of bounds should not crash
        pattern.toggle(track: 99, step: 0)
        pattern.toggle(track: 0, step: 99)
    }

    func testPatternWithZeroTracks() {
        let pattern = BeatPattern(name: "Empty", trackCount: 0, stepCount: 16)
        XCTAssertTrue(pattern.tracks.isEmpty)
        XCTAssertEqual(pattern.stepCount, 16)
    }

    func testDefaultStepValues() {
        let pattern = BeatPattern(name: "Default", trackCount: 1, stepCount: 4)
        for step in pattern.tracks[0] {
            XCTAssertFalse(step.isActive)
            XCTAssertEqual(step.velocity, 0.8)
            XCTAssertEqual(step.probability, 1.0)
        }
    }
}

// MARK: - Extended DrumSlot Tests

final class DrumSlotExtendedTests: XCTestCase {

    func testDefaultCategory() {
        let slot = DrumSlot(name: "Kick", audioData: [0.5], sampleRate: 44100, midiNote: 36)
        XCTAssertEqual(slot.category, "")
    }

    func testAudioDataPreserved() {
        let data: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        let slot = DrumSlot(name: "Test", audioData: data, sampleRate: 44100, midiNote: 60, category: "perc")
        XCTAssertEqual(slot.audioData, data)
        XCTAssertEqual(slot.audioData.count, 5)
    }

    func testSampleRateStored() {
        let slot = DrumSlot(name: "HiRes", audioData: [], sampleRate: 96000, midiNote: 42)
        XCTAssertEqual(slot.sampleRate, 96000)
    }
}

// MARK: - Extended BeatStep Tests

final class BeatStepExtendedTests: XCTestCase {

    func testCodableWithCustomValues() throws {
        let step = BeatStep(isActive: true, velocity: 0.3, probability: 0.6)
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(BeatStep.self, from: data)
        XCTAssertTrue(decoded.isActive)
        XCTAssertEqual(decoded.velocity, 0.3)
        XCTAssertEqual(decoded.probability, 0.6)
    }

    func testCodableDefaultValues() throws {
        let step = BeatStep()
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(BeatStep.self, from: data)
        XCTAssertFalse(decoded.isActive)
        XCTAssertEqual(decoded.velocity, 0.8)
        XCTAssertEqual(decoded.probability, 1.0)
    }

    func testMutability() {
        var step = BeatStep()
        step.isActive = true
        step.velocity = 0.1
        step.probability = 0.5
        XCTAssertTrue(step.isActive)
        XCTAssertEqual(step.velocity, 0.1)
        XCTAssertEqual(step.probability, 0.5)
    }
}

// MARK: - Extended SamplerLFO Shape Tests

final class SamplerLFOShapeExtendedTests: XCTestCase {

    func testShapeRawValues() {
        XCTAssertEqual(SamplerLFO.Shape.sine.rawValue, "sine")
        XCTAssertEqual(SamplerLFO.Shape.triangle.rawValue, "triangle")
        XCTAssertEqual(SamplerLFO.Shape.saw.rawValue, "saw")
        XCTAssertEqual(SamplerLFO.Shape.square.rawValue, "square")
        XCTAssertEqual(SamplerLFO.Shape.random.rawValue, "random")
    }

    func testShapeRawValueInit() {
        XCTAssertEqual(SamplerLFO.Shape(rawValue: "sine"), .sine)
        XCTAssertEqual(SamplerLFO.Shape(rawValue: "square"), .square)
        XCTAssertNil(SamplerLFO.Shape(rawValue: "invalid"))
    }

    func testTriangleWaveSymmetry() {
        var lfo = SamplerLFO()
        lfo.shape = .triangle
        lfo.depth = 1.0
        lfo.rate = 1.0
        // Run enough samples to get through a full cycle
        var values: [Float] = []
        for _ in 0..<44100 {
            values.append(lfo.process(sampleRate: 44100))
        }
        // Triangle wave should have both positive and negative values
        XCTAssertTrue(values.contains(where: { $0 > 0 }))
        XCTAssertTrue(values.contains(where: { $0 < 0 }))
    }

    func testSawWaveRange() {
        var lfo = SamplerLFO()
        lfo.shape = .saw
        lfo.depth = 1.0
        for _ in 0..<1000 {
            let v = lfo.process(sampleRate: 44100)
            XCTAssertGreaterThanOrEqual(v, -1.0)
            XCTAssertLessThanOrEqual(v, 1.0)
        }
    }

    func testTempoSyncChangesRate() {
        var lfo = SamplerLFO()
        lfo.shape = .sine
        lfo.depth = 1.0
        lfo.tempoSync = true
        lfo.rate = 1.0

        // Process at different BPMs
        var valuesAt60: [Float] = []
        for _ in 0..<100 {
            valuesAt60.append(lfo.process(sampleRate: 44100, bpm: 60))
        }

        var lfo2 = SamplerLFO()
        lfo2.shape = .sine
        lfo2.depth = 1.0
        lfo2.tempoSync = true
        lfo2.rate = 1.0

        var valuesAt120: [Float] = []
        for _ in 0..<100 {
            valuesAt120.append(lfo2.process(sampleRate: 44100, bpm: 120))
        }

        // 120 BPM should cycle twice as fast, so values should differ
        XCTAssertNotEqual(valuesAt60, valuesAt120)
    }
}

// MARK: - Extended SampleZone Tests

final class SampleZoneExtendedTests: XCTestCase {

    func testDefaultNameParameter() {
        let zone = SampleZone()
        XCTAssertEqual(zone.name, "Zone")
        XCTAssertEqual(zone.rootNote, 60)
    }

    func testRoundRobinDefaults() {
        let zone = SampleZone(name: "RR", rootNote: 60)
        XCTAssertEqual(zone.roundRobinGroup, 0)
        XCTAssertEqual(zone.roundRobinIndex, 0)
    }

    func testLoopDefaults() {
        let zone = SampleZone(name: "Loop")
        XCTAssertEqual(zone.loopStart, 0)
        XCTAssertEqual(zone.loopEnd, 0)
        XCTAssertFalse(zone.loopEnabled)
    }

    func testMatchesBoundaryConditions() {
        var zone = SampleZone(name: "Boundary")
        zone.keyRangeLow = 60
        zone.keyRangeHigh = 60
        zone.velocityLow = 100
        zone.velocityHigh = 100
        // Exact match
        XCTAssertTrue(zone.matches(note: 60, velocity: 100))
        // Off by one
        XCTAssertFalse(zone.matches(note: 59, velocity: 100))
        XCTAssertFalse(zone.matches(note: 61, velocity: 100))
        XCTAssertFalse(zone.matches(note: 60, velocity: 99))
        XCTAssertFalse(zone.matches(note: 60, velocity: 101))
    }

    func testSampleDataMutability() {
        var zone = SampleZone(name: "Data")
        XCTAssertTrue(zone.sampleData.isEmpty)
        zone.sampleData = [0.1, 0.2, 0.3]
        XCTAssertEqual(zone.sampleData.count, 3)
    }
}

// MARK: - Extended EnvelopeState Tests

final class EnvelopeStateExtendedTests: XCTestCase {

    func testFullEnvelopeCycle() {
        var state = EnvelopeState()
        let env = ADSREnvelope(attack: 0.001, decay: 0.001, sustain: 0.5, release: 0.001)
        let sampleRate: Float = 44100

        state.noteOn()
        XCTAssertEqual(state.stage, .attack)

        // Process through attack
        let attackSamples = Int(env.attack * sampleRate) + 1
        for _ in 0..<attackSamples {
            _ = state.process(env: env, sampleRate: sampleRate)
        }

        // Should be in decay or sustain
        XCTAssertTrue(state.stage == .decay || state.stage == .sustain)

        // Process through decay
        let decaySamples = Int(env.decay * sampleRate) + 1
        for _ in 0..<decaySamples {
            _ = state.process(env: env, sampleRate: sampleRate)
        }

        // Should be in sustain
        XCTAssertEqual(state.stage, .sustain)

        // Sustain returns constant level
        let sustainLevel = state.process(env: env, sampleRate: sampleRate)
        XCTAssertEqual(sustainLevel, env.sustain, accuracy: 0.001)

        // Note off
        state.noteOff()
        XCTAssertEqual(state.stage, .release)

        // Process through release
        let releaseSamples = Int(env.release * sampleRate) + 10
        for _ in 0..<releaseSamples {
            _ = state.process(env: env, sampleRate: sampleRate)
        }

        // Should be idle
        XCTAssertEqual(state.stage, .idle)
    }

    func testNoteOnResetsCounter() {
        var state = EnvelopeState()
        state.noteOn()
        let env = ADSREnvelope()
        _ = state.process(env: env, sampleRate: 44100)
        _ = state.process(env: env, sampleRate: 44100)
        // Re-trigger
        state.noteOn()
        XCTAssertEqual(state.sampleCounter, 0)
    }
}

// MARK: - Extended HiHatMode Tests

final class HiHatModeExtendedTests: XCTestCase {

    func testAllCasesOrdered() {
        let cases: [HiHatMode] = [.closed, .open, .pedal]
        XCTAssertEqual(HiHatMode.allCases, cases)
    }

    func testDecayTimesPositive() {
        for mode in HiHatMode.allCases {
            XCTAssertGreaterThan(mode.decayTime, 0)
        }
    }

    func testRawValueRoundTrip() {
        for mode in HiHatMode.allCases {
            XCTAssertEqual(HiHatMode(rawValue: mode.rawValue), mode)
        }
    }
}

// MARK: - Extended RollDivision Tests

final class RollDivisionExtendedTests: XCTestCase {

    func testAllCasesOrdered() {
        let cases: [RollDivision] = [
            .eighth, .sixteenth, .thirtysecond, .sixtyfourth,
            .eighthTriplet, .sixteenthTriplet, .thirtysecondTriplet
        ]
        XCTAssertEqual(RollDivision.allCases, cases)
    }

    func testStepsPerBeatPositive() {
        for division in RollDivision.allCases {
            XCTAssertGreaterThan(division.stepsPerBeat, 0)
        }
    }

    func testStraightDivisionsDoubleBetweenLevels() {
        XCTAssertEqual(RollDivision.sixteenth.stepsPerBeat, RollDivision.eighth.stepsPerBeat * 2)
        XCTAssertEqual(RollDivision.thirtysecond.stepsPerBeat, RollDivision.sixteenth.stepsPerBeat * 2)
        XCTAssertEqual(RollDivision.sixtyfourth.stepsPerBeat, RollDivision.thirtysecond.stepsPerBeat * 2)
    }

    func testTripletDivisionsScale() {
        XCTAssertEqual(RollDivision.sixteenthTriplet.stepsPerBeat, RollDivision.eighthTriplet.stepsPerBeat * 2)
        XCTAssertEqual(RollDivision.thirtysecondTriplet.stepsPerBeat, RollDivision.sixteenthTriplet.stepsPerBeat * 2)
    }

    func testRawValueRoundTrip() {
        for division in RollDivision.allCases {
            XCTAssertEqual(RollDivision(rawValue: division.rawValue), division)
        }
    }
}

// MARK: - Extended PresetCategory Tests

final class PresetCategoryExtendedTests: XCTestCase {

    func testAllRawValuesHaveECHOELPrefix() {
        for category in PresetCategory.allCases {
            XCTAssertTrue(category.rawValue.hasPrefix("ECHOEL_"),
                          "\(category) raw value should start with ECHOEL_")
        }
    }

    func testRawValueRoundTrip() {
        for category in PresetCategory.allCases {
            XCTAssertEqual(PresetCategory(rawValue: category.rawValue), category)
        }
    }

    func testInvalidRawValues() {
        XCTAssertNil(PresetCategory(rawValue: "DRUMS"))
        XCTAssertNil(PresetCategory(rawValue: "echoel_drums"))
        XCTAssertNil(PresetCategory(rawValue: ""))
    }
}

// MARK: - Extended SamplerConstants Tests

final class SamplerConstantsExtendedTests: XCTestCase {

    func testMaxZonesReasonable() {
        XCTAssertGreaterThan(SamplerConstants.maxZones, 0)
        XCTAssertLessThanOrEqual(SamplerConstants.maxZones, 1024)
    }

    func testMaxVoicesReasonable() {
        XCTAssertGreaterThan(SamplerConstants.maxVoices, 0)
        XCTAssertLessThanOrEqual(SamplerConstants.maxVoices, 256)
    }

    func testSincTapsEven() {
        XCTAssertEqual(SamplerConstants.sincTaps % 2, 0, "Sinc taps must be even for symmetric windowing")
    }
}

// MARK: - Extended ADSREnvelope Tests

final class ADSREnvelopeExtendedTests: XCTestCase {

    func testCurveDefaultIsLinear() {
        let env = ADSREnvelope()
        XCTAssertEqual(env.curve, 1.0) // 1.0 = linear
    }

    func testParameterizedInitPreservesCurveDefault() {
        let env = ADSREnvelope(attack: 0.1, decay: 0.2, sustain: 0.3, release: 0.4)
        XCTAssertEqual(env.curve, 1.0)
    }

    func testAllParametersMutable() {
        var env = ADSREnvelope()
        env.attack = 1.0
        env.decay = 2.0
        env.sustain = 0.0
        env.release = 5.0
        env.curve = 3.0
        XCTAssertEqual(env.attack, 1.0)
        XCTAssertEqual(env.decay, 2.0)
        XCTAssertEqual(env.sustain, 0.0)
        XCTAssertEqual(env.release, 5.0)
        XCTAssertEqual(env.curve, 3.0)
    }
}

// MARK: - Extended SamplerBioModulation Tests

final class SamplerBioModulationExtendedTests: XCTestCase {

    func testAllModulationDepthsInRange() {
        let bio = SamplerBioModulation()
        XCTAssertGreaterThanOrEqual(bio.hrvToFilterDepth, 0)
        XCTAssertLessThanOrEqual(bio.hrvToFilterDepth, 1.0)
        XCTAssertGreaterThanOrEqual(bio.coherenceToResonance, 0)
        XCTAssertLessThanOrEqual(bio.coherenceToResonance, 1.0)
        XCTAssertGreaterThanOrEqual(bio.breathToVolume, 0)
        XCTAssertLessThanOrEqual(bio.breathToVolume, 1.0)
        XCTAssertGreaterThanOrEqual(bio.flowToComplexity, 0)
        XCTAssertLessThanOrEqual(bio.flowToComplexity, 1.0)
    }

    func testFullMutability() {
        var bio = SamplerBioModulation()
        bio.hrvToFilterDepth = 0.0
        bio.coherenceToResonance = 0.0
        bio.heartRateToTempo = true
        bio.breathToVolume = 1.0
        bio.flowToComplexity = 1.0
        XCTAssertEqual(bio.hrvToFilterDepth, 0.0)
        XCTAssertEqual(bio.coherenceToResonance, 0.0)
        XCTAssertTrue(bio.heartRateToTempo)
        XCTAssertEqual(bio.breathToVolume, 1.0)
        XCTAssertEqual(bio.flowToComplexity, 1.0)
    }
}

// MARK: - Extended SamplerFilterType Tests

final class SamplerFilterTypeExtendedTests: XCTestCase {

    func testRawValueRoundTrip() {
        for filterType in SamplerFilterType.allCases {
            XCTAssertEqual(SamplerFilterType(rawValue: filterType.rawValue), filterType)
        }
    }

    func testInvalidRawValues() {
        XCTAssertNil(SamplerFilterType(rawValue: "lowpass"))
        XCTAssertNil(SamplerFilterType(rawValue: "LP"))
        XCTAssertNil(SamplerFilterType(rawValue: ""))
    }

    func testAllCasesOrdered() {
        let expected: [SamplerFilterType] = [.lowpass, .highpass, .bandpass, .notch]
        XCTAssertEqual(SamplerFilterType.allCases, expected)
    }
}

// MARK: - Extended SamplerInterpolation Tests

final class SamplerInterpolationExtendedTests: XCTestCase {

    func testQualityIsStrictlyIncreasing() {
        let qualities = SamplerInterpolation.allCases.map(\.quality)
        for i in 1..<qualities.count {
            XCTAssertGreaterThan(qualities[i], qualities[i - 1])
        }
    }

    func testRawValueRoundTrip() {
        for interp in SamplerInterpolation.allCases {
            XCTAssertEqual(SamplerInterpolation(rawValue: interp.rawValue), interp)
        }
    }

    func testInvalidRawValues() {
        XCTAssertNil(SamplerInterpolation(rawValue: "linear"))
        XCTAssertNil(SamplerInterpolation(rawValue: ""))
    }
}
#endif
