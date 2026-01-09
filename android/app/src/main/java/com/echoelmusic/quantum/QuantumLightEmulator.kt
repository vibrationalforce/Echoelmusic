/**
 * QuantumLightEmulator.kt
 * Echoelmusic - Android Quantum Light System
 *
 * Quantum-inspired audio processing for Android with full feature parity
 * 300% Power Mode - Tauchfliegen Edition
 *
 * Created: 2026-01-05
 */

package com.echoelmusic.quantum

import android.content.Context
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlin.math.*
import kotlin.random.Random

// MARK: - Quantum State

/**
 * Represents a quantum audio state with superposition amplitudes
 */
data class QuantumAudioState(
    val numQubits: Int,
    val amplitudes: MutableList<Complex> = mutableListOf()
) {
    init {
        val size = 1 shl numQubits // 2^numQubits
        if (amplitudes.isEmpty()) {
            // Initialize to equal superposition
            val amplitude = 1.0f / sqrt(size.toFloat())
            repeat(size) {
                amplitudes.add(Complex(amplitude, 0f))
            }
        }
    }

    val probabilities: List<Float>
        get() = amplitudes.map { it.magnitudeSquared }

    fun normalize() {
        val total = sqrt(amplitudes.sumOf { it.magnitudeSquared.toDouble() }.toFloat())
        if (total > 0) {
            amplitudes.forEachIndexed { index, c ->
                amplitudes[index] = Complex(c.real / total, c.imaginary / total)
            }
        }
    }

    fun collapse(): Int {
        val probs = probabilities
        val random = Random.nextFloat()
        var cumulative = 0f

        for (i in probs.indices) {
            cumulative += probs[i]
            if (random < cumulative) {
                return i
            }
        }
        return probs.lastIndex
    }

    fun applyHadamard(qubit: Int) {
        val size = amplitudes.size
        val mask = 1 shl qubit
        val sqrtHalf = 1f / sqrt(2f)

        for (i in 0 until size step (mask * 2)) {
            for (j in i until i + mask) {
                val a = amplitudes[j]
                val b = amplitudes[j + mask]

                amplitudes[j] = Complex(
                    (a.real + b.real) * sqrtHalf,
                    (a.imaginary + b.imaginary) * sqrtHalf
                )
                amplitudes[j + mask] = Complex(
                    (a.real - b.real) * sqrtHalf,
                    (a.imaginary - b.imaginary) * sqrtHalf
                )
            }
        }
    }
}

/**
 * Complex number for quantum amplitudes
 */
data class Complex(val real: Float, val imaginary: Float) {
    val magnitudeSquared: Float
        get() = real * real + imaginary * imaginary

    val magnitude: Float
        get() = sqrt(magnitudeSquared)

    val phase: Float
        get() = atan2(imaginary, real)

    operator fun plus(other: Complex) = Complex(real + other.real, imaginary + other.imaginary)
    operator fun minus(other: Complex) = Complex(real - other.real, imaginary - other.imaginary)
    operator fun times(other: Complex) = Complex(
        real * other.real - imaginary * other.imaginary,
        real * other.imaginary + imaginary * other.real
    )
    operator fun times(scalar: Float) = Complex(real * scalar, imaginary * scalar)
}

// MARK: - Photon

/**
 * Represents a single photon in the light field
 */
data class Photon(
    var position: Vector3,
    var velocity: Vector3,
    val wavelength: Float, // nm (380-780 visible spectrum)
    var phase: Float,
    var amplitude: Float = 1f
) {
    val color: Vector3
        get() = wavelengthToRGB(wavelength)

    val frequency: Float
        get() = 299792458f / (wavelength * 1e-9f) // c / wavelength

    val energy: Float
        get() = 6.626e-34f * frequency // Planck's constant * frequency

    private fun wavelengthToRGB(wavelength: Float): Vector3 {
        val w = wavelength.coerceIn(380f, 780f)

        return when {
            w < 440 -> Vector3((440 - w) / (440 - 380), 0f, 1f)
            w < 490 -> Vector3(0f, (w - 440) / (490 - 440), 1f)
            w < 510 -> Vector3(0f, 1f, (510 - w) / (510 - 490))
            w < 580 -> Vector3((w - 510) / (580 - 510), 1f, 0f)
            w < 645 -> Vector3(1f, (645 - w) / (645 - 580), 0f)
            else -> Vector3(1f, 0f, 0f)
        }
    }
}

/**
 * Simple 3D vector
 */
data class Vector3(val x: Float, val y: Float, val z: Float) {
    operator fun plus(other: Vector3) = Vector3(x + other.x, y + other.y, z + other.z)
    operator fun minus(other: Vector3) = Vector3(x - other.x, y - other.y, z - other.z)
    operator fun times(scalar: Float) = Vector3(x * scalar, y * scalar, z * scalar)

    fun length() = sqrt(x * x + y * y + z * z)
    fun normalized(): Vector3 {
        val len = length()
        return if (len > 0) Vector3(x / len, y / len, z / len) else this
    }

    companion object {
        val ZERO = Vector3(0f, 0f, 0f)
        val ONE = Vector3(1f, 1f, 1f)
        val UP = Vector3(0f, 1f, 0f)
        val RIGHT = Vector3(1f, 0f, 0f)
        val FORWARD = Vector3(0f, 0f, 1f)
    }
}

// MARK: - Light Field

/**
 * Collection of photons forming a coherent light field
 */
data class LightField(
    val photons: MutableList<Photon>,
    val geometry: Geometry
) {
    enum class Geometry {
        SPHERE, GRID, FIBONACCI, HELIX, TORUS,
        FLOWER_OF_LIFE, VORTEX, LINE, PLANE, RANDOM
    }

    val fieldCoherence: Float
        get() {
            if (photons.size < 2) return 1f

            var phaseSum = 0f
            var phaseVariance = 0f

            val meanPhase = photons.map { it.phase }.average().toFloat()
            photons.forEach { photon ->
                val diff = photon.phase - meanPhase
                phaseVariance += diff * diff
            }

            return 1f - (phaseVariance / photons.size).coerceIn(0f, 1f)
        }

    val totalEnergy: Float
        get() = photons.sumOf { it.energy.toDouble() }.toFloat()

    val meanWavelength: Float
        get() = if (photons.isNotEmpty()) photons.map { it.wavelength }.average().toFloat() else 550f

    companion object {
        fun create(photonCount: Int, geometry: Geometry): LightField {
            val photons = mutableListOf<Photon>()

            when (geometry) {
                Geometry.SPHERE -> createSpherePhotons(photons, photonCount)
                Geometry.GRID -> createGridPhotons(photons, photonCount)
                Geometry.FIBONACCI -> createFibonacciPhotons(photons, photonCount)
                Geometry.HELIX -> createHelixPhotons(photons, photonCount)
                Geometry.TORUS -> createTorusPhotons(photons, photonCount)
                Geometry.FLOWER_OF_LIFE -> createFlowerOfLifePhotons(photons, photonCount)
                Geometry.VORTEX -> createVortexPhotons(photons, photonCount)
                Geometry.LINE -> createLinePhotons(photons, photonCount)
                Geometry.PLANE -> createPlanePhotons(photons, photonCount)
                Geometry.RANDOM -> createRandomPhotons(photons, photonCount)
            }

            return LightField(photons, geometry)
        }

        private fun createSpherePhotons(photons: MutableList<Photon>, count: Int) {
            repeat(count) { i ->
                val phi = acos(1 - 2 * (i + 0.5f) / count)
                val theta = PI.toFloat() * (1 + sqrt(5f)) * i

                photons.add(Photon(
                    position = Vector3(
                        sin(phi) * cos(theta),
                        sin(phi) * sin(theta),
                        cos(phi)
                    ),
                    velocity = Vector3.ZERO,
                    wavelength = 380f + (400f * i / count),
                    phase = theta % (2 * PI.toFloat())
                ))
            }
        }

        private fun createGridPhotons(photons: MutableList<Photon>, count: Int) {
            val side = ceil(sqrt(count.toFloat())).toInt()
            repeat(count) { i ->
                val x = (i % side).toFloat() / side - 0.5f
                val y = (i / side).toFloat() / side - 0.5f

                photons.add(Photon(
                    position = Vector3(x, y, 0f),
                    velocity = Vector3.ZERO,
                    wavelength = 480f + 200f * Random.nextFloat(),
                    phase = (x + y) * PI.toFloat()
                ))
            }
        }

        private fun createFibonacciPhotons(photons: MutableList<Photon>, count: Int) {
            val goldenRatio = (1 + sqrt(5f)) / 2

            repeat(count) { i ->
                val theta = 2 * PI.toFloat() * i / goldenRatio
                val r = sqrt(i.toFloat()) * 0.1f

                photons.add(Photon(
                    position = Vector3(r * cos(theta), r * sin(theta), 0f),
                    velocity = Vector3.ZERO,
                    wavelength = 520f + 60f * sin(theta),
                    phase = theta
                ))
            }
        }

        private fun createHelixPhotons(photons: MutableList<Photon>, count: Int) {
            repeat(count) { i ->
                val t = i.toFloat() / count
                val theta = t * 4 * PI.toFloat()

                photons.add(Photon(
                    position = Vector3(cos(theta) * 0.5f, t - 0.5f, sin(theta) * 0.5f),
                    velocity = Vector3.UP * 0.01f,
                    wavelength = 400f + 300f * t,
                    phase = theta
                ))
            }
        }

        private fun createTorusPhotons(photons: MutableList<Photon>, count: Int) {
            val majorRadius = 0.5f
            val minorRadius = 0.2f

            repeat(count) { i ->
                val u = (i % 20) * 2 * PI.toFloat() / 20
                val v = (i / 20) * 2 * PI.toFloat() / (count / 20)

                photons.add(Photon(
                    position = Vector3(
                        (majorRadius + minorRadius * cos(v)) * cos(u),
                        minorRadius * sin(v),
                        (majorRadius + minorRadius * cos(v)) * sin(u)
                    ),
                    velocity = Vector3.ZERO,
                    wavelength = 450f + 250f * (cos(u) + 1) / 2,
                    phase = u + v
                ))
            }
        }

        private fun createFlowerOfLifePhotons(photons: MutableList<Photon>, count: Int) {
            val rings = 3
            val photonsPerRing = count / (rings + 1)

            // Center
            repeat(photonsPerRing) { i ->
                val angle = i * 2 * PI.toFloat() / photonsPerRing
                photons.add(Photon(
                    position = Vector3(cos(angle) * 0.1f, sin(angle) * 0.1f, 0f),
                    velocity = Vector3.ZERO,
                    wavelength = 550f,
                    phase = angle
                ))
            }

            // Outer rings
            repeat(rings) { ring ->
                val ringRadius = (ring + 1) * 0.2f
                repeat(6) { petal ->
                    val petalAngle = petal * PI.toFloat() / 3
                    val cx = cos(petalAngle) * ringRadius
                    val cy = sin(petalAngle) * ringRadius

                    repeat(photonsPerRing / 6) { i ->
                        val angle = i * 2 * PI.toFloat() / (photonsPerRing / 6)
                        photons.add(Photon(
                            position = Vector3(cx + cos(angle) * 0.15f, cy + sin(angle) * 0.15f, 0f),
                            velocity = Vector3.ZERO,
                            wavelength = 400f + 50f * ring + 30f * petal,
                            phase = angle + petalAngle
                        ))
                    }
                }
            }
        }

        private fun createVortexPhotons(photons: MutableList<Photon>, count: Int) {
            repeat(count) { i ->
                val t = i.toFloat() / count
                val r = t * 0.8f
                val theta = t * 6 * PI.toFloat()

                photons.add(Photon(
                    position = Vector3(r * cos(theta), r * sin(theta), t - 0.5f),
                    velocity = Vector3(sin(theta), -cos(theta), 0.1f) * 0.01f,
                    wavelength = 380f + 400f * t,
                    phase = theta
                ))
            }
        }

        private fun createLinePhotons(photons: MutableList<Photon>, count: Int) {
            repeat(count) { i ->
                val t = i.toFloat() / count - 0.5f
                photons.add(Photon(
                    position = Vector3(t, 0f, 0f),
                    velocity = Vector3.RIGHT * 0.01f,
                    wavelength = 550f,
                    phase = t * 2 * PI.toFloat()
                ))
            }
        }

        private fun createPlanePhotons(photons: MutableList<Photon>, count: Int) {
            val side = ceil(sqrt(count.toFloat())).toInt()
            repeat(count) { i ->
                val x = (i % side).toFloat() / side - 0.5f
                val y = (i / side).toFloat() / side - 0.5f
                photons.add(Photon(
                    position = Vector3(x, y, 0f),
                    velocity = Vector3.FORWARD * 0.01f,
                    wavelength = 500f + sin(x * 10) * 100f,
                    phase = (x * x + y * y) * PI.toFloat()
                ))
            }
        }

        private fun createRandomPhotons(photons: MutableList<Photon>, count: Int) {
            repeat(count) {
                photons.add(Photon(
                    position = Vector3(
                        Random.nextFloat() - 0.5f,
                        Random.nextFloat() - 0.5f,
                        Random.nextFloat() - 0.5f
                    ),
                    velocity = Vector3(
                        Random.nextFloat() - 0.5f,
                        Random.nextFloat() - 0.5f,
                        Random.nextFloat() - 0.5f
                    ).normalized() * 0.01f,
                    wavelength = 380f + Random.nextFloat() * 400f,
                    phase = Random.nextFloat() * 2 * PI.toFloat()
                ))
            }
        }
    }
}

// MARK: - Emulation Mode

enum class EmulationMode {
    CLASSICAL,
    QUANTUM_INSPIRED,
    FULL_QUANTUM,
    HYBRID_PHOTONIC,
    BIO_COHERENT
}

// MARK: - Quantum Light Emulator

/**
 * Main quantum light emulator for Android
 * Full feature parity with iOS implementation
 */
@RequiresApi(Build.VERSION_CODES.O)
class QuantumLightEmulator(
    private val context: Context
) : ViewModel() {

    // MARK: - State

    private val _emulationMode = MutableStateFlow(EmulationMode.BIO_COHERENT)
    val emulationMode: StateFlow<EmulationMode> = _emulationMode.asStateFlow()

    private val _coherenceLevel = MutableStateFlow(0.5f)
    val coherenceLevel: StateFlow<Float> = _coherenceLevel.asStateFlow()

    private val _quantumState = MutableStateFlow<QuantumAudioState?>(null)
    val quantumState: StateFlow<QuantumAudioState?> = _quantumState.asStateFlow()

    private val _lightField = MutableStateFlow<LightField?>(null)
    val lightField: StateFlow<LightField?> = _lightField.asStateFlow()

    private val _isRunning = MutableStateFlow(false)
    val isRunning: StateFlow<Boolean> = _isRunning.asStateFlow()

    private val _hrvCoherence = MutableStateFlow(50.0)
    val hrvCoherence: StateFlow<Double> = _hrvCoherence.asStateFlow()

    private val _heartRate = MutableStateFlow(70.0)
    val heartRate: StateFlow<Double> = _heartRate.asStateFlow()

    // Processing
    private var processingJob: Job? = null
    private var photonCount = 100
    private var numQubits = 4

    // MARK: - Lifecycle

    fun start() {
        if (_isRunning.value) return

        _isRunning.value = true
        _quantumState.value = QuantumAudioState(numQubits)
        _lightField.value = LightField.create(photonCount, LightField.Geometry.FIBONACCI)

        startProcessingLoop()
    }

    fun stop() {
        _isRunning.value = false
        processingJob?.cancel()
        processingJob = null
    }

    // MARK: - Mode Control

    fun setMode(mode: EmulationMode) {
        _emulationMode.value = mode

        // Adjust parameters based on mode
        when (mode) {
            EmulationMode.CLASSICAL -> {
                numQubits = 2
                photonCount = 50
            }
            EmulationMode.QUANTUM_INSPIRED -> {
                numQubits = 4
                photonCount = 100
            }
            EmulationMode.FULL_QUANTUM -> {
                numQubits = 8
                photonCount = 200
            }
            EmulationMode.HYBRID_PHOTONIC -> {
                numQubits = 6
                photonCount = 150
            }
            EmulationMode.BIO_COHERENT -> {
                numQubits = 4
                photonCount = 100
            }
        }

        // Recreate state and field
        _quantumState.value = QuantumAudioState(numQubits)
        _lightField.value = LightField.create(photonCount, geometryForMode(mode))
    }

    private fun geometryForMode(mode: EmulationMode): LightField.Geometry {
        return when (mode) {
            EmulationMode.CLASSICAL -> LightField.Geometry.GRID
            EmulationMode.QUANTUM_INSPIRED -> LightField.Geometry.SPHERE
            EmulationMode.FULL_QUANTUM -> LightField.Geometry.FIBONACCI
            EmulationMode.HYBRID_PHOTONIC -> LightField.Geometry.HELIX
            EmulationMode.BIO_COHERENT -> LightField.Geometry.FLOWER_OF_LIFE
        }
    }

    // MARK: - Bio Feedback

    fun updateBioFeedback(coherence: Float, hrv: Double, heartRate: Double) {
        _hrvCoherence.value = hrv
        _heartRate.value = heartRate

        // Bio-coherent mode responds to biometrics
        if (_emulationMode.value == EmulationMode.BIO_COHERENT) {
            val bioCoherence = (coherence * 0.6f + hrv.toFloat() / 100f * 0.4f).coerceIn(0f, 1f)
            _coherenceLevel.value = bioCoherence

            // Modulate photon phases based on heart rate
            _lightField.value?.photons?.forEach { photon ->
                val heartPhase = (heartRate / 60.0).toFloat() * 2 * PI.toFloat()
                photon.phase = (photon.phase + heartPhase * 0.01f) % (2 * PI.toFloat())
            }
        }
    }

    // MARK: - Processing Loop

    private fun startProcessingLoop() {
        processingJob = viewModelScope.launch(Dispatchers.Default) {
            while (_isRunning.value) {
                processQuantumFrame()
                delay(16) // ~60 FPS
            }
        }
    }

    private fun processQuantumFrame() {
        val state = _quantumState.value ?: return
        val field = _lightField.value ?: return

        when (_emulationMode.value) {
            EmulationMode.CLASSICAL -> processClassical(state, field)
            EmulationMode.QUANTUM_INSPIRED -> processQuantumInspired(state, field)
            EmulationMode.FULL_QUANTUM -> processFullQuantum(state, field)
            EmulationMode.HYBRID_PHOTONIC -> processHybridPhotonic(state, field)
            EmulationMode.BIO_COHERENT -> processBioCoherent(state, field)
        }

        // Update coherence from field
        _coherenceLevel.value = field.fieldCoherence
    }

    private fun processClassical(state: QuantumAudioState, field: LightField) {
        // Simple wave propagation
        field.photons.forEach { photon ->
            photon.position = photon.position + photon.velocity
            photon.phase = (photon.phase + 0.1f) % (2 * PI.toFloat())
        }
    }

    private fun processQuantumInspired(state: QuantumAudioState, field: LightField) {
        // Apply Hadamard gates
        for (q in 0 until state.numQubits) {
            if (Random.nextFloat() < 0.1f) {
                state.applyHadamard(q)
            }
        }

        // Modulate photons based on state probabilities
        val probs = state.probabilities
        field.photons.forEachIndexed { index, photon ->
            val probIndex = index % probs.size
            photon.amplitude = probs[probIndex]
            photon.phase = (photon.phase + probs[probIndex] * 0.5f) % (2 * PI.toFloat())
        }
    }

    private fun processFullQuantum(state: QuantumAudioState, field: LightField) {
        // Full quantum simulation with collapse
        for (q in 0 until state.numQubits) {
            state.applyHadamard(q)
        }

        // Occasional collapse
        if (Random.nextFloat() < 0.05f) {
            val collapsed = state.collapse()

            // Reset to collapsed state
            state.amplitudes.forEachIndexed { index, _ ->
                state.amplitudes[index] = if (index == collapsed) Complex(1f, 0f) else Complex(0f, 0f)
            }
        }

        // Update photons
        field.photons.forEach { photon ->
            photon.position = photon.position + photon.velocity
        }
    }

    private fun processHybridPhotonic(state: QuantumAudioState, field: LightField) {
        // Light-matter interaction simulation
        val totalIntensity = field.photons.sumOf { it.amplitude.toDouble() }.toFloat()

        state.amplitudes.forEachIndexed { index, amp ->
            val modulation = sin(totalIntensity * index.toFloat() * 0.1f)
            state.amplitudes[index] = Complex(amp.real * (1 + modulation * 0.1f), amp.imaginary)
        }

        state.normalize()

        // Photon evolution
        field.photons.forEach { photon ->
            val stateInfluence = state.probabilities[0]
            photon.phase = (photon.phase + stateInfluence * 0.2f) % (2 * PI.toFloat())
        }
    }

    private fun processBioCoherent(state: QuantumAudioState, field: LightField) {
        val hrv = _hrvCoherence.value.toFloat() / 100f
        val hr = _heartRate.value.toFloat()

        // HRV modulates coherence
        state.amplitudes.forEachIndexed { index, amp ->
            val hrvModulation = hrv * sin(index.toFloat() * 0.5f)
            state.amplitudes[index] = Complex(amp.real + hrvModulation * 0.1f, amp.imaginary)
        }
        state.normalize()

        // Heart rate modulates photon wavelengths
        field.photons.forEach { photon ->
            val hrShift = (hr - 60) * 0.5f // Shift based on deviation from 60 BPM
            photon.phase = (photon.phase + _coherenceLevel.value * 0.1f) % (2 * PI.toFloat())
        }
    }

    // MARK: - Audio Processing

    /**
     * Process audio samples with quantum modulation
     */
    fun processAudio(samples: FloatArray): FloatArray {
        val state = _quantumState.value ?: return samples
        val probs = state.probabilities
        val output = samples.copyOf()

        for (i in samples.indices) {
            val probIndex = i % probs.size
            val modulation = probs[probIndex] * _coherenceLevel.value

            when (_emulationMode.value) {
                EmulationMode.CLASSICAL -> {
                    output[i] = samples[i]
                }
                EmulationMode.QUANTUM_INSPIRED -> {
                    output[i] = samples[i] * (0.8f + modulation * 0.4f)
                }
                EmulationMode.FULL_QUANTUM -> {
                    val phaseShift = probs[probIndex] * PI.toFloat() * 0.5f
                    output[i] = samples[i] * cos(phaseShift)
                }
                EmulationMode.HYBRID_PHOTONIC -> {
                    val field = _lightField.value
                    val photonInfluence = field?.fieldCoherence ?: 1f
                    output[i] = samples[i] * photonInfluence
                }
                EmulationMode.BIO_COHERENT -> {
                    val bioMod = _hrvCoherence.value.toFloat() / 100f
                    output[i] = samples[i] * (0.7f + bioMod * 0.6f)
                }
            }
        }

        return output
    }

    override fun onCleared() {
        super.onCleared()
        stop()
    }
}

// MARK: - Visualization Types

enum class VisualizationType {
    INTERFERENCE_PATTERN,
    WAVE_FUNCTION,
    COHERENCE_FIELD,
    PHOTON_FLOW,
    SACRED_GEOMETRY,
    QUANTUM_TUNNEL,
    BIOPHOTON_AURA,
    LIGHT_MANDALA,
    HOLOGRAPHIC_DISPLAY,
    COSMIC_WEB
}

// MARK: - Presets

data class QuantumPreset(
    val id: String,
    val name: String,
    val description: String,
    val icon: String,
    val emulationMode: EmulationMode,
    val visualizationType: VisualizationType,
    val binauralFrequency: Float,
    val sessionDuration: Long, // seconds
    val category: PresetCategory
)

enum class PresetCategory {
    MEDITATION, FOCUS, SLEEP, CREATIVITY,
    HEALING, ENERGY, RELAXATION, EXPLORATION
}

object QuantumPresets {
    val deepMeditation = QuantumPreset(
        id = "deep-meditation",
        name = "Deep Meditation",
        description = "Theta waves for deep meditative states",
        icon = "🧘",
        emulationMode = EmulationMode.BIO_COHERENT,
        visualizationType = VisualizationType.WAVE_FUNCTION,
        binauralFrequency = 6f,
        sessionDuration = 1200,
        category = PresetCategory.MEDITATION
    )

    val focusFlow = QuantumPreset(
        id = "focus-flow",
        name = "Focus Flow",
        description = "Beta waves for concentration",
        icon = "🎯",
        emulationMode = EmulationMode.QUANTUM_INSPIRED,
        visualizationType = VisualizationType.COHERENCE_FIELD,
        binauralFrequency = 18f,
        sessionDuration = 1800,
        category = PresetCategory.FOCUS
    )

    val quantumDream = QuantumPreset(
        id = "quantum-dream",
        name = "Quantum Dream",
        description = "Delta waves for lucid dreaming",
        icon = "🌙",
        emulationMode = EmulationMode.FULL_QUANTUM,
        visualizationType = VisualizationType.COSMIC_WEB,
        binauralFrequency = 2f,
        sessionDuration = 3600,
        category = PresetCategory.SLEEP
    )

    val allPresets = listOf(deepMeditation, focusFlow, quantumDream)
}
