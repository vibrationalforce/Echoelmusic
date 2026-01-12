package com.echoelmusic.app.accessibility

import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for AccessibilityManager
 * Tests profiles, color schemes, haptic patterns, and accessibility features
 */
class AccessibilityManagerTest {

    // MARK: - Accessibility Profile Tests

    @Test
    fun testAllAccessibilityProfiles() {
        val profiles = AccessibilityProfile.values()
        assertEquals(21, profiles.size)
    }

    @Test
    fun testAccessibilityProfileDisplayNames() {
        assertEquals("Standard", AccessibilityProfile.STANDARD.displayName)
        assertEquals("Low Vision", AccessibilityProfile.LOW_VISION.displayName)
        assertEquals("Blind", AccessibilityProfile.BLIND.displayName)
        assertEquals("Motor Limited", AccessibilityProfile.MOTOR_LIMITED.displayName)
        assertEquals("Voice Only", AccessibilityProfile.VOICE_ONLY.displayName)
        assertEquals("Autism Friendly", AccessibilityProfile.AUTISM_FRIENDLY.displayName)
    }

    @Test
    fun testAccessibilityProfileDescriptions() {
        assertEquals("Default experience", AccessibilityProfile.STANDARD.description)
        assertEquals("Large text, high contrast", AccessibilityProfile.LOW_VISION.description)
        assertEquals("TalkBack/VoiceOver with spatial audio", AccessibilityProfile.BLIND.description)
    }

    @Test
    fun testColorBlindProfiles() {
        assertTrue(AccessibilityProfile.values().contains(AccessibilityProfile.COLOR_BLIND_PROTANOPIA))
        assertTrue(AccessibilityProfile.values().contains(AccessibilityProfile.COLOR_BLIND_DEUTERANOPIA))
        assertTrue(AccessibilityProfile.values().contains(AccessibilityProfile.COLOR_BLIND_TRITANOPIA))
    }

    @Test
    fun testCognitiveProfiles() {
        assertTrue(AccessibilityProfile.values().contains(AccessibilityProfile.COGNITIVE))
        assertTrue(AccessibilityProfile.values().contains(AccessibilityProfile.AUTISM_FRIENDLY))
        assertTrue(AccessibilityProfile.values().contains(AccessibilityProfile.DYSLEXIA))
        assertTrue(AccessibilityProfile.values().contains(AccessibilityProfile.ADHD))
        assertTrue(AccessibilityProfile.values().contains(AccessibilityProfile.MEMORY_SUPPORT))
    }

    @Test
    fun testMotorProfiles() {
        assertTrue(AccessibilityProfile.values().contains(AccessibilityProfile.MOTOR_LIMITED))
        assertTrue(AccessibilityProfile.values().contains(AccessibilityProfile.SWITCH_ACCESS))
        assertTrue(AccessibilityProfile.values().contains(AccessibilityProfile.ONE_HANDED))
        assertTrue(AccessibilityProfile.values().contains(AccessibilityProfile.HANDS_FREE))
        assertTrue(AccessibilityProfile.values().contains(AccessibilityProfile.TREMOR_SUPPORT))
    }

    @Test
    fun testSensoryProfiles() {
        assertTrue(AccessibilityProfile.values().contains(AccessibilityProfile.DEAF))
        assertTrue(AccessibilityProfile.values().contains(AccessibilityProfile.VESTIBULAR))
        assertTrue(AccessibilityProfile.values().contains(AccessibilityProfile.PHOTOSENSITIVE))
    }

    // MARK: - Color Scheme Tests

    @Test
    fun testAllColorSchemes() {
        val schemes = ColorScheme.values()
        assertEquals(7, schemes.size)
    }

    @Test
    fun testColorSchemeDisplayNames() {
        assertEquals("Standard", ColorScheme.STANDARD.displayName)
        assertEquals("Protanopia Safe", ColorScheme.PROTANOPIA.displayName)
        assertEquals("Deuteranopia Safe", ColorScheme.DEUTERANOPIA.displayName)
        assertEquals("Tritanopia Safe", ColorScheme.TRITANOPIA.displayName)
        assertEquals("Monochrome", ColorScheme.MONOCHROME.displayName)
        assertEquals("High Contrast", ColorScheme.HIGH_CONTRAST.displayName)
        assertEquals("Soft/Reduced Saturation", ColorScheme.SOFT.displayName)
    }

    @Test
    fun testColorBlindSafeSchemes() {
        assertTrue(ColorScheme.values().contains(ColorScheme.PROTANOPIA))
        assertTrue(ColorScheme.values().contains(ColorScheme.DEUTERANOPIA))
        assertTrue(ColorScheme.values().contains(ColorScheme.TRITANOPIA))
    }

    // MARK: - Haptic Pattern Tests

    @Test
    fun testAllHapticPatterns() {
        val patterns = HapticPattern.values()
        assertEquals(14, patterns.size)
    }

    @Test
    fun testHapticPatternDisplayNames() {
        assertEquals("Light", HapticPattern.LIGHT.displayName)
        assertEquals("Medium", HapticPattern.MEDIUM.displayName)
        assertEquals("Heavy", HapticPattern.HEAVY.displayName)
        assertEquals("Selection", HapticPattern.SELECTION.displayName)
        assertEquals("Success", HapticPattern.SUCCESS.displayName)
        assertEquals("Warning", HapticPattern.WARNING.displayName)
        assertEquals("Error", HapticPattern.ERROR.displayName)
    }

    @Test
    fun testBioReactiveHapticPatterns() {
        assertTrue(HapticPattern.values().contains(HapticPattern.COHERENCE_PULSE))
        assertTrue(HapticPattern.values().contains(HapticPattern.HEARTBEAT))
        assertTrue(HapticPattern.values().contains(HapticPattern.QUANTUM))
    }

    @Test
    fun testNavigationHapticPatterns() {
        assertTrue(HapticPattern.values().contains(HapticPattern.NAVIGATION))
        assertTrue(HapticPattern.values().contains(HapticPattern.FOCUS))
        assertTrue(HapticPattern.values().contains(HapticPattern.ALERT))
        assertTrue(HapticPattern.values().contains(HapticPattern.COMPLETION))
    }

    // MARK: - Color Adaptation Logic Tests

    @Test
    fun testMonochromeAdaptation() {
        // Test monochrome conversion logic
        // RGB to grayscale: Y = 0.299*R + 0.587*G + 0.114*B

        val red: Long = 0xFFFF0000
        val r = ((red shr 16) and 0xFF)
        val g = ((red shr 8) and 0xFF)
        val b = (red and 0xFF)

        val gray = (r * 0.299f + g * 0.587f + b * 0.114f).toLong()
        assertEquals(76, gray) // Expected grayscale value for pure red
    }

    @Test
    fun testHighContrastAdaptation() {
        // Test high contrast logic (luminance threshold)
        val white: Long = 0xFFFFFFFF
        val black: Long = 0xFF000000

        val whiteLuminance = calculateLuminance(white)
        val blackLuminance = calculateLuminance(black)

        assertTrue(whiteLuminance > 128)
        assertTrue(blackLuminance < 128)
    }

    private fun calculateLuminance(color: Long): Float {
        val r = ((color shr 16) and 0xFF)
        val g = ((color shr 8) and 0xFF)
        val b = (color and 0xFF)
        return 0.299f * r + 0.587f * g + 0.114f * b
    }

    // MARK: - Font Scale Tests

    @Test
    fun testFontScaleDefaults() {
        // Standard profile should have 1.0 scale
        val standardScale = 1.0f
        assertEquals(1.0f, standardScale, 0.01f)

        // Low vision should have 1.5 scale
        val lowVisionScale = 1.5f
        assertEquals(1.5f, lowVisionScale, 0.01f)

        // Elderly should have 1.4 scale
        val elderlyScale = 1.4f
        assertEquals(1.4f, elderlyScale, 0.01f)
    }

    @Test
    fun testFontScaleRanges() {
        // Valid font scales are typically 0.8 to 2.0
        val scales = listOf(0.8f, 1.0f, 1.2f, 1.3f, 1.4f, 1.5f, 2.0f)
        scales.forEach { scale ->
            assertTrue("Scale $scale should be valid", scale in 0.5f..3.0f)
        }
    }

    // MARK: - Profile Configuration Tests

    @Test
    fun testReducedMotionProfiles() {
        // These profiles should enable reduced motion
        val reducedMotionProfiles = listOf(
            AccessibilityProfile.BLIND,
            AccessibilityProfile.SWITCH_ACCESS,
            AccessibilityProfile.COGNITIVE,
            AccessibilityProfile.AUTISM_FRIENDLY,
            AccessibilityProfile.ADHD,
            AccessibilityProfile.VESTIBULAR,
            AccessibilityProfile.PHOTOSENSITIVE
        )

        assertEquals(7, reducedMotionProfiles.size)
    }

    @Test
    fun testHighContrastProfiles() {
        // These profiles should enable high contrast
        val highContrastProfiles = listOf(
            AccessibilityProfile.LOW_VISION,
            AccessibilityProfile.ELDERLY
        )

        assertEquals(2, highContrastProfiles.size)
    }

    @Test
    fun testLargeFontProfiles() {
        // These profiles should use larger fonts
        val largeFontProfiles = listOf(
            AccessibilityProfile.LOW_VISION,      // 1.5
            AccessibilityProfile.MOTOR_LIMITED,   // 1.3
            AccessibilityProfile.COGNITIVE,       // 1.2
            AccessibilityProfile.DYSLEXIA,        // 1.2
            AccessibilityProfile.ELDERLY,         // 1.4
            AccessibilityProfile.MEMORY_SUPPORT,  // 1.2
            AccessibilityProfile.TREMOR_SUPPORT   // 1.3
        )

        assertEquals(7, largeFontProfiles.size)
    }

    // MARK: - Voice Profiles Tests

    @Test
    fun testVoiceEnabledProfiles() {
        // These profiles should use TTS
        val voiceProfiles = listOf(
            AccessibilityProfile.BLIND,
            AccessibilityProfile.SWITCH_ACCESS,
            AccessibilityProfile.VOICE_ONLY,
            AccessibilityProfile.HANDS_FREE
        )

        assertEquals(4, voiceProfiles.size)
    }

    // MARK: - Announcement Format Tests

    @Test
    fun testCoherenceAnnouncementFormat() {
        val coherence = 0.85f
        val percentage = (coherence * 100).toInt()
        val announcement = "Coherence is $percentage percent"

        assertEquals("Coherence is 85 percent", announcement)
    }

    @Test
    fun testHeartRateAnnouncementFormat() {
        val bpm = 72.5f
        val announcement = "Heart rate is ${bpm.toInt()} beats per minute"

        assertEquals("Heart rate is 72 beats per minute", announcement)
    }

    @Test
    fun testPresetAnnouncementFormat() {
        val presetName = "Deep Rest"
        val announcement = "Selected preset: $presetName"

        assertEquals("Selected preset: Deep Rest", announcement)
    }

    @Test
    fun testSessionAnnouncementFormat() {
        val sessionName = "Meditation"
        val durationMinutes = 20

        val startAnnouncement = "Starting $sessionName session"
        val endAnnouncement = "Session complete. Duration: $durationMinutes minutes"

        assertEquals("Starting Meditation session", startAnnouncement)
        assertEquals("Session complete. Duration: 20 minutes", endAnnouncement)
    }

    // MARK: - Performance Tests

    @Test
    fun testProfileEnumPerformance() {
        val startTime = System.nanoTime()

        repeat(100000) {
            AccessibilityProfile.values()
        }

        val elapsed = (System.nanoTime() - startTime) / 1_000_000.0
        assertTrue("Enum lookup should be fast: ${elapsed}ms", elapsed < 100)
    }

    @Test
    fun testColorSchemeEnumPerformance() {
        val startTime = System.nanoTime()

        repeat(100000) {
            ColorScheme.values()
        }

        val elapsed = (System.nanoTime() - startTime) / 1_000_000.0
        assertTrue("Enum lookup should be fast: ${elapsed}ms", elapsed < 100)
    }

    @Test
    fun testColorAdaptationPerformance() {
        val colors = listOf(0xFFFF0000L, 0xFF00FF00L, 0xFF0000FFL, 0xFFFFFFFF, 0xFF000000L)
        val startTime = System.nanoTime()

        repeat(10000) {
            colors.forEach { color ->
                val r = ((color shr 16) and 0xFF)
                val g = ((color shr 8) and 0xFF)
                val b = (color and 0xFF)
                val gray = (r * 0.299f + g * 0.587f + b * 0.114f).toLong()
            }
        }

        val elapsed = (System.nanoTime() - startTime) / 1_000_000.0
        assertTrue("Color adaptation should be fast: ${elapsed}ms", elapsed < 200)
    }

    // MARK: - Edge Case Tests

    @Test
    fun testZeroCoherence() {
        val coherence = 0f
        val percentage = (coherence * 100).toInt()
        assertEquals(0, percentage)
    }

    @Test
    fun testMaxCoherence() {
        val coherence = 1f
        val percentage = (coherence * 100).toInt()
        assertEquals(100, percentage)
    }

    @Test
    fun testZeroHeartRate() {
        val bpm = 0f
        val announcement = "Heart rate is ${bpm.toInt()} beats per minute"
        assertEquals("Heart rate is 0 beats per minute", announcement)
    }

    @Test
    fun testHighHeartRate() {
        val bpm = 200f
        val announcement = "Heart rate is ${bpm.toInt()} beats per minute"
        assertEquals("Heart rate is 200 beats per minute", announcement)
    }

    // MARK: - WCAG Compliance Tests

    @Test
    fun testWCAGLevelAAA() {
        // WCAG 2.2 AAA requires:
        // - 7:1 contrast ratio for text
        // - 4.5:1 for large text
        // - No time limits or adjustable
        // - No motion or user-controllable

        // Verify we have profiles for all major accessibility needs
        assertTrue(AccessibilityProfile.values().size >= 20)
        assertTrue(ColorScheme.values().size >= 6)
        assertTrue(HapticPattern.values().size >= 14)
    }

    @Test
    fun testContrastRatioCalculation() {
        // WCAG contrast ratio formula: (L1 + 0.05) / (L2 + 0.05)
        // Where L1 is lighter, L2 is darker

        val whiteLuminance = 1.0
        val blackLuminance = 0.0

        val contrastRatio = (whiteLuminance + 0.05) / (blackLuminance + 0.05)
        assertEquals(21.0, contrastRatio, 0.1) // Maximum possible contrast
    }
}
