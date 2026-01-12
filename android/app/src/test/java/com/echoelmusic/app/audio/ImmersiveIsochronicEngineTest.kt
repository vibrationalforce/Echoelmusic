package com.echoelmusic.app.audio

import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

/**
 * Unit tests for ImmersiveIsochronicEngine
 * Tests entrainment presets, soundscapes, bio-reactive modulation, and session statistics
 */
class ImmersiveIsochronicEngineTest {

    private lateinit var engine: ImmersiveIsochronicEngine

    @Before
    fun setUp() {
        engine = ImmersiveIsochronicEngine()
    }

    @After
    fun tearDown() {
        engine.shutdown()
    }

    // MARK: - Default Configuration Tests

    @Test
    fun testDefaultConfiguration() = runBlocking {
        assertEquals(ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS, engine.currentPreset.first())
        assertEquals(ImmersiveIsochronicEngine.Soundscape.WARM_PAD, engine.currentSoundscape.first())
        assertEquals(0.5f, engine.volume, 0.01f)
        assertEquals(0.7f, engine.pulseSoftness, 0.01f)
        assertFalse(engine.isPlaying.first())
    }

    // MARK: - Entrainment Preset Tests

    @Test
    fun testAllEntrainmentPresets() = runBlocking {
        val expectedFrequencies = mapOf(
            ImmersiveIsochronicEngine.EntrainmentPreset.DEEP_REST to 2.5f,
            ImmersiveIsochronicEngine.EntrainmentPreset.MEDITATION to 6.0f,
            ImmersiveIsochronicEngine.EntrainmentPreset.RELAXED_FOCUS to 10.0f,
            ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS to 13.5f,
            ImmersiveIsochronicEngine.EntrainmentPreset.ACTIVE_THINKING to 17.5f,
            ImmersiveIsochronicEngine.EntrainmentPreset.PEAK_FLOW to 30.0f
        )

        for ((preset, expectedFreq) in expectedFrequencies) {
            engine.configure(preset)
            assertEquals(preset, engine.currentPreset.first())
            assertEquals(expectedFreq, engine.rhythmFrequency.first(), 0.1f)
        }
    }

    @Test
    fun testPresetDisplayNames() {
        ImmersiveIsochronicEngine.EntrainmentPreset.values().forEach { preset ->
            assertFalse(preset.displayName.isEmpty())
            assertFalse(preset.description.isEmpty())
        }
    }

    @Test
    fun testPresetFrequencyRanges() {
        ImmersiveIsochronicEngine.EntrainmentPreset.values().forEach { preset ->
            val range = preset.frequencyRange
            assertTrue(range.start < range.endInclusive)
            assertTrue(preset.centerFrequency in range)
        }
    }

    @Test
    fun testPresetRecommendedDurations() {
        // Peak flow should have shortest recommended duration
        assertTrue(
            ImmersiveIsochronicEngine.EntrainmentPreset.PEAK_FLOW.recommendedDuration <
                    ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS.recommendedDuration
        )

        // All durations should be reasonable
        ImmersiveIsochronicEngine.EntrainmentPreset.values().forEach { preset ->
            assertTrue(preset.recommendedDuration > 0)
            assertTrue(preset.recommendedDuration <= 60)
        }
    }

    // MARK: - Soundscape Tests

    @Test
    fun testAllSoundscapes() = runBlocking {
        ImmersiveIsochronicEngine.Soundscape.values().forEach { soundscape ->
            engine.configure(
                ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS,
                soundscape
            )
            assertEquals(soundscape, engine.currentSoundscape.first())
            assertFalse(soundscape.displayName.isEmpty())
            assertTrue(soundscape.carrierFrequency > 0)
        }
    }

    @Test
    fun testSoundscapeHarmonicProfiles() {
        ImmersiveIsochronicEngine.Soundscape.values().forEach { soundscape ->
            assertTrue(soundscape.harmonics.isNotEmpty())
            assertEquals(
                soundscape.harmonics.size,
                soundscape.detuning.size,
                "Harmonics and detuning should match for ${soundscape.name}"
            )
        }
    }

    // MARK: - Volume and Parameter Tests

    @Test
    fun testVolumeConfiguration() {
        engine.volume = 0.75f
        assertEquals(0.75f, engine.volume, 0.01f)
    }

    @Test
    fun testVolumeClamping() {
        engine.volume = 1.5f
        assertEquals(1.0f, engine.volume, 0.01f)

        engine.volume = -0.5f
        assertEquals(0.0f, engine.volume, 0.01f)
    }

    @Test
    fun testPulseSoftness() {
        engine.pulseSoftness = 0.3f
        assertEquals(0.3f, engine.pulseSoftness, 0.01f)

        engine.pulseSoftness = 1.5f
        assertEquals(1.0f, engine.pulseSoftness, 0.01f)

        engine.pulseSoftness = -0.5f
        assertEquals(0.0f, engine.pulseSoftness, 0.01f)
    }

    @Test
    fun testRhythmFrequencyDirect() = runBlocking {
        engine.setRhythmFrequency(15.0f)
        assertEquals(15.0f, engine.rhythmFrequency.first(), 0.1f)

        // Test clamping
        engine.setRhythmFrequency(100.0f)
        assertEquals(60.0f, engine.rhythmFrequency.first(), 0.1f)

        engine.setRhythmFrequency(0.1f)
        assertEquals(0.5f, engine.rhythmFrequency.first(), 0.1f)
    }

    // MARK: - Bio-Reactive Modulation Tests

    @Test
    fun testCoherenceModulation() = runBlocking {
        engine.configure(ImmersiveIsochronicEngine.EntrainmentPreset.RELAXED_FOCUS)
        engine.bioModulationAmount = 1.0f

        // Low coherence
        engine.modulateFromCoherence(0.0)
        val lowCoherenceFreq = engine.rhythmFrequency.first()

        engine.configure(ImmersiveIsochronicEngine.EntrainmentPreset.RELAXED_FOCUS)
        engine.modulateFromCoherence(100.0)
        val highCoherenceFreq = engine.rhythmFrequency.first()

        assertTrue(lowCoherenceFreq < highCoherenceFreq)
    }

    @Test
    fun testCoherenceModulationDisabled() = runBlocking {
        engine.configure(ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS)
        engine.bioModulationAmount = 0.0f

        val baseFreq = engine.rhythmFrequency.first()
        engine.modulateFromCoherence(0.0)
        assertEquals(baseFreq, engine.rhythmFrequency.first(), 0.1f)
    }

    @Test
    fun testHeartRateModulation() {
        engine.bioModulationAmount = 1.0f

        engine.modulateFromHeartRate(60.0)
        val lowHRSoftness = engine.pulseSoftness

        engine.modulateFromHeartRate(120.0)
        val highHRSoftness = engine.pulseSoftness

        assertTrue(lowHRSoftness > highHRSoftness)
    }

    // MARK: - Breath Sync Tests

    @Test
    fun testEnableBreathSync() = runBlocking {
        assertFalse(engine.breathSyncEnabled.first())

        engine.enableBreathSync(6.0f)

        assertTrue(engine.breathSyncEnabled.first())
        assertEquals(6.0f, engine.rhythmFrequency.first(), 0.1f)
    }

    @Test
    fun testUpdateBreathingRate() = runBlocking {
        engine.enableBreathSync(6.0f)
        val initialFreq = engine.rhythmFrequency.first()

        engine.updateBreathingRate(12.0f)

        assertEquals(initialFreq * 2, engine.rhythmFrequency.first(), 0.1f)
    }

    @Test
    fun testUpdateBreathingRateWhenNotEnabled() = runBlocking {
        val initialFreq = engine.rhythmFrequency.first()

        engine.updateBreathingRate(12.0f)

        assertEquals(initialFreq, engine.rhythmFrequency.first(), 0.1f)
    }

    @Test
    fun testDisableBreathSync() = runBlocking {
        engine.configure(ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS)
        val presetFreq = engine.currentPreset.first().centerFrequency

        engine.enableBreathSync(6.0f)
        assertTrue(engine.breathSyncEnabled.first())

        engine.disableBreathSync()

        assertFalse(engine.breathSyncEnabled.first())
        assertEquals(presetFreq, engine.rhythmFrequency.first(), 0.1f)
    }

    // MARK: - Soundscape Transition Tests

    @Test
    fun testTransitionToSoundscape() = runBlocking {
        engine.configure(
            ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS,
            ImmersiveIsochronicEngine.Soundscape.WARM_PAD
        )

        engine.transitionTo(ImmersiveIsochronicEngine.Soundscape.CRYSTAL_BOWL)

        assertEquals(
            ImmersiveIsochronicEngine.Soundscape.CRYSTAL_BOWL,
            engine.currentSoundscape.first()
        )
    }

    @Test
    fun testCrossfadeDurationConfiguration() {
        engine.crossfadeDuration = 3.0f
        assertEquals(3.0f, engine.crossfadeDuration, 0.01f)
    }

    // MARK: - Session Statistics Tests

    @Test
    fun testInitialSessionStats() = runBlocking {
        val stats = engine.sessionStats.first()
        assertEquals(0, stats.totalListeningSeconds)
        assertEquals(0, stats.sessionsCompleted)
        assertNull(stats.lastSessionDate)
        assertEquals(0, stats.currentStreak)
    }

    @Test
    fun testSessionStatsRecording() {
        val stats = ImmersiveIsochronicEngine.SessionStatistics()

        stats.recordSession(ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS, 15)

        assertEquals(1, stats.sessionsCompleted)
        assertEquals(15, stats.totalMinutes)
        assertNotNull(stats.lastSessionDate)
        assertEquals(1, stats.currentStreak)
    }

    @Test
    fun testSessionStatsFavoritePreset() {
        val stats = ImmersiveIsochronicEngine.SessionStatistics()

        stats.recordSession(ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS, 30)
        stats.recordSession(ImmersiveIsochronicEngine.EntrainmentPreset.MEDITATION, 10)
        stats.recordSession(ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS, 20)

        assertEquals("FOCUS", stats.favoritePreset)
        assertEquals(50, stats.presetMinutes["FOCUS"])
        assertEquals(10, stats.presetMinutes["MEDITATION"])
    }

    @Test
    fun testCurrentSessionDuration() {
        assertEquals(0, engine.currentSessionDuration)
    }

    // MARK: - Enumeration Tests

    @Test
    fun testAllPresetsIteration() {
        val allPresets = ImmersiveIsochronicEngine.EntrainmentPreset.values()
        assertEquals(6, allPresets.size)

        assertTrue(allPresets.contains(ImmersiveIsochronicEngine.EntrainmentPreset.DEEP_REST))
        assertTrue(allPresets.contains(ImmersiveIsochronicEngine.EntrainmentPreset.MEDITATION))
        assertTrue(allPresets.contains(ImmersiveIsochronicEngine.EntrainmentPreset.RELAXED_FOCUS))
        assertTrue(allPresets.contains(ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS))
        assertTrue(allPresets.contains(ImmersiveIsochronicEngine.EntrainmentPreset.ACTIVE_THINKING))
        assertTrue(allPresets.contains(ImmersiveIsochronicEngine.EntrainmentPreset.PEAK_FLOW))
    }

    @Test
    fun testAllSoundscapesIteration() {
        val allSoundscapes = ImmersiveIsochronicEngine.Soundscape.values()
        assertEquals(6, allSoundscapes.size)

        assertTrue(allSoundscapes.contains(ImmersiveIsochronicEngine.Soundscape.WARM_PAD))
        assertTrue(allSoundscapes.contains(ImmersiveIsochronicEngine.Soundscape.CRYSTAL_BOWL))
        assertTrue(allSoundscapes.contains(ImmersiveIsochronicEngine.Soundscape.ORGANIC_DRONE))
        assertTrue(allSoundscapes.contains(ImmersiveIsochronicEngine.Soundscape.COSMIC_WASH))
        assertTrue(allSoundscapes.contains(ImmersiveIsochronicEngine.Soundscape.EARTHY_GROUND))
        assertTrue(allSoundscapes.contains(ImmersiveIsochronicEngine.Soundscape.SHIMMERING_AIR))
    }
}
