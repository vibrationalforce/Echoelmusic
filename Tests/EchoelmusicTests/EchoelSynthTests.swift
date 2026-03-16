#if canImport(AVFoundation)
//
//  EchoelSynthTests.swift
//  Echoelmusic
//
//  Tests for EchoelSynth types: SynthEngineType, SynthFilterMode, EchoelSynthConfig
//

import XCTest
@testable import Echoelmusic

// MARK: - SynthEngineType Tests

final class SynthEngineTypeTests: XCTestCase {

    // MARK: - CaseIterable

    func testSynthEngineType_allCases_countIsFive() {
        XCTAssertEqual(SynthEngineType.allCases.count, 5)
    }

    func testSynthEngineType_allCases_containsAllEngines() {
        let cases = SynthEngineType.allCases
        XCTAssertTrue(cases.contains(.analog))
        XCTAssertTrue(cases.contains(.fm))
        XCTAssertTrue(cases.contains(.wavetable))
        XCTAssertTrue(cases.contains(.pluck))
        XCTAssertTrue(cases.contains(.pad))
    }

    // MARK: - Raw Values

    func testSynthEngineType_analogRawValue() {
        XCTAssertEqual(SynthEngineType.analog.rawValue, "Analog")
    }

    func testSynthEngineType_fmRawValue() {
        XCTAssertEqual(SynthEngineType.fm.rawValue, "FM")
    }

    func testSynthEngineType_wavetableRawValue() {
        XCTAssertEqual(SynthEngineType.wavetable.rawValue, "Wavetable")
    }

    func testSynthEngineType_pluckRawValue() {
        XCTAssertEqual(SynthEngineType.pluck.rawValue, "Pluck")
    }

    func testSynthEngineType_padRawValue() {
        XCTAssertEqual(SynthEngineType.pad.rawValue, "Pad")
    }

    // MARK: - Init from Raw Value

    func testSynthEngineType_initFromRawValue_analog() {
        let engine = SynthEngineType(rawValue: "Analog")
        XCTAssertEqual(engine, .analog)
    }

    func testSynthEngineType_initFromRawValue_fm() {
        let engine = SynthEngineType(rawValue: "FM")
        XCTAssertEqual(engine, .fm)
    }

    func testSynthEngineType_initFromRawValue_wavetable() {
        let engine = SynthEngineType(rawValue: "Wavetable")
        XCTAssertEqual(engine, .wavetable)
    }

    func testSynthEngineType_initFromRawValue_pluck() {
        let engine = SynthEngineType(rawValue: "Pluck")
        XCTAssertEqual(engine, .pluck)
    }

    func testSynthEngineType_initFromRawValue_pad() {
        let engine = SynthEngineType(rawValue: "Pad")
        XCTAssertEqual(engine, .pad)
    }

    func testSynthEngineType_initFromRawValue_invalidReturnsNil() {
        let engine = SynthEngineType(rawValue: "Digital")
        XCTAssertNil(engine)
    }

    func testSynthEngineType_initFromRawValue_emptyReturnsNil() {
        let engine = SynthEngineType(rawValue: "")
        XCTAssertNil(engine)
    }

    func testSynthEngineType_initFromRawValue_caseSensitive() {
        XCTAssertNil(SynthEngineType(rawValue: "analog"))
        XCTAssertNil(SynthEngineType(rawValue: "ANALOG"))
        XCTAssertNil(SynthEngineType(rawValue: "fm"))
    }

    // MARK: - Codable Round-Trip

    func testSynthEngineType_codableRoundTrip_analog() throws {
        let original = SynthEngineType.analog
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SynthEngineType.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testSynthEngineType_codableRoundTrip_fm() throws {
        let original = SynthEngineType.fm
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SynthEngineType.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testSynthEngineType_codableRoundTrip_wavetable() throws {
        let original = SynthEngineType.wavetable
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SynthEngineType.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testSynthEngineType_codableRoundTrip_pluck() throws {
        let original = SynthEngineType.pluck
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SynthEngineType.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testSynthEngineType_codableRoundTrip_pad() throws {
        let original = SynthEngineType.pad
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SynthEngineType.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testSynthEngineType_codableRoundTrip_allCases() throws {
        for engineType in SynthEngineType.allCases {
            let data = try JSONEncoder().encode(engineType)
            let decoded = try JSONDecoder().decode(SynthEngineType.self, from: data)
            XCTAssertEqual(engineType, decoded, "Round-trip failed for \(engineType)")
        }
    }

    func testSynthEngineType_encodesToExpectedJSON() throws {
        let data = try JSONEncoder().encode(SynthEngineType.analog)
        let jsonString = String(data: data, encoding: .utf8)
        XCTAssertEqual(jsonString, "\"Analog\"")
    }

    func testSynthEngineType_decodesFromRawJSON() throws {
        let json = "\"FM\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SynthEngineType.self, from: json)
        XCTAssertEqual(decoded, .fm)
    }

    func testSynthEngineType_decodeInvalidJSON_throws() {
        let json = "\"Granular\"".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(SynthEngineType.self, from: json))
    }
}

// MARK: - SynthFilterMode Tests

final class SynthFilterModeTests: XCTestCase {

    // MARK: - CaseIterable

    func testSynthFilterMode_allCases_countIsThree() {
        XCTAssertEqual(SynthFilterMode.allCases.count, 3)
    }

    func testSynthFilterMode_allCases_containsAllModes() {
        let cases = SynthFilterMode.allCases
        XCTAssertTrue(cases.contains(.lowpass))
        XCTAssertTrue(cases.contains(.highpass))
        XCTAssertTrue(cases.contains(.bandpass))
    }

    // MARK: - Raw Values

    func testSynthFilterMode_lowpassRawValue() {
        XCTAssertEqual(SynthFilterMode.lowpass.rawValue, "LP")
    }

    func testSynthFilterMode_highpassRawValue() {
        XCTAssertEqual(SynthFilterMode.highpass.rawValue, "HP")
    }

    func testSynthFilterMode_bandpassRawValue() {
        XCTAssertEqual(SynthFilterMode.bandpass.rawValue, "BP")
    }

    // MARK: - Init from Raw Value

    func testSynthFilterMode_initFromRawValue_LP() {
        XCTAssertEqual(SynthFilterMode(rawValue: "LP"), .lowpass)
    }

    func testSynthFilterMode_initFromRawValue_HP() {
        XCTAssertEqual(SynthFilterMode(rawValue: "HP"), .highpass)
    }

    func testSynthFilterMode_initFromRawValue_BP() {
        XCTAssertEqual(SynthFilterMode(rawValue: "BP"), .bandpass)
    }

    func testSynthFilterMode_initFromRawValue_invalidReturnsNil() {
        XCTAssertNil(SynthFilterMode(rawValue: "Notch"))
    }

    func testSynthFilterMode_initFromRawValue_caseSensitive() {
        XCTAssertNil(SynthFilterMode(rawValue: "lp"))
        XCTAssertNil(SynthFilterMode(rawValue: "Lp"))
    }

    // MARK: - Codable Round-Trip

    func testSynthFilterMode_codableRoundTrip_allCases() throws {
        for mode in SynthFilterMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(SynthFilterMode.self, from: data)
            XCTAssertEqual(mode, decoded, "Round-trip failed for \(mode)")
        }
    }

    func testSynthFilterMode_encodesToExpectedJSON() throws {
        let data = try JSONEncoder().encode(SynthFilterMode.lowpass)
        let jsonString = String(data: data, encoding: .utf8)
        XCTAssertEqual(jsonString, "\"LP\"")
    }
}

// MARK: - EchoelSynthConfig Tests

final class EchoelSynthConfigTests: XCTestCase {

    // MARK: - Default Values — Engine Selection

    func testConfig_defaultEngine_isAnalog() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.engine, .analog)
    }

    func testConfig_defaultTuning_isZero() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.tuning, 0.0)
    }

    func testConfig_defaultOctave_isZero() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.octave, 0)
    }

    // MARK: - Default Values — Analog Engine

    func testConfig_defaultAnalogDetune_is12() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.analogDetune, 12.0)
    }

    func testConfig_defaultAnalogVoices_is3() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.analogVoices, 3)
    }

    func testConfig_defaultAnalogWaveform_isZero() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.analogWaveform, 0.0)
    }

    func testConfig_defaultAnalogPWM_is05() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.analogPWM, 0.5)
    }

    // MARK: - Default Values — FM Engine

    func testConfig_defaultFmRatio_is2() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.fmRatio, 2.0)
    }

    func testConfig_defaultFmDepth_is05() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.fmDepth, 0.5)
    }

    func testConfig_defaultFmFeedback_isZero() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.fmFeedback, 0.0)
    }

    func testConfig_defaultFmModDecay_is03() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.fmModDecay, 0.3)
    }

    // MARK: - Default Values — Wavetable Engine

    func testConfig_defaultWtPosition_isZero() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.wtPosition, 0.0)
    }

    func testConfig_defaultWtModSpeed_isZero() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.wtModSpeed, 0.0)
    }

    // MARK: - Default Values — Pluck Engine

    func testConfig_defaultPluckDamping_is05() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.pluckDamping, 0.5)
    }

    func testConfig_defaultPluckDecay_is0995() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.pluckDecay, 0.995, accuracy: 0.0001)
    }

    func testConfig_defaultPluckBrightness_is07() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.pluckBrightness, 0.7, accuracy: 0.0001)
    }

    func testConfig_defaultPluckStretch_isZero() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.pluckStretch, 0.0)
    }

    // MARK: - Default Values — Pad Engine

    func testConfig_defaultPadSpread_is20() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.padSpread, 20.0)
    }

    func testConfig_defaultPadVoiceCount_is7() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.padVoiceCount, 7)
    }

    func testConfig_defaultPadChorusRate_is03() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.padChorusRate, 0.3, accuracy: 0.0001)
    }

    func testConfig_defaultPadChorusDepth_is05() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.padChorusDepth, 0.5)
    }

    // MARK: - Default Values — Filter

    func testConfig_defaultFilterMode_isLowpass() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.filterMode, .lowpass)
    }

    func testConfig_defaultFilterCutoff_is8000() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.filterCutoff, 8000.0)
    }

    func testConfig_defaultFilterResonance_is02() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.filterResonance, 0.2)
    }

    func testConfig_defaultFilterEnvAmount_is2000() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.filterEnvAmount, 2000.0)
    }

    func testConfig_defaultFilterEnvDecay_is04() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.filterEnvDecay, 0.4)
    }

    func testConfig_defaultFilterKeyTrack_is05() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.filterKeyTrack, 0.5)
    }

    // MARK: - Default Values — Envelope

    func testConfig_defaultAttack_is001() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.attack, 0.01, accuracy: 0.0001)
    }

    func testConfig_defaultDecay_is03() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.decay, 0.3, accuracy: 0.0001)
    }

    func testConfig_defaultSustain_is07() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.sustain, 0.7, accuracy: 0.0001)
    }

    func testConfig_defaultRelease_is04() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.release, 0.4, accuracy: 0.0001)
    }

    // MARK: - Default Values — Effects

    func testConfig_defaultDrive_isZero() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.drive, 0.0)
    }

    func testConfig_defaultChorusAmount_isZero() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.chorusAmount, 0.0)
    }

    func testConfig_defaultLevel_is08() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.level, 0.8, accuracy: 0.0001)
    }

    func testConfig_defaultStereoWidth_is03() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.stereoWidth, 0.3, accuracy: 0.0001)
    }

    func testConfig_defaultVibratoRate_is5() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.vibratoRate, 5.0)
    }

    func testConfig_defaultVibratoDepth_isZero() {
        let config = EchoelSynthConfig()
        XCTAssertEqual(config.vibratoDepth, 0.0)
    }

    // MARK: - Codable Round-Trip

    func testConfig_codableRoundTrip_defaultConfig() throws {
        let original = EchoelSynthConfig()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EchoelSynthConfig.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testConfig_codableRoundTrip_allFieldsCustomized() throws {
        var config = EchoelSynthConfig()
        config.engine = .fm
        config.tuning = -50.0
        config.octave = 2
        config.analogDetune = 25.0
        config.analogVoices = 5
        config.analogWaveform = 1.0
        config.analogPWM = 0.9
        config.fmRatio = 3.5
        config.fmDepth = 1.2
        config.fmFeedback = 0.1
        config.fmModDecay = 2.0
        config.wtPosition = 0.7
        config.wtModSpeed = 0.5
        config.pluckDamping = 0.8
        config.pluckDecay = 0.998
        config.pluckBrightness = 1.0
        config.pluckStretch = 0.1
        config.padSpread = 30.0
        config.padVoiceCount = 5
        config.padChorusRate = 0.6
        config.padChorusDepth = 0.8
        config.filterMode = .bandpass
        config.filterCutoff = 2000.0
        config.filterResonance = 0.8
        config.filterEnvAmount = 5000.0
        config.filterEnvDecay = 1.0
        config.filterKeyTrack = 1.0
        config.attack = 0.5
        config.decay = 1.0
        config.sustain = 0.3
        config.release = 2.0
        config.drive = 0.5
        config.chorusAmount = 0.7
        config.level = 0.5
        config.stereoWidth = 0.9
        config.vibratoRate = 7.0
        config.vibratoDepth = 0.3

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(EchoelSynthConfig.self, from: data)
        XCTAssertEqual(config, decoded)
    }

    func testConfig_codableRoundTrip_classicLeadPreset() throws {
        let original = EchoelSynthConfig.classicLead
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EchoelSynthConfig.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testConfig_codableRoundTrip_electricPianoPreset() throws {
        let original = EchoelSynthConfig.electricPiano
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EchoelSynthConfig.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testConfig_codableRoundTrip_warmPadPreset() throws {
        let original = EchoelSynthConfig.warmPad
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EchoelSynthConfig.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testConfig_codableRoundTrip_bioReactivePreset() throws {
        let original = EchoelSynthConfig.bioReactive
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EchoelSynthConfig.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testConfig_codable_producesValidJSON() throws {
        let config = EchoelSynthConfig()
        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertNotNil(json?["engine"])
        XCTAssertNotNil(json?["tuning"])
        XCTAssertNotNil(json?["filterCutoff"])
    }

    // MARK: - Equatable

    func testConfig_equatable_twoDefaultsAreEqual() {
        let config1 = EchoelSynthConfig()
        let config2 = EchoelSynthConfig()
        XCTAssertEqual(config1, config2)
    }

    func testConfig_equatable_differentEngine_notEqual() {
        var config1 = EchoelSynthConfig()
        var config2 = EchoelSynthConfig()
        config2.engine = .fm
        XCTAssertNotEqual(config1, config2)

        config1.engine = .fm
        XCTAssertEqual(config1, config2)
    }

    func testConfig_equatable_differentTuning_notEqual() {
        var config1 = EchoelSynthConfig()
        var config2 = EchoelSynthConfig()
        config2.tuning = 10.0
        XCTAssertNotEqual(config1, config2)
    }

    func testConfig_equatable_differentOctave_notEqual() {
        var config1 = EchoelSynthConfig()
        var config2 = EchoelSynthConfig()
        config2.octave = 1
        XCTAssertNotEqual(config1, config2)
    }

    func testConfig_equatable_differentFilterMode_notEqual() {
        var config1 = EchoelSynthConfig()
        var config2 = EchoelSynthConfig()
        config2.filterMode = .highpass
        XCTAssertNotEqual(config1, config2)
    }

    func testConfig_equatable_differentLevel_notEqual() {
        var config1 = EchoelSynthConfig()
        var config2 = EchoelSynthConfig()
        config2.level = 0.5
        XCTAssertNotEqual(config1, config2)
    }

    func testConfig_equatable_differentAnalogDetune_notEqual() {
        var config1 = EchoelSynthConfig()
        var config2 = EchoelSynthConfig()
        config2.analogDetune = 25.0
        XCTAssertNotEqual(config1, config2)
    }

    func testConfig_equatable_differentFmDepth_notEqual() {
        var config1 = EchoelSynthConfig()
        var config2 = EchoelSynthConfig()
        config2.fmDepth = 1.0
        XCTAssertNotEqual(config1, config2)
    }

    // MARK: - Presets Validation

    func testConfig_classicLead_isAnalog() {
        XCTAssertEqual(EchoelSynthConfig.classicLead.engine, .analog)
    }

    func testConfig_electricPiano_isFM() {
        XCTAssertEqual(EchoelSynthConfig.electricPiano.engine, .fm)
    }

    func testConfig_bellKeys_isFM() {
        XCTAssertEqual(EchoelSynthConfig.bellKeys.engine, .fm)
    }

    func testConfig_pluckedGuitar_isPluck() {
        XCTAssertEqual(EchoelSynthConfig.pluckedGuitar.engine, .pluck)
    }

    func testConfig_warmPad_isPad() {
        XCTAssertEqual(EchoelSynthConfig.warmPad.engine, .pad)
    }

    func testConfig_synthBrass_isAnalog() {
        XCTAssertEqual(EchoelSynthConfig.synthBrass.engine, .analog)
    }

    func testConfig_crystalPluck_isPluck() {
        XCTAssertEqual(EchoelSynthConfig.crystalPluck.engine, .pluck)
    }

    func testConfig_retroWavetable_isWavetable() {
        XCTAssertEqual(EchoelSynthConfig.retroWavetable.engine, .wavetable)
    }

    func testConfig_bioReactive_isWavetable() {
        XCTAssertEqual(EchoelSynthConfig.bioReactive.engine, .wavetable)
    }

    // MARK: - Mutation

    func testConfig_mutation_engineCanBeChanged() {
        var config = EchoelSynthConfig()
        config.engine = .pad
        XCTAssertEqual(config.engine, .pad)
    }

    func testConfig_mutation_filterModeCanBeChanged() {
        var config = EchoelSynthConfig()
        config.filterMode = .highpass
        XCTAssertEqual(config.filterMode, .highpass)
    }

    func testConfig_mutation_multipleFieldsCanBeChanged() {
        var config = EchoelSynthConfig()
        config.engine = .wavetable
        config.wtPosition = 0.5
        config.filterCutoff = 3000.0
        config.attack = 0.1

        XCTAssertEqual(config.engine, .wavetable)
        XCTAssertEqual(config.wtPosition, 0.5)
        XCTAssertEqual(config.filterCutoff, 3000.0)
        XCTAssertEqual(config.attack, 0.1, accuracy: 0.0001)
    }
}

#endif
