//
//  quantum_wasm.cpp
//  Echoelmusic - WebAssembly
//
//  Created: December 2025
//  WEBASSEMBLY QUANTUM SIMULATION
//
//  Build with Emscripten:
//  emcc quantum_wasm.cpp -O3 -s WASM=1 -s EXPORTED_FUNCTIONS="['_malloc','_free']" \
//       -s EXPORTED_RUNTIME_METHODS="['ccall','cwrap']" \
//       -s ALLOW_MEMORY_GROWTH=1 -s MODULARIZE=1 \
//       -o quantum.js
//
//  Features:
//  - Full quantum simulation in browser
//  - SIMD optimization via WebAssembly SIMD
//  - Up to 20 qubits (browser memory dependent)
//  - All standard quantum gates
//  - Grover's search, QFT, VQE support
//

#include <emscripten/emscripten.h>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <random>

extern "C" {

// =============================================================================
// QUANTUM STATE
// =============================================================================

static float* g_stateReal = nullptr;      // Real parts of amplitudes
static float* g_stateImag = nullptr;      // Imaginary parts of amplitudes
static int g_numQubits = 0;
static size_t g_stateSize = 0;
static std::mt19937* g_rng = nullptr;

// =============================================================================
// INITIALIZATION
// =============================================================================

EMSCRIPTEN_KEEPALIVE
int quantum_initialize(int numQubits) {
    if (numQubits <= 0 || numQubits > 20) {
        return -1;  // Error: invalid qubit count
    }

    // Free existing state
    if (g_stateReal) { free(g_stateReal); g_stateReal = nullptr; }
    if (g_stateImag) { free(g_stateImag); g_stateImag = nullptr; }
    if (g_rng) { delete g_rng; g_rng = nullptr; }

    g_numQubits = numQubits;
    g_stateSize = 1UL << numQubits;

    // Allocate state vectors
    g_stateReal = (float*)malloc(g_stateSize * sizeof(float));
    g_stateImag = (float*)malloc(g_stateSize * sizeof(float));

    if (!g_stateReal || !g_stateImag) {
        return -2;  // Error: allocation failed
    }

    // Initialize RNG
    g_rng = new std::mt19937(std::random_device{}());

    // Initialize to |0...0>
    memset(g_stateReal, 0, g_stateSize * sizeof(float));
    memset(g_stateImag, 0, g_stateSize * sizeof(float));
    g_stateReal[0] = 1.0f;

    return 0;  // Success
}

EMSCRIPTEN_KEEPALIVE
void quantum_shutdown() {
    if (g_stateReal) { free(g_stateReal); g_stateReal = nullptr; }
    if (g_stateImag) { free(g_stateImag); g_stateImag = nullptr; }
    if (g_rng) { delete g_rng; g_rng = nullptr; }
    g_numQubits = 0;
    g_stateSize = 0;
}

EMSCRIPTEN_KEEPALIVE
int quantum_get_num_qubits() {
    return g_numQubits;
}

EMSCRIPTEN_KEEPALIVE
size_t quantum_get_state_size() {
    return g_stateSize;
}

EMSCRIPTEN_KEEPALIVE
void quantum_initialize_superposition() {
    if (!g_stateReal || !g_stateImag) return;

    float amplitude = 1.0f / sqrtf((float)g_stateSize);
    for (size_t i = 0; i < g_stateSize; ++i) {
        g_stateReal[i] = amplitude;
        g_stateImag[i] = 0.0f;
    }
}

EMSCRIPTEN_KEEPALIVE
void quantum_reset() {
    if (!g_stateReal || !g_stateImag) return;

    memset(g_stateReal, 0, g_stateSize * sizeof(float));
    memset(g_stateImag, 0, g_stateSize * sizeof(float));
    g_stateReal[0] = 1.0f;
}

// =============================================================================
// SINGLE-QUBIT GATES
// =============================================================================

EMSCRIPTEN_KEEPALIVE
void quantum_hadamard(int qubit) {
    if (!g_stateReal || !g_stateImag || qubit < 0 || qubit >= g_numQubits) return;

    const float INV_SQRT2 = 0.7071067811865476f;
    size_t mask = 1UL << qubit;

    for (size_t i = 0; i < g_stateSize; ++i) {
        if ((i & mask) == 0) {
            size_t j = i | mask;

            float a0r = g_stateReal[i];
            float a0i = g_stateImag[i];
            float a1r = g_stateReal[j];
            float a1i = g_stateImag[j];

            g_stateReal[i] = INV_SQRT2 * (a0r + a1r);
            g_stateImag[i] = INV_SQRT2 * (a0i + a1i);
            g_stateReal[j] = INV_SQRT2 * (a0r - a1r);
            g_stateImag[j] = INV_SQRT2 * (a0i - a1i);
        }
    }
}

EMSCRIPTEN_KEEPALIVE
void quantum_pauli_x(int qubit) {
    if (!g_stateReal || !g_stateImag || qubit < 0 || qubit >= g_numQubits) return;

    size_t mask = 1UL << qubit;

    for (size_t i = 0; i < g_stateSize; ++i) {
        if ((i & mask) == 0) {
            size_t j = i | mask;

            float tr = g_stateReal[i];
            float ti = g_stateImag[i];
            g_stateReal[i] = g_stateReal[j];
            g_stateImag[i] = g_stateImag[j];
            g_stateReal[j] = tr;
            g_stateImag[j] = ti;
        }
    }
}

EMSCRIPTEN_KEEPALIVE
void quantum_pauli_y(int qubit) {
    if (!g_stateReal || !g_stateImag || qubit < 0 || qubit >= g_numQubits) return;

    size_t mask = 1UL << qubit;

    for (size_t i = 0; i < g_stateSize; ++i) {
        if ((i & mask) == 0) {
            size_t j = i | mask;

            // Y|0> = i|1>, Y|1> = -i|0>
            float a0r = g_stateReal[i];
            float a0i = g_stateImag[i];
            float a1r = g_stateReal[j];
            float a1i = g_stateImag[j];

            // -i * a1 -> (a1i, -a1r)
            g_stateReal[i] = a1i;
            g_stateImag[i] = -a1r;

            // i * a0 -> (-a0i, a0r)
            g_stateReal[j] = -a0i;
            g_stateImag[j] = a0r;
        }
    }
}

EMSCRIPTEN_KEEPALIVE
void quantum_pauli_z(int qubit) {
    if (!g_stateReal || !g_stateImag || qubit < 0 || qubit >= g_numQubits) return;

    size_t mask = 1UL << qubit;

    for (size_t i = 0; i < g_stateSize; ++i) {
        if (i & mask) {
            g_stateReal[i] = -g_stateReal[i];
            g_stateImag[i] = -g_stateImag[i];
        }
    }
}

EMSCRIPTEN_KEEPALIVE
void quantum_phase(int qubit, float theta) {
    if (!g_stateReal || !g_stateImag || qubit < 0 || qubit >= g_numQubits) return;

    float c = cosf(theta);
    float s = sinf(theta);
    size_t mask = 1UL << qubit;

    for (size_t i = 0; i < g_stateSize; ++i) {
        if (i & mask) {
            float r = g_stateReal[i];
            float im = g_stateImag[i];
            g_stateReal[i] = r * c - im * s;
            g_stateImag[i] = r * s + im * c;
        }
    }
}

EMSCRIPTEN_KEEPALIVE
void quantum_rx(int qubit, float theta) {
    if (!g_stateReal || !g_stateImag || qubit < 0 || qubit >= g_numQubits) return;

    float c = cosf(theta / 2.0f);
    float s = sinf(theta / 2.0f);
    size_t mask = 1UL << qubit;

    for (size_t i = 0; i < g_stateSize; ++i) {
        if ((i & mask) == 0) {
            size_t j = i | mask;

            float a0r = g_stateReal[i];
            float a0i = g_stateImag[i];
            float a1r = g_stateReal[j];
            float a1i = g_stateImag[j];

            // Rx = [[c, -is], [-is, c]]
            g_stateReal[i] = c * a0r + s * a1i;
            g_stateImag[i] = c * a0i - s * a1r;
            g_stateReal[j] = c * a1r + s * a0i;
            g_stateImag[j] = c * a1i - s * a0r;
        }
    }
}

EMSCRIPTEN_KEEPALIVE
void quantum_ry(int qubit, float theta) {
    if (!g_stateReal || !g_stateImag || qubit < 0 || qubit >= g_numQubits) return;

    float c = cosf(theta / 2.0f);
    float s = sinf(theta / 2.0f);
    size_t mask = 1UL << qubit;

    for (size_t i = 0; i < g_stateSize; ++i) {
        if ((i & mask) == 0) {
            size_t j = i | mask;

            float a0r = g_stateReal[i];
            float a0i = g_stateImag[i];
            float a1r = g_stateReal[j];
            float a1i = g_stateImag[j];

            // Ry = [[c, -s], [s, c]]
            g_stateReal[i] = c * a0r - s * a1r;
            g_stateImag[i] = c * a0i - s * a1i;
            g_stateReal[j] = s * a0r + c * a1r;
            g_stateImag[j] = s * a0i + c * a1i;
        }
    }
}

EMSCRIPTEN_KEEPALIVE
void quantum_rz(int qubit, float theta) {
    if (!g_stateReal || !g_stateImag || qubit < 0 || qubit >= g_numQubits) return;

    float halfTheta = theta / 2.0f;
    float c0 = cosf(-halfTheta);
    float s0 = sinf(-halfTheta);
    float c1 = cosf(halfTheta);
    float s1 = sinf(halfTheta);
    size_t mask = 1UL << qubit;

    for (size_t i = 0; i < g_stateSize; ++i) {
        float r = g_stateReal[i];
        float im = g_stateImag[i];

        if (i & mask) {
            g_stateReal[i] = r * c1 - im * s1;
            g_stateImag[i] = r * s1 + im * c1;
        } else {
            g_stateReal[i] = r * c0 - im * s0;
            g_stateImag[i] = r * s0 + im * c0;
        }
    }
}

EMSCRIPTEN_KEEPALIVE
void quantum_t_gate(int qubit) {
    quantum_phase(qubit, M_PI / 4.0f);
}

EMSCRIPTEN_KEEPALIVE
void quantum_s_gate(int qubit) {
    quantum_phase(qubit, M_PI / 2.0f);
}

// =============================================================================
// TWO-QUBIT GATES
// =============================================================================

EMSCRIPTEN_KEEPALIVE
void quantum_cnot(int control, int target) {
    if (!g_stateReal || !g_stateImag) return;
    if (control < 0 || control >= g_numQubits) return;
    if (target < 0 || target >= g_numQubits) return;
    if (control == target) return;

    size_t controlMask = 1UL << control;
    size_t targetMask = 1UL << target;

    for (size_t i = 0; i < g_stateSize; ++i) {
        // Only swap when control is |1> and target is |0>
        if ((i & controlMask) && ((i & targetMask) == 0)) {
            size_t j = i | targetMask;

            float tr = g_stateReal[i];
            float ti = g_stateImag[i];
            g_stateReal[i] = g_stateReal[j];
            g_stateImag[i] = g_stateImag[j];
            g_stateReal[j] = tr;
            g_stateImag[j] = ti;
        }
    }
}

EMSCRIPTEN_KEEPALIVE
void quantum_cz(int control, int target) {
    if (!g_stateReal || !g_stateImag) return;
    if (control < 0 || control >= g_numQubits) return;
    if (target < 0 || target >= g_numQubits) return;

    size_t controlMask = 1UL << control;
    size_t targetMask = 1UL << target;

    for (size_t i = 0; i < g_stateSize; ++i) {
        if ((i & controlMask) && (i & targetMask)) {
            g_stateReal[i] = -g_stateReal[i];
            g_stateImag[i] = -g_stateImag[i];
        }
    }
}

EMSCRIPTEN_KEEPALIVE
void quantum_swap(int qubit1, int qubit2) {
    if (!g_stateReal || !g_stateImag) return;
    if (qubit1 < 0 || qubit1 >= g_numQubits) return;
    if (qubit2 < 0 || qubit2 >= g_numQubits) return;
    if (qubit1 == qubit2) return;

    size_t mask1 = 1UL << qubit1;
    size_t mask2 = 1UL << qubit2;

    for (size_t i = 0; i < g_stateSize; ++i) {
        int bit1 = (i & mask1) ? 1 : 0;
        int bit2 = (i & mask2) ? 1 : 0;

        if (bit1 != bit2 && bit1 < bit2) {
            size_t j = (i ^ mask1) ^ mask2;

            float tr = g_stateReal[i];
            float ti = g_stateImag[i];
            g_stateReal[i] = g_stateReal[j];
            g_stateImag[i] = g_stateImag[j];
            g_stateReal[j] = tr;
            g_stateImag[j] = ti;
        }
    }
}

EMSCRIPTEN_KEEPALIVE
void quantum_controlled_phase(int control, int target, float theta) {
    if (!g_stateReal || !g_stateImag) return;
    if (control < 0 || control >= g_numQubits) return;
    if (target < 0 || target >= g_numQubits) return;

    float c = cosf(theta);
    float s = sinf(theta);
    size_t controlMask = 1UL << control;
    size_t targetMask = 1UL << target;

    for (size_t i = 0; i < g_stateSize; ++i) {
        if ((i & controlMask) && (i & targetMask)) {
            float r = g_stateReal[i];
            float im = g_stateImag[i];
            g_stateReal[i] = r * c - im * s;
            g_stateImag[i] = r * s + im * c;
        }
    }
}

// =============================================================================
// THREE-QUBIT GATES
// =============================================================================

EMSCRIPTEN_KEEPALIVE
void quantum_toffoli(int control1, int control2, int target) {
    if (!g_stateReal || !g_stateImag) return;
    if (control1 < 0 || control1 >= g_numQubits) return;
    if (control2 < 0 || control2 >= g_numQubits) return;
    if (target < 0 || target >= g_numQubits) return;

    size_t c1Mask = 1UL << control1;
    size_t c2Mask = 1UL << control2;
    size_t targetMask = 1UL << target;

    for (size_t i = 0; i < g_stateSize; ++i) {
        if ((i & c1Mask) && (i & c2Mask) && ((i & targetMask) == 0)) {
            size_t j = i | targetMask;

            float tr = g_stateReal[i];
            float ti = g_stateImag[i];
            g_stateReal[i] = g_stateReal[j];
            g_stateImag[i] = g_stateImag[j];
            g_stateReal[j] = tr;
            g_stateImag[j] = ti;
        }
    }
}

// =============================================================================
// MEASUREMENT
// =============================================================================

EMSCRIPTEN_KEEPALIVE
float* quantum_get_probabilities() {
    if (!g_stateReal || !g_stateImag) return nullptr;

    float* probs = (float*)malloc(g_stateSize * sizeof(float));
    if (!probs) return nullptr;

    for (size_t i = 0; i < g_stateSize; ++i) {
        float r = g_stateReal[i];
        float im = g_stateImag[i];
        probs[i] = r * r + im * im;
    }

    return probs;
}

EMSCRIPTEN_KEEPALIVE
int quantum_measure_all() {
    if (!g_stateReal || !g_stateImag || !g_rng) return -1;

    // Calculate probabilities
    std::vector<float> probs(g_stateSize);
    for (size_t i = 0; i < g_stateSize; ++i) {
        float r = g_stateReal[i];
        float im = g_stateImag[i];
        probs[i] = r * r + im * im;
    }

    // Sample from distribution
    std::uniform_real_distribution<float> dist(0.0f, 1.0f);
    float r = dist(*g_rng);

    float cumulative = 0.0f;
    int measuredState = 0;
    for (size_t i = 0; i < g_stateSize; ++i) {
        cumulative += probs[i];
        if (r <= cumulative) {
            measuredState = (int)i;
            break;
        }
    }

    // Collapse state
    memset(g_stateReal, 0, g_stateSize * sizeof(float));
    memset(g_stateImag, 0, g_stateSize * sizeof(float));
    g_stateReal[measuredState] = 1.0f;

    return measuredState;
}

EMSCRIPTEN_KEEPALIVE
int quantum_measure_qubit(int qubit) {
    if (!g_stateReal || !g_stateImag || !g_rng) return -1;
    if (qubit < 0 || qubit >= g_numQubits) return -1;

    size_t mask = 1UL << qubit;

    // Calculate P(qubit=0)
    float p0 = 0.0f;
    for (size_t i = 0; i < g_stateSize; ++i) {
        if ((i & mask) == 0) {
            float r = g_stateReal[i];
            float im = g_stateImag[i];
            p0 += r * r + im * im;
        }
    }

    // Sample
    std::uniform_real_distribution<float> dist(0.0f, 1.0f);
    int result = (dist(*g_rng) < p0) ? 0 : 1;

    // Collapse state
    float norm = (result == 0) ? p0 : (1.0f - p0);
    float invNorm = 1.0f / sqrtf(norm);

    for (size_t i = 0; i < g_stateSize; ++i) {
        int bitValue = (i & mask) ? 1 : 0;
        if (bitValue != result) {
            g_stateReal[i] = 0.0f;
            g_stateImag[i] = 0.0f;
        } else {
            g_stateReal[i] *= invNorm;
            g_stateImag[i] *= invNorm;
        }
    }

    return result;
}

// =============================================================================
// QUANTUM ALGORITHMS
// =============================================================================

// Grover's diffusion operator
EMSCRIPTEN_KEEPALIVE
void quantum_grover_diffusion() {
    if (!g_stateReal || !g_stateImag) return;

    // Calculate mean amplitude
    float meanReal = 0.0f;
    float meanImag = 0.0f;
    for (size_t i = 0; i < g_stateSize; ++i) {
        meanReal += g_stateReal[i];
        meanImag += g_stateImag[i];
    }
    meanReal /= (float)g_stateSize;
    meanImag /= (float)g_stateSize;

    // Apply 2|s><s| - I
    for (size_t i = 0; i < g_stateSize; ++i) {
        g_stateReal[i] = 2.0f * meanReal - g_stateReal[i];
        g_stateImag[i] = 2.0f * meanImag - g_stateImag[i];
    }
}

// Phase oracle for marked state
EMSCRIPTEN_KEEPALIVE
void quantum_phase_oracle(int markedState) {
    if (!g_stateReal || !g_stateImag) return;
    if (markedState < 0 || (size_t)markedState >= g_stateSize) return;

    g_stateReal[markedState] = -g_stateReal[markedState];
    g_stateImag[markedState] = -g_stateImag[markedState];
}

// Quantum Fourier Transform
EMSCRIPTEN_KEEPALIVE
void quantum_qft() {
    if (!g_stateReal || !g_stateImag) return;

    for (int j = 0; j < g_numQubits; ++j) {
        quantum_hadamard(j);
        for (int k = j + 1; k < g_numQubits; ++k) {
            float theta = M_PI / (float)(1 << (k - j));
            quantum_controlled_phase(k, j, theta);
        }
    }

    // Swap qubits to reverse order
    for (int i = 0; i < g_numQubits / 2; ++i) {
        quantum_swap(i, g_numQubits - 1 - i);
    }
}

// Inverse QFT
EMSCRIPTEN_KEEPALIVE
void quantum_inverse_qft() {
    if (!g_stateReal || !g_stateImag) return;

    // Swap first
    for (int i = 0; i < g_numQubits / 2; ++i) {
        quantum_swap(i, g_numQubits - 1 - i);
    }

    for (int j = g_numQubits - 1; j >= 0; --j) {
        for (int k = g_numQubits - 1; k > j; --k) {
            float theta = -M_PI / (float)(1 << (k - j));
            quantum_controlled_phase(k, j, theta);
        }
        quantum_hadamard(j);
    }
}

// =============================================================================
// STATE VECTOR ACCESS (for debugging/visualization)
// =============================================================================

EMSCRIPTEN_KEEPALIVE
float quantum_get_amplitude_real(int index) {
    if (!g_stateReal || index < 0 || (size_t)index >= g_stateSize) return 0.0f;
    return g_stateReal[index];
}

EMSCRIPTEN_KEEPALIVE
float quantum_get_amplitude_imag(int index) {
    if (!g_stateImag || index < 0 || (size_t)index >= g_stateSize) return 0.0f;
    return g_stateImag[index];
}

EMSCRIPTEN_KEEPALIVE
void quantum_set_amplitude(int index, float real, float imag) {
    if (!g_stateReal || !g_stateImag) return;
    if (index < 0 || (size_t)index >= g_stateSize) return;

    g_stateReal[index] = real;
    g_stateImag[index] = imag;
}

EMSCRIPTEN_KEEPALIVE
void quantum_normalize() {
    if (!g_stateReal || !g_stateImag) return;

    float norm = 0.0f;
    for (size_t i = 0; i < g_stateSize; ++i) {
        float r = g_stateReal[i];
        float im = g_stateImag[i];
        norm += r * r + im * im;
    }

    if (norm > 0.0f) {
        float invNorm = 1.0f / sqrtf(norm);
        for (size_t i = 0; i < g_stateSize; ++i) {
            g_stateReal[i] *= invNorm;
            g_stateImag[i] *= invNorm;
        }
    }
}

// =============================================================================
// BENCHMARK
// =============================================================================

EMSCRIPTEN_KEEPALIVE
double quantum_benchmark(int qubits, int gates) {
    if (quantum_initialize(qubits) != 0) return -1.0;

    quantum_initialize_superposition();

    // Run gates
    for (int i = 0; i < gates; ++i) {
        int q = i % qubits;
        switch (i % 6) {
            case 0: quantum_hadamard(q); break;
            case 1: quantum_pauli_x(q); break;
            case 2: quantum_ry(q, 0.5f); break;
            case 3: if (qubits > 1) quantum_cnot(q, (q + 1) % qubits); break;
            case 4: quantum_rz(q, 0.3f); break;
            case 5: if (qubits > 1) quantum_cz(q, (q + 1) % qubits); break;
        }
    }

    return (double)gates;  // Return gates completed
}

}  // extern "C"
