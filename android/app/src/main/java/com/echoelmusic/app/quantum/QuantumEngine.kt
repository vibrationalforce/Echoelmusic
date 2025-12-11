package com.echoelmusic.app.quantum

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext
import kotlin.math.PI
import kotlin.math.sqrt

/**
 * Echoelmusic Quantum Engine - Android
 *
 * Native quantum simulation with ARM NEON SIMD optimization.
 * Supports up to 20 qubits (1M amplitudes).
 *
 * Features:
 * - Full quantum gate set (H, X, Y, Z, Rx, Ry, Rz, CNOT, CZ, SWAP)
 * - Grover's search algorithm
 * - Quantum Fourier Transform
 * - Bio-data quantum encoding
 * - VQE optimization
 */
class QuantumEngine {

    companion object {
        private const val TAG = "QuantumEngine"
        private const val MAX_QUBITS = 20

        init {
            try {
                System.loadLibrary("quantum_jni")
                Log.i(TAG, "Quantum native library loaded successfully")
            } catch (e: UnsatisfiedLinkError) {
                Log.e(TAG, "Failed to load quantum native library: ${e.message}")
            }
        }

        @Volatile
        private var instance: QuantumEngine? = null

        fun getInstance(): QuantumEngine {
            return instance ?: synchronized(this) {
                instance ?: QuantumEngine().also { instance = it }
            }
        }
    }

    // State
    private val _numQubits = MutableStateFlow(0)
    val numQubits: StateFlow<Int> = _numQubits

    private val _stateSize = MutableStateFlow(0L)
    val stateSize: StateFlow<Long> = _stateSize

    private val _isInitialized = MutableStateFlow(false)
    val isInitialized: StateFlow<Boolean> = _isInitialized

    // ═══════════════════════════════════════════════════════════════════════════════
    // INITIALIZATION
    // ═══════════════════════════════════════════════════════════════════════════════

    /**
     * Initialize quantum state with specified number of qubits
     */
    fun initialize(qubits: Int): Boolean {
        if (qubits <= 0 || qubits > MAX_QUBITS) {
            Log.e(TAG, "Invalid qubit count: $qubits (max: $MAX_QUBITS)")
            return false
        }

        nativeInitialize(qubits)
        _numQubits.value = qubits
        _stateSize.value = 1L shl qubits
        _isInitialized.value = true

        Log.i(TAG, "Initialized $qubits-qubit quantum state (${_stateSize.value} amplitudes)")
        return true
    }

    /**
     * Initialize to uniform superposition |+...+⟩
     */
    fun initializeSuperposition() {
        if (!_isInitialized.value) {
            Log.w(TAG, "Must initialize state first")
            return
        }
        nativeInitializeSuperposition()
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // SINGLE-QUBIT GATES
    // ═══════════════════════════════════════════════════════════════════════════════

    /**
     * Apply Hadamard gate to qubit
     */
    fun hadamard(qubit: Int) {
        validateQubit(qubit)
        nativeApplyHadamard(qubit)
    }

    /**
     * Apply Hadamard to all qubits
     */
    fun hadamardAll() {
        for (q in 0 until _numQubits.value) {
            hadamard(q)
        }
    }

    /**
     * Apply Pauli-X (NOT) gate
     */
    fun pauliX(qubit: Int) {
        validateQubit(qubit)
        nativeApplyPauliX(qubit)
    }

    /**
     * Apply Pauli-Y gate
     */
    fun pauliY(qubit: Int) {
        validateQubit(qubit)
        nativeApplyPauliY(qubit)
    }

    /**
     * Apply Pauli-Z gate
     */
    fun pauliZ(qubit: Int) {
        validateQubit(qubit)
        nativeApplyPauliZ(qubit)
    }

    /**
     * Apply Rx rotation gate
     */
    fun rx(qubit: Int, theta: Float) {
        validateQubit(qubit)
        nativeApplyRx(qubit, theta)
    }

    /**
     * Apply Ry rotation gate
     */
    fun ry(qubit: Int, theta: Float) {
        validateQubit(qubit)
        nativeApplyRy(qubit, theta)
    }

    /**
     * Apply Rz rotation gate
     */
    fun rz(qubit: Int, theta: Float) {
        validateQubit(qubit)
        nativeApplyRz(qubit, theta)
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // TWO-QUBIT GATES
    // ═══════════════════════════════════════════════════════════════════════════════

    /**
     * Apply CNOT (controlled-X) gate
     */
    fun cnot(control: Int, target: Int) {
        validateQubit(control)
        validateQubit(target)
        require(control != target) { "Control and target must be different qubits" }
        nativeApplyCNOT(control, target)
    }

    /**
     * Apply CZ (controlled-Z) gate
     */
    fun cz(control: Int, target: Int) {
        validateQubit(control)
        validateQubit(target)
        require(control != target) { "Control and target must be different qubits" }
        nativeApplyCZ(control, target)
    }

    /**
     * Apply SWAP gate
     */
    fun swap(qubit1: Int, qubit2: Int) {
        validateQubit(qubit1)
        validateQubit(qubit2)
        require(qubit1 != qubit2) { "Qubits must be different" }
        nativeApplySWAP(qubit1, qubit2)
    }

    /**
     * Apply controlled phase gate
     */
    fun controlledPhase(control: Int, target: Int, theta: Float) {
        validateQubit(control)
        validateQubit(target)
        nativeApplyControlledPhase(control, target, theta)
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // MEASUREMENT
    // ═══════════════════════════════════════════════════════════════════════════════

    /**
     * Get probability distribution for all basis states
     */
    fun getProbabilities(): FloatArray {
        if (!_isInitialized.value) return floatArrayOf()
        return nativeGetProbabilities()
    }

    /**
     * Measure all qubits, returns bitstring
     */
    fun measureAll(): IntArray {
        if (!_isInitialized.value) return intArrayOf()
        return nativeMeasureAll()
    }

    /**
     * Measure single qubit (collapses state)
     */
    fun measureQubit(qubit: Int): Int {
        validateQubit(qubit)
        return nativeMeasureQubit(qubit)
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // QUANTUM ALGORITHMS
    // ═══════════════════════════════════════════════════════════════════════════════

    /**
     * Grover's search algorithm
     * Finds marked state with O(sqrt(N)) queries
     */
    suspend fun groverSearch(markedState: Int, iterations: Int? = null): GroverResult = withContext(Dispatchers.Default) {
        require(markedState in 0 until _stateSize.value) { "Marked state out of range" }

        val n = _numQubits.value
        val optimalIterations = iterations ?: (PI / 4 * sqrt(_stateSize.value.toDouble())).toInt()

        // Initialize to uniform superposition
        initialize(n)
        hadamardAll()

        // Grover iterations
        repeat(optimalIterations) {
            // Oracle: phase flip marked state
            nativeApplyPhaseOracle(markedState)

            // Diffusion operator
            nativeApplyGroverDiffusion()
        }

        // Measure
        val result = measureAll()
        val measured = result.foldIndexed(0) { idx, acc, bit -> acc + (bit shl idx) }

        GroverResult(
            searchTarget = markedState,
            measuredState = measured,
            success = measured == markedState,
            iterations = optimalIterations,
            probability = getProbabilities().getOrNull(markedState) ?: 0f
        )
    }

    data class GroverResult(
        val searchTarget: Int,
        val measuredState: Int,
        val success: Boolean,
        val iterations: Int,
        val probability: Float
    )

    /**
     * Create Bell state (maximally entangled pair)
     */
    fun createBellState(): IntArray {
        require(_numQubits.value >= 2) { "Need at least 2 qubits for Bell state" }

        initialize(_numQubits.value)
        hadamard(0)
        cnot(0, 1)

        return measureAll()
    }

    /**
     * Create GHZ state (maximally entangled n qubits)
     */
    fun createGHZState(): IntArray {
        val n = _numQubits.value
        require(n >= 2) { "Need at least 2 qubits for GHZ state" }

        initialize(n)
        hadamard(0)
        for (i in 0 until n - 1) {
            cnot(i, i + 1)
        }

        return measureAll()
    }

    /**
     * Quantum Fourier Transform
     */
    fun qft() {
        val n = _numQubits.value

        for (j in 0 until n) {
            hadamard(j)
            for (k in j + 1 until n) {
                val theta = PI.toFloat() / (1 shl (k - j))
                controlledPhase(k, j, theta)
            }
        }

        // Swap qubits to reverse order
        for (i in 0 until n / 2) {
            swap(i, n - 1 - i)
        }
    }

    /**
     * Inverse Quantum Fourier Transform
     */
    fun inverseQft() {
        val n = _numQubits.value

        // Swap qubits first
        for (i in 0 until n / 2) {
            swap(i, n - 1 - i)
        }

        for (j in n - 1 downTo 0) {
            for (k in n - 1 downTo j + 1) {
                val theta = -PI.toFloat() / (1 shl (k - j))
                controlledPhase(k, j, theta)
            }
            hadamard(j)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // BIO-DATA INTEGRATION
    // ═══════════════════════════════════════════════════════════════════════════════

    /**
     * Encode bio-data into quantum state using angle encoding
     * @param hrvFeatures Normalized HRV features (0-1 range)
     */
    fun encodeBioData(hrvFeatures: List<Float>) {
        val n = minOf(hrvFeatures.size, _numQubits.value)

        // Initialize
        initialize(_numQubits.value)

        // Encode each feature as rotation angle
        for (i in 0 until n) {
            val theta = hrvFeatures[i] * PI.toFloat()
            ry(i, theta)
        }

        // Add entanglement layer
        for (i in 0 until n - 1) {
            cnot(i, i + 1)
        }
    }

    /**
     * Quantum kernel evaluation for bio-data classification
     */
    fun quantumKernel(x: List<Float>, y: List<Float>): Float {
        require(x.size == y.size) { "Feature vectors must have same length" }
        val n = minOf(x.size, _numQubits.value)

        // Encode x
        encodeBioData(x)

        // Get state |φ(x)⟩
        val stateX = getProbabilities()

        // Encode y
        encodeBioData(y)

        // Get state |φ(y)⟩
        val stateY = getProbabilities()

        // Compute kernel as probability overlap
        var kernel = 0f
        for (i in stateX.indices) {
            kernel += sqrt(stateX[i] * stateY[i])
        }

        return kernel * kernel  // Fidelity
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // VARIATIONAL QUANTUM EIGENSOLVER (VQE)
    // ═══════════════════════════════════════════════════════════════════════════════

    /**
     * Simple VQE for finding ground state energy
     */
    suspend fun vqe(
        hamiltonian: (List<Float>) -> Float,  // Cost function
        initialParams: List<Float>,
        iterations: Int = 100,
        learningRate: Float = 0.1f
    ): VQEResult = withContext(Dispatchers.Default) {
        var params = initialParams.toMutableList()
        var bestEnergy = Float.MAX_VALUE
        var bestParams = params.toList()

        repeat(iterations) { iteration ->
            // Prepare ansatz state
            prepareAnsatz(params)

            // Evaluate energy
            val energy = hamiltonian(params)

            if (energy < bestEnergy) {
                bestEnergy = energy
                bestParams = params.toList()
            }

            // Gradient descent using parameter shift rule
            for (i in params.indices) {
                val shift = PI.toFloat() / 2

                // f(θ + π/2)
                params[i] += shift
                prepareAnsatz(params)
                val energyPlus = hamiltonian(params)

                // f(θ - π/2)
                params[i] -= 2 * shift
                prepareAnsatz(params)
                val energyMinus = hamiltonian(params)

                // Restore and update
                params[i] += shift
                val gradient = (energyPlus - energyMinus) / 2
                params[i] -= learningRate * gradient
            }
        }

        VQEResult(
            groundStateEnergy = bestEnergy,
            optimalParams = bestParams,
            iterations = iterations
        )
    }

    data class VQEResult(
        val groundStateEnergy: Float,
        val optimalParams: List<Float>,
        val iterations: Int
    )

    private fun prepareAnsatz(params: List<Float>) {
        val n = _numQubits.value
        initialize(n)

        var paramIdx = 0
        for (layer in 0 until 2) {  // 2 layers
            // Single-qubit rotations
            for (q in 0 until n) {
                if (paramIdx < params.size) ry(q, params[paramIdx++])
                if (paramIdx < params.size) rz(q, params[paramIdx++])
            }

            // Entangling layer
            for (q in 0 until n - 1) {
                cnot(q, q + 1)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // UTILITY
    // ═══════════════════════════════════════════════════════════════════════════════

    private fun validateQubit(qubit: Int) {
        require(_isInitialized.value) { "Quantum state not initialized" }
        require(qubit in 0 until _numQubits.value) {
            "Qubit $qubit out of range (0-${_numQubits.value - 1})"
        }
    }

    /**
     * Get quantum state info
     */
    fun getInfo(): String {
        return """
            Quantum Engine Status:
            - Initialized: ${_isInitialized.value}
            - Qubits: ${_numQubits.value}
            - State Size: ${_stateSize.value} amplitudes
            - Memory: ${_stateSize.value * 8 / 1024} KB
        """.trimIndent()
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // NATIVE METHODS
    // ═══════════════════════════════════════════════════════════════════════════════

    private external fun nativeInitialize(qubits: Int)
    private external fun nativeInitializeSuperposition()
    private external fun nativeApplyHadamard(qubit: Int)
    private external fun nativeApplyPauliX(qubit: Int)
    private external fun nativeApplyPauliY(qubit: Int)
    private external fun nativeApplyPauliZ(qubit: Int)
    private external fun nativeApplyRx(qubit: Int, theta: Float)
    private external fun nativeApplyRy(qubit: Int, theta: Float)
    private external fun nativeApplyRz(qubit: Int, theta: Float)
    private external fun nativeApplyCNOT(control: Int, target: Int)
    private external fun nativeApplyCZ(control: Int, target: Int)
    private external fun nativeApplySWAP(qubit1: Int, qubit2: Int)
    private external fun nativeApplyControlledPhase(control: Int, target: Int, theta: Float)
    private external fun nativeGetProbabilities(): FloatArray
    private external fun nativeMeasureAll(): IntArray
    private external fun nativeMeasureQubit(qubit: Int): Int
    private external fun nativeApplyGroverDiffusion()
    private external fun nativeApplyPhaseOracle(markedState: Int)
}
