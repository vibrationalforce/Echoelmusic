package com.echoelmusic.app.engines

import com.echoelmusic.app.wellness.*
import com.echoelmusic.app.presets.*
import com.echoelmusic.app.visual.*
import com.echoelmusic.app.led.*
import com.echoelmusic.app.lambda.*
import com.echoelmusic.app.quantum.*
import org.junit.Assert.*
import org.junit.Test

/**
 * Comprehensive tests for advanced Android engines
 * Wellness, Presets, Visual, LED, Lambda, Quantum
 */
class AdvancedEnginesTest {

    // =====================================================
    // WELLNESS ENGINE TESTS
    // =====================================================

    @Test
    fun testAllWellnessCategories() {
        val categories = WellnessCategory.values()
        assertTrue("Should have 25+ wellness categories", categories.size >= 25)
    }

    @Test
    fun testWellnessCategoryDisplayNames() {
        assertEquals("Relaxation", WellnessCategory.RELAXATION.displayName)
        assertEquals("Meditation", WellnessCategory.MEDITATION.displayName)
        assertEquals("Breathwork", WellnessCategory.BREATHWORK.displayName)
        assertEquals("Sleep Support", WellnessCategory.SLEEP_SUPPORT.displayName)
    }

    @Test
    fun testMoodLevelValues() {
        assertEquals(1, MoodLevel.VERY_LOW.value)
        assertEquals(2, MoodLevel.LOW.value)
        assertEquals(3, MoodLevel.NEUTRAL.value)
        assertEquals(4, MoodLevel.GOOD.value)
        assertEquals(5, MoodLevel.GREAT.value)
    }

    @Test
    fun testMoodLevelEmojis() {
        assertEquals("😔", MoodLevel.VERY_LOW.emoji)
        assertEquals("😕", MoodLevel.LOW.emoji)
        assertEquals("😐", MoodLevel.NEUTRAL.emoji)
        assertEquals("🙂", MoodLevel.GOOD.emoji)
        assertEquals("😊", MoodLevel.GREAT.emoji)
    }

    @Test
    fun testBreathingPatternPresets() {
        val patterns = BreathingPattern.ALL_PATTERNS
        assertEquals(6, patterns.size)
    }

    @Test
    fun testBoxBreathingPattern() {
        val box = BreathingPattern.BOX_BREATHING
        assertEquals("Box Breathing", box.name)
        assertEquals(4.0, box.inhaleSeconds, 0.01)
        assertEquals(4.0, box.holdInSeconds, 0.01)
        assertEquals(4.0, box.exhaleSeconds, 0.01)
        assertEquals(4.0, box.holdOutSeconds, 0.01)
        assertEquals(6, box.cycles)
        assertEquals(16.0, box.cycleDuration, 0.01)
    }

    @Test
    fun testRelaxingBreathPattern() {
        val pattern = BreathingPattern.RELAXING_BREATH
        assertEquals("Relaxing Breath (4-7-8)", pattern.name)
        assertEquals(4.0, pattern.inhaleSeconds, 0.01)
        assertEquals(7.0, pattern.holdInSeconds, 0.01)
        assertEquals(8.0, pattern.exhaleSeconds, 0.01)
    }

    @Test
    fun testMeditationGuidePresets() {
        val guides = MeditationGuide.ALL_GUIDES
        assertEquals(5, guides.size)
    }

    @Test
    fun testMeditationDifficulties() {
        val difficulties = MeditationDifficulty.values()
        assertEquals(3, difficulties.size)
        assertTrue(difficulties.contains(MeditationDifficulty.BEGINNER))
        assertTrue(difficulties.contains(MeditationDifficulty.INTERMEDIATE))
        assertTrue(difficulties.contains(MeditationDifficulty.ADVANCED))
    }

    @Test
    fun testSoundBathTypes() {
        val types = SoundType.values()
        assertTrue("Should have 10+ sound types", types.size >= 10)
    }

    @Test
    fun testWellnessDisclaimer() {
        assertTrue(WellnessDisclaimer.FULL.contains("NOT"))
        assertTrue(WellnessDisclaimer.SHORT.contains("Not medical advice"))
        assertTrue(WellnessDisclaimer.BIOFEEDBACK.contains("self-awareness"))
    }

    @Test
    fun testWellnessSessionCreation() {
        val session = WellnessSession(
            name = "Test Session",
            category = WellnessCategory.MEDITATION
        )
        assertEquals("Test Session", session.name)
        assertEquals(WellnessCategory.MEDITATION, session.category)
        assertFalse(session.isComplete)
    }

    @Test
    fun testWellnessGoalCreation() {
        val goal = WellnessGoal(
            title = "Daily Meditation",
            category = WellnessCategory.MEDITATION,
            targetMinutesPerDay = 15,
            targetDaysPerWeek = 5
        )
        assertEquals("Daily Meditation", goal.title)
        assertEquals(15, goal.targetMinutesPerDay)
        assertEquals(5, goal.targetDaysPerWeek)
        assertTrue(goal.isActive)
    }

    // =====================================================
    // PRESETS MANAGER TESTS
    // =====================================================

    @Test
    fun testBioReactivePresets() {
        val presets = BioReactivePreset.ALL
        assertEquals(10, presets.size)
    }

    @Test
    fun testDeepMeditationPreset() {
        val preset = BioReactivePreset.DEEP_MEDITATION
        assertEquals("Deep Meditation", preset.name)
        assertEquals("Meditation", preset.category)
        assertEquals(0.9, preset.hrvCoherenceTarget, 0.01)
        assertEquals(5.0, preset.breathingRateTarget, 0.01)
        assertFalse(preset.heartRateModulation)
        assertTrue(preset.coherenceModulation)
    }

    @Test
    fun testMusicalPresets() {
        val presets = MusicalPreset.ALL
        assertEquals(10, presets.size)
    }

    @Test
    fun testTechnoMinimalPreset() {
        val preset = MusicalPreset.TECHNO_MINIMAL
        assertEquals("Techno Minimal", preset.name)
        assertEquals(132.0, preset.bpm, 0.01)
        assertEquals("Am", preset.key)
        assertEquals("Minor", preset.scale)
        assertEquals("stereo", preset.spatialMode)
    }

    @Test
    fun testVisualPresets() {
        val presets = VisualPreset.ALL
        assertEquals(10, presets.size)
    }

    @Test
    fun testSacredMandalaPreset() {
        val preset = VisualPreset.SACRED_MANDALA
        assertEquals("Sacred Mandala", preset.name)
        assertEquals("Sacred Geometry", preset.category)
        assertEquals("mandala", preset.visualMode)
        assertEquals(0.9, preset.bioReactivity, 0.01)
    }

    @Test
    fun testLightingPresets() {
        val presets = LightingPreset.ALL
        assertEquals(10, presets.size)
    }

    @Test
    fun testStreamingPresets() {
        val presets = StreamingPreset.ALL
        assertEquals(5, presets.size)
    }

    @Test
    fun testCollaborationPresets() {
        val presets = CollaborationPreset.ALL
        assertEquals(5, presets.size)
    }

    @Test
    fun testPresetsManagerTotalCount() {
        val manager = PresetsManager()
        assertTrue("Should have 50+ presets", manager.getTotalPresetCount() >= 50)
    }

    @Test
    fun testPresetsManagerAllCategories() {
        val manager = PresetsManager()
        val categories = manager.getAllCategories()
        assertTrue("Should have multiple categories", categories.size >= 10)
    }

    // =====================================================
    // VISUAL ENGINE TESTS
    // =====================================================

    @Test
    fun testAllVisualModes() {
        val modes = VisualMode.values()
        assertTrue("Should have 30 visual modes", modes.size >= 30)
    }

    @Test
    fun testVisualModeCategories() {
        assertTrue(VisualMode.FLOWER_OF_LIFE.category == VisualCategory.SACRED_GEOMETRY)
        assertTrue(VisualMode.MANDELBROT.category == VisualCategory.FRACTAL)
        assertTrue(VisualMode.PARTICLE_FLOW.category == VisualCategory.PARTICLES)
        assertTrue(VisualMode.QUANTUM_WAVE.category == VisualCategory.QUANTUM)
    }

    @Test
    fun testProjectionModes() {
        val modes = ProjectionMode.values()
        assertTrue("Should have 8 projection modes", modes.size >= 8)
    }

    @Test
    fun testBlendModes() {
        val modes = BlendMode.values()
        assertTrue("Should have 15+ blend modes", modes.size >= 15)
        assertTrue(modes.contains(BlendMode.QUANTUM_BLEND))
        assertTrue(modes.contains(BlendMode.BIO_COHERENT))
    }

    @Test
    fun testColorPalettes() {
        val palettes = ColorPalette.values()
        assertTrue("Should have 10+ palettes", palettes.size >= 10)
    }

    @Test
    fun testColorPaletteColors() {
        val quantum = ColorPalette.QUANTUM
        assertTrue("Palette should have colors", quantum.colors.isNotEmpty())
    }

    @Test
    fun testVisualLayerCreation() {
        val layer = VisualLayer(
            mode = VisualMode.FLOWER_OF_LIFE,
            opacity = 0.8f,
            blendMode = BlendMode.ADD
        )
        assertEquals(VisualMode.FLOWER_OF_LIFE, layer.mode)
        assertEquals(0.8f, layer.opacity, 0.01f)
        assertEquals(BlendMode.ADD, layer.blendMode)
        assertTrue(layer.isVisible)
    }

    @Test
    fun testBioReactiveMapping() {
        val mapping = BioReactiveMapping(
            source = BioSource.COHERENCE,
            target = VisualTarget.BRIGHTNESS,
            curve = MappingCurve.S_CURVE,
            intensity = 0.8f
        )
        assertEquals(BioSource.COHERENCE, mapping.source)
        assertEquals(VisualTarget.BRIGHTNESS, mapping.target)
        assertEquals(MappingCurve.S_CURVE, mapping.curve)
    }

    @Test
    fun testVisualPresetConfigs() {
        val configs = VisualPresetConfig.ALL
        assertEquals(4, configs.size)
    }

    // =====================================================
    // LED LIGHTING CONTROLLER TESTS
    // =====================================================

    @Test
    fun testDMXProtocols() {
        val protocols = DMXProtocol.values()
        assertEquals(5, protocols.size)
        assertTrue(protocols.contains(DMXProtocol.ART_NET))
        assertTrue(protocols.contains(DMXProtocol.SACN))
    }

    @Test
    fun testFixtureTypes() {
        val types = FixtureType.values()
        assertTrue("Should have 15+ fixture types", types.size >= 15)
    }

    @Test
    fun testFixtureTypeChannels() {
        assertEquals(1, FixtureType.DIMMER.channels)
        assertEquals(3, FixtureType.RGB.channels)
        assertEquals(4, FixtureType.RGBW.channels)
        assertEquals(16, FixtureType.MOVING_HEAD_WASH.channels)
    }

    @Test
    fun testLightColorPresets() {
        assertEquals(255, LightColor.RED.red)
        assertEquals(0, LightColor.RED.green)
        assertEquals(0, LightColor.RED.blue)

        assertEquals(0, LightColor.GREEN.red)
        assertEquals(255, LightColor.GREEN.green)

        assertEquals(0, LightColor.BLUE.red)
        assertEquals(255, LightColor.BLUE.blue)
    }

    @Test
    fun testLightColorFromHSV() {
        val red = LightColor.fromHSV(0f, 1f, 1f)
        assertEquals(255, red.red)
        assertEquals(0, red.green)
        assertEquals(0, red.blue)

        val green = LightColor.fromHSV(120f, 1f, 1f)
        assertEquals(0, green.red)
        assertEquals(255, green.green)
    }

    @Test
    fun testFixtureCreation() {
        val fixture = Fixture(
            name = "Test PAR",
            type = FixtureType.RGB,
            dmxAddress = 1,
            universe = 0
        )
        assertEquals("Test PAR", fixture.name)
        assertEquals(FixtureType.RGB, fixture.type)
        assertEquals(1, fixture.dmxAddress)
        assertTrue(fixture.isActive)
    }

    @Test
    fun testLightBioSources() {
        val sources = LightBioSource.values()
        assertTrue("Should have 10 bio sources", sources.size >= 10)
    }

    @Test
    fun testLightTargets() {
        val targets = LightTarget.values()
        assertTrue("Should have 8+ targets", targets.size >= 8)
    }

    @Test
    fun testTriggerTypes() {
        val types = TriggerType.values()
        assertEquals(8, types.size)
        assertTrue(types.contains(TriggerType.COHERENCE))
        assertTrue(types.contains(TriggerType.BPM))
    }

    // =====================================================
    // LAMBDA MODE ENGINE TESTS
    // =====================================================

    @Test
    fun testTranscendenceStates() {
        val states = TranscendenceState.values()
        assertEquals(8, states.size)
    }

    @Test
    fun testTranscendenceStateLevels() {
        assertEquals(0, TranscendenceState.DORMANT.level)
        assertEquals(1, TranscendenceState.AWAKENING.level)
        assertEquals(2, TranscendenceState.AWARE.level)
        assertEquals(3, TranscendenceState.FLOWING.level)
        assertEquals(4, TranscendenceState.COHERENT.level)
        assertEquals(5, TranscendenceState.TRANSCENDENT.level)
        assertEquals(6, TranscendenceState.UNIFIED.level)
        assertEquals(7, TranscendenceState.LAMBDA.level)
    }

    @Test
    fun testUnifiedBioDataDefaults() {
        val data = UnifiedBioData()
        assertEquals(70f, data.heartRate, 0.01f)
        assertEquals(50f, data.hrv, 0.01f)
        assertEquals(0.5f, data.coherence, 0.01f)
        assertEquals(12f, data.breathingRate, 0.01f)
    }

    @Test
    fun testUnifiedBioDataScores() {
        val data = UnifiedBioData(hrv = 80f, coherence = 0.8f)
        assertEquals(0.8f, data.hrvScore, 0.01f)
        assertEquals(0.8f, data.coherenceScore, 0.01f)
    }

    @Test
    fun testBreathCoherence() {
        // Optimal breathing is 6 breaths/min
        val optimal = UnifiedBioData(breathingRate = 6f)
        assertEquals(1.0f, optimal.breathCoherence, 0.01f)

        val fast = UnifiedBioData(breathingRate = 12f)
        assertTrue(fast.breathCoherence < 1.0f)
    }

    @Test
    fun testLambdaScoreLevel() {
        val lowScore = LambdaScore(overall = 0.3f)
        assertEquals(2, lowScore.level)

        val highScore = LambdaScore(overall = 0.9f)
        assertEquals(6, highScore.level)

        val maxScore = LambdaScore(overall = 1.0f)
        assertEquals(7, maxScore.level)
    }

    @Test
    fun testLambdaScoreTranscendenceState() {
        val lowScore = LambdaScore(overall = 0.1f)
        assertEquals(TranscendenceState.DORMANT, lowScore.transcendenceState)

        val highScore = LambdaScore(overall = 0.95f)
        assertEquals(TranscendenceState.UNIFIED, highScore.transcendenceState)
    }

    @Test
    fun testLambdaHealthDisclaimer() {
        assertTrue(LambdaHealthDisclaimer.FULL.contains("NOT"))
        assertTrue(LambdaHealthDisclaimer.FULL.contains("medical"))
        assertTrue(LambdaHealthDisclaimer.SHORT.contains("Not medical advice"))
    }

    @Test
    fun testVisualModulation() {
        val modulation = VisualModulation(
            brightness = 0.8f,
            saturation = 0.7f,
            speed = 0.5f,
            complexity = 0.6f,
            breathScale = 1.0f,
            pulseRate = 1.2f,
            hue = 0.5f
        )
        assertEquals(0.8f, modulation.brightness, 0.01f)
        assertEquals(0.5f, modulation.speed, 0.01f)
    }

    @Test
    fun testAudioModulation() {
        val modulation = AudioModulation(
            filterCutoff = 2000f,
            reverbMix = 0.3f,
            volume = 0.7f,
            tempo = 90f,
            harmonicity = 0.8f
        )
        assertEquals(2000f, modulation.filterCutoff, 0.01f)
        assertEquals(90f, modulation.tempo, 0.01f)
    }

    // =====================================================
    // QUANTUM LIGHT EMULATOR TESTS
    // =====================================================

    @Test
    fun testEmulationModes() {
        val modes = EmulationMode.values()
        assertEquals(5, modes.size)
    }

    @Test
    fun testEmulationModeNames() {
        assertEquals("Classical", EmulationMode.CLASSICAL.displayName)
        assertEquals("Quantum Inspired", EmulationMode.QUANTUM_INSPIRED.displayName)
        assertEquals("Bio-Coherent", EmulationMode.BIO_COHERENT.displayName)
    }

    @Test
    fun testVisualizationTypes() {
        val types = VisualizationType.values()
        assertEquals(10, types.size)
    }

    @Test
    fun testQuantumStatePresets() {
        val ground = QuantumState.GROUND
        assertEquals(1f, ground.probability0, 0.01f)
        assertEquals(0f, ground.probability1, 0.01f)

        val excited = QuantumState.EXCITED
        assertEquals(0f, excited.probability0, 0.01f)
        assertEquals(1f, excited.probability1, 0.01f)

        val superposition = QuantumState.SUPERPOSITION
        assertTrue(superposition.probability0 > 0.4f)
        assertTrue(superposition.probability1 > 0.4f)
    }

    @Test
    fun testPhotonCreation() {
        val photon = Photon(
            x = 0f, y = 0f, z = 0f,
            wavelength = 550f,
            intensity = 1.0f
        )
        assertEquals(550f, photon.wavelength, 0.01f)
        assertEquals(1.0f, photon.intensity, 0.01f)
        assertTrue(photon.coherent)
    }

    @Test
    fun testPhotonUpdate() {
        val photon = Photon(
            x = 0f, y = 0f,
            vx = 1f, vy = 1f
        )
        photon.update(1f)
        assertEquals(1f, photon.x, 0.01f)
        assertEquals(1f, photon.y, 0.01f)
    }

    @Test
    fun testFieldGeometries() {
        val geometries = FieldGeometry.values()
        assertTrue("Should have 9 geometries", geometries.size >= 9)
        assertTrue(geometries.contains(FieldGeometry.FIBONACCI))
        assertTrue(geometries.contains(FieldGeometry.TOROIDAL))
        assertTrue(geometries.contains(FieldGeometry.CALABI_YAU))
    }

    @Test
    fun testWaveFunctionNormalization() {
        val wf = WaveFunction(resolution = 10)
        for (i in wf.amplitudes.indices) {
            wf.amplitudes[i] = 1f
        }
        wf.normalize()

        val sumSq = wf.amplitudes.sumOf { (it * it).toDouble() }
        assertEquals(1.0, sumSq, 0.01)
    }

    @Test
    fun testWaveFunctionProbabilityDensity() {
        val wf = WaveFunction(resolution = 4)
        wf.amplitudes[0] = 0.5f
        wf.amplitudes[1] = 0.5f
        wf.amplitudes[2] = 0.5f
        wf.amplitudes[3] = 0.5f

        val density = wf.probabilityDensity()
        assertEquals(0.25f, density[0], 0.01f)
    }

    @Test
    fun testQuantumEmulatorState() {
        val state = QuantumEmulatorState(
            mode = EmulationMode.BIO_COHERENT,
            visualizationType = VisualizationType.COHERENCE_FIELD,
            coherenceLevel = 0.8f
        )
        assertEquals(EmulationMode.BIO_COHERENT, state.mode)
        assertEquals(0.8f, state.coherenceLevel, 0.01f)
    }

    // =====================================================
    // PERFORMANCE TESTS
    // =====================================================

    @Test
    fun testPresetLookupPerformance() {
        val manager = PresetsManager()
        val startTime = System.nanoTime()

        repeat(10000) {
            manager.getAllPresets()
        }

        val elapsed = (System.nanoTime() - startTime) / 1_000_000.0
        assertTrue("Preset lookup should be fast: ${elapsed}ms", elapsed < 500)
    }

    @Test
    fun testWaveFunctionNormalizationPerformance() {
        val wf = WaveFunction(resolution = 1024)
        val startTime = System.nanoTime()

        repeat(10000) {
            wf.normalize()
        }

        val elapsed = (System.nanoTime() - startTime) / 1_000_000.0
        assertTrue("Wave function normalization should be fast: ${elapsed}ms", elapsed < 500)
    }

    @Test
    fun testPhotonUpdatePerformance() {
        val photons = (0 until 1000).map { Photon() }
        val startTime = System.nanoTime()

        repeat(1000) {
            photons.forEach { it.update(0.016f) }
        }

        val elapsed = (System.nanoTime() - startTime) / 1_000_000.0
        assertTrue("Photon updates should be fast: ${elapsed}ms", elapsed < 500)
    }

    @Test
    fun testLightColorHSVPerformance() {
        val startTime = System.nanoTime()

        repeat(10000) {
            LightColor.fromHSV((it % 360).toFloat(), 1f, 1f)
        }

        val elapsed = (System.nanoTime() - startTime) / 1_000_000.0
        assertTrue("HSV conversion should be fast: ${elapsed}ms", elapsed < 200)
    }
}
