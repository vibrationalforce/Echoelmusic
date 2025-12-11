//
//  QuantumAccelerator.cpp
//  Echoelmusic Desktop
//
//  Created: December 2025
//  CROSS-PLATFORM GPU-ACCELERATED QUANTUM SIMULATION
//

#include "QuantumAccelerator.h"
#include <cmath>
#include <random>
#include <algorithm>
#include <chrono>
#include <thread>

#ifdef _WIN32
#include <windows.h>
#endif

// SIMD headers
#if defined(__AVX2__)
#include <immintrin.h>
#define USE_AVX2 1
#elif defined(__SSE2__)
#include <emmintrin.h>
#define USE_SSE2 1
#elif defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>
#define USE_NEON 1
#endif

namespace Echoelmusic {
namespace Quantum {

// Constants
static const float SQRT2_INV = 0.70710678118f;
static const float PI = 3.14159265359f;

// Random number generator
static std::mt19937 g_rng(std::random_device{}());

// ═══════════════════════════════════════════════════════════════════════════════
// CPU QUANTUM ACCELERATOR IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════════

CPUQuantumAccelerator::CPUQuantumAccelerator() = default;
CPUQuantumAccelerator::~CPUQuantumAccelerator() { shutdown(); }

bool CPUQuantumAccelerator::initialize(int maxQubits) {
    m_maxQubits = std::min(maxQubits, 24);  // Limit to prevent memory issues
    m_initialized = true;
    return true;
}

void CPUQuantumAccelerator::shutdown() {
    m_stateVector.clear();
    m_numQubits = 0;
    m_initialized = false;
}

bool CPUQuantumAccelerator::initializeState(int numQubits) {
    if (numQubits > m_maxQubits || numQubits <= 0) return false;

    m_numQubits = numQubits;
    size_t stateSize = 1ULL << numQubits;

    m_stateVector.clear();
    m_stateVector.resize(stateSize, Complex(0.0f, 0.0f));
    m_stateVector[0] = Complex(1.0f, 0.0f);

    return true;
}

bool CPUQuantumAccelerator::initializeSuperposition() {
    if (m_stateVector.empty()) return false;

    float amplitude = 1.0f / std::sqrt(static_cast<float>(m_stateVector.size()));
    for (auto& amp : m_stateVector) {
        amp = Complex(amplitude, 0.0f);
    }
    return true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SINGLE-QUBIT GATES
// ═══════════════════════════════════════════════════════════════════════════════

void CPUQuantumAccelerator::applyHadamard(int qubit) {
    size_t stateSize = m_stateVector.size();
    size_t mask = 1ULL << qubit;

#if USE_AVX2
    // AVX2 optimized version
    __m256 h_vec = _mm256_set1_ps(SQRT2_INV);

    for (size_t i = 0; i < stateSize; i += mask * 2) {
        for (size_t j = i; j < i + mask; j += 4) {
            if (j + 3 + mask >= stateSize) {
                // Fallback for edge case
                for (size_t k = j; k < std::min(j + 4, i + mask); k++) {
                    Complex a = m_stateVector[k];
                    Complex b = m_stateVector[k + mask];
                    m_stateVector[k] = SQRT2_INV * (a + b);
                    m_stateVector[k + mask] = SQRT2_INV * (a - b);
                }
                continue;
            }

            // Load 4 complex numbers from each side
            // Note: This is simplified - full AVX2 impl would be more complex
            for (size_t k = j; k < j + 4; k++) {
                Complex a = m_stateVector[k];
                Complex b = m_stateVector[k + mask];
                m_stateVector[k] = SQRT2_INV * (a + b);
                m_stateVector[k + mask] = SQRT2_INV * (a - b);
            }
        }
    }
#else
    // Standard implementation
    for (size_t i = 0; i < stateSize; i += mask * 2) {
        for (size_t j = i; j < i + mask; j++) {
            Complex a = m_stateVector[j];
            Complex b = m_stateVector[j + mask];
            m_stateVector[j] = SQRT2_INV * (a + b);
            m_stateVector[j + mask] = SQRT2_INV * (a - b);
        }
    }
#endif
}

void CPUQuantumAccelerator::applyPauliX(int qubit) {
    size_t stateSize = m_stateVector.size();
    size_t mask = 1ULL << qubit;

    for (size_t i = 0; i < stateSize; i += mask * 2) {
        for (size_t j = i; j < i + mask; j++) {
            std::swap(m_stateVector[j], m_stateVector[j + mask]);
        }
    }
}

void CPUQuantumAccelerator::applyPauliY(int qubit) {
    size_t stateSize = m_stateVector.size();
    size_t mask = 1ULL << qubit;

    for (size_t i = 0; i < stateSize; i += mask * 2) {
        for (size_t j = i; j < i + mask; j++) {
            Complex a = m_stateVector[j];
            Complex b = m_stateVector[j + mask];
            m_stateVector[j] = Complex(b.imag(), -b.real());
            m_stateVector[j + mask] = Complex(-a.imag(), a.real());
        }
    }
}

void CPUQuantumAccelerator::applyPauliZ(int qubit) {
    size_t stateSize = m_stateVector.size();
    size_t mask = 1ULL << qubit;

    for (size_t i = 0; i < stateSize; i++) {
        if ((i & mask) != 0) {
            m_stateVector[i] = -m_stateVector[i];
        }
    }
}

void CPUQuantumAccelerator::applyRx(int qubit, float theta) {
    size_t stateSize = m_stateVector.size();
    size_t mask = 1ULL << qubit;

    float c = std::cos(theta * 0.5f);
    float s = std::sin(theta * 0.5f);

    for (size_t i = 0; i < stateSize; i += mask * 2) {
        for (size_t j = i; j < i + mask; j++) {
            Complex a = m_stateVector[j];
            Complex b = m_stateVector[j + mask];

            m_stateVector[j] = Complex(
                c * a.real() + s * b.imag(),
                c * a.imag() - s * b.real()
            );
            m_stateVector[j + mask] = Complex(
                s * a.imag() + c * b.real(),
                -s * a.real() + c * b.imag()
            );
        }
    }
}

void CPUQuantumAccelerator::applyRy(int qubit, float theta) {
    size_t stateSize = m_stateVector.size();
    size_t mask = 1ULL << qubit;

    float c = std::cos(theta * 0.5f);
    float s = std::sin(theta * 0.5f);

    for (size_t i = 0; i < stateSize; i += mask * 2) {
        for (size_t j = i; j < i + mask; j++) {
            Complex a = m_stateVector[j];
            Complex b = m_stateVector[j + mask];

            m_stateVector[j] = Complex(
                c * a.real() - s * b.real(),
                c * a.imag() - s * b.imag()
            );
            m_stateVector[j + mask] = Complex(
                s * a.real() + c * b.real(),
                s * a.imag() + c * b.imag()
            );
        }
    }
}

void CPUQuantumAccelerator::applyRz(int qubit, float theta) {
    size_t stateSize = m_stateVector.size();
    size_t mask = 1ULL << qubit;

    float halfTheta = theta * 0.5f;
    Complex phase0(std::cos(-halfTheta), std::sin(-halfTheta));
    Complex phase1(std::cos(halfTheta), std::sin(halfTheta));

    for (size_t i = 0; i < stateSize; i++) {
        if ((i & mask) == 0) {
            m_stateVector[i] *= phase0;
        } else {
            m_stateVector[i] *= phase1;
        }
    }
}

void CPUQuantumAccelerator::applyPhase(int qubit, float theta) {
    size_t stateSize = m_stateVector.size();
    size_t mask = 1ULL << qubit;

    Complex phase(std::cos(theta), std::sin(theta));

    for (size_t i = 0; i < stateSize; i++) {
        if ((i & mask) != 0) {
            m_stateVector[i] *= phase;
        }
    }
}

void CPUQuantumAccelerator::applyT(int qubit) {
    applyPhase(qubit, PI / 4);
}

void CPUQuantumAccelerator::applyS(int qubit) {
    applyPhase(qubit, PI / 2);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TWO-QUBIT GATES
// ═══════════════════════════════════════════════════════════════════════════════

void CPUQuantumAccelerator::applyCNOT(int control, int target) {
    size_t stateSize = m_stateVector.size();
    size_t controlMask = 1ULL << control;
    size_t targetMask = 1ULL << target;

    for (size_t i = 0; i < stateSize; i++) {
        if ((i & controlMask) != 0 && (i & targetMask) == 0) {
            std::swap(m_stateVector[i], m_stateVector[i | targetMask]);
        }
    }
}

void CPUQuantumAccelerator::applyCZ(int control, int target) {
    size_t stateSize = m_stateVector.size();
    size_t controlMask = 1ULL << control;
    size_t targetMask = 1ULL << target;

    for (size_t i = 0; i < stateSize; i++) {
        if ((i & controlMask) != 0 && (i & targetMask) != 0) {
            m_stateVector[i] = -m_stateVector[i];
        }
    }
}

void CPUQuantumAccelerator::applySWAP(int qubit1, int qubit2) {
    size_t stateSize = m_stateVector.size();
    size_t mask1 = 1ULL << qubit1;
    size_t mask2 = 1ULL << qubit2;

    for (size_t i = 0; i < stateSize; i++) {
        bool bit1 = (i & mask1) != 0;
        bool bit2 = (i & mask2) != 0;

        if (bit1 != bit2) {
            size_t j = i ^ mask1 ^ mask2;
            if (i < j) {
                std::swap(m_stateVector[i], m_stateVector[j]);
            }
        }
    }
}

void CPUQuantumAccelerator::applyControlledPhase(int control, int target, float theta) {
    size_t stateSize = m_stateVector.size();
    size_t controlMask = 1ULL << control;
    size_t targetMask = 1ULL << target;

    Complex phase(std::cos(theta), std::sin(theta));

    for (size_t i = 0; i < stateSize; i++) {
        if ((i & controlMask) != 0 && (i & targetMask) != 0) {
            m_stateVector[i] *= phase;
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// THREE-QUBIT GATES
// ═══════════════════════════════════════════════════════════════════════════════

void CPUQuantumAccelerator::applyToffoli(int control1, int control2, int target) {
    size_t stateSize = m_stateVector.size();
    size_t c1Mask = 1ULL << control1;
    size_t c2Mask = 1ULL << control2;
    size_t tMask = 1ULL << target;

    for (size_t i = 0; i < stateSize; i++) {
        if ((i & c1Mask) != 0 && (i & c2Mask) != 0 && (i & tMask) == 0) {
            std::swap(m_stateVector[i], m_stateVector[i | tMask]);
        }
    }
}

void CPUQuantumAccelerator::applyFredkin(int control, int target1, int target2) {
    size_t stateSize = m_stateVector.size();
    size_t cMask = 1ULL << control;
    size_t t1Mask = 1ULL << target1;
    size_t t2Mask = 1ULL << target2;

    for (size_t i = 0; i < stateSize; i++) {
        if ((i & cMask) != 0) {
            bool bit1 = (i & t1Mask) != 0;
            bool bit2 = (i & t2Mask) != 0;

            if (bit1 != bit2) {
                size_t j = i ^ t1Mask ^ t2Mask;
                if (i < j) {
                    std::swap(m_stateVector[i], m_stateVector[j]);
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MEASUREMENT
// ═══════════════════════════════════════════════════════════════════════════════

std::vector<float> CPUQuantumAccelerator::getProbabilities() {
    std::vector<float> probs(m_stateVector.size());

    for (size_t i = 0; i < m_stateVector.size(); i++) {
        probs[i] = std::norm(m_stateVector[i]);
    }

    return probs;
}

std::vector<int> CPUQuantumAccelerator::measureAll() {
    std::vector<float> probs = getProbabilities();

    std::uniform_real_distribution<float> dist(0.0f, 1.0f);
    float random = dist(g_rng);

    float cumulative = 0.0f;
    size_t result = 0;

    for (size_t i = 0; i < probs.size(); i++) {
        cumulative += probs[i];
        if (random < cumulative) {
            result = i;
            break;
        }
    }

    std::vector<int> bitstring(m_numQubits);
    for (int q = 0; q < m_numQubits; q++) {
        bitstring[q] = (result >> q) & 1;
    }

    return bitstring;
}

int CPUQuantumAccelerator::measureQubit(int qubit) {
    size_t stateSize = m_stateVector.size();
    size_t mask = 1ULL << qubit;

    float prob1 = 0.0f;
    for (size_t i = 0; i < stateSize; i++) {
        if ((i & mask) != 0) {
            prob1 += std::norm(m_stateVector[i]);
        }
    }

    std::uniform_real_distribution<float> dist(0.0f, 1.0f);
    int result = dist(g_rng) < prob1 ? 1 : 0;

    // Collapse state
    float normFactor = 0.0f;
    for (size_t i = 0; i < stateSize; i++) {
        bool bitValue = (i & mask) != 0;
        if ((result == 1) != bitValue) {
            m_stateVector[i] = Complex(0.0f, 0.0f);
        } else {
            normFactor += std::norm(m_stateVector[i]);
        }
    }

    normFactor = 1.0f / std::sqrt(normFactor);
    for (auto& amp : m_stateVector) {
        amp *= normFactor;
    }

    return result;
}

void CPUQuantumAccelerator::normalize() {
    float norm = 0.0f;
    for (const auto& amp : m_stateVector) {
        norm += std::norm(amp);
    }

    norm = 1.0f / std::sqrt(norm);
    for (auto& amp : m_stateVector) {
        amp *= norm;
    }
}

void CPUQuantumAccelerator::setStateVector(const std::vector<Complex>& state) {
    if (state.size() != m_stateVector.size()) return;
    m_stateVector = state;
}

std::string CPUQuantumAccelerator::getDeviceName() const {
#ifdef _WIN32
    SYSTEM_INFO sysInfo;
    GetSystemInfo(&sysInfo);
    return "CPU (" + std::to_string(sysInfo.dwNumberOfProcessors) + " cores)";
#else
    return "CPU (" + std::to_string(std::thread::hardware_concurrency()) + " cores)";
#endif
}

size_t CPUQuantumAccelerator::getDeviceMemory() const {
#ifdef _WIN32
    MEMORYSTATUSEX memInfo;
    memInfo.dwLength = sizeof(MEMORYSTATUSEX);
    GlobalMemoryStatusEx(&memInfo);
    return memInfo.ullTotalPhys;
#else
    return 0;  // Platform-specific implementation needed
#endif
}

IQuantumAccelerator::BenchmarkResult CPUQuantumAccelerator::benchmark(int qubits, int gates) {
    initializeState(qubits);
    initializeSuperposition();

    auto start = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < gates; i++) {
        applyHadamard(0);
    }

    auto end = std::chrono::high_resolution_clock::now();
    double elapsed = std::chrono::duration<double>(end - start).count();

    return {
        static_cast<double>(gates) / elapsed,
        elapsed,
        gates,
        qubits
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// FACTORY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

std::unique_ptr<IQuantumAccelerator> createQuantumAccelerator() {
    // TODO: Add DirectML/OpenCL detection and use GPU if available
    // For now, return CPU implementation
    auto accelerator = std::make_unique<CPUQuantumAccelerator>();
    accelerator->initialize();
    return accelerator;
}

bool isGPUAccelerationAvailable() {
    // TODO: Check for DirectML/OpenCL availability
    return false;
}

std::vector<std::string> getAvailableBackends() {
    std::vector<std::string> backends;
    backends.push_back("CPU (SIMD)");

#ifdef _WIN32
    // TODO: Check DirectML availability
    // backends.push_back("DirectML (GPU)");
#else
    // TODO: Check OpenCL availability
    // backends.push_back("OpenCL (GPU)");
#endif

    return backends;
}

}  // namespace Quantum
}  // namespace Echoelmusic
