//
//  VaporWaveThemeTests.swift
//  EchoelmusicTests
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Unit tests for VaporWave theme system
//

import XCTest
import SwiftUI
@testable import Echoelmusic

@MainActor
final class VaporWaveThemeTests: XCTestCase {

    var theme: VaporWaveThemeManager!

    override func setUp() async throws {
        try await super.setUp()
        theme = VaporWaveThemeManager.shared
        theme.isEnabled = true
        theme.intensity = 0.75
    }

    override func tearDown() async throws {
        theme = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testThemeInitialization() {
        XCTAssertNotNil(theme, "Theme manager should initialize")
        XCTAssertTrue(theme.isEnabled, "Theme should be enabled by default")
        XCTAssertEqual(theme.intensity, 0.75, "Default intensity should be 0.75")
    }

    // MARK: - Color Tests

    func testNeonColors() {
        // Test neon cyan
        let cyan = theme.neonCyan
        XCTAssertNotNil(cyan, "Neon cyan should be created")

        // Test neon magenta
        let magenta = theme.neonMagenta
        XCTAssertNotNil(magenta, "Neon magenta should be created")

        // Test neon purple
        let purple = theme.neonPurple
        XCTAssertNotNil(purple, "Neon purple should be created")

        // Test neon pink
        let pink = theme.neonPink
        XCTAssertNotNil(pink, "Neon pink should be created")

        // Test sunset orange
        let orange = theme.sunsetOrange
        XCTAssertNotNil(orange, "Sunset orange should be created")

        // Test electric blue
        let blue = theme.electricBlue
        XCTAssertNotNil(blue, "Electric blue should be created")
    }

    func testGradients() {
        // Test sunset gradient
        let sunsetGradient = theme.sunsetGradient
        XCTAssertNotNil(sunsetGradient, "Sunset gradient should be created")

        // Test grid gradient
        let gridGradient = theme.gridGradient
        XCTAssertNotNil(gridGradient, "Grid gradient should be created")

        // Test chrome gradient
        let chromeGradient = theme.chromeGradient
        XCTAssertNotNil(chromeGradient, "Chrome gradient should be created")
    }

    // MARK: - Intensity Tests

    func testIntensityLevels() {
        // Test 0% intensity (off)
        theme.intensity = 0.0
        XCTAssertFalse(theme.shouldShowGrid, "Grid should not show at 0% intensity")
        XCTAssertFalse(theme.shouldEnableGlitchEffects, "Glitch should not show at 0% intensity")

        // Test 25% intensity (subtle)
        theme.intensity = 0.25
        XCTAssertFalse(theme.shouldShowGrid, "Grid should not show at 25% intensity")
        XCTAssertFalse(theme.shouldEnableGlitchEffects, "Glitch should not show at 25% intensity")

        // Test 50% intensity (moderate)
        theme.intensity = 0.5
        XCTAssertTrue(theme.shouldShowGrid, "Grid should show at 50% intensity")
        XCTAssertFalse(theme.shouldEnableGlitchEffects, "Glitch should not show at 50% intensity")

        // Test 75% intensity (strong)
        theme.intensity = 0.75
        XCTAssertTrue(theme.shouldShowGrid, "Grid should show at 75% intensity")
        XCTAssertTrue(theme.shouldEnableGlitchEffects, "Glitch should show at 75% intensity")
        XCTAssertFalse(theme.shouldEnableScanLines, "Scan lines should not show at 75% intensity")

        // Test 100% intensity (maximum)
        theme.intensity = 1.0
        XCTAssertTrue(theme.shouldShowGrid, "Grid should show at 100% intensity")
        XCTAssertTrue(theme.shouldEnableGlitchEffects, "Glitch should show at 100% intensity")
        XCTAssertTrue(theme.shouldEnableScanLines, "Scan lines should show at 100% intensity")
        XCTAssertTrue(theme.shouldEnableChromaticAberration, "Chromatic aberration should show at 100% intensity")
    }

    func testIntensityWithDisabledTheme() {
        theme.isEnabled = false
        theme.intensity = 1.0

        XCTAssertFalse(theme.shouldShowGrid, "Grid should not show when theme is disabled")
        XCTAssertFalse(theme.shouldEnableGlitchEffects, "Glitch should not show when theme is disabled")
        XCTAssertFalse(theme.shouldEnableScanLines, "Scan lines should not show when theme is disabled")
    }

    // MARK: - Bio-Reactive Tests

    func testBioReactiveIntensity() {
        // Test low coherence
        theme.updateBioReactiveIntensity(coherence: 0.2)
        XCTAssertEqual(theme.bioReactiveIntensity, 0.2, "Bio-reactive intensity should match coherence")

        // Test high coherence
        theme.updateBioReactiveIntensity(coherence: 0.9)
        XCTAssertEqual(theme.bioReactiveIntensity, 0.9, "Bio-reactive intensity should match coherence")

        // Test maximum coherence
        theme.updateBioReactiveIntensity(coherence: 1.0)
        XCTAssertEqual(theme.bioReactiveIntensity, 1.0, "Bio-reactive intensity should match maximum coherence")
    }

    // MARK: - Preset Tests

    func testOffPreset() {
        theme.applyPreset(.off)

        XCTAssertFalse(theme.isEnabled, "Theme should be disabled")
        XCTAssertEqual(theme.intensity, 0.0, "Intensity should be 0")
        XCTAssertFalse(theme.showGrid, "Grid should be disabled")
        XCTAssertFalse(theme.enableGlitchEffects, "Glitch should be disabled")
        XCTAssertFalse(theme.enableScanLines, "Scan lines should be disabled")
        XCTAssertFalse(theme.enableChromaticAberration, "Chromatic aberration should be disabled")
    }

    func testSubtlePreset() {
        theme.applyPreset(.subtle)

        XCTAssertTrue(theme.isEnabled, "Theme should be enabled")
        XCTAssertEqual(theme.intensity, 0.25, "Intensity should be 25%")
        XCTAssertFalse(theme.showGrid, "Grid should be disabled")
        XCTAssertFalse(theme.enableGlitchEffects, "Glitch should be disabled")
        XCTAssertFalse(theme.enableScanLines, "Scan lines should be disabled")
    }

    func testModeratePreset() {
        theme.applyPreset(.moderate)

        XCTAssertTrue(theme.isEnabled, "Theme should be enabled")
        XCTAssertEqual(theme.intensity, 0.5, "Intensity should be 50%")
        XCTAssertTrue(theme.showGrid, "Grid should be enabled")
        XCTAssertFalse(theme.enableGlitchEffects, "Glitch should be disabled")
        XCTAssertFalse(theme.enableScanLines, "Scan lines should be disabled")
    }

    func testStrongPreset() {
        theme.applyPreset(.strong)

        XCTAssertTrue(theme.isEnabled, "Theme should be enabled")
        XCTAssertEqual(theme.intensity, 0.75, "Intensity should be 75%")
        XCTAssertTrue(theme.showGrid, "Grid should be enabled")
        XCTAssertTrue(theme.enableGlitchEffects, "Glitch should be enabled")
        XCTAssertFalse(theme.enableScanLines, "Scan lines should be disabled")
    }

    func testMaximumPreset() {
        theme.applyPreset(.maximum)

        XCTAssertTrue(theme.isEnabled, "Theme should be enabled")
        XCTAssertEqual(theme.intensity, 1.0, "Intensity should be 100%")
        XCTAssertTrue(theme.showGrid, "Grid should be enabled")
        XCTAssertTrue(theme.enableGlitchEffects, "Glitch should be enabled")
        XCTAssertTrue(theme.enableScanLines, "Scan lines should be enabled")
        XCTAssertTrue(theme.enableChromaticAberration, "Chromatic aberration should be enabled")
    }

    // MARK: - Settings Persistence Tests

    func testSettingsPersistence() {
        // Set custom values
        theme.intensity = 0.6
        theme.isEnabled = true
        theme.showGrid = true
        theme.enableGlitchEffects = false

        // Save settings
        theme.saveSettings()

        // Verify saved to UserDefaults
        let savedIntensity = UserDefaults.standard.double(forKey: "vaporwave_intensity")
        let savedEnabled = UserDefaults.standard.bool(forKey: "vaporwave_enabled")
        let savedGrid = UserDefaults.standard.bool(forKey: "vaporwave_show_grid")
        let savedGlitch = UserDefaults.standard.bool(forKey: "vaporwave_glitch_effects")

        XCTAssertEqual(savedIntensity, 0.6, "Intensity should be saved")
        XCTAssertTrue(savedEnabled, "Enabled state should be saved")
        XCTAssertTrue(savedGrid, "Grid state should be saved")
        XCTAssertFalse(savedGlitch, "Glitch state should be saved")

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "vaporwave_intensity")
        UserDefaults.standard.removeObject(forKey: "vaporwave_enabled")
        UserDefaults.standard.removeObject(forKey: "vaporwave_show_grid")
        UserDefaults.standard.removeObject(forKey: "vaporwave_glitch_effects")
    }

    // MARK: - Effect Threshold Tests

    func testGridThreshold() {
        theme.showGrid = true

        // Below threshold
        theme.intensity = 0.49
        XCTAssertFalse(theme.shouldShowGrid, "Grid should not show below 50% threshold")

        // At threshold
        theme.intensity = 0.5
        XCTAssertTrue(theme.shouldShowGrid, "Grid should show at 50% threshold")

        // Above threshold
        theme.intensity = 0.75
        XCTAssertTrue(theme.shouldShowGrid, "Grid should show above 50% threshold")
    }

    func testGlitchThreshold() {
        theme.enableGlitchEffects = true

        // Below threshold
        theme.intensity = 0.74
        XCTAssertFalse(theme.shouldEnableGlitchEffects, "Glitch should not show below 75% threshold")

        // At threshold
        theme.intensity = 0.75
        XCTAssertTrue(theme.shouldEnableGlitchEffects, "Glitch should show at 75% threshold")

        // Above threshold
        theme.intensity = 1.0
        XCTAssertTrue(theme.shouldEnableGlitchEffects, "Glitch should show above 75% threshold")
    }

    func testScanLinesThreshold() {
        theme.enableScanLines = true

        // Below threshold
        theme.intensity = 0.89
        XCTAssertFalse(theme.shouldEnableScanLines, "Scan lines should not show below 90% threshold")

        // At threshold
        theme.intensity = 0.9
        XCTAssertTrue(theme.shouldEnableScanLines, "Scan lines should show at 90% threshold")

        // Maximum
        theme.intensity = 1.0
        XCTAssertTrue(theme.shouldEnableScanLines, "Scan lines should show at 100%")
    }

    // MARK: - Performance Tests

    func testColorCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = theme.neonCyan
                _ = theme.neonMagenta
                _ = theme.neonPurple
                _ = theme.neonPink
            }
        }
    }

    func testGradientCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = theme.sunsetGradient
                _ = theme.gridGradient
                _ = theme.chromeGradient
            }
        }
    }

    func testPresetApplicationPerformance() {
        measure {
            for _ in 0..<100 {
                theme.applyPreset(.subtle)
                theme.applyPreset(.moderate)
                theme.applyPreset(.strong)
                theme.applyPreset(.maximum)
                theme.applyPreset(.off)
            }
        }
    }

    // MARK: - Edge Case Tests

    func testNegativeIntensity() {
        theme.intensity = -0.5
        // Should still function without crashing
        XCTAssertNotNil(theme.neonCyan, "Should handle negative intensity gracefully")
    }

    func testExcessiveIntensity() {
        theme.intensity = 5.0
        // Should still function without crashing
        XCTAssertNotNil(theme.neonCyan, "Should handle excessive intensity gracefully")
    }

    func testRapidIntensityChanges() {
        for i in 0..<100 {
            theme.intensity = Double(i) / 100.0
        }
        // Should handle rapid changes without crashing
        XCTAssertNotNil(theme, "Should handle rapid intensity changes")
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentAccess() async {
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { @MainActor in
                    _ = self.theme.neonCyan
                    _ = self.theme.shouldShowGrid
                    _ = self.theme.sunsetGradient
                    self.theme.intensity = Double.random(in: 0...1)
                }
            }
        }

        // Should not crash with concurrent access
        XCTAssertNotNil(theme, "Theme should still be valid after concurrent access")
    }
}
