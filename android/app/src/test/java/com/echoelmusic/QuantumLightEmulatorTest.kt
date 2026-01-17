/**
 * QuantumLightEmulatorTest.kt
 * Comprehensive unit tests for Android Quantum Light System
 *
 * Created: 2026-01-15
 */

package com.echoelmusic

import com.echoelmusic.quantum.*
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import kotlin.math.*

/**
 * Tests for Complex number operations
 */
class ComplexTest {

    @Test
    fun `complex creation with real and imaginary`() {
        val c = Complex(3f, 4f)
        assertEquals(3f, c.real, 0.001f)
        assertEquals(4f, c.imaginary, 0.001f)
    }

    @Test
    fun `complex magnitude squared`() {
        val c = Complex(3f, 4f)
        assertEquals(25f, c.magnitudeSquared, 0.001f)
    }

    @Test
    fun `complex magnitude`() {
        val c = Complex(3f, 4f)
        assertEquals(5f, c.magnitude, 0.001f)
    }

    @Test
    fun `complex phase`() {
        val c = Complex(1f, 1f)
        assertEquals(PI.toFloat() / 4f, c.phase, 0.001f)
    }

    @Test
    fun `complex addition`() {
        val a = Complex(1f, 2f)
        val b = Complex(3f, 4f)
        val result = a + b
        assertEquals(4f, result.real, 0.001f)
        assertEquals(6f, result.imaginary, 0.001f)
    }

    @Test
    fun `complex subtraction`() {
        val a = Complex(5f, 7f)
        val b = Complex(2f, 3f)
        val result = a - b
        assertEquals(3f, result.real, 0.001f)
        assertEquals(4f, result.imaginary, 0.001f)
    }

    @Test
    fun `complex multiplication`() {
        val a = Complex(1f, 2f)
        val b = Complex(3f, 4f)
        // (1+2i)(3+4i) = 3 + 4i + 6i + 8i² = 3 + 10i - 8 = -5 + 10i
        val result = a * b
        assertEquals(-5f, result.real, 0.001f)
        assertEquals(10f, result.imaginary, 0.001f)
    }

    @Test
    fun `complex scalar multiplication`() {
        val c = Complex(2f, 3f)
        val result = c * 2f
        assertEquals(4f, result.real, 0.001f)
        assertEquals(6f, result.imaginary, 0.001f)
    }

    @Test
    fun `zero complex number`() {
        val c = Complex(0f, 0f)
        assertEquals(0f, c.magnitude, 0.001f)
        assertEquals(0f, c.magnitudeSquared, 0.001f)
    }

    @Test
    fun `purely real complex number`() {
        val c = Complex(5f, 0f)
        assertEquals(5f, c.magnitude, 0.001f)
        assertEquals(0f, c.phase, 0.001f)
    }

    @Test
    fun `purely imaginary complex number`() {
        val c = Complex(0f, 5f)
        assertEquals(5f, c.magnitude, 0.001f)
        assertEquals(PI.toFloat() / 2f, c.phase, 0.001f)
    }
}

/**
 * Tests for Vector3 operations
 */
class Vector3Test {

    @Test
    fun `vector creation`() {
        val v = Vector3(1f, 2f, 3f)
        assertEquals(1f, v.x, 0.001f)
        assertEquals(2f, v.y, 0.001f)
        assertEquals(3f, v.z, 0.001f)
    }

    @Test
    fun `vector addition`() {
        val a = Vector3(1f, 2f, 3f)
        val b = Vector3(4f, 5f, 6f)
        val result = a + b
        assertEquals(5f, result.x, 0.001f)
        assertEquals(7f, result.y, 0.001f)
        assertEquals(9f, result.z, 0.001f)
    }

    @Test
    fun `vector subtraction`() {
        val a = Vector3(4f, 5f, 6f)
        val b = Vector3(1f, 2f, 3f)
        val result = a - b
        assertEquals(3f, result.x, 0.001f)
        assertEquals(3f, result.y, 0.001f)
        assertEquals(3f, result.z, 0.001f)
    }

    @Test
    fun `vector scalar multiplication`() {
        val v = Vector3(1f, 2f, 3f)
        val result = v * 2f
        assertEquals(2f, result.x, 0.001f)
        assertEquals(4f, result.y, 0.001f)
        assertEquals(6f, result.z, 0.001f)
    }

    @Test
    fun `vector length`() {
        val v = Vector3(3f, 4f, 0f)
        assertEquals(5f, v.length(), 0.001f)
    }

    @Test
    fun `vector length 3D`() {
        val v = Vector3(1f, 2f, 2f)
        assertEquals(3f, v.length(), 0.001f)
    }

    @Test
    fun `vector normalized`() {
        val v = Vector3(3f, 4f, 0f)
        val n = v.normalized()
        assertEquals(0.6f, n.x, 0.001f)
        assertEquals(0.8f, n.y, 0.001f)
        assertEquals(0f, n.z, 0.001f)
        assertEquals(1f, n.length(), 0.001f)
    }

    @Test
    fun `zero vector normalized returns self`() {
        val v = Vector3.ZERO
        val n = v.normalized()
        assertEquals(0f, n.x, 0.001f)
        assertEquals(0f, n.y, 0.001f)
        assertEquals(0f, n.z, 0.001f)
    }

    @Test
    fun `static vectors`() {
        assertEquals(0f, Vector3.ZERO.length(), 0.001f)
        assertEquals(sqrt(3f), Vector3.ONE.length(), 0.001f)
        assertEquals(1f, Vector3.UP.y, 0.001f)
        assertEquals(1f, Vector3.RIGHT.x, 0.001f)
        assertEquals(1f, Vector3.FORWARD.z, 0.001f)
    }
}

/**
 * Tests for Photon class
 */
class PhotonTest {

    @Test
    fun `photon creation with wavelength`() {
        val photon = Photon(
            position = Vector3.ZERO,
            velocity = Vector3.UP,
            wavelength = 550f, // Green light
            phase = 0f
        )
        assertEquals(550f, photon.wavelength, 0.001f)
        assertEquals(0f, photon.phase, 0.001f)
        assertEquals(1f, photon.amplitude, 0.001f)
    }

    @Test
    fun `photon frequency calculation`() {
        val photon = Photon(
            position = Vector3.ZERO,
            velocity = Vector3.ZERO,
            wavelength = 500f, // 500nm
            phase = 0f
        )
        // f = c / wavelength
        val expectedFreq = 299792458f / (500f * 1e-9f)
        assertEquals(expectedFreq, photon.frequency, expectedFreq * 0.001f)
    }

    @Test
    fun `photon energy calculation`() {
        val photon = Photon(
            position = Vector3.ZERO,
            velocity = Vector3.ZERO,
            wavelength = 500f,
            phase = 0f
        )
        // E = h * f
        val expectedEnergy = 6.626e-34f * photon.frequency
        assertEquals(expectedEnergy, photon.energy, expectedEnergy * 0.01f)
    }

    @Test
    fun `photon color red wavelength`() {
        val photon = Photon(
            position = Vector3.ZERO,
            velocity = Vector3.ZERO,
            wavelength = 700f, // Red
            phase = 0f
        )
        val color = photon.color
        assertEquals(1f, color.x, 0.1f) // Red channel
        assertTrue(color.y < 0.5f) // Green low
    }

    @Test
    fun `photon color blue wavelength`() {
        val photon = Photon(
            position = Vector3.ZERO,
            velocity = Vector3.ZERO,
            wavelength = 450f, // Blue
            phase = 0f
        )
        val color = photon.color
        assertTrue(color.z > 0.5f) // Blue channel high
    }

    @Test
    fun `photon amplitude modifiable`() {
        val photon = Photon(
            position = Vector3.ZERO,
            velocity = Vector3.ZERO,
            wavelength = 550f,
            phase = 0f,
            amplitude = 0.5f
        )
        assertEquals(0.5f, photon.amplitude, 0.001f)
    }
}

/**
 * Tests for QuantumAudioState
 */
class QuantumAudioStateTest {

    @Test
    fun `quantum state initialization with 1 qubit`() {
        val state = QuantumAudioState(numQubits = 1)
        assertEquals(1, state.numQubits)
        assertEquals(2, state.amplitudes.size) // 2^1 = 2
    }

    @Test
    fun `quantum state initialization with 4 qubits`() {
        val state = QuantumAudioState(numQubits = 4)
        assertEquals(4, state.numQubits)
        assertEquals(16, state.amplitudes.size) // 2^4 = 16
    }

    @Test
    fun `quantum state equal superposition`() {
        val state = QuantumAudioState(numQubits = 2)
        val probs = state.probabilities
        // Each state should have equal probability: 1/4 = 0.25
        probs.forEach { prob ->
            assertEquals(0.25f, prob, 0.01f)
        }
    }

    @Test
    fun `quantum state probabilities sum to 1`() {
        val state = QuantumAudioState(numQubits = 3)
        val totalProb = state.probabilities.sum()
        assertEquals(1f, totalProb, 0.01f)
    }

    @Test
    fun `quantum state normalization`() {
        val state = QuantumAudioState(numQubits = 2)
        // Manually modify amplitudes
        state.amplitudes[0] = Complex(1f, 0f)
        state.amplitudes[1] = Complex(1f, 0f)
        state.amplitudes[2] = Complex(1f, 0f)
        state.amplitudes[3] = Complex(1f, 0f)

        state.normalize()

        val totalProb = state.probabilities.sum()
        assertEquals(1f, totalProb, 0.01f)
    }

    @Test
    fun `quantum state collapse returns valid index`() {
        val state = QuantumAudioState(numQubits = 3)
        val collapsed = state.collapse()
        assertTrue(collapsed >= 0)
        assertTrue(collapsed < 8) // 2^3 = 8
    }

    @Test
    fun `quantum state hadamard gate`() {
        val state = QuantumAudioState(numQubits = 1)
        // Start in |0> state
        state.amplitudes[0] = Complex(1f, 0f)
        state.amplitudes[1] = Complex(0f, 0f)

        state.applyHadamard(0)

        // After Hadamard, should be in equal superposition
        val sqrtHalf = 1f / sqrt(2f)
        assertEquals(sqrtHalf, state.amplitudes[0].real, 0.01f)
        assertEquals(sqrtHalf, state.amplitudes[1].real, 0.01f)
    }

    @Test
    fun `quantum state hadamard preserves normalization`() {
        val state = QuantumAudioState(numQubits = 2)
        state.applyHadamard(0)
        state.applyHadamard(1)

        val totalProb = state.probabilities.sum()
        assertEquals(1f, totalProb, 0.01f)
    }
}

/**
 * Tests for LightField
 */
class LightFieldTest {

    @Test
    fun `light field creation sphere geometry`() {
        val field = LightField.create(100, LightField.Geometry.SPHERE)
        assertEquals(100, field.photons.size)
        assertEquals(LightField.Geometry.SPHERE, field.geometry)
    }

    @Test
    fun `light field creation all geometries`() {
        LightField.Geometry.values().forEach { geometry ->
            val field = LightField.create(50, geometry)
            assertEquals(50, field.photons.size)
            assertEquals(geometry, field.geometry)
        }
    }

    @Test
    fun `light field coherence calculation`() {
        val field = LightField.create(100, LightField.Geometry.FIBONACCI)
        val coherence = field.fieldCoherence
        assertTrue(coherence >= 0f)
        assertTrue(coherence <= 1f)
    }

    @Test
    fun `light field total energy positive`() {
        val field = LightField.create(100, LightField.Geometry.HELIX)
        assertTrue(field.totalEnergy > 0)
    }

    @Test
    fun `light field mean wavelength in visible range`() {
        val field = LightField.create(100, LightField.Geometry.TORUS)
        val meanWavelength = field.meanWavelength
        assertTrue(meanWavelength >= 380f) // Violet
        assertTrue(meanWavelength <= 780f) // Red
    }

    @Test
    fun `light field fibonacci photons on spiral`() {
        val field = LightField.create(50, LightField.Geometry.FIBONACCI)
        // Fibonacci positions should radiate outward from center
        val distances = field.photons.map { sqrt(it.position.x * it.position.x + it.position.y * it.position.y) }
        // Later photons should generally be farther out
        assertTrue(distances.last() > distances.first())
    }

    @Test
    fun `light field grid photons in plane`() {
        val field = LightField.create(100, LightField.Geometry.GRID)
        // Grid photons should have z = 0
        field.photons.forEach { photon ->
            assertEquals(0f, photon.position.z, 0.001f)
        }
    }

    @Test
    fun `light field flower of life geometry`() {
        val field = LightField.create(100, LightField.Geometry.FLOWER_OF_LIFE)
        // Should have photons arranged in ring patterns
        assertTrue(field.photons.isNotEmpty())
    }

    @Test
    fun `light field empty returns coherence 1`() {
        val photons = mutableListOf<Photon>()
        val field = LightField(photons, LightField.Geometry.LINE)
        // Single or zero photons should have coherence 1
        assertEquals(1f, field.fieldCoherence, 0.001f)
    }
}

/**
 * Tests for EmulationMode
 */
class EmulationModeTest {

    @Test
    fun `all emulation modes exist`() {
        assertEquals(5, EmulationMode.values().size)
        assertNotNull(EmulationMode.CLASSICAL)
        assertNotNull(EmulationMode.QUANTUM_INSPIRED)
        assertNotNull(EmulationMode.FULL_QUANTUM)
        assertNotNull(EmulationMode.HYBRID_PHOTONIC)
        assertNotNull(EmulationMode.BIO_COHERENT)
    }
}

/**
 * Tests for QuantumPreset
 */
class QuantumPresetTest {

    @Test
    fun `preset deep meditation configuration`() {
        val preset = QuantumPresets.deepMeditation
        assertEquals("deep-meditation", preset.id)
        assertEquals("Deep Meditation", preset.name)
        assertEquals(EmulationMode.BIO_COHERENT, preset.emulationMode)
        assertEquals(6f, preset.binauralFrequency, 0.001f)
        assertEquals(PresetCategory.MEDITATION, preset.category)
    }

    @Test
    fun `preset focus flow configuration`() {
        val preset = QuantumPresets.focusFlow
        assertEquals("focus-flow", preset.id)
        assertEquals(EmulationMode.QUANTUM_INSPIRED, preset.emulationMode)
        assertEquals(18f, preset.binauralFrequency, 0.001f)
        assertEquals(PresetCategory.FOCUS, preset.category)
    }

    @Test
    fun `preset quantum dream configuration`() {
        val preset = QuantumPresets.quantumDream
        assertEquals("quantum-dream", preset.id)
        assertEquals(EmulationMode.FULL_QUANTUM, preset.emulationMode)
        assertEquals(2f, preset.binauralFrequency, 0.001f)
        assertEquals(PresetCategory.SLEEP, preset.category)
    }

    @Test
    fun `all presets list contains expected presets`() {
        val presets = QuantumPresets.allPresets
        assertEquals(3, presets.size)
        assertTrue(presets.any { it.id == "deep-meditation" })
        assertTrue(presets.any { it.id == "focus-flow" })
        assertTrue(presets.any { it.id == "quantum-dream" })
    }

    @Test
    fun `preset session durations reasonable`() {
        QuantumPresets.allPresets.forEach { preset ->
            assertTrue(preset.sessionDuration > 0)
            assertTrue(preset.sessionDuration <= 7200) // Max 2 hours
        }
    }
}

/**
 * Tests for VisualizationType
 */
class VisualizationTypeTest {

    @Test
    fun `all visualization types exist`() {
        assertEquals(10, VisualizationType.values().size)
        assertNotNull(VisualizationType.INTERFERENCE_PATTERN)
        assertNotNull(VisualizationType.WAVE_FUNCTION)
        assertNotNull(VisualizationType.COHERENCE_FIELD)
        assertNotNull(VisualizationType.PHOTON_FLOW)
        assertNotNull(VisualizationType.SACRED_GEOMETRY)
        assertNotNull(VisualizationType.QUANTUM_TUNNEL)
        assertNotNull(VisualizationType.BIOPHOTON_AURA)
        assertNotNull(VisualizationType.LIGHT_MANDALA)
        assertNotNull(VisualizationType.HOLOGRAPHIC_DISPLAY)
        assertNotNull(VisualizationType.COSMIC_WEB)
    }
}

/**
 * Tests for PresetCategory
 */
class PresetCategoryTest {

    @Test
    fun `all preset categories exist`() {
        assertEquals(8, PresetCategory.values().size)
        assertNotNull(PresetCategory.MEDITATION)
        assertNotNull(PresetCategory.FOCUS)
        assertNotNull(PresetCategory.SLEEP)
        assertNotNull(PresetCategory.CREATIVITY)
        assertNotNull(PresetCategory.HEALING)
        assertNotNull(PresetCategory.ENERGY)
        assertNotNull(PresetCategory.RELAXATION)
        assertNotNull(PresetCategory.EXPLORATION)
    }
}
