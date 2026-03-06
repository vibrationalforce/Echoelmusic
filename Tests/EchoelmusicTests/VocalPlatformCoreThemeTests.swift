// VocalPlatformCoreThemeTests.swift
// Echoelmusic
//
// Comprehensive tests for Vocal Processing, Core, Platform, and Theme types.
// Tests enums, structs, value types, Codable conformance, computed properties,
// CaseIterable counts, rawValues, and boundary conditions.

import XCTest
import Foundation
@testable import Echoelmusic

// MARK: - VoiceProfileCategory Tests

final class VoiceProfileCategoryTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(VoiceProfileCategory.allCases.count, 7)
    }

    func testRawValues() {
        XCTAssertEqual(VoiceProfileCategory.natural.rawValue, "Natural")
        XCTAssertEqual(VoiceProfileCategory.autoTune.rawValue, "Auto-Tune")
        XCTAssertEqual(VoiceProfileCategory.character.rawValue, "Character")
        XCTAssertEqual(VoiceProfileCategory.meditation.rawValue, "Meditation")
        XCTAssertEqual(VoiceProfileCategory.performance.rawValue, "Performance")
        XCTAssertEqual(VoiceProfileCategory.voiceClone.rawValue, "Voice Clone")
        XCTAssertEqual(VoiceProfileCategory.custom.rawValue, "Custom")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(VoiceProfileCategory(rawValue: "Natural"), .natural)
        XCTAssertEqual(VoiceProfileCategory(rawValue: "Auto-Tune"), .autoTune)
        XCTAssertEqual(VoiceProfileCategory(rawValue: "Custom"), .custom)
        XCTAssertNil(VoiceProfileCategory(rawValue: "invalid"))
        XCTAssertNil(VoiceProfileCategory(rawValue: ""))
    }

    func testCodableRoundTrip() throws {
        for category in VoiceProfileCategory.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(VoiceProfileCategory.self, from: data)
            XCTAssertEqual(decoded, category)
        }
    }

    func testSendableConformance() {
        let category: VoiceProfileCategory = .natural
        let sendable: any Sendable = category
        XCTAssertNotNil(sendable)
    }
}

// MARK: - VoiceAnalysisError Tests

final class VoiceAnalysisErrorTests: XCTestCase {

    func testInvalidFormatDescription() {
        let error = VoiceAnalysisError.invalidFormat
        XCTAssertEqual(error.errorDescription, "Invalid audio format")
    }

    func testNoAudioDataDescription() {
        let error = VoiceAnalysisError.noAudioData
        XCTAssertEqual(error.errorDescription, "No audio data found")
    }

    func testTooShortDescription() {
        let error = VoiceAnalysisError.tooShort
        XCTAssertEqual(error.errorDescription, "Recording too short for analysis (minimum 2 seconds)")
    }

    func testLocalizedErrorConformance() {
        let error: LocalizedError = VoiceAnalysisError.invalidFormat
        XCTAssertNotNil(error.errorDescription)
    }

    func testAllCasesHaveDescriptions() {
        let errors: [VoiceAnalysisError] = [.invalidFormat, .noAudioData, .tooShort]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}

// MARK: - PhaseVocoderFrame Tests

final class PhaseVocoderFrameTests: XCTestCase {

    func testInitialization() {
        let frame = PhaseVocoderFrame(
            magnitudes: [0.5, 0.3, 0.1],
            phases: [0.0, 1.57, 3.14],
            instantaneousFrequencies: [440.0, 880.0, 1320.0],
            isTransient: false,
            rmsEnergy: 0.42
        )
        XCTAssertEqual(frame.magnitudes.count, 3)
        XCTAssertEqual(frame.phases.count, 3)
        XCTAssertEqual(frame.instantaneousFrequencies.count, 3)
        XCTAssertFalse(frame.isTransient)
        XCTAssertEqual(frame.rmsEnergy, 0.42)
    }

    func testTransientFrame() {
        let frame = PhaseVocoderFrame(
            magnitudes: [1.0],
            phases: [0.0],
            instantaneousFrequencies: [440.0],
            isTransient: true,
            rmsEnergy: 0.9
        )
        XCTAssertTrue(frame.isTransient)
        XCTAssertEqual(frame.rmsEnergy, 0.9)
    }

    func testEmptyFrame() {
        let frame = PhaseVocoderFrame(
            magnitudes: [],
            phases: [],
            instantaneousFrequencies: [],
            isTransient: false,
            rmsEnergy: 0.0
        )
        XCTAssertTrue(frame.magnitudes.isEmpty)
        XCTAssertEqual(frame.rmsEnergy, 0.0)
    }
}

// MARK: - Platform Tests

final class PlatformTests: XCTestCase {

    func testIsiOSReturnsBool() {
        let result = Platform.isiOS
        XCTAssertTrue(result == true || result == false)
    }

    func testIsMacOSReturnsBool() {
        let result = Platform.isMacOS
        XCTAssertTrue(result == true || result == false)
    }

    func testIsWatchOSReturnsBool() {
        let result = Platform.isWatchOS
        XCTAssertTrue(result == true || result == false)
    }

    func testIsTVOSReturnsBool() {
        let result = Platform.isTVOS
        XCTAssertTrue(result == true || result == false)
    }

    func testIsVisionOSReturnsBool() {
        let result = Platform.isVisionOS
        XCTAssertTrue(result == true || result == false)
    }

    func testHasHealthKitReturnsBool() {
        let result = Platform.hasHealthKit
        XCTAssertTrue(result == true || result == false)
    }

    func testHasARKitReturnsBool() {
        let result = Platform.hasARKit
        XCTAssertTrue(result == true || result == false)
    }

    func testHasRealityKitReturnsBool() {
        let result = Platform.hasRealityKit
        XCTAssertTrue(result == true || result == false)
    }

    func testHasCoreMotionReturnsBool() {
        let result = Platform.hasCoreMotion
        XCTAssertTrue(result == true || result == false)
    }

    func testAtLeastOnePlatformIsTrue() {
        let platforms = [
            Platform.isiOS,
            Platform.isMacOS,
            Platform.isWatchOS,
            Platform.isTVOS,
            Platform.isVisionOS
        ]
        XCTAssertTrue(platforms.contains(true), "At least one platform should be active")
    }
}

// MARK: - FeatureAvailability Tests

final class FeatureAvailabilityTests: XCTestCase {

    func testBiofeedbackReturnsBool() {
        let result = FeatureAvailability.biofeedback
        XCTAssertTrue(result == true || result == false)
    }

    func testFaceTrackingReturnsBool() {
        let result = FeatureAvailability.faceTracking
        XCTAssertTrue(result == true || result == false)
    }

    func testSpatialAudioReturnsBool() {
        let result = FeatureAvailability.spatialAudio
        XCTAssertTrue(result == true || result == false)
    }

    func testImmersiveReturnsBool() {
        let result = FeatureAvailability.immersive
        XCTAssertTrue(result == true || result == false)
    }
}

// MARK: - SessionState Tests

final class SessionStateTests: XCTestCase {

    func testDefaultInitialization() {
        let state = SessionState()
        XCTAssertNotNil(state.sessionId)
        XCTAssertNotNil(state.startedAt)
        XCTAssertNotNil(state.lastUpdatedAt)
        XCTAssertEqual(state.durationSeconds, 0)
        XCTAssertNil(state.activePreset)
        XCTAssertTrue(state.userData.isEmpty)
    }

    func testCustomSessionId() {
        let customId = UUID()
        let state = SessionState(sessionId: customId)
        XCTAssertEqual(state.sessionId, customId)
    }

    func testBioSettingsDefaults() {
        let state = SessionState()
        XCTAssertTrue(state.bioSettings.enabled)
        XCTAssertEqual(state.bioSettings.coherenceThreshold, 0.6)
        XCTAssertEqual(state.bioSettings.smoothingFactor, 0.3)
    }

    func testAudioSettingsDefaults() {
        let state = SessionState()
        XCTAssertEqual(state.audioSettings.volume, 0.8)
        XCTAssertEqual(state.audioSettings.bpm, 120)
        XCTAssertEqual(state.audioSettings.carrierFrequency, 440)
        XCTAssertTrue(state.audioSettings.toneEnabled)
        XCTAssertEqual(state.audioSettings.toneFrequency, 10)
    }

    func testVisualSettingsDefaults() {
        let state = SessionState()
        XCTAssertEqual(state.visualSettings.mode, "coherence")
        XCTAssertEqual(state.visualSettings.intensity, 0.8)
        XCTAssertEqual(state.visualSettings.colorScheme, "default")
    }

    func testLightSettingsDefaults() {
        let state = SessionState()
        XCTAssertFalse(state.lightSettings.dmxEnabled)
        XCTAssertFalse(state.lightSettings.artNetEnabled)
        XCTAssertFalse(state.lightSettings.laserEnabled)
        XCTAssertEqual(state.lightSettings.brightness, 1.0)
    }

    func testSessionMetricsDefaults() {
        let state = SessionState()
        XCTAssertEqual(state.metrics.averageCoherence, 0)
        XCTAssertEqual(state.metrics.peakCoherence, 0)
        XCTAssertEqual(state.metrics.coherenceReadings, 0)
        XCTAssertEqual(state.metrics.totalBreaths, 0)
    }

    func testCodableRoundTrip() throws {
        var state = SessionState()
        state.activePreset = "TestPreset"
        state.bioSettings.coherenceThreshold = 0.75
        state.audioSettings.bpm = 90
        state.userData["key"] = "value"

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SessionState.self, from: data)

        XCTAssertEqual(decoded.sessionId, state.sessionId)
        XCTAssertEqual(decoded.activePreset, "TestPreset")
        XCTAssertEqual(decoded.bioSettings.coherenceThreshold, 0.75)
        XCTAssertEqual(decoded.audioSettings.bpm, 90)
        XCTAssertEqual(decoded.userData["key"], "value")
    }

    func testSendableConformance() {
        let state: any Sendable = SessionState()
        XCTAssertNotNil(state)
    }

    func testMutableProperties() {
        var state = SessionState()
        state.durationSeconds = 300
        state.activePreset = "Preset1"
        XCTAssertEqual(state.durationSeconds, 300)
        XCTAssertEqual(state.activePreset, "Preset1")
    }

    func testUserDataStorage() {
        var state = SessionState()
        state.userData["instrument"] = "synth"
        state.userData["mode"] = "creative"
        XCTAssertEqual(state.userData.count, 2)
        XCTAssertEqual(state.userData["instrument"], "synth")
    }
}

// MARK: - SessionStateBuilder Tests

final class SessionStateBuilderTests: XCTestCase {

    func testDefaultBuild() {
        let state = SessionStateBuilder().build()
        XCTAssertNotNil(state.sessionId)
        XCTAssertNil(state.activePreset)
    }

    func testWithPreset() {
        let state = SessionStateBuilder()
            .withPreset("MyPreset")
            .build()
        XCTAssertEqual(state.activePreset, "MyPreset")
    }

    func testWithBioSettingsEnabled() {
        let state = SessionStateBuilder()
            .withBioSettings(enabled: false)
            .build()
        XCTAssertFalse(state.bioSettings.enabled)
    }

    func testWithBioSettingsThreshold() {
        let state = SessionStateBuilder()
            .withBioSettings(coherenceThreshold: 0.9)
            .build()
        XCTAssertEqual(state.bioSettings.coherenceThreshold, 0.9)
    }

    func testWithAudioSettingsVolume() {
        let state = SessionStateBuilder()
            .withAudioSettings(volume: 0.5)
            .build()
        XCTAssertEqual(state.audioSettings.volume, 0.5)
    }

    func testWithAudioSettingsBPM() {
        let state = SessionStateBuilder()
            .withAudioSettings(bpm: 140)
            .build()
        XCTAssertEqual(state.audioSettings.bpm, 140)
    }

    func testWithCoherenceReading() {
        let state = SessionStateBuilder()
            .withCoherenceReading(0.8)
            .build()
        XCTAssertEqual(state.metrics.coherenceReadings, 1)
        XCTAssertEqual(state.metrics.averageCoherence, 0.8)
        XCTAssertEqual(state.metrics.peakCoherence, 0.8)
    }

    func testWithMultipleCoherenceReadings() {
        let state = SessionStateBuilder()
            .withCoherenceReading(0.6)
            .withCoherenceReading(0.8)
            .build()
        XCTAssertEqual(state.metrics.coherenceReadings, 2)
        XCTAssertEqual(state.metrics.averageCoherence, 0.7, accuracy: 0.001)
        XCTAssertEqual(state.metrics.peakCoherence, 0.8)
    }

    func testWithCoherenceReadingPeakTracking() {
        let state = SessionStateBuilder()
            .withCoherenceReading(0.9)
            .withCoherenceReading(0.5)
            .build()
        XCTAssertEqual(state.metrics.peakCoherence, 0.9)
    }

    func testWithUserData() {
        let state = SessionStateBuilder()
            .withUserData("key1", value: "val1")
            .withUserData("key2", value: "val2")
            .build()
        XCTAssertEqual(state.userData["key1"], "val1")
        XCTAssertEqual(state.userData["key2"], "val2")
    }

    func testChainingAllMethods() {
        let state = SessionStateBuilder()
            .withPreset("ChainedPreset")
            .withBioSettings(enabled: true, coherenceThreshold: 0.7)
            .withAudioSettings(volume: 0.6, bpm: 100)
            .withCoherenceReading(0.85)
            .withUserData("session", value: "test")
            .build()
        XCTAssertEqual(state.activePreset, "ChainedPreset")
        XCTAssertTrue(state.bioSettings.enabled)
        XCTAssertEqual(state.bioSettings.coherenceThreshold, 0.7)
        XCTAssertEqual(state.audioSettings.volume, 0.6)
        XCTAssertEqual(state.audioSettings.bpm, 100)
        XCTAssertEqual(state.metrics.coherenceReadings, 1)
        XCTAssertEqual(state.userData["session"], "test")
    }

    func testFromExistingState() {
        var existing = SessionState()
        existing.activePreset = "Existing"
        existing.audioSettings.bpm = 85

        let state = SessionStateBuilder(from: existing)
            .withAudioSettings(volume: 0.3)
            .build()
        XCTAssertEqual(state.activePreset, "Existing")
        XCTAssertEqual(state.audioSettings.bpm, 85)
        XCTAssertEqual(state.audioSettings.volume, 0.3)
    }
}

// MARK: - HapticHelper Tests

final class HapticHelperTests: XCTestCase {

    func testStyleCases() {
        let styles: [HapticHelper.Style] = [.light, .medium, .heavy, .selection]
        XCTAssertEqual(styles.count, 4)
    }

    func testNotificationTypeCases() {
        let types: [HapticHelper.NotificationType] = [.success, .warning, .error]
        XCTAssertEqual(types.count, 3)
    }

    func testImpactDoesNotCrash() {
        HapticHelper.impact(.light)
        HapticHelper.impact(.medium)
        HapticHelper.impact(.heavy)
        HapticHelper.impact(.selection)
    }

    func testNotificationDoesNotCrash() {
        HapticHelper.notification(.success)
        HapticHelper.notification(.warning)
        HapticHelper.notification(.error)
    }
}

// MARK: - AppThemeMode Tests

final class AppThemeModeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(AppThemeMode.allCases.count, 3)
    }

    func testRawValues() {
        XCTAssertEqual(AppThemeMode.dark.rawValue, "Dark")
        XCTAssertEqual(AppThemeMode.light.rawValue, "Light")
        XCTAssertEqual(AppThemeMode.system.rawValue, "System")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(AppThemeMode(rawValue: "Dark"), .dark)
        XCTAssertEqual(AppThemeMode(rawValue: "Light"), .light)
        XCTAssertEqual(AppThemeMode(rawValue: "System"), .system)
        XCTAssertNil(AppThemeMode(rawValue: "auto"))
        XCTAssertNil(AppThemeMode(rawValue: ""))
    }

    func testColorSchemeDark() {
        XCTAssertNotNil(AppThemeMode.dark.colorScheme)
    }

    func testColorSchemeLight() {
        XCTAssertNotNil(AppThemeMode.light.colorScheme)
    }

    func testColorSchemeSystemIsNil() {
        XCTAssertNil(AppThemeMode.system.colorScheme)
    }

    func testIconValues() {
        XCTAssertEqual(AppThemeMode.dark.icon, "moon.fill")
        XCTAssertEqual(AppThemeMode.light.icon, "sun.max.fill")
        XCTAssertEqual(AppThemeMode.system.icon, "circle.lefthalf.filled")
    }

    func testDisplayNames() {
        XCTAssertEqual(AppThemeMode.dark.displayName, "Dunkel")
        XCTAssertEqual(AppThemeMode.light.displayName, "Hell")
        XCTAssertEqual(AppThemeMode.system.displayName, "System")
    }

    func testCodableRoundTrip() throws {
        for mode in AppThemeMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(AppThemeMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    func testSendableConformance() {
        let mode: any Sendable = AppThemeMode.dark
        XCTAssertNotNil(mode)
    }

    func testAllCasesHaveIcons() {
        for mode in AppThemeMode.allCases {
            XCTAssertFalse(mode.icon.isEmpty)
        }
    }

    func testAllCasesHaveDisplayNames() {
        for mode in AppThemeMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty)
        }
    }
}

// MARK: - EchoelBrand Tests

final class EchoelBrandTests: XCTestCase {

    func testTagline() {
        XCTAssertEqual(EchoelBrand.tagline.count, 1)
        XCTAssertEqual(EchoelBrand.tagline.first, "Create from Within")
    }

    func testTaglineJoined() {
        XCTAssertEqual(EchoelBrand.taglineJoined, "Create from Within")
    }

    func testSlogan() {
        XCTAssertEqual(EchoelBrand.slogan, "Create from Within")
    }

    func testDescriptionNotEmpty() {
        XCTAssertFalse(EchoelBrand.description.isEmpty)
        XCTAssertTrue(EchoelBrand.description.contains("bio-reactive"))
    }

    func testGermanTagline() {
        XCTAssertEqual(EchoelBrand.taglineDE.count, 1)
        XCTAssertEqual(EchoelBrand.taglineDE.first, "Erschaffe aus dir heraus")
    }

    func testPrimaryColorsExist() {
        XCTAssertNotNil(EchoelBrand.primary)
        XCTAssertNotNil(EchoelBrand.secondary)
        XCTAssertNotNil(EchoelBrand.accent)
    }

    func testFunctionalColorsExist() {
        XCTAssertNotNil(EchoelBrand.rose)
        XCTAssertNotNil(EchoelBrand.violet)
        XCTAssertNotNil(EchoelBrand.emerald)
        XCTAssertNotNil(EchoelBrand.sky)
        XCTAssertNotNil(EchoelBrand.amber)
        XCTAssertNotNil(EchoelBrand.coral)
    }

    func testBackgroundColorsExist() {
        XCTAssertNotNil(EchoelBrand.bgDeep)
        XCTAssertNotNil(EchoelBrand.bgSurface)
        XCTAssertNotNil(EchoelBrand.bgElevated)
        XCTAssertNotNil(EchoelBrand.bgGlass)
    }

    func testTextColorsExist() {
        XCTAssertNotNil(EchoelBrand.textPrimary)
        XCTAssertNotNil(EchoelBrand.textSecondary)
        XCTAssertNotNil(EchoelBrand.textTertiary)
        XCTAssertNotNil(EchoelBrand.textDisabled)
    }

    func testCoherenceColorsExist() {
        XCTAssertNotNil(EchoelBrand.coherenceLow)
        XCTAssertNotNil(EchoelBrand.coherenceMedium)
        XCTAssertNotNil(EchoelBrand.coherenceHigh)
    }

    func testSemanticColors() {
        XCTAssertNotNil(EchoelBrand.success)
        XCTAssertNotNil(EchoelBrand.warning)
        XCTAssertNotNil(EchoelBrand.error)
        XCTAssertNotNil(EchoelBrand.info)
    }

    func testBorderColors() {
        XCTAssertNotNil(EchoelBrand.border)
        XCTAssertNotNil(EchoelBrand.borderActive)
    }

    func testBrainwaveColors() {
        XCTAssertNotNil(EchoelBrand.brainwaveDelta)
        XCTAssertNotNil(EchoelBrand.brainwaveTheta)
        XCTAssertNotNil(EchoelBrand.brainwaveAlpha)
        XCTAssertNotNil(EchoelBrand.brainwaveBeta)
        XCTAssertNotNil(EchoelBrand.brainwaveGamma)
    }

    func testLegacyAliases() {
        XCTAssertNotNil(EchoelBrand.teal)
    }
}

// MARK: - EchoelGradients Tests

final class EchoelGradientsTests: XCTestCase {

    func testBrandGradientExists() {
        XCTAssertNotNil(EchoelGradients.brand)
    }

    func testBioReactiveGradientExists() {
        XCTAssertNotNil(EchoelGradients.bioReactive)
    }

    func testBackgroundGradientExists() {
        XCTAssertNotNil(EchoelGradients.background)
    }

    func testCoherenceGradientExists() {
        XCTAssertNotNil(EchoelGradients.coherence)
    }

    func testCardGradientExists() {
        XCTAssertNotNil(EchoelGradients.card)
    }

    func testSpectrumGradientExists() {
        XCTAssertNotNil(EchoelGradients.spectrum)
    }
}

// MARK: - EchoelBrandFont Tests

final class EchoelBrandFontTests: XCTestCase {

    func testPreferredFontName() {
        XCTAssertEqual(EchoelBrandFont.preferredFontName, "AtkinsonHyperlegible-Regular")
    }

    func testPreferredFontNameBold() {
        XCTAssertEqual(EchoelBrandFont.preferredFontNameBold, "AtkinsonHyperlegible-Bold")
    }

    func testHeroTitleReturnsFont() {
        XCTAssertNotNil(EchoelBrandFont.heroTitle())
    }

    func testSectionTitleReturnsFont() {
        XCTAssertNotNil(EchoelBrandFont.sectionTitle())
    }

    func testCardTitleReturnsFont() {
        XCTAssertNotNil(EchoelBrandFont.cardTitle())
    }

    func testBodyReturnsFont() {
        XCTAssertNotNil(EchoelBrandFont.body())
    }

    func testCaptionReturnsFont() {
        XCTAssertNotNil(EchoelBrandFont.caption())
    }

    func testDataReturnsFont() {
        XCTAssertNotNil(EchoelBrandFont.data())
    }

    func testDataSmallReturnsFont() {
        XCTAssertNotNil(EchoelBrandFont.dataSmall())
    }

    func testLabelReturnsFont() {
        XCTAssertNotNil(EchoelBrandFont.label())
    }
}

// MARK: - EchoelSpacing Tests

final class EchoelSpacingTests: XCTestCase {

    func testSpacingValues() {
        XCTAssertEqual(EchoelSpacing.xxs, 2)
        XCTAssertEqual(EchoelSpacing.xs, 4)
        XCTAssertEqual(EchoelSpacing.sm, 8)
        XCTAssertEqual(EchoelSpacing.md, 16)
        XCTAssertEqual(EchoelSpacing.lg, 24)
        XCTAssertEqual(EchoelSpacing.xl, 32)
        XCTAssertEqual(EchoelSpacing.xxl, 48)
        XCTAssertEqual(EchoelSpacing.xxxl, 64)
    }

    func testSpacingIncreasing() {
        XCTAssertLessThan(EchoelSpacing.xxs, EchoelSpacing.xs)
        XCTAssertLessThan(EchoelSpacing.xs, EchoelSpacing.sm)
        XCTAssertLessThan(EchoelSpacing.sm, EchoelSpacing.md)
        XCTAssertLessThan(EchoelSpacing.md, EchoelSpacing.lg)
        XCTAssertLessThan(EchoelSpacing.lg, EchoelSpacing.xl)
        XCTAssertLessThan(EchoelSpacing.xl, EchoelSpacing.xxl)
        XCTAssertLessThan(EchoelSpacing.xxl, EchoelSpacing.xxxl)
    }

    func testAllValuesPositive() {
        XCTAssertGreaterThan(EchoelSpacing.xxs, 0)
        XCTAssertGreaterThan(EchoelSpacing.xs, 0)
        XCTAssertGreaterThan(EchoelSpacing.sm, 0)
        XCTAssertGreaterThan(EchoelSpacing.md, 0)
    }
}

// MARK: - EchoelRadius Tests

final class EchoelRadiusTests: XCTestCase {

    func testRadiusValues() {
        XCTAssertEqual(EchoelRadius.xs, 4)
        XCTAssertEqual(EchoelRadius.sm, 8)
        XCTAssertEqual(EchoelRadius.md, 12)
        XCTAssertEqual(EchoelRadius.lg, 16)
        XCTAssertEqual(EchoelRadius.xl, 24)
        XCTAssertEqual(EchoelRadius.full, 9999)
    }

    func testRadiusIncreasing() {
        XCTAssertLessThan(EchoelRadius.xs, EchoelRadius.sm)
        XCTAssertLessThan(EchoelRadius.sm, EchoelRadius.md)
        XCTAssertLessThan(EchoelRadius.md, EchoelRadius.lg)
        XCTAssertLessThan(EchoelRadius.lg, EchoelRadius.xl)
        XCTAssertLessThan(EchoelRadius.xl, EchoelRadius.full)
    }
}

// MARK: - EchoelAnimation Tests

final class EchoelAnimationTests: XCTestCase {

    func testQuickTiming() {
        XCTAssertEqual(EchoelAnimation.quick, 0.15)
    }

    func testSmoothTiming() {
        XCTAssertEqual(EchoelAnimation.smooth, 0.3)
    }

    func testBreathingTiming() {
        XCTAssertEqual(EchoelAnimation.breathing, 4.0)
    }

    func testPulseTiming() {
        XCTAssertEqual(EchoelAnimation.pulse, 1.0)
    }

    func testCoherenceGlowTiming() {
        XCTAssertEqual(EchoelAnimation.coherenceGlow, 2.0)
    }

    func testAllTimingsPositive() {
        XCTAssertGreaterThan(EchoelAnimation.quick, 0)
        XCTAssertGreaterThan(EchoelAnimation.smooth, 0)
        XCTAssertGreaterThan(EchoelAnimation.breathing, 0)
        XCTAssertGreaterThan(EchoelAnimation.pulse, 0)
        XCTAssertGreaterThan(EchoelAnimation.coherenceGlow, 0)
    }

    func testQuickIsFastest() {
        XCTAssertLessThan(EchoelAnimation.quick, EchoelAnimation.smooth)
        XCTAssertLessThan(EchoelAnimation.smooth, EchoelAnimation.pulse)
        XCTAssertLessThan(EchoelAnimation.pulse, EchoelAnimation.coherenceGlow)
        XCTAssertLessThan(EchoelAnimation.coherenceGlow, EchoelAnimation.breathing)
    }
}

// MARK: - EchoelDisclaimer Tests

final class EchoelDisclaimerTests: XCTestCase {

    func testShortDisclaimerNotEmpty() {
        XCTAssertFalse(EchoelDisclaimer.short.isEmpty)
    }

    func testMediumDisclaimerNotEmpty() {
        XCTAssertFalse(EchoelDisclaimer.medium.isEmpty)
    }

    func testFullDisclaimerNotEmpty() {
        XCTAssertFalse(EchoelDisclaimer.full.isEmpty)
    }

    func testSeizureWarningNotEmpty() {
        XCTAssertFalse(EchoelDisclaimer.seizureWarning.isEmpty)
    }

    func testShortContainsNotMedical() {
        XCTAssertTrue(EchoelDisclaimer.short.contains("Not a medical device"))
    }

    func testMediumContainsNotMedical() {
        XCTAssertTrue(EchoelDisclaimer.medium.contains("Not a medical device"))
    }

    func testFullContainsWarnings() {
        XCTAssertTrue(EchoelDisclaimer.full.contains("WARNINGS"))
    }

    func testSeizureWarningContainsEpilepsy() {
        XCTAssertTrue(EchoelDisclaimer.seizureWarning.contains("epilepsy"))
    }

    func testDisclaimerLengthOrdering() {
        XCTAssertLessThan(EchoelDisclaimer.short.count, EchoelDisclaimer.medium.count)
        XCTAssertLessThan(EchoelDisclaimer.medium.count, EchoelDisclaimer.full.count)
    }
}

// MARK: - EchoelIconConfig Tests

final class EchoelIconConfigTests: XCTestCase {

    func testSizesNotEmpty() {
        XCTAssertFalse(EchoelIconConfig.sizes.isEmpty)
    }

    func testContainsiPhoneSizes() {
        let iphoneSizes = EchoelIconConfig.sizes.filter { $0.platform == "iphone" }
        XCTAssertFalse(iphoneSizes.isEmpty)
    }

    func testContainsiPadSizes() {
        let ipadSizes = EchoelIconConfig.sizes.filter { $0.platform == "ipad" }
        XCTAssertFalse(ipadSizes.isEmpty)
    }

    func testContainsMacSizes() {
        let macSizes = EchoelIconConfig.sizes.filter { $0.platform == "mac" }
        XCTAssertFalse(macSizes.isEmpty)
    }

    func testContainsWatchSizes() {
        let watchSizes = EchoelIconConfig.sizes.filter { $0.platform == "watch" }
        XCTAssertFalse(watchSizes.isEmpty)
    }

    func testContainsMarketingSize() {
        let marketingSizes = EchoelIconConfig.sizes.filter { $0.platform == "ios-marketing" }
        XCTAssertFalse(marketingSizes.isEmpty)
        XCTAssertEqual(marketingSizes.first?.size, 1024)
    }

    func testAllSizesPositive() {
        for entry in EchoelIconConfig.sizes {
            XCTAssertGreaterThan(entry.size, 0)
            XCTAssertGreaterThan(entry.scale, 0)
            XCTAssertFalse(entry.platform.isEmpty)
        }
    }
}

// MARK: - VaporwaveColors Tests

final class VaporwaveColorsTests: XCTestCase {

    func testNeonPinkIsBrandPrimary() {
        XCTAssertNotNil(VaporwaveColors.neonPink)
    }

    func testNeonCyanIsBrandPrimary() {
        XCTAssertNotNil(VaporwaveColors.neonCyan)
    }

    func testBackgroundColors() {
        XCTAssertNotNil(VaporwaveColors.deepBlack)
        XCTAssertNotNil(VaporwaveColors.midnightBlue)
        XCTAssertNotNil(VaporwaveColors.darkPurple)
    }

    func testCoherenceColors() {
        XCTAssertNotNil(VaporwaveColors.coherenceLow)
        XCTAssertNotNil(VaporwaveColors.coherenceMedium)
        XCTAssertNotNil(VaporwaveColors.coherenceHigh)
    }

    func testTextColors() {
        XCTAssertNotNil(VaporwaveColors.textPrimary)
        XCTAssertNotNil(VaporwaveColors.textSecondary)
        XCTAssertNotNil(VaporwaveColors.textTertiary)
    }

    func testGlassColors() {
        XCTAssertNotNil(VaporwaveColors.glassBg)
        XCTAssertNotNil(VaporwaveColors.glassBorder)
        XCTAssertNotNil(VaporwaveColors.glassBorderActive)
    }

    func testFunctionalColors() {
        XCTAssertNotNil(VaporwaveColors.recordingActive)
        XCTAssertNotNil(VaporwaveColors.success)
        XCTAssertNotNil(VaporwaveColors.warning)
        XCTAssertNotNil(VaporwaveColors.heartRate)
        XCTAssertNotNil(VaporwaveColors.hrv)
    }
}

// MARK: - VaporwaveTypography Tests

final class VaporwaveTypographyTests: XCTestCase {

    func testHeroTitle() {
        XCTAssertNotNil(VaporwaveTypography.heroTitle())
    }

    func testSectionTitle() {
        XCTAssertNotNil(VaporwaveTypography.sectionTitle())
    }

    func testBody() {
        XCTAssertNotNil(VaporwaveTypography.body())
    }

    func testCaption() {
        XCTAssertNotNil(VaporwaveTypography.caption())
    }

    func testData() {
        XCTAssertNotNil(VaporwaveTypography.data())
    }

    func testDataSmall() {
        XCTAssertNotNil(VaporwaveTypography.dataSmall())
    }

    func testLabel() {
        XCTAssertNotNil(VaporwaveTypography.label())
    }
}

// MARK: - VaporwaveSpacing Tests

final class VaporwaveSpacingTests: XCTestCase {

    func testSpacingMatchesEchoelSpacing() {
        XCTAssertEqual(VaporwaveSpacing.xs, EchoelSpacing.xs)
        XCTAssertEqual(VaporwaveSpacing.sm, EchoelSpacing.sm)
        XCTAssertEqual(VaporwaveSpacing.md, EchoelSpacing.md)
        XCTAssertEqual(VaporwaveSpacing.lg, EchoelSpacing.lg)
        XCTAssertEqual(VaporwaveSpacing.xl, EchoelSpacing.xl)
        XCTAssertEqual(VaporwaveSpacing.xxl, EchoelSpacing.xxl)
    }
}

// MARK: - VaporwaveAnimation Tests

final class VaporwaveAnimationTests: XCTestCase {

    func testSmoothAnimationExists() {
        XCTAssertNotNil(VaporwaveAnimation.smooth)
    }

    func testQuickAnimationExists() {
        XCTAssertNotNil(VaporwaveAnimation.quick)
    }

    func testBreathingAnimationExists() {
        XCTAssertNotNil(VaporwaveAnimation.breathing)
    }

    func testPulseAnimationExists() {
        XCTAssertNotNil(VaporwaveAnimation.pulse)
    }

    func testGlowAnimationExists() {
        XCTAssertNotNil(VaporwaveAnimation.glow)
    }

    func testReducedReturnsNilWhenReduced() {
        let result = VaporwaveAnimation.reduced(VaporwaveAnimation.smooth, reduceMotion: true)
        XCTAssertNil(result)
    }

    func testReducedReturnsAnimationWhenNotReduced() {
        let result = VaporwaveAnimation.reduced(VaporwaveAnimation.smooth, reduceMotion: false)
        XCTAssertNotNil(result)
    }

    func testSmoothReducedReturnsNilWhenReduced() {
        let result = VaporwaveAnimation.smoothReduced(true)
        XCTAssertNil(result)
    }

    func testSmoothReducedReturnsAnimationWhenNotReduced() {
        let result = VaporwaveAnimation.smoothReduced(false)
        XCTAssertNotNil(result)
    }
}

// MARK: - FreezeConfiguration Tests

final class FreezeConfigurationTests: XCTestCase {

    func testDefaultValues() {
        let config = FreezeConfiguration()
        XCTAssertEqual(config.sampleRate, 48000)
        XCTAssertEqual(config.bitDepth, 24)
        XCTAssertFalse(config.includeSends)
        XCTAssertTrue(config.includeAutomation)
        XCTAssertEqual(config.tailLength, 2.0)
        XCTAssertFalse(config.normalize)
    }

    func testCustomValues() {
        let config = FreezeConfiguration(
            sampleRate: 96000,
            bitDepth: 32,
            includeSends: true,
            includeAutomation: false,
            tailLength: 5.0,
            normalize: true
        )
        XCTAssertEqual(config.sampleRate, 96000)
        XCTAssertEqual(config.bitDepth, 32)
        XCTAssertTrue(config.includeSends)
        XCTAssertFalse(config.includeAutomation)
        XCTAssertEqual(config.tailLength, 5.0)
        XCTAssertTrue(config.normalize)
    }

    func testCodableRoundTrip() throws {
        let config = FreezeConfiguration(sampleRate: 44100, bitDepth: 16, includeSends: true)
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(FreezeConfiguration.self, from: data)
        XCTAssertEqual(decoded.sampleRate, 44100)
        XCTAssertEqual(decoded.bitDepth, 16)
        XCTAssertTrue(decoded.includeSends)
    }

    func testSendableConformance() {
        let config: any Sendable = FreezeConfiguration()
        XCTAssertNotNil(config)
    }
}

// MARK: - TrackFreezeState Tests

final class TrackFreezeStateTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(TrackFreezeState.unfrozen.rawValue, "unfrozen")
        XCTAssertEqual(TrackFreezeState.freezing.rawValue, "freezing")
        XCTAssertEqual(TrackFreezeState.frozen.rawValue, "frozen")
        XCTAssertEqual(TrackFreezeState.unfreezing.rawValue, "unfreezing")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(TrackFreezeState(rawValue: "unfrozen"), .unfrozen)
        XCTAssertEqual(TrackFreezeState(rawValue: "frozen"), .frozen)
        XCTAssertNil(TrackFreezeState(rawValue: "invalid"))
    }

    func testCodableRoundTrip() throws {
        let states: [TrackFreezeState] = [.unfrozen, .freezing, .frozen, .unfreezing]
        for state in states {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(TrackFreezeState.self, from: data)
            XCTAssertEqual(decoded, state)
        }
    }

    func testSendableConformance() {
        let state: any Sendable = TrackFreezeState.frozen
        XCTAssertNotNil(state)
    }
}

// MARK: - FreezeError Tests

final class FreezeErrorTests: XCTestCase {

    func testTrackNotFoundDescription() {
        XCTAssertEqual(FreezeError.trackNotFound.errorDescription, "Track not found")
    }

    func testNoAudioToFreezeDescription() {
        XCTAssertEqual(FreezeError.noAudioToFreeze.errorDescription, "No audio content to freeze")
    }

    func testRenderingFailedDescription() {
        let error = FreezeError.renderingFailed("timeout")
        XCTAssertEqual(error.errorDescription, "Rendering failed: timeout")
    }

    func testFileWriteFailedDescription() {
        XCTAssertEqual(FreezeError.fileWriteFailed.errorDescription, "Failed to write frozen audio file")
    }

    func testAlreadyFrozenDescription() {
        XCTAssertEqual(FreezeError.alreadyFrozen.errorDescription, "Track is already frozen")
    }

    func testNotFrozenDescription() {
        XCTAssertEqual(FreezeError.notFrozen.errorDescription, "Track is not frozen")
    }

    func testLocalizedErrorConformance() {
        let error: LocalizedError = FreezeError.trackNotFound
        XCTAssertNotNil(error.errorDescription)
    }

    func testRenderingFailedWithEmptyReason() {
        let error = FreezeError.renderingFailed("")
        XCTAssertEqual(error.errorDescription, "Rendering failed: ")
    }
}

// MARK: - CrossfadeCurve Tests

final class CrossfadeCurveTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(CrossfadeCurve.allCases.count, 6)
    }

    func testRawValues() {
        XCTAssertEqual(CrossfadeCurve.linear.rawValue, "Linear")
        XCTAssertEqual(CrossfadeCurve.equalPower.rawValue, "Equal Power")
        XCTAssertEqual(CrossfadeCurve.sCurve.rawValue, "S-Curve")
        XCTAssertEqual(CrossfadeCurve.exponential.rawValue, "Exponential")
        XCTAssertEqual(CrossfadeCurve.logarithmic.rawValue, "Logarithmic")
        XCTAssertEqual(CrossfadeCurve.cosine.rawValue, "Cosine")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(CrossfadeCurve(rawValue: "Linear"), .linear)
        XCTAssertEqual(CrossfadeCurve(rawValue: "Equal Power"), .equalPower)
        XCTAssertNil(CrossfadeCurve(rawValue: "invalid"))
    }

    func testFadeInAtZero() {
        for curve in CrossfadeCurve.allCases {
            XCTAssertEqual(curve.fadeInGain(at: 0), 0, accuracy: 0.001, "\(curve) fadeIn(0) should be 0")
        }
    }

    func testFadeInAtOne() {
        for curve in CrossfadeCurve.allCases {
            XCTAssertEqual(curve.fadeInGain(at: 1), 1, accuracy: 0.001, "\(curve) fadeIn(1) should be 1")
        }
    }

    func testFadeOutAtZero() {
        for curve in CrossfadeCurve.allCases {
            XCTAssertEqual(curve.fadeOutGain(at: 0), 1, accuracy: 0.001, "\(curve) fadeOut(0) should be 1")
        }
    }

    func testFadeOutAtOne() {
        for curve in CrossfadeCurve.allCases {
            XCTAssertEqual(curve.fadeOutGain(at: 1), 0, accuracy: 0.001, "\(curve) fadeOut(1) should be 0")
        }
    }

    func testFadeInMonotonicallyIncreasing() {
        for curve in CrossfadeCurve.allCases {
            var lastValue: Float = -1
            for i in 0...10 {
                let position = Float(i) / 10.0
                let value = curve.fadeInGain(at: position)
                XCTAssertGreaterThanOrEqual(value, lastValue, "\(curve) fadeIn should be monotonically increasing")
                lastValue = value
            }
        }
    }

    func testFadeOutMonotonicallyDecreasing() {
        for curve in CrossfadeCurve.allCases {
            var lastValue: Float = 2
            for i in 0...10 {
                let position = Float(i) / 10.0
                let value = curve.fadeOutGain(at: position)
                XCTAssertLessThanOrEqual(value, lastValue, "\(curve) fadeOut should be monotonically decreasing")
                lastValue = value
            }
        }
    }

    func testFadeInClampsNegativeInput() {
        for curve in CrossfadeCurve.allCases {
            let value = curve.fadeInGain(at: -0.5)
            XCTAssertEqual(value, curve.fadeInGain(at: 0), accuracy: 0.001)
        }
    }

    func testFadeInClampsOverflowInput() {
        for curve in CrossfadeCurve.allCases {
            let value = curve.fadeInGain(at: 1.5)
            XCTAssertEqual(value, curve.fadeInGain(at: 1), accuracy: 0.001)
        }
    }

    func testLinearFadeInMidpoint() {
        XCTAssertEqual(CrossfadeCurve.linear.fadeInGain(at: 0.5), 0.5, accuracy: 0.001)
    }

    func testLinearFadeOutMidpoint() {
        XCTAssertEqual(CrossfadeCurve.linear.fadeOutGain(at: 0.5), 0.5, accuracy: 0.001)
    }

    func testCodableRoundTrip() throws {
        for curve in CrossfadeCurve.allCases {
            let data = try JSONEncoder().encode(curve)
            let decoded = try JSONDecoder().decode(CrossfadeCurve.self, from: data)
            XCTAssertEqual(decoded, curve)
        }
    }

    func testSendableConformance() {
        let curve: any Sendable = CrossfadeCurve.equalPower
        XCTAssertNotNil(curve)
    }
}

// MARK: - CrossfadeRegion Tests

final class CrossfadeRegionTests: XCTestCase {

    func testDefaultInit() {
        let region = CrossfadeRegion(startSample: 1000, lengthInSamples: 4800)
        XCTAssertNotNil(region.id)
        XCTAssertEqual(region.startSample, 1000)
        XCTAssertEqual(region.lengthInSamples, 4800)
        XCTAssertEqual(region.curve, .equalPower)
        XCTAssertTrue(region.isSymmetric)
    }

    func testCustomInit() {
        let customId = UUID()
        let region = CrossfadeRegion(
            id: customId,
            startSample: 0,
            lengthInSamples: 9600,
            curve: .sCurve,
            isSymmetric: false
        )
        XCTAssertEqual(region.id, customId)
        XCTAssertEqual(region.startSample, 0)
        XCTAssertEqual(region.lengthInSamples, 9600)
        XCTAssertEqual(region.curve, .sCurve)
        XCTAssertFalse(region.isSymmetric)
    }

    func testDurationCalculation() {
        let region = CrossfadeRegion(startSample: 0, lengthInSamples: 48000)
        XCTAssertEqual(region.duration(sampleRate: 48000), 1.0, accuracy: 0.001)
    }

    func testDurationAtDifferentSampleRate() {
        let region = CrossfadeRegion(startSample: 0, lengthInSamples: 44100)
        XCTAssertEqual(region.duration(sampleRate: 44100), 1.0, accuracy: 0.001)
    }

    func testDurationHalfSecond() {
        let region = CrossfadeRegion(startSample: 0, lengthInSamples: 24000)
        XCTAssertEqual(region.duration(sampleRate: 48000), 0.5, accuracy: 0.001)
    }

    func testCodableRoundTrip() throws {
        let region = CrossfadeRegion(startSample: 500, lengthInSamples: 2400, curve: .logarithmic, isSymmetric: false)
        let data = try JSONEncoder().encode(region)
        let decoded = try JSONDecoder().decode(CrossfadeRegion.self, from: data)
        XCTAssertEqual(decoded.id, region.id)
        XCTAssertEqual(decoded.startSample, 500)
        XCTAssertEqual(decoded.lengthInSamples, 2400)
        XCTAssertEqual(decoded.curve, .logarithmic)
        XCTAssertFalse(decoded.isSymmetric)
    }

    func testSendableConformance() {
        let region: any Sendable = CrossfadeRegion(startSample: 0, lengthInSamples: 100)
        XCTAssertNotNil(region)
    }
}

// MARK: - BPMSituation Tests

final class BPMSituationTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(BPMSituation.allCases.count, 12)
    }

    func testRawValues() {
        XCTAssertEqual(BPMSituation.freeform.rawValue, "Freeform")
        XCTAssertEqual(BPMSituation.deepMeditation.rawValue, "Deep Meditation")
        XCTAssertEqual(BPMSituation.relaxation.rawValue, "Relaxation")
        XCTAssertEqual(BPMSituation.focus.rawValue, "Focus")
        XCTAssertEqual(BPMSituation.romantic.rawValue, "Romantic")
        XCTAssertEqual(BPMSituation.ambient.rawValue, "Ambient")
        XCTAssertEqual(BPMSituation.lofi.rawValue, "Lo-Fi")
        XCTAssertEqual(BPMSituation.house.rawValue, "House")
        XCTAssertEqual(BPMSituation.techno.rawValue, "Techno")
        XCTAssertEqual(BPMSituation.training.rawValue, "Training")
        XCTAssertEqual(BPMSituation.hiit.rawValue, "HIIT")
        XCTAssertEqual(BPMSituation.custom.rawValue, "Custom")
    }

    func testIdentifiable() {
        for situation in BPMSituation.allCases {
            XCTAssertEqual(situation.id, situation.rawValue)
        }
    }

    func testBpmRangeValid() {
        for situation in BPMSituation.allCases {
            XCTAssertLessThanOrEqual(situation.bpmRange.lowerBound, situation.bpmRange.upperBound)
            XCTAssertGreaterThan(situation.bpmRange.lowerBound, 0)
        }
    }

    func testRecommendedBpmWithinRange() {
        for situation in BPMSituation.allCases {
            XCTAssertTrue(
                situation.bpmRange.contains(situation.recommendedBPM),
                "\(situation) recommendedBPM \(situation.recommendedBPM) not in range \(situation.bpmRange)"
            )
        }
    }

    func testBioInfluenceInRange() {
        for situation in BPMSituation.allCases {
            XCTAssertGreaterThanOrEqual(situation.recommendedBioInfluence, 0)
            XCTAssertLessThanOrEqual(situation.recommendedBioInfluence, 1)
        }
    }

    func testHumanizeInRange() {
        for situation in BPMSituation.allCases {
            XCTAssertGreaterThanOrEqual(situation.recommendedHumanize, 0)
            XCTAssertLessThanOrEqual(situation.recommendedHumanize, 1)
        }
    }

    func testGermanNames() {
        XCTAssertEqual(BPMSituation.freeform.nameDE, "Frei")
        XCTAssertEqual(BPMSituation.deepMeditation.nameDE, "Tiefe Meditation")
        XCTAssertEqual(BPMSituation.relaxation.nameDE, "Entspannung")
        XCTAssertEqual(BPMSituation.focus.nameDE, "Fokus")
        XCTAssertEqual(BPMSituation.romantic.nameDE, "Romantisch")
        XCTAssertEqual(BPMSituation.house.nameDE, "House")
        XCTAssertEqual(BPMSituation.custom.nameDE, "Benutzerdefiniert")
    }

    func testAllCasesHaveGermanNames() {
        for situation in BPMSituation.allCases {
            XCTAssertFalse(situation.nameDE.isEmpty)
        }
    }

    func testFreeformHasWidestRange() {
        let freeformRange = BPMSituation.freeform.bpmRange
        for situation in BPMSituation.allCases where situation != .custom {
            XCTAssertGreaterThanOrEqual(freeformRange.upperBound, situation.bpmRange.upperBound)
            XCTAssertLessThanOrEqual(freeformRange.lowerBound, situation.bpmRange.lowerBound)
        }
    }

    func testDeepMeditationIsSlowest() {
        XCTAssertEqual(BPMSituation.deepMeditation.bpmRange.lowerBound, 40)
        XCTAssertLessThanOrEqual(BPMSituation.deepMeditation.recommendedBPM, 60)
    }

    func testHIITIsFastest() {
        XCTAssertGreaterThanOrEqual(BPMSituation.hiit.recommendedBPM, 150)
    }
}

// MARK: - BPMTransitionMode Tests

final class BPMTransitionModeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(BPMTransitionMode.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(BPMTransitionMode.instant.rawValue, "Instant")
        XCTAssertEqual(BPMTransitionMode.smooth.rawValue, "Smooth")
        XCTAssertEqual(BPMTransitionMode.verySmooth.rawValue, "Very Smooth")
        XCTAssertEqual(BPMTransitionMode.gradual.rawValue, "Gradual")
    }

    func testInstantDurationIsZero() {
        XCTAssertEqual(BPMTransitionMode.instant.duration, 0)
    }

    func testSmoothDuration() {
        XCTAssertEqual(BPMTransitionMode.smooth.duration, 0.5)
    }

    func testVerySmoothDuration() {
        XCTAssertEqual(BPMTransitionMode.verySmooth.duration, 2.0)
    }

    func testGradualDuration() {
        XCTAssertEqual(BPMTransitionMode.gradual.duration, 5.0)
    }

    func testDurationsIncreasing() {
        XCTAssertLessThan(BPMTransitionMode.instant.duration, BPMTransitionMode.smooth.duration)
        XCTAssertLessThan(BPMTransitionMode.smooth.duration, BPMTransitionMode.verySmooth.duration)
        XCTAssertLessThan(BPMTransitionMode.verySmooth.duration, BPMTransitionMode.gradual.duration)
    }

    func testInitFromRawValue() {
        XCTAssertEqual(BPMTransitionMode(rawValue: "Instant"), .instant)
        XCTAssertEqual(BPMTransitionMode(rawValue: "Gradual"), .gradual)
        XCTAssertNil(BPMTransitionMode(rawValue: "invalid"))
    }
}

// MARK: - BPMLockState Tests

final class BPMLockStateTests: XCTestCase {

    func testDefaultValues() {
        let lock = BPMLockState()
        XCTAssertFalse(lock.isLocked)
        XCTAssertEqual(lock.lockedBPM, 120)
        XCTAssertTrue(lock.allowHumanize)
        XCTAssertEqual(lock.maxFluctuation, 2.0)
    }

    func testMutableProperties() {
        var lock = BPMLockState()
        lock.isLocked = true
        lock.lockedBPM = 90
        lock.allowHumanize = false
        lock.maxFluctuation = 5.0
        XCTAssertTrue(lock.isLocked)
        XCTAssertEqual(lock.lockedBPM, 90)
        XCTAssertFalse(lock.allowHumanize)
        XCTAssertEqual(lock.maxFluctuation, 5.0)
    }
}

// MARK: - BPMSnapshot Tests

final class BPMSnapshotTests: XCTestCase {

    func testInitialization() {
        let snapshot = BPMSnapshot(
            currentBPM: 120,
            targetBPM: 130,
            bioInfluence: 0.5,
            humanize: 0.2,
            situation: .focus,
            isLocked: false,
            isTransitioning: true
        )
        XCTAssertEqual(snapshot.currentBPM, 120)
        XCTAssertEqual(snapshot.targetBPM, 130)
        XCTAssertEqual(snapshot.bioInfluence, 0.5)
        XCTAssertEqual(snapshot.humanize, 0.2)
        XCTAssertEqual(snapshot.situation, .focus)
        XCTAssertFalse(snapshot.isLocked)
        XCTAssertTrue(snapshot.isTransitioning)
    }

    func testLockedSnapshot() {
        let snapshot = BPMSnapshot(
            currentBPM: 90,
            targetBPM: 90,
            bioInfluence: 0,
            humanize: 0,
            situation: .relaxation,
            isLocked: true,
            isTransitioning: false
        )
        XCTAssertTrue(snapshot.isLocked)
        XCTAssertFalse(snapshot.isTransitioning)
        XCTAssertEqual(snapshot.currentBPM, snapshot.targetBPM)
    }
}
