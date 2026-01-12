package com.echoelmusic.app.quantum

import android.util.Log
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.*
import kotlin.math.*

/**
 * Echoelmusic Quantum Light Emulator for Android
 * Quantum-inspired audio processing and photonics visualization
 *
 * Features:
 * - 5 emulation modes (classical to bio-coherent)
 * - 10 visualization types
 * - Quantum state simulation
 * - Photon field generation
 * - Wave function collapse
 * - Bio-coherent coupling
 * - Sacred geometry patterns
 *
 * Port of iOS QuantumLightEmulator + PhotonicsVisualizationEngine
 *
 * DISCLAIMER: This uses quantum-inspired algorithms for creative purposes.
 * It does not simulate actual quantum mechanics or use quantum hardware.
 */

// MARK: - Emulation Mode

enum class EmulationMode(val displayName: String, val description: String) {
    CLASSICAL("Classical", "Standard audio processing"),
    QUANTUM_INSPIRED("Quantum Inspired", "Superposition-based audio effects"),
    FULL_QUANTUM("Full Quantum", "Future quantum hardware ready"),
    HYBRID_PHOTONIC("Hybrid Photonic", "Light-based processing simulation"),
    BIO_COHERENT("Bio-Coherent", "HRV-driven quantum coherence")
}

// MARK: - Visualization Type

enum class VisualizationType(val displayName: String) {
    INTERFERENCE_PATTERN("Interference Pattern"),
    WAVE_FUNCTION("Wave Function"),
    COHERENCE_FIELD("Coherence Field"),
    PHOTON_FLOW("Photon Flow"),
    SACRED_GEOMETRY("Sacred Geometry"),
    QUANTUM_TUNNEL("Quantum Tunnel"),
    BIOPHOTON_AURA("Biophoton Aura"),
    LIGHT_MANDALA("Light Mandala"),
    HOLOGRAPHIC_DISPLAY("Holographic Display"),
    COSMIC_WEB("Cosmic Web")
}

// MARK: - Quantum State

data class QuantumState(
    val amplitude: Float = 1.0f,
    val phase: Float = 0f,
    val coherence: Float = 1.0f,
    val entanglement: Float = 0f,
    val superposition: List<Float> = listOf(1f, 0f), // |0⟩ and |1⟩ amplitudes
    val collapsed: Boolean = false,
    val timestamp: Long = System.currentTimeMillis()
) {
    val probability0: Float get() = superposition[0] * superposition[0]
    val probability1: Float get() = if (superposition.size > 1) superposition[1] * superposition[1] else 0f

    fun measure(): Boolean {
        return Math.random() < probability1
    }

    companion object {
        val GROUND = QuantumState(superposition = listOf(1f, 0f))
        val EXCITED = QuantumState(superposition = listOf(0f, 1f))
        val SUPERPOSITION = QuantumState(superposition = listOf(0.707f, 0.707f))
    }
}

// MARK: - Photon

data class Photon(
    val id: String = UUID.randomUUID().toString(),
    var x: Float = 0f,
    var y: Float = 0f,
    var z: Float = 0f,
    var vx: Float = 0f,
    var vy: Float = 0f,
    var vz: Float = 0f,
    var wavelength: Float = 550f, // nm (green)
    var intensity: Float = 1.0f,
    var phase: Float = 0f,
    var polarization: Float = 0f,
    var coherent: Boolean = true
) {
    val color: Long get() {
        // Convert wavelength to RGB
        return when {
            wavelength < 380 -> 0xFF000000 // UV (invisible)
            wavelength < 440 -> { // Violet
                val t = (wavelength - 380) / (440 - 380)
                0xFF000000 or (((1 - t) * 0.5 * 255).toLong() shl 16) or ((t * 255).toLong())
            }
            wavelength < 490 -> { // Blue
                val t = (wavelength - 440) / (490 - 440)
                0xFF000000 or ((t * 255).toLong() shl 8) or 0xFF
            }
            wavelength < 510 -> { // Cyan
                val t = (wavelength - 490) / (510 - 490)
                0xFF000000 or 0xFF00 or (((1 - t) * 255).toLong())
            }
            wavelength < 580 -> { // Green to Yellow
                val t = (wavelength - 510) / (580 - 510)
                0xFF000000 or ((t * 255).toLong() shl 16) or 0xFF00
            }
            wavelength < 645 -> { // Yellow to Orange
                val t = (wavelength - 580) / (645 - 580)
                0xFF000000 or 0xFF0000 or (((1 - t) * 255).toLong() shl 8)
            }
            wavelength < 780 -> 0xFFFF0000 // Red
            else -> 0xFF000000 // IR (invisible)
        }
    }

    fun update(deltaTime: Float) {
        x += vx * deltaTime
        y += vy * deltaTime
        z += vz * deltaTime
        phase = (phase + deltaTime * 2 * PI.toFloat()) % (2 * PI.toFloat())
    }
}

// MARK: - Light Field

data class LightField(
    val id: String = UUID.randomUUID().toString(),
    val photons: MutableList<Photon> = mutableListOf(),
    var coherence: Float = 1.0f,
    var intensity: Float = 1.0f,
    var geometry: FieldGeometry = FieldGeometry.SPHERICAL
)

enum class FieldGeometry(val displayName: String) {
    SPHERICAL("Spherical"),
    TOROIDAL("Toroidal"),
    FIBONACCI("Fibonacci Spiral"),
    PLATONIC("Platonic Solid"),
    HYPERBOLIC("Hyperbolic"),
    FRACTAL("Fractal"),
    MOBIUS("Möbius Strip"),
    HOPF("Hopf Fibration"),
    CALABI_YAU("Calabi-Yau")
}

// MARK: - Wave Function

data class WaveFunction(
    val resolution: Int = 256,
    val amplitudes: FloatArray = FloatArray(resolution) { 0f },
    val phases: FloatArray = FloatArray(resolution) { 0f }
) {
    fun normalize() {
        val sum = amplitudes.sumOf { (it * it).toDouble() }.toFloat()
        if (sum > 0) {
            val factor = 1f / sqrt(sum)
            for (i in amplitudes.indices) {
                amplitudes[i] *= factor
            }
        }
    }

    fun probabilityDensity(): FloatArray {
        return FloatArray(resolution) { amplitudes[it] * amplitudes[it] }
    }

    fun evolve(deltaTime: Float, energy: Float) {
        for (i in phases.indices) {
            phases[i] = (phases[i] + energy * deltaTime) % (2 * PI.toFloat())
        }
    }
}

// MARK: - Quantum Emulator State

data class QuantumEmulatorState(
    val mode: EmulationMode = EmulationMode.BIO_COHERENT,
    val visualizationType: VisualizationType = VisualizationType.COHERENCE_FIELD,
    val quantumState: QuantumState = QuantumState.SUPERPOSITION,
    val coherenceLevel: Float = 0.5f,
    val entanglementStrength: Float = 0f,
    val photonCount: Int = 100,
    val fieldGeometry: FieldGeometry = FieldGeometry.FIBONACCI,
    val bioCoherence: Float = 0.5f,
    val audioReactivity: Float = 0.5f
)

// MARK: - Quantum Light Emulator

class QuantumLightEmulator {

    companion object {
        private const val TAG = "QuantumLightEmulator"
        private const val UPDATE_RATE_HZ = 60
        private const val UPDATE_INTERVAL_MS = 1000L / UPDATE_RATE_HZ
        private const val MAX_PHOTONS = 1000
        private const val GOLDEN_RATIO = 1.618033988749895f
        private const val GOLDEN_ANGLE = 2.399963229728653f // radians
        private const val SCHUMANN_FREQUENCY = 7.83f // Hz
    }

    // State
    private val _isRunning = MutableStateFlow(false)
    val isRunning: StateFlow<Boolean> = _isRunning

    private val _state = MutableStateFlow(QuantumEmulatorState())
    val state: StateFlow<QuantumEmulatorState> = _state

    private val _lightField = MutableStateFlow(LightField())
    val lightField: StateFlow<LightField> = _lightField

    private val _waveFunction = MutableStateFlow(WaveFunction())
    val waveFunction: StateFlow<WaveFunction> = _waveFunction

    private val _coherenceHistory = MutableStateFlow<List<Float>>(emptyList())
    val coherenceHistory: StateFlow<List<Float>> = _coherenceHistory

    // Bio input
    private var currentBioCoherence = 0.5f
    private var currentHeartRate = 70f
    private var currentBreathPhase = 0f

    // Processing
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private var updateJob: Job? = null
    private var time = 0f

    init {
        Log.i(TAG, "Quantum Light Emulator initialized")
        initializeLightField()
        initializeWaveFunction()
    }

    private fun initializeLightField() {
        val field = LightField(geometry = FieldGeometry.FIBONACCI)

        // Generate photons in Fibonacci spiral pattern
        for (i in 0 until 100) {
            val theta = i * GOLDEN_ANGLE
            val r = sqrt(i.toFloat()) * 0.1f

            field.photons.add(Photon(
                x = r * cos(theta),
                y = r * sin(theta),
                z = 0f,
                wavelength = 400f + (i % 10) * 30f // Rainbow
            ))
        }

        _lightField.value = field
    }

    private fun initializeWaveFunction() {
        val wf = WaveFunction(256)

        // Initialize as Gaussian packet
        val center = 128
        val width = 20f
        for (i in 0 until 256) {
            val x = (i - center).toFloat()
            wf.amplitudes[i] = exp(-x * x / (2 * width * width))
        }
        wf.normalize()

        _waveFunction.value = wf
    }

    // MARK: - Lifecycle

    fun start() {
        if (_isRunning.value) return

        _isRunning.value = true
        startUpdateLoop()
        Log.i(TAG, "Quantum Emulator started in ${_state.value.mode.displayName} mode")
    }

    fun stop() {
        _isRunning.value = false
        updateJob?.cancel()
        Log.i(TAG, "Quantum Emulator stopped")
    }

    fun shutdown() {
        stop()
        scope.cancel()
        Log.i(TAG, "Quantum Emulator shutdown")
    }

    private fun startUpdateLoop() {
        updateJob?.cancel()
        updateJob = scope.launch {
            while (_isRunning.value && isActive) {
                val deltaTime = 1f / UPDATE_RATE_HZ
                time += deltaTime

                updateQuantumState(deltaTime)
                updateLightField(deltaTime)
                updateWaveFunction(deltaTime)
                updateCoherenceHistory()

                delay(UPDATE_INTERVAL_MS)
            }
        }
    }

    // MARK: - Mode Control

    fun setMode(mode: EmulationMode) {
        _state.value = _state.value.copy(mode = mode)
        Log.d(TAG, "Emulation mode set to ${mode.displayName}")
    }

    fun setVisualizationType(type: VisualizationType) {
        _state.value = _state.value.copy(visualizationType = type)
    }

    fun setFieldGeometry(geometry: FieldGeometry) {
        _state.value = _state.value.copy(fieldGeometry = geometry)
        regenerateLightField(geometry)
    }

    fun setPhotonCount(count: Int) {
        _state.value = _state.value.copy(photonCount = count.coerceIn(10, MAX_PHOTONS))
        regenerateLightField(_state.value.fieldGeometry)
    }

    // MARK: - Bio Input

    fun updateBioData(coherence: Float, heartRate: Float, breathPhase: Float) {
        currentBioCoherence = coherence
        currentHeartRate = heartRate
        currentBreathPhase = breathPhase

        _state.value = _state.value.copy(bioCoherence = coherence)
    }

    // MARK: - Quantum State Operations

    private fun updateQuantumState(deltaTime: Float) {
        val currentState = _state.value.quantumState

        // Apply phase evolution
        val newPhase = (currentState.phase + SCHUMANN_FREQUENCY * 2 * PI.toFloat() * deltaTime) % (2 * PI.toFloat())

        // Coherence decays unless in bio-coherent mode
        var newCoherence = currentState.coherence
        if (_state.value.mode == EmulationMode.BIO_COHERENT) {
            newCoherence = lerp(newCoherence, currentBioCoherence, 0.1f)
        } else {
            newCoherence *= (1 - 0.01f * deltaTime) // Slow decoherence
        }

        val newState = currentState.copy(
            phase = newPhase,
            coherence = newCoherence.coerceIn(0f, 1f)
        )

        _state.value = _state.value.copy(
            quantumState = newState,
            coherenceLevel = newCoherence
        )
    }

    private fun updateLightField(deltaTime: Float) {
        val field = _lightField.value
        val state = _state.value

        // Update each photon
        for (photon in field.photons) {
            // Add velocity based on mode
            when (state.mode) {
                EmulationMode.BIO_COHERENT -> {
                    // Photons breathe with breath phase
                    val breathMod = sin(currentBreathPhase * PI.toFloat())
                    photon.vx += breathMod * 0.01f
                    photon.vy += breathMod * 0.01f
                }
                EmulationMode.QUANTUM_INSPIRED -> {
                    // Random quantum fluctuations
                    photon.vx += (Math.random().toFloat() - 0.5f) * 0.02f
                    photon.vy += (Math.random().toFloat() - 0.5f) * 0.02f
                }
                else -> {}
            }

            // Apply coherent rotation
            val angle = state.coherenceLevel * 0.01f
            val newX = photon.x * cos(angle) - photon.y * sin(angle)
            val newY = photon.x * sin(angle) + photon.y * cos(angle)
            photon.x = newX
            photon.y = newY

            photon.update(deltaTime)
        }

        // Update field coherence
        field.coherence = state.coherenceLevel

        _lightField.value = field
    }

    private fun updateWaveFunction(deltaTime: Float) {
        val wf = _waveFunction.value
        val energy = SCHUMANN_FREQUENCY + currentBioCoherence * 10f

        wf.evolve(deltaTime, energy)

        // Add bio-modulated perturbation
        if (_state.value.mode == EmulationMode.BIO_COHERENT) {
            val breathMod = sin(currentBreathPhase * PI.toFloat())
            val shift = (breathMod * 5).toInt()

            for (i in wf.amplitudes.indices) {
                val sourceIdx = (i + shift).coerceIn(0, wf.amplitudes.size - 1)
                wf.amplitudes[i] = lerp(wf.amplitudes[i], wf.amplitudes[sourceIdx], 0.1f)
            }
            wf.normalize()
        }

        _waveFunction.value = wf
    }

    private fun updateCoherenceHistory() {
        val history = _coherenceHistory.value.toMutableList()
        history.add(_state.value.coherenceLevel)

        // Keep last 100 values
        if (history.size > 100) {
            history.removeAt(0)
        }

        _coherenceHistory.value = history
    }

    // MARK: - Light Field Generation

    private fun regenerateLightField(geometry: FieldGeometry) {
        val field = LightField(geometry = geometry)
        val count = _state.value.photonCount

        when (geometry) {
            FieldGeometry.FIBONACCI -> generateFibonacciField(field, count)
            FieldGeometry.SPHERICAL -> generateSphericalField(field, count)
            FieldGeometry.TOROIDAL -> generateToroidalField(field, count)
            FieldGeometry.PLATONIC -> generatePlatonicField(field, count)
            else -> generateFibonacciField(field, count)
        }

        _lightField.value = field
    }

    private fun generateFibonacciField(field: LightField, count: Int) {
        for (i in 0 until count) {
            val theta = i * GOLDEN_ANGLE
            val r = sqrt(i.toFloat()) * 0.1f

            field.photons.add(Photon(
                x = r * cos(theta),
                y = r * sin(theta),
                z = 0f,
                wavelength = 400f + (i % 10) * 30f
            ))
        }
    }

    private fun generateSphericalField(field: LightField, count: Int) {
        for (i in 0 until count) {
            val phi = acos(1 - 2 * (i + 0.5f) / count)
            val theta = PI.toFloat() * (1 + sqrt(5f)) * i

            field.photons.add(Photon(
                x = sin(phi) * cos(theta),
                y = sin(phi) * sin(theta),
                z = cos(phi),
                wavelength = 380f + (i.toFloat() / count) * 400f
            ))
        }
    }

    private fun generateToroidalField(field: LightField, count: Int) {
        val R = 1.0f // Major radius
        val r = 0.3f // Minor radius

        for (i in 0 until count) {
            val u = (i.toFloat() / count) * 2 * PI.toFloat()
            val v = (i * GOLDEN_RATIO) * 2 * PI.toFloat()

            field.photons.add(Photon(
                x = (R + r * cos(v)) * cos(u),
                y = (R + r * cos(v)) * sin(u),
                z = r * sin(v),
                wavelength = 400f + (v / (2 * PI.toFloat())) * 380f
            ))
        }
    }

    private fun generatePlatonicField(field: LightField, count: Int) {
        // Generate icosahedron vertices
        val phi = GOLDEN_RATIO
        val vertices = listOf(
            Triple(0f, 1f, phi), Triple(0f, -1f, phi), Triple(0f, 1f, -phi), Triple(0f, -1f, -phi),
            Triple(1f, phi, 0f), Triple(-1f, phi, 0f), Triple(1f, -phi, 0f), Triple(-1f, -phi, 0f),
            Triple(phi, 0f, 1f), Triple(-phi, 0f, 1f), Triple(phi, 0f, -1f), Triple(-phi, 0f, -1f)
        )

        var idx = 0
        while (field.photons.size < count) {
            val v = vertices[idx % vertices.size]
            val scale = sqrt(v.first * v.first + v.second * v.second + v.third * v.third)

            field.photons.add(Photon(
                x = v.first / scale,
                y = v.second / scale,
                z = v.third / scale,
                wavelength = 400f + (idx % 12) * 30f
            ))
            idx++
        }
    }

    // MARK: - Wave Function Collapse

    fun collapse(): Boolean {
        val state = _state.value.quantumState
        val result = state.measure()

        val collapsedState = if (result) {
            QuantumState.EXCITED.copy(collapsed = true)
        } else {
            QuantumState.GROUND.copy(collapsed = true)
        }

        _state.value = _state.value.copy(quantumState = collapsedState)

        Log.i(TAG, "Wave function collapsed to |${if (result) "1" else "0"}⟩")
        return result
    }

    fun resetSuperposition() {
        _state.value = _state.value.copy(quantumState = QuantumState.SUPERPOSITION)
        Log.d(TAG, "Reset to superposition state")
    }

    // MARK: - Entanglement

    fun entangle(strength: Float) {
        val newStrength = strength.coerceIn(0f, 1f)
        _state.value = _state.value.copy(
            entanglementStrength = newStrength,
            quantumState = _state.value.quantumState.copy(entanglement = newStrength)
        )
    }

    // MARK: - Helpers

    private fun lerp(a: Float, b: Float, t: Float): Float = a + (b - a) * t

    // MARK: - Visualization Data

    fun getInterferencePattern(width: Int, height: Int): FloatArray {
        val pattern = FloatArray(width * height)
        val state = _state.value
        val wavelength = 0.05f

        for (y in 0 until height) {
            for (x in 0 until width) {
                val nx = (x.toFloat() / width - 0.5f) * 2
                val ny = (y.toFloat() / height - 0.5f) * 2

                // Two-slit interference
                val d1 = sqrt((nx + 0.2f) * (nx + 0.2f) + ny * ny)
                val d2 = sqrt((nx - 0.2f) * (nx - 0.2f) + ny * ny)

                val phase1 = d1 / wavelength * 2 * PI.toFloat() + time
                val phase2 = d2 / wavelength * 2 * PI.toFloat() + time

                val amp = (cos(phase1) + cos(phase2)) / 2 * state.coherenceLevel

                pattern[y * width + x] = (amp + 1) / 2 // Normalize to 0-1
            }
        }

        return pattern
    }

    fun getCoherenceFieldPoints(): List<Triple<Float, Float, Float>> {
        return _lightField.value.photons.map {
            Triple(it.x * _state.value.coherenceLevel, it.y * _state.value.coherenceLevel, it.z)
        }
    }
}
