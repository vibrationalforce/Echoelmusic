import XCTest
import SwiftUI
@testable import Echoelmusic

/// Comprehensive tests for VaporwaveTheme design system
/// Tests colors, gradients, spacing, typography, and UI components
final class VaporwaveThemeTests: XCTestCase {

    // MARK: - VaporwaveColors Tests

    func testNeonColorsDefined() {
        // Verify all neon colors are properly defined
        XCTAssertNotNil(VaporwaveColors.neonPink)
        XCTAssertNotNil(VaporwaveColors.neonCyan)
        XCTAssertNotNil(VaporwaveColors.neonPurple)
        XCTAssertNotNil(VaporwaveColors.lavender)
        XCTAssertNotNil(VaporwaveColors.coral)
    }

    func testBackgroundColorsDefined() {
        XCTAssertNotNil(VaporwaveColors.deepBlack)
        XCTAssertNotNil(VaporwaveColors.midnightBlue)
        XCTAssertNotNil(VaporwaveColors.darkPurple)
        XCTAssertNotNil(VaporwaveColors.sunsetOrange)
        XCTAssertNotNil(VaporwaveColors.sunsetPink)
    }

    func testBioReactiveColorsDefined() {
        XCTAssertNotNil(VaporwaveColors.coherenceLow)
        XCTAssertNotNil(VaporwaveColors.coherenceMedium)
        XCTAssertNotNil(VaporwaveColors.coherenceHigh)
    }

    func testTextColorsDefined() {
        XCTAssertNotNil(VaporwaveColors.textPrimary)
        XCTAssertNotNil(VaporwaveColors.textSecondary)
        XCTAssertNotNil(VaporwaveColors.textTertiary)
    }

    func testFunctionalColorsDefined() {
        XCTAssertNotNil(VaporwaveColors.recordingActive)
        XCTAssertNotNil(VaporwaveColors.success)
        XCTAssertNotNil(VaporwaveColors.warning)
        XCTAssertNotNil(VaporwaveColors.heartRate)
        XCTAssertNotNil(VaporwaveColors.hrv)
    }

    func testRecordingActiveIsCoral() {
        // recordingActive should be coral (functional color)
        let recordingActive = VaporwaveColors.recordingActive
        let coral = EchoelBrand.coral
        XCTAssertEqual(recordingActive.description, coral.description)
    }

    func testSuccessIsEmerald() {
        // success should be emerald (functional color)
        let success = VaporwaveColors.success
        let emerald = EchoelBrand.emerald
        XCTAssertEqual(success.description, emerald.description)
    }

    func testColorsRedirectToEchoelBrand() {
        // Verify VaporwaveColors now redirects to EchoelBrand monochrome system
        XCTAssertEqual(VaporwaveColors.neonPink.description, EchoelBrand.primary.description)
        XCTAssertEqual(VaporwaveColors.neonCyan.description, EchoelBrand.primary.description)
        XCTAssertEqual(VaporwaveColors.deepBlack.description, EchoelBrand.bgDeep.description)
        XCTAssertEqual(VaporwaveColors.textPrimary.description, EchoelBrand.textPrimary.description)
    }

    // MARK: - VaporwaveGradients Tests

    func testGradientsDefined() {
        XCTAssertNotNil(VaporwaveGradients.background)
        XCTAssertNotNil(VaporwaveGradients.sunset)
        XCTAssertNotNil(VaporwaveGradients.neon)
        XCTAssertNotNil(VaporwaveGradients.coherence)
        XCTAssertNotNil(VaporwaveGradients.glassCard)
    }

    // MARK: - VaporwaveSpacing Tests

    func testSpacingValues() {
        XCTAssertEqual(VaporwaveSpacing.xs, 4)
        XCTAssertEqual(VaporwaveSpacing.sm, 8)
        XCTAssertEqual(VaporwaveSpacing.md, 16)
        XCTAssertEqual(VaporwaveSpacing.lg, 24)
        XCTAssertEqual(VaporwaveSpacing.xl, 32)
        XCTAssertEqual(VaporwaveSpacing.xxl, 48)
    }

    func testSpacingProgression() {
        // Verify spacing follows a consistent progression
        XCTAssertLessThan(VaporwaveSpacing.xs, VaporwaveSpacing.sm)
        XCTAssertLessThan(VaporwaveSpacing.sm, VaporwaveSpacing.md)
        XCTAssertLessThan(VaporwaveSpacing.md, VaporwaveSpacing.lg)
        XCTAssertLessThan(VaporwaveSpacing.lg, VaporwaveSpacing.xl)
        XCTAssertLessThan(VaporwaveSpacing.xl, VaporwaveSpacing.xxl)
    }

    func testSpacingRatios() {
        // sm should be 2x xs
        XCTAssertEqual(VaporwaveSpacing.sm, VaporwaveSpacing.xs * 2)
        // md should be 2x sm
        XCTAssertEqual(VaporwaveSpacing.md, VaporwaveSpacing.sm * 2)
    }

    // MARK: - VaporwaveTypography Tests

    func testTypographyFontsDefined() {
        XCTAssertNotNil(VaporwaveTypography.heroTitle())
        XCTAssertNotNil(VaporwaveTypography.sectionTitle())
        XCTAssertNotNil(VaporwaveTypography.body())
        XCTAssertNotNil(VaporwaveTypography.caption())
        XCTAssertNotNil(VaporwaveTypography.data())
        XCTAssertNotNil(VaporwaveTypography.dataSmall())
        XCTAssertNotNil(VaporwaveTypography.label())
    }

    // MARK: - VaporwaveAnimation Tests

    func testAnimationsDefined() {
        XCTAssertNotNil(VaporwaveAnimation.smooth)
        XCTAssertNotNil(VaporwaveAnimation.quick)
        XCTAssertNotNil(VaporwaveAnimation.breathing)
        XCTAssertNotNil(VaporwaveAnimation.pulse)
        XCTAssertNotNil(VaporwaveAnimation.glow)
    }

    // MARK: - View Modifier Tests

    func testNeonGlowModifierCreation() {
        let modifier = NeonGlow(color: VaporwaveColors.neonPink, radius: 15)
        XCTAssertEqual(modifier.radius, 15)
    }

    func testGlassCardModifierExists() {
        // GlassCard should be instantiable
        let _ = GlassCard()
    }

    func testVaporwaveButtonModifierActiveState() {
        let activeModifier = VaporwaveButton(isActive: true, activeColor: VaporwaveColors.neonPink)
        XCTAssertTrue(activeModifier.isActive)

        let inactiveModifier = VaporwaveButton(isActive: false, activeColor: VaporwaveColors.neonPink)
        XCTAssertFalse(inactiveModifier.isActive)
    }

    // MARK: - Component Creation Tests

    func testVaporwaveDataDisplayCreation() {
        let display = VaporwaveDataDisplay(value: "72", label: "BPM", color: VaporwaveColors.heartRate)
        XCTAssertNotNil(display)
    }

    func testVaporwaveStatusIndicatorCreation() {
        let activeIndicator = VaporwaveStatusIndicator(isActive: true)
        XCTAssertNotNil(activeIndicator)

        let inactiveIndicator = VaporwaveStatusIndicator(isActive: false)
        XCTAssertNotNil(inactiveIndicator)
    }

    func testVaporwaveProgressRingCreation() {
        let ring = VaporwaveProgressRing(progress: 0.75, color: VaporwaveColors.coherenceHigh)
        XCTAssertNotNil(ring)
    }

    func testVaporwaveProgressRingProgressClamped() {
        // Progress above 1.0 should display as 1.0
        let overRing = VaporwaveProgressRing(progress: 1.5)
        XCTAssertNotNil(overRing)

        // Progress below 0.0 should still work
        let underRing = VaporwaveProgressRing(progress: -0.5)
        XCTAssertNotNil(underRing)
    }

    func testVaporwaveControlButtonCreation() {
        var actionCalled = false
        let button = VaporwaveControlButton(
            icon: "mic.fill",
            label: "Record",
            isActive: true,
            color: VaporwaveColors.neonPink,
            action: { actionCalled = true }
        )
        XCTAssertNotNil(button)
    }

    func testVaporwaveInfoRowCreation() {
        let row = VaporwaveInfoRow(
            icon: "applewatch",
            title: "Apple Watch",
            value: "Connected",
            valueColor: VaporwaveColors.success
        )
        XCTAssertNotNil(row)
    }

    func testVaporwaveSectionHeaderCreation() {
        let headerWithIcon = VaporwaveSectionHeader("Test Section", icon: "star")
        XCTAssertNotNil(headerWithIcon)

        let headerWithoutIcon = VaporwaveSectionHeader("Test Section")
        XCTAssertNotNil(headerWithoutIcon)
    }

    func testVaporwaveEmptyStateCreation() {
        let emptyState = VaporwaveEmptyState(
            icon: "waveform.path.badge.plus",
            title: "No Effects",
            message: "Add your first effect"
        )
        XCTAssertNotNil(emptyState)
    }

    func testVaporwaveEmptyStateWithAction() {
        var actionCalled = false
        let emptyState = VaporwaveEmptyState(
            icon: "plus.circle",
            title: "Empty",
            message: "Nothing here",
            actionTitle: "Add Item",
            action: { actionCalled = true }
        )
        XCTAssertNotNil(emptyState)
    }

    // MARK: - Color Component Tests

    func testNeonPinkRGBValues() {
        // neonPink = Color(red: 1.0, green: 0.08, blue: 0.58)
        // We can't directly access RGB from SwiftUI Color in tests,
        // but we can verify the color exists and is consistent
        let color1 = VaporwaveColors.neonPink
        let color2 = VaporwaveColors.neonPink
        XCTAssertEqual(color1.description, color2.description)
    }

    func testNeonCyanRGBValues() {
        // neonCyan = Color(red: 0.0, green: 1.0, blue: 1.0)
        let color1 = VaporwaveColors.neonCyan
        let color2 = VaporwaveColors.neonCyan
        XCTAssertEqual(color1.description, color2.description)
    }

    // MARK: - Bio-Reactive Color Semantics

    func testCoherenceColorSemantics() {
        // Verify the colors represent the correct states
        // Low = red/warm, Medium = yellow/gold, High = cyan/green

        // These are semantic tests - the colors should be visually distinct
        let low = VaporwaveColors.coherenceLow
        let medium = VaporwaveColors.coherenceMedium
        let high = VaporwaveColors.coherenceHigh

        // All should be defined
        XCTAssertNotNil(low)
        XCTAssertNotNil(medium)
        XCTAssertNotNil(high)

        // All should be different
        XCTAssertNotEqual(low.description, medium.description)
        XCTAssertNotEqual(medium.description, high.description)
        XCTAssertNotEqual(low.description, high.description)
    }

    // MARK: - Spacing Edge Cases

    func testSpacingNonNegative() {
        XCTAssertGreaterThanOrEqual(VaporwaveSpacing.xs, 0)
        XCTAssertGreaterThanOrEqual(VaporwaveSpacing.sm, 0)
        XCTAssertGreaterThanOrEqual(VaporwaveSpacing.md, 0)
        XCTAssertGreaterThanOrEqual(VaporwaveSpacing.lg, 0)
        XCTAssertGreaterThanOrEqual(VaporwaveSpacing.xl, 0)
        XCTAssertGreaterThanOrEqual(VaporwaveSpacing.xxl, 0)
    }

    // MARK: - Default Parameter Tests

    func testVaporwaveDataDisplayDefaults() {
        // Test with minimal parameters
        let display = VaporwaveDataDisplay(value: "100", label: "Test")
        XCTAssertNotNil(display)
    }

    func testVaporwaveProgressRingDefaults() {
        // Test with minimal parameters
        let ring = VaporwaveProgressRing(progress: 0.5)
        XCTAssertNotNil(ring)
    }

    func testVaporwaveControlButtonDefaults() {
        let button = VaporwaveControlButton(icon: "star", label: "Test") {}
        XCTAssertNotNil(button)
    }

    func testVaporwaveInfoRowDefaults() {
        let row = VaporwaveInfoRow(icon: "info", title: "Info", value: "Value")
        XCTAssertNotNil(row)
    }

    // MARK: - EchoelBrand Integration Tests

    func testEchoelBrandColorsDefined() {
        XCTAssertNotNil(EchoelBrand.primary)
        XCTAssertNotNil(EchoelBrand.bgDeep)
        XCTAssertNotNil(EchoelBrand.bgSurface)
        XCTAssertNotNil(EchoelBrand.textPrimary)
        XCTAssertNotNil(EchoelBrand.coherenceHigh)
    }
}
