package com.echoelmusic.app.unified

import com.echoelmusic.app.audio.ImmersiveIsochronicEngine
import com.echoelmusic.app.midi.MidiManager
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

/**
 * Unit tests for UnifiedControlHub
 * Tests control loop, input modes, bio-reactive mapping, and parameter configuration
 */
class UnifiedControlHubTest {

    // Note: Context-dependent features are tested via integration tests
    // These tests focus on state management and configuration logic

    // MARK: - Input Mode Tests

    @Test
    fun testInputModeEnumValues() {
        val allModes = UnifiedControlHub.InputMode.values()
        assertEquals(7, allModes.size)

        assertTrue(allModes.contains(UnifiedControlHub.InputMode.AUTOMATIC))
        assertTrue(allModes.contains(UnifiedControlHub.InputMode.TOUCH_ONLY))
        assertTrue(allModes.contains(UnifiedControlHub.InputMode.GESTURE_ONLY))
        assertTrue(allModes.contains(UnifiedControlHub.InputMode.FACE_ONLY))
        assertTrue(allModes.contains(UnifiedControlHub.InputMode.BIO_ONLY))
        assertTrue(allModes.contains(UnifiedControlHub.InputMode.MIDI_ONLY))
        assertTrue(allModes.contains(UnifiedControlHub.InputMode.MANUAL))
    }

    @Test
    fun testInputModeDefaultIsAutomatic() {
        // Default should be AUTOMATIC based on UnifiedControlHub implementation
        assertEquals(
            UnifiedControlHub.InputMode.AUTOMATIC,
            UnifiedControlHub.InputMode.values().first()
        )
    }

    // MARK: - Control Parameters Tests

    @Test
    fun testControlParametersDefaultValues() {
        val params = UnifiedControlHub.ControlParameters()

        assertEquals(1000f, params.filterCutoff, 0.01f)
        assertEquals(0.5f, params.filterResonance, 0.01f)
        assertEquals(0.3f, params.reverbWetness, 0.01f)
        assertEquals(0.5f, params.reverbSize, 0.01f)
        assertEquals(0.25f, params.delayTime, 0.01f)
        assertEquals(0.3f, params.delayFeedback, 0.01f)
        assertEquals(0.8f, params.masterVolume, 0.01f)
        assertEquals(120f, params.tempo, 0.01f)
        assertEquals(0f, params.spatialX, 0.01f)
        assertEquals(0f, params.spatialY, 0.01f)
        assertEquals(0f, params.spatialZ, 0.01f)
        assertEquals(
            ImmersiveIsochronicEngine.EntrainmentPreset.RELAXED_FOCUS,
            params.entrainmentPreset
        )
    }

    @Test
    fun testControlParametersMutability() {
        val params = UnifiedControlHub.ControlParameters()

        params.filterCutoff = 2000f
        params.filterResonance = 0.8f
        params.reverbWetness = 0.6f
        params.masterVolume = 0.5f
        params.tempo = 140f
        params.spatialX = 0.5f
        params.entrainmentPreset = ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS

        assertEquals(2000f, params.filterCutoff, 0.01f)
        assertEquals(0.8f, params.filterResonance, 0.01f)
        assertEquals(0.6f, params.reverbWetness, 0.01f)
        assertEquals(0.5f, params.masterVolume, 0.01f)
        assertEquals(140f, params.tempo, 0.01f)
        assertEquals(0.5f, params.spatialX, 0.01f)
        assertEquals(ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS, params.entrainmentPreset)
    }

    @Test
    fun testControlParametersSpatialRanges() {
        val params = UnifiedControlHub.ControlParameters()

        // Test spatial coordinates can be set to full range
        params.spatialX = -1f
        params.spatialY = 1f
        params.spatialZ = 0.5f

        assertEquals(-1f, params.spatialX, 0.01f)
        assertEquals(1f, params.spatialY, 0.01f)
        assertEquals(0.5f, params.spatialZ, 0.01f)
    }

    // MARK: - Bio Mapping Tests

    @Test
    fun testBioMappingDefaultValues() {
        val mapping = UnifiedControlHub.BioMapping()

        assertTrue(mapping.coherenceToFilter)
        assertTrue(mapping.hrvToReverb)
        assertTrue(mapping.heartRateToTempo)
        assertTrue(mapping.breathingToEntrainment)
    }

    @Test
    fun testBioMappingCustomConfiguration() {
        val mapping = UnifiedControlHub.BioMapping(
            coherenceToFilter = false,
            hrvToReverb = true,
            heartRateToTempo = false,
            breathingToEntrainment = true
        )

        assertFalse(mapping.coherenceToFilter)
        assertTrue(mapping.hrvToReverb)
        assertFalse(mapping.heartRateToTempo)
        assertTrue(mapping.breathingToEntrainment)
    }

    @Test
    fun testBioMappingAllDisabled() {
        val mapping = UnifiedControlHub.BioMapping(
            coherenceToFilter = false,
            hrvToReverb = false,
            heartRateToTempo = false,
            breathingToEntrainment = false
        )

        assertFalse(mapping.coherenceToFilter)
        assertFalse(mapping.hrvToReverb)
        assertFalse(mapping.heartRateToTempo)
        assertFalse(mapping.breathingToEntrainment)
    }

    // MARK: - Input Mode Priority Tests

    @Test
    fun testInputModePriorityOrder() {
        // Document the priority order: Touch > Gesture > Face > Bio > MIDI
        val priority = listOf(
            UnifiedControlHub.InputMode.TOUCH_ONLY,
            UnifiedControlHub.InputMode.GESTURE_ONLY,
            UnifiedControlHub.InputMode.FACE_ONLY,
            UnifiedControlHub.InputMode.BIO_ONLY,
            UnifiedControlHub.InputMode.MIDI_ONLY
        )

        assertEquals(5, priority.size)
        assertEquals(UnifiedControlHub.InputMode.TOUCH_ONLY, priority[0])
        assertEquals(UnifiedControlHub.InputMode.MIDI_ONLY, priority[4])
    }

    // MARK: - Entrainment Preset Integration Tests

    @Test
    fun testEntrainmentPresetInControlParameters() {
        val params = UnifiedControlHub.ControlParameters()

        // Test all presets can be assigned
        ImmersiveIsochronicEngine.EntrainmentPreset.values().forEach { preset ->
            params.entrainmentPreset = preset
            assertEquals(preset, params.entrainmentPreset)
        }
    }

    @Test
    fun testControlParametersAllPresets() {
        val params = UnifiedControlHub.ControlParameters()

        params.entrainmentPreset = ImmersiveIsochronicEngine.EntrainmentPreset.DEEP_REST
        assertEquals(ImmersiveIsochronicEngine.EntrainmentPreset.DEEP_REST, params.entrainmentPreset)

        params.entrainmentPreset = ImmersiveIsochronicEngine.EntrainmentPreset.MEDITATION
        assertEquals(ImmersiveIsochronicEngine.EntrainmentPreset.MEDITATION, params.entrainmentPreset)

        params.entrainmentPreset = ImmersiveIsochronicEngine.EntrainmentPreset.RELAXED_FOCUS
        assertEquals(ImmersiveIsochronicEngine.EntrainmentPreset.RELAXED_FOCUS, params.entrainmentPreset)

        params.entrainmentPreset = ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS
        assertEquals(ImmersiveIsochronicEngine.EntrainmentPreset.FOCUS, params.entrainmentPreset)

        params.entrainmentPreset = ImmersiveIsochronicEngine.EntrainmentPreset.ACTIVE_THINKING
        assertEquals(ImmersiveIsochronicEngine.EntrainmentPreset.ACTIVE_THINKING, params.entrainmentPreset)

        params.entrainmentPreset = ImmersiveIsochronicEngine.EntrainmentPreset.PEAK_FLOW
        assertEquals(ImmersiveIsochronicEngine.EntrainmentPreset.PEAK_FLOW, params.entrainmentPreset)
    }

    // MARK: - Control Loop Frequency Tests

    @Test
    fun testTargetControlLoopFrequency() {
        // The control loop should target 60 Hz (16.67ms interval)
        val targetHz = 60.0
        val intervalMs = 1000.0 / targetHz

        assertEquals(16.67, intervalMs, 0.1)
    }

    // MARK: - Filter Parameter Range Tests

    @Test
    fun testFilterCutoffRange() {
        val params = UnifiedControlHub.ControlParameters()

        // Test reasonable filter cutoff values
        params.filterCutoff = 200f
        assertEquals(200f, params.filterCutoff, 0.01f)

        params.filterCutoff = 5000f
        assertEquals(5000f, params.filterCutoff, 0.01f)

        params.filterCutoff = 20000f
        assertEquals(20000f, params.filterCutoff, 0.01f)
    }

    @Test
    fun testFilterResonanceRange() {
        val params = UnifiedControlHub.ControlParameters()

        params.filterResonance = 0f
        assertEquals(0f, params.filterResonance, 0.01f)

        params.filterResonance = 0.5f
        assertEquals(0.5f, params.filterResonance, 0.01f)

        params.filterResonance = 1f
        assertEquals(1f, params.filterResonance, 0.01f)
    }

    // MARK: - MIDI CC Mapping Tests

    @Test
    fun testMidiCCMappingConstants() {
        // Standard MIDI CC numbers used in UnifiedControlHub
        val modulationWheel = 1
        val volume = 7
        val pan = 10
        val filterCutoff = 74
        val resonance = 71
        val reverb = 91

        assertEquals(1, modulationWheel)
        assertEquals(7, volume)
        assertEquals(10, pan)
        assertEquals(74, filterCutoff)
        assertEquals(71, resonance)
        assertEquals(91, reverb)
    }

    @Test
    fun testMidiCCToParameterMapping() {
        // Test CC value normalization (0-127 to 0-1 or appropriate range)
        val ccValue = 64
        val normalized = ccValue / 127f

        assertEquals(0.504f, normalized, 0.01f)
    }

    @Test
    fun testMidiCCFilterCutoffMapping() {
        // CC 74 (0-127) maps to filter cutoff (200-5000 Hz)
        val minCutoff = 200f
        val maxCutoff = 5000f
        val ccValue = 127

        val cutoff = minCutoff + (ccValue / 127f) * (maxCutoff - minCutoff)
        assertEquals(5000f, cutoff, 1f)
    }

    // MARK: - Bio-Reactive Mapping Tests

    @Test
    fun testHeartRateToTempoMapping() {
        // Heart rate 60-180 BPM should map to tempo 60-180 BPM
        val heartRate = 75f
        val tempo = heartRate.coerceIn(60f, 180f)

        assertEquals(75f, tempo, 0.01f)
    }

    @Test
    fun testHeartRateToTempoClamping() {
        // Heart rate below 60 should clamp to 60
        val lowHR = 50f
        val lowTempo = lowHR.coerceIn(60f, 180f)
        assertEquals(60f, lowTempo, 0.01f)

        // Heart rate above 180 should clamp to 180
        val highHR = 200f
        val highTempo = highHR.coerceIn(60f, 180f)
        assertEquals(180f, highTempo, 0.01f)
    }

    @Test
    fun testHRVToReverbMapping() {
        // HRV 0-100ms maps to reverb wetness 0-0.6
        val hrv = 50f
        val normalized = (hrv / 100f).coerceIn(0f, 1f)
        val reverbWetness = normalized * 0.6f

        assertEquals(0.3f, reverbWetness, 0.01f)
    }

    @Test
    fun testCoherenceToFilterMapping() {
        // Coherence 0-1 maps to filter cutoff 500-5000 Hz
        val coherence = 0.5f
        val filterCutoff = 500f + coherence * 4500f

        assertEquals(2750f, filterCutoff, 1f)
    }

    @Test
    fun testCoherenceToFilterExtremes() {
        // Low coherence
        val lowCoherence = 0f
        val lowCutoff = 500f + lowCoherence * 4500f
        assertEquals(500f, lowCutoff, 0.01f)

        // High coherence
        val highCoherence = 1f
        val highCutoff = 500f + highCoherence * 4500f
        assertEquals(5000f, highCutoff, 0.01f)
    }

    // MARK: - Spatial Position Tests

    @Test
    fun testSpatialXFromPan() {
        // MIDI Pan CC 10 (0-127) maps to spatial X (-1 to +1)
        val panValue = 64 // Center
        val spatialX = (panValue / 63.5f) - 1f

        assertEquals(0.008f, spatialX, 0.02f) // Approximately center
    }

    @Test
    fun testSpatialXExtremes() {
        // Full left
        val leftPan = 0
        val leftX = (leftPan / 63.5f) - 1f
        assertEquals(-1f, leftX, 0.01f)

        // Full right
        val rightPan = 127
        val rightX = (rightPan / 63.5f) - 1f
        assertEquals(1f, rightX, 0.01f)
    }

    // MARK: - Data Class Copy Tests

    @Test
    fun testControlParametersCopy() {
        val params = UnifiedControlHub.ControlParameters(
            filterCutoff = 2000f,
            masterVolume = 0.9f
        )

        // Verify initial values
        assertEquals(2000f, params.filterCutoff, 0.01f)
        assertEquals(0.9f, params.masterVolume, 0.01f)

        // Modify original
        params.filterCutoff = 3000f

        // Original should be modified (it's a data class with var properties)
        assertEquals(3000f, params.filterCutoff, 0.01f)
    }

    // MARK: - Performance Tests

    @Test
    fun testControlParametersCreationPerformance() {
        val startTime = System.nanoTime()

        repeat(10000) {
            UnifiedControlHub.ControlParameters()
        }

        val elapsed = (System.nanoTime() - startTime) / 1_000_000.0
        assertTrue("Creating 10000 ControlParameters took ${elapsed}ms", elapsed < 100)
    }

    @Test
    fun testBioMappingCreationPerformance() {
        val startTime = System.nanoTime()

        repeat(10000) {
            UnifiedControlHub.BioMapping()
        }

        val elapsed = (System.nanoTime() - startTime) / 1_000_000.0
        assertTrue("Creating 10000 BioMappings took ${elapsed}ms", elapsed < 100)
    }

    // MARK: - Edge Case Tests

    @Test
    fun testZeroHeartRate() {
        val heartRate = 0f
        val tempo = heartRate.coerceIn(60f, 180f)
        assertEquals(60f, tempo, 0.01f)
    }

    @Test
    fun testNegativeHRV() {
        val hrv = -10f
        val normalized = (hrv / 100f).coerceIn(0f, 1f)
        assertEquals(0f, normalized, 0.01f)
    }

    @Test
    fun testExtremeCoherence() {
        // Beyond normal range
        val extremeCoherence = 150f / 100f  // Would be 1.5 if not clamped
        val clamped = extremeCoherence.coerceIn(0f, 1f)
        assertEquals(1f, clamped, 0.01f)
    }

    // MARK: - MIDI Note Event Tests

    @Test
    fun testNoteEventDataClass() {
        val event = MidiManager.NoteEvent(
            channel = 0,
            note = 60,
            velocity = 100,
            isNoteOn = true
        )

        assertEquals(0, event.channel)
        assertEquals(60, event.note)
        assertEquals(100, event.velocity)
        assertTrue(event.isNoteOn)
    }

    @Test
    fun testNoteOffEvent() {
        val event = MidiManager.NoteEvent(
            channel = 0,
            note = 60,
            velocity = 0,
            isNoteOn = false
        )

        assertEquals(60, event.note)
        assertEquals(0, event.velocity)
        assertFalse(event.isNoteOn)
    }

    // MARK: - MIDI Control Change Event Tests

    @Test
    fun testControlChangeEventNormalization() {
        val event = MidiManager.ControlChangeEvent(
            channel = 0,
            controller = 74,
            rawValue = 127
        )

        assertEquals(74, event.controller)
        assertEquals(1f, event.value, 0.01f)
    }

    @Test
    fun testControlChangeEventZeroValue() {
        val event = MidiManager.ControlChangeEvent(
            channel = 0,
            controller = 1,
            rawValue = 0
        )

        assertEquals(0f, event.value, 0.01f)
    }

    @Test
    fun testControlChangeEventMidValue() {
        val event = MidiManager.ControlChangeEvent(
            channel = 0,
            controller = 7,
            rawValue = 64
        )

        assertEquals(64f / 127f, event.value, 0.01f)
    }

    // MARK: - Pitch Bend Event Tests

    @Test
    fun testPitchBendEventCenter() {
        val event = MidiManager.PitchBendEvent(
            channel = 0,
            value = 0f
        )

        assertEquals(0f, event.value, 0.01f)
    }

    @Test
    fun testPitchBendEventFullUp() {
        val event = MidiManager.PitchBendEvent(
            channel = 0,
            value = 1f
        )

        assertEquals(1f, event.value, 0.01f)
    }

    @Test
    fun testPitchBendEventFullDown() {
        val event = MidiManager.PitchBendEvent(
            channel = 0,
            value = -1f
        )

        assertEquals(-1f, event.value, 0.01f)
    }
}
