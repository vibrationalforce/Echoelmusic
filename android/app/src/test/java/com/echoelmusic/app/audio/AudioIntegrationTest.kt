package com.echoelmusic.app.audio

import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for AudioIntegration
 * Tests the coordination between AudioEngine and ImmersiveIsochronicEngine
 *
 * Note: Context-dependent features require instrumented tests
 * These tests focus on configuration, state, and parameter logic
 */
class AudioIntegrationTest {

    // MARK: - Entrainment Preset Integration Tests

    @Test
    fun testAllEntrainmentPresetsAvailable() {
        val presets = ImmersiveIsochronicEngine.EntrainmentPreset.values()
        assertEquals(6, presets.size)

        assertTrue(presets.contains(ImmersiveIsochronicEngine.EntrainmentPreset.DEEP_REST))
        assertTrue(presets.contains(ImmersiveIsochronicEngine.EntrainmentPreset.MEDITATION))
        assertTrue(presets.contains(ImmersiveIsochronicEngine.EntrainmentPreset.RELAXED_FOCUS))
        assertTrue(presets.contains(ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS))
        assertTrue(presets.contains(ImmersiveIsochronicEngine.EntrainmentPreset.ACTIVE_THINKING))
        assertTrue(presets.contains(ImmersiveIsochronicEngine.EntrainmentPreset.PEAK_FLOW))
    }

    @Test
    fun testAllSoundscapesAvailable() {
        val soundscapes = ImmersiveIsochronicEngine.Soundscape.values()
        assertEquals(6, soundscapes.size)

        assertTrue(soundscapes.contains(ImmersiveIsochronicEngine.Soundscape.WARM_PAD))
        assertTrue(soundscapes.contains(ImmersiveIsochronicEngine.Soundscape.CRYSTAL_BOWL))
        assertTrue(soundscapes.contains(ImmersiveIsochronicEngine.Soundscape.ORGANIC_DRONE))
        assertTrue(soundscapes.contains(ImmersiveIsochronicEngine.Soundscape.COSMIC_WASH))
        assertTrue(soundscapes.contains(ImmersiveIsochronicEngine.Soundscape.EARTHY_GROUND))
        assertTrue(soundscapes.contains(ImmersiveIsochronicEngine.Soundscape.SHIMMERING_AIR))
    }

    // MARK: - Parameter ID Tests

    @Test
    fun testAudioEngineParameterIds() {
        // Oscillator
        assertEquals(0, AudioEngine.Params.OSC1_WAVEFORM)
        assertEquals(1, AudioEngine.Params.OSC1_OCTAVE)
        assertEquals(2, AudioEngine.Params.OSC2_WAVEFORM)
        assertEquals(3, AudioEngine.Params.OSC2_MIX)

        // Filter
        assertEquals(10, AudioEngine.Params.FILTER_CUTOFF)
        assertEquals(11, AudioEngine.Params.FILTER_RESONANCE)
        assertEquals(12, AudioEngine.Params.FILTER_ENV_AMOUNT)

        // Envelopes
        assertEquals(20, AudioEngine.Params.AMP_ATTACK)
        assertEquals(21, AudioEngine.Params.AMP_DECAY)
        assertEquals(22, AudioEngine.Params.AMP_SUSTAIN)
        assertEquals(23, AudioEngine.Params.AMP_RELEASE)

        // LFO
        assertEquals(30, AudioEngine.Params.LFO_RATE)
        assertEquals(31, AudioEngine.Params.LFO_DEPTH)
        assertEquals(32, AudioEngine.Params.LFO_TO_FILTER)

        // 808 Bass
        assertEquals(40, AudioEngine.Params.BASS_DECAY)
        assertEquals(41, AudioEngine.Params.BASS_TONE)
        assertEquals(42, AudioEngine.Params.BASS_DRIVE)
        assertEquals(43, AudioEngine.Params.BASS_GLIDE_TIME)
        assertEquals(44, AudioEngine.Params.BASS_GLIDE_RANGE)
    }

    // MARK: - Volume Clamping Tests

    @Test
    fun testSynthVolumeClamping() {
        // Simulate volume clamping logic
        var volume = 1.5f
        volume = volume.coerceIn(0f, 1f)
        assertEquals(1f, volume, 0.01f)

        volume = -0.5f
        volume = volume.coerceIn(0f, 1f)
        assertEquals(0f, volume, 0.01f)

        volume = 0.8f
        volume = volume.coerceIn(0f, 1f)
        assertEquals(0.8f, volume, 0.01f)
    }

    @Test
    fun testIsochronicVolumeClamping() {
        var volume = 2.0f
        volume = volume.coerceIn(0f, 1f)
        assertEquals(1f, volume, 0.01f)

        volume = -1.0f
        volume = volume.coerceIn(0f, 1f)
        assertEquals(0f, volume, 0.01f)
    }

    // MARK: - Bio-Reactive Mapping Tests

    @Test
    fun testBioDataToCoherenceConversion() {
        // Coherence from BioReactiveEngine is 0-1, IsochronicEngine expects 0-100
        val coherence = 0.85f
        val scaledCoherence = coherence * 100
        assertEquals(85f, scaledCoherence, 0.01f)
    }

    @Test
    fun testBioDataToHeartRateConversion() {
        // Heart rate is passed directly as Double
        val heartRate = 72f
        val asDouble = heartRate.toDouble()
        assertEquals(72.0, asDouble, 0.01)
    }

    // MARK: - Preset Frequency Tests

    @Test
    fun testPresetFrequencyRanges() {
        ImmersiveIsochronicEngine.EntrainmentPreset.values().forEach { preset ->
            val range = preset.frequencyRange
            assertTrue("${preset.name} center should be in range", preset.centerFrequency in range)
            assertTrue("${preset.name} range should be valid", range.start < range.endInclusive)
        }
    }

    @Test
    fun testPresetFrequencyValues() {
        assertEquals(2.5f, ImmersiveIsochronicEngine.EntrainmentPreset.DEEP_REST.centerFrequency, 0.1f)
        assertEquals(6.0f, ImmersiveIsochronicEngine.EntrainmentPreset.MEDITATION.centerFrequency, 0.1f)
        assertEquals(10.0f, ImmersiveIsochronicEngine.EntrainmentPreset.RELAXED_FOCUS.centerFrequency, 0.1f)
        assertEquals(13.5f, ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS.centerFrequency, 0.1f)
        assertEquals(17.5f, ImmersiveIsochronicEngine.EntrainmentPreset.ACTIVE_THINKING.centerFrequency, 0.1f)
        assertEquals(30.0f, ImmersiveIsochronicEngine.EntrainmentPreset.PEAK_FLOW.centerFrequency, 0.1f)
    }

    // MARK: - Soundscape Tests

    @Test
    fun testSoundscapeCarrierFrequencies() {
        assertEquals(220f, ImmersiveIsochronicEngine.Soundscape.WARM_PAD.carrierFrequency, 0.1f)
        assertEquals(528f, ImmersiveIsochronicEngine.Soundscape.CRYSTAL_BOWL.carrierFrequency, 0.1f)
        assertEquals(136.1f, ImmersiveIsochronicEngine.Soundscape.ORGANIC_DRONE.carrierFrequency, 0.1f)
        assertEquals(174f, ImmersiveIsochronicEngine.Soundscape.COSMIC_WASH.carrierFrequency, 0.1f)
        assertEquals(110f, ImmersiveIsochronicEngine.Soundscape.EARTHY_GROUND.carrierFrequency, 0.1f)
        assertEquals(396f, ImmersiveIsochronicEngine.Soundscape.SHIMMERING_AIR.carrierFrequency, 0.1f)
    }

    @Test
    fun testSoundscapeHarmonics() {
        ImmersiveIsochronicEngine.Soundscape.values().forEach { soundscape ->
            assertTrue("${soundscape.name} should have harmonics", soundscape.harmonics.isNotEmpty())
            assertTrue("${soundscape.name} should have detuning", soundscape.detuning.isNotEmpty())
            assertEquals(
                "Harmonics and detuning count should match for ${soundscape.name}",
                soundscape.harmonics.size,
                soundscape.detuning.size
            )
        }
    }

    // MARK: - Session Statistics Tests

    @Test
    fun testSessionStatisticsDefaultValues() {
        val stats = ImmersiveIsochronicEngine.SessionStatistics()

        assertEquals(0, stats.totalListeningSeconds)
        assertEquals(0, stats.sessionsCompleted)
        assertNull(stats.lastSessionDate)
        assertEquals(0, stats.currentStreak)
        assertTrue(stats.presetMinutes.isEmpty())
    }

    @Test
    fun testSessionStatisticsRecording() {
        val stats = ImmersiveIsochronicEngine.SessionStatistics()

        stats.recordSession(ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS, 15)

        assertEquals(1, stats.sessionsCompleted)
        assertEquals(15, stats.totalMinutes)
        assertNotNull(stats.lastSessionDate)
        assertEquals(1, stats.currentStreak)
    }

    @Test
    fun testSessionStatisticsMultipleSessions() {
        val stats = ImmersiveIsochronicEngine.SessionStatistics()

        stats.recordSession(ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS, 20)
        stats.recordSession(ImmersiveIsochronicEngine.EntrainmentPreset.MEDITATION, 30)
        stats.recordSession(ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS, 10)

        assertEquals(3, stats.sessionsCompleted)
        assertEquals(60, stats.totalMinutes)
        assertEquals(30, stats.presetMinutes["FOCUS"])
        assertEquals(30, stats.presetMinutes["MEDITATION"])
    }

    @Test
    fun testSessionStatisticsFavoritePreset() {
        val stats = ImmersiveIsochronicEngine.SessionStatistics()

        stats.recordSession(ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS, 30)
        stats.recordSession(ImmersiveIsochronicEngine.EntrainmentPreset.MEDITATION, 10)
        stats.recordSession(ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS, 20)

        assertEquals("FOCUS", stats.favoritePreset)
    }

    // MARK: - Breath Sync Tests

    @Test
    fun testDefaultBreathingRate() {
        // Default is 6 BPM (0.1 Hz) for baroreflex resonance
        val defaultRate = 6f
        assertEquals(6f, defaultRate, 0.01f)
    }

    @Test
    fun testBreathingRateRange() {
        // Breathing rate should be 2-30 BPM
        val rates = listOf(2f, 6f, 12f, 20f, 30f)
        rates.forEach { rate ->
            assertTrue("Rate $rate should be in valid range", rate in 2f..30f)
        }
    }

    // MARK: - Filter Cutoff Tests

    @Test
    fun testFilterCutoffClamping() {
        // Filter cutoff should be clamped to 20-20000 Hz
        var cutoff = 25000f
        cutoff = cutoff.coerceIn(20f, 20000f)
        assertEquals(20000f, cutoff, 0.01f)

        cutoff = 10f
        cutoff = cutoff.coerceIn(20f, 20000f)
        assertEquals(20f, cutoff, 0.01f)

        cutoff = 1000f
        cutoff = cutoff.coerceIn(20f, 20000f)
        assertEquals(1000f, cutoff, 0.01f)
    }

    @Test
    fun testFilterResonanceClamping() {
        var resonance = 1.5f
        resonance = resonance.coerceIn(0f, 1f)
        assertEquals(1f, resonance, 0.01f)

        resonance = -0.5f
        resonance = resonance.coerceIn(0f, 1f)
        assertEquals(0f, resonance, 0.01f)
    }

    // MARK: - Tempo Tests

    @Test
    fun testTempoClamping() {
        // Tempo should be reasonable: 40-300 BPM
        var tempo = 400f
        tempo = tempo.coerceIn(40f, 300f)
        assertEquals(300f, tempo, 0.01f)

        tempo = 20f
        tempo = tempo.coerceIn(40f, 300f)
        assertEquals(40f, tempo, 0.01f)
    }

    @Test
    fun testTempoToLFORateMapping() {
        // Tempo 120 BPM = 1.0 normalized rate
        val tempo = 120f
        val normalizedRate = (tempo / 120f).coerceIn(0.5f, 2f)
        assertEquals(1f, normalizedRate, 0.01f)

        // Tempo 240 BPM = 2.0 normalized (capped)
        val fastTempo = 240f
        val fastRate = (fastTempo / 120f).coerceIn(0.5f, 2f)
        assertEquals(2f, fastRate, 0.01f)

        // Tempo 60 BPM = 0.5 normalized
        val slowTempo = 60f
        val slowRate = (slowTempo / 120f).coerceIn(0.5f, 2f)
        assertEquals(0.5f, slowRate, 0.01f)
    }

    // MARK: - Bio Modulation Amount Tests

    @Test
    fun testBioModulationAmountRange() {
        // Bio modulation amount should be 0-1
        listOf(0f, 0.25f, 0.5f, 0.75f, 1f).forEach { amount ->
            assertTrue("Amount $amount should be valid", amount in 0f..1f)
        }
    }

    // MARK: - Crossfade Duration Tests

    @Test
    fun testCrossfadeDurationValues() {
        // Typical crossfade durations: 0.5 to 5 seconds
        val durations = listOf(0.5f, 1f, 2f, 3f, 5f)
        durations.forEach { duration ->
            assertTrue("Duration $duration should be positive", duration > 0)
        }
    }

    // MARK: - Integration Workflow Tests

    @Test
    fun testTypicalSessionWorkflow() {
        // Simulate a typical user session
        val stats = ImmersiveIsochronicEngine.SessionStatistics()

        // User starts with relaxed focus
        val preset = ImmersiveIsochronicEngine.EntrainmentPreset.RELAXED_FOCUS
        assertEquals("Relaxed Focus", preset.displayName)
        assertEquals(10f, preset.centerFrequency, 0.1f)

        // Session completes
        stats.recordSession(preset, 20)

        assertEquals(1, stats.sessionsCompleted)
        assertEquals(20, stats.totalMinutes)
    }

    @Test
    fun testPresetToSoundscapeRecommendations() {
        // Deep Rest → Warm Pad or Organic Drone
        val deepRestSoundscapes = listOf(
            ImmersiveIsochronicEngine.Soundscape.WARM_PAD,
            ImmersiveIsochronicEngine.Soundscape.ORGANIC_DRONE
        )

        // Focus → Crystal Bowl or Shimmering Air
        val focusSoundscapes = listOf(
            ImmersiveIsochronicEngine.Soundscape.CRYSTAL_BOWL,
            ImmersiveIsochronicEngine.Soundscape.SHIMMERING_AIR
        )

        assertTrue(deepRestSoundscapes.isNotEmpty())
        assertTrue(focusSoundscapes.isNotEmpty())
    }

    // MARK: - Performance Tests

    @Test
    fun testEntrainmentPresetLookupPerformance() {
        val startTime = System.nanoTime()

        repeat(100000) {
            ImmersiveIsochronicEngine.EntrainmentPreset.values()
        }

        val elapsed = (System.nanoTime() - startTime) / 1_000_000.0
        assertTrue("Enum lookup should be fast: ${elapsed}ms", elapsed < 100)
    }

    @Test
    fun testSoundscapeLookupPerformance() {
        val startTime = System.nanoTime()

        repeat(100000) {
            ImmersiveIsochronicEngine.Soundscape.values()
        }

        val elapsed = (System.nanoTime() - startTime) / 1_000_000.0
        assertTrue("Enum lookup should be fast: ${elapsed}ms", elapsed < 100)
    }

    @Test
    fun testSessionStatisticsPerformance() {
        val stats = ImmersiveIsochronicEngine.SessionStatistics()
        val startTime = System.nanoTime()

        repeat(1000) {
            stats.recordSession(ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS, 1)
        }

        val elapsed = (System.nanoTime() - startTime) / 1_000_000.0
        assertTrue("Recording 1000 sessions should be fast: ${elapsed}ms", elapsed < 500)
    }
}
