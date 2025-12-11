//
//  QuantumAccelerator.h
//  Echoelmusic Desktop
//
//  Created: December 2025
//  CROSS-PLATFORM GPU-ACCELERATED QUANTUM SIMULATION
//
//  Backends:
//  - Windows: DirectML (DirectX 12)
//  - Linux: OpenCL
//  - macOS: Metal (handled by Swift)
//
//  Features:
//  - GPU-accelerated quantum gate operations
//  - SIMD optimization on CPU fallback
//  - Automatic backend selection
//  - Thread-safe operations
//

#pragma once

#include <vector>
#include <complex>
#include <memory>
#include <string>
#include <functional>

namespace Echoelmusic {
namespace Quantum {

// Complex amplitude type
using Complex = std::complex<float>;

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTUM ACCELERATOR INTERFACE
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Abstract interface for GPU-accelerated quantum simulation
 */
class IQuantumAccelerator {
public:
    virtual ~IQuantumAccelerator() = default;

    // Initialization
    virtual bool initialize(int maxQubits = 20) = 0;
    virtual void shutdown() = 0;
    virtual bool isAvailable() const = 0;

    // State management
    virtual bool initializeState(int numQubits) = 0;
    virtual bool initializeSuperposition() = 0;
    virtual int getNumQubits() const = 0;
    virtual size_t getStateSize() const = 0;

    // Single-qubit gates
    virtual void applyHadamard(int qubit) = 0;
    virtual void applyPauliX(int qubit) = 0;
    virtual void applyPauliY(int qubit) = 0;
    virtual void applyPauliZ(int qubit) = 0;
    virtual void applyRx(int qubit, float theta) = 0;
    virtual void applyRy(int qubit, float theta) = 0;
    virtual void applyRz(int qubit, float theta) = 0;
    virtual void applyPhase(int qubit, float theta) = 0;
    virtual void applyT(int qubit) = 0;
    virtual void applyS(int qubit) = 0;

    // Two-qubit gates
    virtual void applyCNOT(int control, int target) = 0;
    virtual void applyCZ(int control, int target) = 0;
    virtual void applySWAP(int qubit1, int qubit2) = 0;
    virtual void applyControlledPhase(int control, int target, float theta) = 0;

    // Three-qubit gates
    virtual void applyToffoli(int control1, int control2, int target) = 0;
    virtual void applyFredkin(int control, int target1, int target2) = 0;

    // Measurement
    virtual std::vector<float> getProbabilities() = 0;
    virtual std::vector<int> measureAll() = 0;
    virtual int measureQubit(int qubit) = 0;

    // Utility
    virtual void normalize() = 0;
    virtual std::vector<Complex> getStateVector() = 0;
    virtual void setStateVector(const std::vector<Complex>& state) = 0;

    // Info
    virtual std::string getBackendName() const = 0;
    virtual std::string getDeviceName() const = 0;
    virtual size_t getDeviceMemory() const = 0;

    // Benchmark
    struct BenchmarkResult {
        double gatesPerSecond;
        double totalTime;
        int gates;
        int qubits;
    };
    virtual BenchmarkResult benchmark(int qubits, int gates = 10000) = 0;
};

// ═══════════════════════════════════════════════════════════════════════════════
// CPU FALLBACK IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * CPU-based quantum simulation with SIMD optimization
 */
class CPUQuantumAccelerator : public IQuantumAccelerator {
public:
    CPUQuantumAccelerator();
    ~CPUQuantumAccelerator() override;

    bool initialize(int maxQubits = 20) override;
    void shutdown() override;
    bool isAvailable() const override { return true; }

    bool initializeState(int numQubits) override;
    bool initializeSuperposition() override;
    int getNumQubits() const override { return m_numQubits; }
    size_t getStateSize() const override { return m_stateVector.size(); }

    void applyHadamard(int qubit) override;
    void applyPauliX(int qubit) override;
    void applyPauliY(int qubit) override;
    void applyPauliZ(int qubit) override;
    void applyRx(int qubit, float theta) override;
    void applyRy(int qubit, float theta) override;
    void applyRz(int qubit, float theta) override;
    void applyPhase(int qubit, float theta) override;
    void applyT(int qubit) override;
    void applyS(int qubit) override;

    void applyCNOT(int control, int target) override;
    void applyCZ(int control, int target) override;
    void applySWAP(int qubit1, int qubit2) override;
    void applyControlledPhase(int control, int target, float theta) override;

    void applyToffoli(int control1, int control2, int target) override;
    void applyFredkin(int control, int target1, int target2) override;

    std::vector<float> getProbabilities() override;
    std::vector<int> measureAll() override;
    int measureQubit(int qubit) override;

    void normalize() override;
    std::vector<Complex> getStateVector() override { return m_stateVector; }
    void setStateVector(const std::vector<Complex>& state) override;

    std::string getBackendName() const override { return "CPU (SIMD)"; }
    std::string getDeviceName() const override;
    size_t getDeviceMemory() const override;

    BenchmarkResult benchmark(int qubits, int gates = 10000) override;

private:
    std::vector<Complex> m_stateVector;
    int m_numQubits = 0;
    int m_maxQubits = 20;
    bool m_initialized = false;
};

// ═══════════════════════════════════════════════════════════════════════════════
// FACTORY
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Create best available quantum accelerator for current platform
 */
std::unique_ptr<IQuantumAccelerator> createQuantumAccelerator();

/**
 * Check if GPU acceleration is available
 */
bool isGPUAccelerationAvailable();

/**
 * Get list of available backends
 */
std::vector<std::string> getAvailableBackends();

}  // namespace Quantum
}  // namespace Echoelmusic
