//
//  LinuxQuantumCL.cpp
//  Echoelmusic Desktop - Linux
//
//  Created: December 2025
//  OPENCL GPU-ACCELERATED QUANTUM SIMULATION
//
//  Features:
//  - GPU-accelerated quantum gate operations via OpenCL
//  - Automatic device selection (GPU preferred, CPU fallback)
//  - Double-buffered state vector for efficient gate application
//  - Supports up to 28 qubits on high-end GPUs (16GB+ VRAM)
//  - SIMD CPU fallback when OpenCL unavailable
//

#ifdef __linux__

#include "QuantumAccelerator.h"
#include <CL/cl.h>
#include <iostream>
#include <sstream>
#include <random>
#include <chrono>
#include <cstring>

namespace Echoelmusic {
namespace Quantum {

// =============================================================================
// OPENCL KERNEL SOURCE
// =============================================================================

static const char* QUANTUM_KERNELS = R"(
// Complex number operations
typedef float2 Complex;

Complex cmul(Complex a, Complex b) {
    return (Complex)(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

Complex cadd(Complex a, Complex b) {
    return (Complex)(a.x + b.x, a.y + b.y);
}

Complex csub(Complex a, Complex b) {
    return (Complex)(a.x - b.x, a.y - b.y);
}

Complex cscale(Complex a, float s) {
    return (Complex)(a.x * s, a.y * s);
}

float cnorm2(Complex a) {
    return a.x * a.x + a.y * a.y;
}

// =============================================================================
// SINGLE-QUBIT GATES
// =============================================================================

__kernel void hadamard(
    __global Complex* stateIn,
    __global Complex* stateOut,
    int qubit,
    int numQubits
) {
    size_t idx = get_global_id(0);
    size_t stateSize = 1UL << numQubits;

    if (idx >= stateSize) return;

    size_t mask = 1UL << qubit;
    size_t idx0 = idx & ~mask;
    size_t idx1 = idx | mask;

    if ((idx & mask) == 0) {
        Complex a0 = stateIn[idx0];
        Complex a1 = stateIn[idx1];

        float inv_sqrt2 = 0.7071067811865476f;

        stateOut[idx0] = cscale(cadd(a0, a1), inv_sqrt2);
        stateOut[idx1] = cscale(csub(a0, a1), inv_sqrt2);
    }
}

__kernel void pauliX(
    __global Complex* stateIn,
    __global Complex* stateOut,
    int qubit,
    int numQubits
) {
    size_t idx = get_global_id(0);
    size_t stateSize = 1UL << numQubits;

    if (idx >= stateSize) return;

    size_t mask = 1UL << qubit;
    size_t idx0 = idx & ~mask;
    size_t idx1 = idx | mask;

    if ((idx & mask) == 0) {
        Complex a0 = stateIn[idx0];
        Complex a1 = stateIn[idx1];

        stateOut[idx0] = a1;
        stateOut[idx1] = a0;
    }
}

__kernel void pauliY(
    __global Complex* stateIn,
    __global Complex* stateOut,
    int qubit,
    int numQubits
) {
    size_t idx = get_global_id(0);
    size_t stateSize = 1UL << numQubits;

    if (idx >= stateSize) return;

    size_t mask = 1UL << qubit;
    size_t idx0 = idx & ~mask;
    size_t idx1 = idx | mask;

    if ((idx & mask) == 0) {
        Complex a0 = stateIn[idx0];
        Complex a1 = stateIn[idx1];

        // -i * a1, i * a0
        stateOut[idx0] = (Complex)(a1.y, -a1.x);
        stateOut[idx1] = (Complex)(-a0.y, a0.x);
    }
}

__kernel void pauliZ(
    __global Complex* stateIn,
    __global Complex* stateOut,
    int qubit,
    int numQubits
) {
    size_t idx = get_global_id(0);
    size_t stateSize = 1UL << numQubits;

    if (idx >= stateSize) return;

    size_t mask = 1UL << qubit;

    Complex a = stateIn[idx];
    if (idx & mask) {
        stateOut[idx] = (Complex)(-a.x, -a.y);
    } else {
        stateOut[idx] = a;
    }
}

__kernel void phase(
    __global Complex* stateIn,
    __global Complex* stateOut,
    int qubit,
    float theta,
    int numQubits
) {
    size_t idx = get_global_id(0);
    size_t stateSize = 1UL << numQubits;

    if (idx >= stateSize) return;

    size_t mask = 1UL << qubit;
    Complex a = stateIn[idx];

    if (idx & mask) {
        float c = cos(theta);
        float s = sin(theta);
        stateOut[idx] = (Complex)(a.x * c - a.y * s, a.x * s + a.y * c);
    } else {
        stateOut[idx] = a;
    }
}

__kernel void rx(
    __global Complex* stateIn,
    __global Complex* stateOut,
    int qubit,
    float theta,
    int numQubits
) {
    size_t idx = get_global_id(0);
    size_t stateSize = 1UL << numQubits;

    if (idx >= stateSize) return;

    size_t mask = 1UL << qubit;
    size_t idx0 = idx & ~mask;
    size_t idx1 = idx | mask;

    if ((idx & mask) == 0) {
        Complex a0 = stateIn[idx0];
        Complex a1 = stateIn[idx1];

        float c = cos(theta / 2.0f);
        float s = sin(theta / 2.0f);

        // Rx = [[c, -is], [-is, c]]
        stateOut[idx0] = (Complex)(c * a0.x + s * a1.y, c * a0.y - s * a1.x);
        stateOut[idx1] = (Complex)(c * a1.x + s * a0.y, c * a1.y - s * a0.x);
    }
}

__kernel void ry(
    __global Complex* stateIn,
    __global Complex* stateOut,
    int qubit,
    float theta,
    int numQubits
) {
    size_t idx = get_global_id(0);
    size_t stateSize = 1UL << numQubits;

    if (idx >= stateSize) return;

    size_t mask = 1UL << qubit;
    size_t idx0 = idx & ~mask;
    size_t idx1 = idx | mask;

    if ((idx & mask) == 0) {
        Complex a0 = stateIn[idx0];
        Complex a1 = stateIn[idx1];

        float c = cos(theta / 2.0f);
        float s = sin(theta / 2.0f);

        // Ry = [[c, -s], [s, c]]
        stateOut[idx0] = (Complex)(c * a0.x - s * a1.x, c * a0.y - s * a1.y);
        stateOut[idx1] = (Complex)(s * a0.x + c * a1.x, s * a0.y + c * a1.y);
    }
}

__kernel void rz(
    __global Complex* stateIn,
    __global Complex* stateOut,
    int qubit,
    float theta,
    int numQubits
) {
    size_t idx = get_global_id(0);
    size_t stateSize = 1UL << numQubits;

    if (idx >= stateSize) return;

    size_t mask = 1UL << qubit;
    Complex a = stateIn[idx];

    float halfTheta = theta / 2.0f;
    float c, s;

    if (idx & mask) {
        c = cos(halfTheta);
        s = sin(halfTheta);
    } else {
        c = cos(-halfTheta);
        s = sin(-halfTheta);
    }

    stateOut[idx] = (Complex)(a.x * c - a.y * s, a.x * s + a.y * c);
}

// =============================================================================
// TWO-QUBIT GATES
// =============================================================================

__kernel void cnot(
    __global Complex* stateIn,
    __global Complex* stateOut,
    int control,
    int target,
    int numQubits
) {
    size_t idx = get_global_id(0);
    size_t stateSize = 1UL << numQubits;

    if (idx >= stateSize) return;

    size_t controlMask = 1UL << control;
    size_t targetMask = 1UL << target;

    // Only process when control is set and we're at lower target index
    if ((idx & controlMask) && ((idx & targetMask) == 0)) {
        size_t idx0 = idx;
        size_t idx1 = idx | targetMask;

        Complex a0 = stateIn[idx0];
        Complex a1 = stateIn[idx1];

        stateOut[idx0] = a1;
        stateOut[idx1] = a0;
    } else if (!(idx & controlMask)) {
        // Control not set, copy through
        stateOut[idx] = stateIn[idx];
    }
}

__kernel void cz(
    __global Complex* stateIn,
    __global Complex* stateOut,
    int control,
    int target,
    int numQubits
) {
    size_t idx = get_global_id(0);
    size_t stateSize = 1UL << numQubits;

    if (idx >= stateSize) return;

    size_t controlMask = 1UL << control;
    size_t targetMask = 1UL << target;

    Complex a = stateIn[idx];

    // Negate phase when both control and target are |1>
    if ((idx & controlMask) && (idx & targetMask)) {
        stateOut[idx] = (Complex)(-a.x, -a.y);
    } else {
        stateOut[idx] = a;
    }
}

__kernel void swap(
    __global Complex* stateIn,
    __global Complex* stateOut,
    int qubit1,
    int qubit2,
    int numQubits
) {
    size_t idx = get_global_id(0);
    size_t stateSize = 1UL << numQubits;

    if (idx >= stateSize) return;

    size_t mask1 = 1UL << qubit1;
    size_t mask2 = 1UL << qubit2;

    int bit1 = (idx & mask1) ? 1 : 0;
    int bit2 = (idx & mask2) ? 1 : 0;

    if (bit1 != bit2) {
        // Swap the bits
        size_t swappedIdx = idx ^ mask1 ^ mask2;
        stateOut[idx] = stateIn[swappedIdx];
    } else {
        stateOut[idx] = stateIn[idx];
    }
}

__kernel void controlledPhase(
    __global Complex* stateIn,
    __global Complex* stateOut,
    int control,
    int target,
    float theta,
    int numQubits
) {
    size_t idx = get_global_id(0);
    size_t stateSize = 1UL << numQubits;

    if (idx >= stateSize) return;

    size_t controlMask = 1UL << control;
    size_t targetMask = 1UL << target;

    Complex a = stateIn[idx];

    if ((idx & controlMask) && (idx & targetMask)) {
        float c = cos(theta);
        float s = sin(theta);
        stateOut[idx] = (Complex)(a.x * c - a.y * s, a.x * s + a.y * c);
    } else {
        stateOut[idx] = a;
    }
}

// =============================================================================
// THREE-QUBIT GATES
// =============================================================================

__kernel void toffoli(
    __global Complex* stateIn,
    __global Complex* stateOut,
    int control1,
    int control2,
    int target,
    int numQubits
) {
    size_t idx = get_global_id(0);
    size_t stateSize = 1UL << numQubits;

    if (idx >= stateSize) return;

    size_t c1Mask = 1UL << control1;
    size_t c2Mask = 1UL << control2;
    size_t targetMask = 1UL << target;

    // Only flip target when both controls are |1>
    if ((idx & c1Mask) && (idx & c2Mask) && ((idx & targetMask) == 0)) {
        size_t idx0 = idx;
        size_t idx1 = idx | targetMask;

        Complex a0 = stateIn[idx0];
        Complex a1 = stateIn[idx1];

        stateOut[idx0] = a1;
        stateOut[idx1] = a0;
    } else if (!((idx & c1Mask) && (idx & c2Mask))) {
        stateOut[idx] = stateIn[idx];
    }
}

// =============================================================================
// MEASUREMENT
// =============================================================================

__kernel void computeProbabilities(
    __global Complex* state,
    __global float* probabilities,
    int numQubits
) {
    size_t idx = get_global_id(0);
    size_t stateSize = 1UL << numQubits;

    if (idx >= stateSize) return;

    Complex a = state[idx];
    probabilities[idx] = cnorm2(a);
}

__kernel void normalize(
    __global Complex* state,
    float invNorm,
    int numQubits
) {
    size_t idx = get_global_id(0);
    size_t stateSize = 1UL << numQubits;

    if (idx >= stateSize) return;

    state[idx] = cscale(state[idx], invNorm);
}

// =============================================================================
// INITIALIZATION
// =============================================================================

__kernel void initializeZero(
    __global Complex* state,
    int numQubits
) {
    size_t idx = get_global_id(0);
    size_t stateSize = 1UL << numQubits;

    if (idx >= stateSize) return;

    state[idx] = (idx == 0) ? (Complex)(1.0f, 0.0f) : (Complex)(0.0f, 0.0f);
}

__kernel void initializeSuperposition(
    __global Complex* state,
    int numQubits
) {
    size_t idx = get_global_id(0);
    size_t stateSize = 1UL << numQubits;

    if (idx >= stateSize) return;

    float amplitude = 1.0f / sqrt((float)stateSize);
    state[idx] = (Complex)(amplitude, 0.0f);
}
)";

// =============================================================================
// OPENCL QUANTUM ACCELERATOR
// =============================================================================

class OpenCLQuantumAccelerator : public IQuantumAccelerator {
public:
    OpenCLQuantumAccelerator();
    ~OpenCLQuantumAccelerator() override;

    bool initialize(int maxQubits = 20) override;
    void shutdown() override;
    bool isAvailable() const override;

    bool initializeState(int numQubits) override;
    bool initializeSuperposition() override;
    int getNumQubits() const override { return m_numQubits; }
    size_t getStateSize() const override { return m_stateSize; }

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
    std::vector<Complex> getStateVector() override;
    void setStateVector(const std::vector<Complex>& state) override;

    std::string getBackendName() const override { return "OpenCL"; }
    std::string getDeviceName() const override { return m_deviceName; }
    size_t getDeviceMemory() const override { return m_deviceMemory; }

    BenchmarkResult benchmark(int qubits, int gates = 10000) override;

private:
    // OpenCL objects
    cl_platform_id m_platform = nullptr;
    cl_device_id m_device = nullptr;
    cl_context m_context = nullptr;
    cl_command_queue m_queue = nullptr;
    cl_program m_program = nullptr;

    // Kernels
    cl_kernel m_hadamardKernel = nullptr;
    cl_kernel m_pauliXKernel = nullptr;
    cl_kernel m_pauliYKernel = nullptr;
    cl_kernel m_pauliZKernel = nullptr;
    cl_kernel m_phaseKernel = nullptr;
    cl_kernel m_rxKernel = nullptr;
    cl_kernel m_ryKernel = nullptr;
    cl_kernel m_rzKernel = nullptr;
    cl_kernel m_cnotKernel = nullptr;
    cl_kernel m_czKernel = nullptr;
    cl_kernel m_swapKernel = nullptr;
    cl_kernel m_controlledPhaseKernel = nullptr;
    cl_kernel m_toffoliKernel = nullptr;
    cl_kernel m_computeProbKernel = nullptr;
    cl_kernel m_normalizeKernel = nullptr;
    cl_kernel m_initZeroKernel = nullptr;
    cl_kernel m_initSuperKernel = nullptr;

    // Buffers
    cl_mem m_stateBuffer1 = nullptr;
    cl_mem m_stateBuffer2 = nullptr;
    cl_mem m_probBuffer = nullptr;
    bool m_useBuffer1 = true;

    // State
    int m_numQubits = 0;
    size_t m_stateSize = 0;
    int m_maxQubits = 20;
    bool m_initialized = false;
    bool m_available = false;

    // Device info
    std::string m_deviceName;
    size_t m_deviceMemory = 0;

    // RNG
    std::mt19937 m_rng;

    // Helpers
    bool initializeOpenCL();
    bool createKernels();
    void swapBuffers();
    cl_mem getCurrentBuffer() { return m_useBuffer1 ? m_stateBuffer1 : m_stateBuffer2; }
    cl_mem getOtherBuffer() { return m_useBuffer1 ? m_stateBuffer2 : m_stateBuffer1; }
    void runSingleQubitKernel(cl_kernel kernel, int qubit);
    void runSingleQubitKernelWithParam(cl_kernel kernel, int qubit, float param);
    void runTwoQubitKernel(cl_kernel kernel, int q1, int q2);
    void runTwoQubitKernelWithParam(cl_kernel kernel, int q1, int q2, float param);
};

// =============================================================================
// IMPLEMENTATION
// =============================================================================

OpenCLQuantumAccelerator::OpenCLQuantumAccelerator() {
    std::random_device rd;
    m_rng.seed(rd());
}

OpenCLQuantumAccelerator::~OpenCLQuantumAccelerator() {
    shutdown();
}

bool OpenCLQuantumAccelerator::initialize(int maxQubits) {
    m_maxQubits = maxQubits;

    if (!initializeOpenCL()) {
        std::cerr << "OpenCL initialization failed" << std::endl;
        return false;
    }

    if (!createKernels()) {
        std::cerr << "Kernel creation failed" << std::endl;
        return false;
    }

    m_initialized = true;
    m_available = true;
    return true;
}

bool OpenCLQuantumAccelerator::initializeOpenCL() {
    cl_int err;

    // Get platform
    cl_uint numPlatforms;
    err = clGetPlatformIDs(0, nullptr, &numPlatforms);
    if (err != CL_SUCCESS || numPlatforms == 0) {
        return false;
    }

    std::vector<cl_platform_id> platforms(numPlatforms);
    clGetPlatformIDs(numPlatforms, platforms.data(), nullptr);

    // Find GPU device (prefer discrete GPU)
    m_device = nullptr;
    for (auto platform : platforms) {
        cl_uint numDevices;
        err = clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, 0, nullptr, &numDevices);
        if (err == CL_SUCCESS && numDevices > 0) {
            std::vector<cl_device_id> devices(numDevices);
            clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, numDevices, devices.data(), nullptr);

            // Pick device with most memory
            size_t maxMem = 0;
            for (auto dev : devices) {
                cl_ulong memSize;
                clGetDeviceInfo(dev, CL_DEVICE_GLOBAL_MEM_SIZE, sizeof(memSize), &memSize, nullptr);
                if (memSize > maxMem) {
                    maxMem = memSize;
                    m_device = dev;
                    m_platform = platform;
                    m_deviceMemory = memSize;
                }
            }
        }
    }

    // Fallback to CPU if no GPU
    if (m_device == nullptr) {
        for (auto platform : platforms) {
            cl_uint numDevices;
            err = clGetDeviceIDs(platform, CL_DEVICE_TYPE_CPU, 0, nullptr, &numDevices);
            if (err == CL_SUCCESS && numDevices > 0) {
                clGetDeviceIDs(platform, CL_DEVICE_TYPE_CPU, 1, &m_device, nullptr);
                m_platform = platform;
                clGetDeviceInfo(m_device, CL_DEVICE_GLOBAL_MEM_SIZE, sizeof(m_deviceMemory), &m_deviceMemory, nullptr);
                break;
            }
        }
    }

    if (m_device == nullptr) {
        return false;
    }

    // Get device name
    char deviceName[256];
    clGetDeviceInfo(m_device, CL_DEVICE_NAME, sizeof(deviceName), deviceName, nullptr);
    m_deviceName = deviceName;

    // Create context
    m_context = clCreateContext(nullptr, 1, &m_device, nullptr, nullptr, &err);
    if (err != CL_SUCCESS) {
        return false;
    }

    // Create command queue (using deprecated function for broader compatibility)
    #pragma GCC diagnostic push
    #pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    m_queue = clCreateCommandQueue(m_context, m_device, 0, &err);
    #pragma GCC diagnostic pop
    if (err != CL_SUCCESS) {
        return false;
    }

    // Create and build program
    const char* sources[] = { QUANTUM_KERNELS };
    size_t lengths[] = { strlen(QUANTUM_KERNELS) };

    m_program = clCreateProgramWithSource(m_context, 1, sources, lengths, &err);
    if (err != CL_SUCCESS) {
        return false;
    }

    err = clBuildProgram(m_program, 1, &m_device, "-cl-fast-relaxed-math", nullptr, nullptr);
    if (err != CL_SUCCESS) {
        // Get build log
        size_t logSize;
        clGetProgramBuildInfo(m_program, m_device, CL_PROGRAM_BUILD_LOG, 0, nullptr, &logSize);
        std::vector<char> log(logSize);
        clGetProgramBuildInfo(m_program, m_device, CL_PROGRAM_BUILD_LOG, logSize, log.data(), nullptr);
        std::cerr << "OpenCL build error: " << log.data() << std::endl;
        return false;
    }

    return true;
}

bool OpenCLQuantumAccelerator::createKernels() {
    cl_int err;

    m_hadamardKernel = clCreateKernel(m_program, "hadamard", &err);
    if (err != CL_SUCCESS) return false;

    m_pauliXKernel = clCreateKernel(m_program, "pauliX", &err);
    if (err != CL_SUCCESS) return false;

    m_pauliYKernel = clCreateKernel(m_program, "pauliY", &err);
    if (err != CL_SUCCESS) return false;

    m_pauliZKernel = clCreateKernel(m_program, "pauliZ", &err);
    if (err != CL_SUCCESS) return false;

    m_phaseKernel = clCreateKernel(m_program, "phase", &err);
    if (err != CL_SUCCESS) return false;

    m_rxKernel = clCreateKernel(m_program, "rx", &err);
    if (err != CL_SUCCESS) return false;

    m_ryKernel = clCreateKernel(m_program, "ry", &err);
    if (err != CL_SUCCESS) return false;

    m_rzKernel = clCreateKernel(m_program, "rz", &err);
    if (err != CL_SUCCESS) return false;

    m_cnotKernel = clCreateKernel(m_program, "cnot", &err);
    if (err != CL_SUCCESS) return false;

    m_czKernel = clCreateKernel(m_program, "cz", &err);
    if (err != CL_SUCCESS) return false;

    m_swapKernel = clCreateKernel(m_program, "swap", &err);
    if (err != CL_SUCCESS) return false;

    m_controlledPhaseKernel = clCreateKernel(m_program, "controlledPhase", &err);
    if (err != CL_SUCCESS) return false;

    m_toffoliKernel = clCreateKernel(m_program, "toffoli", &err);
    if (err != CL_SUCCESS) return false;

    m_computeProbKernel = clCreateKernel(m_program, "computeProbabilities", &err);
    if (err != CL_SUCCESS) return false;

    m_normalizeKernel = clCreateKernel(m_program, "normalize", &err);
    if (err != CL_SUCCESS) return false;

    m_initZeroKernel = clCreateKernel(m_program, "initializeZero", &err);
    if (err != CL_SUCCESS) return false;

    m_initSuperKernel = clCreateKernel(m_program, "initializeSuperposition", &err);
    if (err != CL_SUCCESS) return false;

    return true;
}

void OpenCLQuantumAccelerator::shutdown() {
    // Release kernels
    if (m_hadamardKernel) clReleaseKernel(m_hadamardKernel);
    if (m_pauliXKernel) clReleaseKernel(m_pauliXKernel);
    if (m_pauliYKernel) clReleaseKernel(m_pauliYKernel);
    if (m_pauliZKernel) clReleaseKernel(m_pauliZKernel);
    if (m_phaseKernel) clReleaseKernel(m_phaseKernel);
    if (m_rxKernel) clReleaseKernel(m_rxKernel);
    if (m_ryKernel) clReleaseKernel(m_ryKernel);
    if (m_rzKernel) clReleaseKernel(m_rzKernel);
    if (m_cnotKernel) clReleaseKernel(m_cnotKernel);
    if (m_czKernel) clReleaseKernel(m_czKernel);
    if (m_swapKernel) clReleaseKernel(m_swapKernel);
    if (m_controlledPhaseKernel) clReleaseKernel(m_controlledPhaseKernel);
    if (m_toffoliKernel) clReleaseKernel(m_toffoliKernel);
    if (m_computeProbKernel) clReleaseKernel(m_computeProbKernel);
    if (m_normalizeKernel) clReleaseKernel(m_normalizeKernel);
    if (m_initZeroKernel) clReleaseKernel(m_initZeroKernel);
    if (m_initSuperKernel) clReleaseKernel(m_initSuperKernel);

    // Release buffers
    if (m_stateBuffer1) clReleaseMemObject(m_stateBuffer1);
    if (m_stateBuffer2) clReleaseMemObject(m_stateBuffer2);
    if (m_probBuffer) clReleaseMemObject(m_probBuffer);

    // Release OpenCL objects
    if (m_queue) clReleaseCommandQueue(m_queue);
    if (m_program) clReleaseProgram(m_program);
    if (m_context) clReleaseContext(m_context);

    m_initialized = false;
    m_available = false;
}

bool OpenCLQuantumAccelerator::isAvailable() const {
    return m_available;
}

bool OpenCLQuantumAccelerator::initializeState(int numQubits) {
    if (!m_initialized || numQubits <= 0 || numQubits > m_maxQubits) {
        return false;
    }

    // Check memory requirements
    m_stateSize = 1UL << numQubits;
    size_t bufferSize = m_stateSize * sizeof(Complex);

    if (bufferSize * 3 > m_deviceMemory) {  // Need 3 buffers
        std::cerr << "Insufficient GPU memory for " << numQubits << " qubits" << std::endl;
        return false;
    }

    m_numQubits = numQubits;

    // Release old buffers
    if (m_stateBuffer1) clReleaseMemObject(m_stateBuffer1);
    if (m_stateBuffer2) clReleaseMemObject(m_stateBuffer2);
    if (m_probBuffer) clReleaseMemObject(m_probBuffer);

    cl_int err;

    // Create buffers
    m_stateBuffer1 = clCreateBuffer(m_context, CL_MEM_READ_WRITE, bufferSize, nullptr, &err);
    if (err != CL_SUCCESS) return false;

    m_stateBuffer2 = clCreateBuffer(m_context, CL_MEM_READ_WRITE, bufferSize, nullptr, &err);
    if (err != CL_SUCCESS) return false;

    m_probBuffer = clCreateBuffer(m_context, CL_MEM_READ_WRITE, m_stateSize * sizeof(float), nullptr, &err);
    if (err != CL_SUCCESS) return false;

    // Initialize to |0...0>
    clSetKernelArg(m_initZeroKernel, 0, sizeof(cl_mem), &m_stateBuffer1);
    clSetKernelArg(m_initZeroKernel, 1, sizeof(int), &m_numQubits);

    size_t globalSize = m_stateSize;
    clEnqueueNDRangeKernel(m_queue, m_initZeroKernel, 1, nullptr, &globalSize, nullptr, 0, nullptr, nullptr);
    clFinish(m_queue);

    m_useBuffer1 = true;

    return true;
}

bool OpenCLQuantumAccelerator::initializeSuperposition() {
    if (m_numQubits == 0) return false;

    cl_mem buffer = getCurrentBuffer();
    clSetKernelArg(m_initSuperKernel, 0, sizeof(cl_mem), &buffer);
    clSetKernelArg(m_initSuperKernel, 1, sizeof(int), &m_numQubits);

    size_t globalSize = m_stateSize;
    clEnqueueNDRangeKernel(m_queue, m_initSuperKernel, 1, nullptr, &globalSize, nullptr, 0, nullptr, nullptr);
    clFinish(m_queue);

    return true;
}

void OpenCLQuantumAccelerator::swapBuffers() {
    m_useBuffer1 = !m_useBuffer1;
}

void OpenCLQuantumAccelerator::runSingleQubitKernel(cl_kernel kernel, int qubit) {
    cl_mem inBuffer = getCurrentBuffer();
    cl_mem outBuffer = getOtherBuffer();

    clSetKernelArg(kernel, 0, sizeof(cl_mem), &inBuffer);
    clSetKernelArg(kernel, 1, sizeof(cl_mem), &outBuffer);
    clSetKernelArg(kernel, 2, sizeof(int), &qubit);
    clSetKernelArg(kernel, 3, sizeof(int), &m_numQubits);

    size_t globalSize = m_stateSize;
    clEnqueueNDRangeKernel(m_queue, kernel, 1, nullptr, &globalSize, nullptr, 0, nullptr, nullptr);
    clFinish(m_queue);

    swapBuffers();
}

void OpenCLQuantumAccelerator::runSingleQubitKernelWithParam(cl_kernel kernel, int qubit, float param) {
    cl_mem inBuffer = getCurrentBuffer();
    cl_mem outBuffer = getOtherBuffer();

    clSetKernelArg(kernel, 0, sizeof(cl_mem), &inBuffer);
    clSetKernelArg(kernel, 1, sizeof(cl_mem), &outBuffer);
    clSetKernelArg(kernel, 2, sizeof(int), &qubit);
    clSetKernelArg(kernel, 3, sizeof(float), &param);
    clSetKernelArg(kernel, 4, sizeof(int), &m_numQubits);

    size_t globalSize = m_stateSize;
    clEnqueueNDRangeKernel(m_queue, kernel, 1, nullptr, &globalSize, nullptr, 0, nullptr, nullptr);
    clFinish(m_queue);

    swapBuffers();
}

void OpenCLQuantumAccelerator::runTwoQubitKernel(cl_kernel kernel, int q1, int q2) {
    cl_mem inBuffer = getCurrentBuffer();
    cl_mem outBuffer = getOtherBuffer();

    clSetKernelArg(kernel, 0, sizeof(cl_mem), &inBuffer);
    clSetKernelArg(kernel, 1, sizeof(cl_mem), &outBuffer);
    clSetKernelArg(kernel, 2, sizeof(int), &q1);
    clSetKernelArg(kernel, 3, sizeof(int), &q2);
    clSetKernelArg(kernel, 4, sizeof(int), &m_numQubits);

    size_t globalSize = m_stateSize;
    clEnqueueNDRangeKernel(m_queue, kernel, 1, nullptr, &globalSize, nullptr, 0, nullptr, nullptr);
    clFinish(m_queue);

    swapBuffers();
}

void OpenCLQuantumAccelerator::runTwoQubitKernelWithParam(cl_kernel kernel, int q1, int q2, float param) {
    cl_mem inBuffer = getCurrentBuffer();
    cl_mem outBuffer = getOtherBuffer();

    clSetKernelArg(kernel, 0, sizeof(cl_mem), &inBuffer);
    clSetKernelArg(kernel, 1, sizeof(cl_mem), &outBuffer);
    clSetKernelArg(kernel, 2, sizeof(int), &q1);
    clSetKernelArg(kernel, 3, sizeof(int), &q2);
    clSetKernelArg(kernel, 4, sizeof(float), &param);
    clSetKernelArg(kernel, 5, sizeof(int), &m_numQubits);

    size_t globalSize = m_stateSize;
    clEnqueueNDRangeKernel(m_queue, kernel, 1, nullptr, &globalSize, nullptr, 0, nullptr, nullptr);
    clFinish(m_queue);

    swapBuffers();
}

// Single-qubit gates
void OpenCLQuantumAccelerator::applyHadamard(int qubit) {
    runSingleQubitKernel(m_hadamardKernel, qubit);
}

void OpenCLQuantumAccelerator::applyPauliX(int qubit) {
    runSingleQubitKernel(m_pauliXKernel, qubit);
}

void OpenCLQuantumAccelerator::applyPauliY(int qubit) {
    runSingleQubitKernel(m_pauliYKernel, qubit);
}

void OpenCLQuantumAccelerator::applyPauliZ(int qubit) {
    runSingleQubitKernel(m_pauliZKernel, qubit);
}

void OpenCLQuantumAccelerator::applyRx(int qubit, float theta) {
    runSingleQubitKernelWithParam(m_rxKernel, qubit, theta);
}

void OpenCLQuantumAccelerator::applyRy(int qubit, float theta) {
    runSingleQubitKernelWithParam(m_ryKernel, qubit, theta);
}

void OpenCLQuantumAccelerator::applyRz(int qubit, float theta) {
    runSingleQubitKernelWithParam(m_rzKernel, qubit, theta);
}

void OpenCLQuantumAccelerator::applyPhase(int qubit, float theta) {
    runSingleQubitKernelWithParam(m_phaseKernel, qubit, theta);
}

void OpenCLQuantumAccelerator::applyT(int qubit) {
    applyPhase(qubit, M_PI / 4.0f);
}

void OpenCLQuantumAccelerator::applyS(int qubit) {
    applyPhase(qubit, M_PI / 2.0f);
}

// Two-qubit gates
void OpenCLQuantumAccelerator::applyCNOT(int control, int target) {
    runTwoQubitKernel(m_cnotKernel, control, target);
}

void OpenCLQuantumAccelerator::applyCZ(int control, int target) {
    runTwoQubitKernel(m_czKernel, control, target);
}

void OpenCLQuantumAccelerator::applySWAP(int qubit1, int qubit2) {
    runTwoQubitKernel(m_swapKernel, qubit1, qubit2);
}

void OpenCLQuantumAccelerator::applyControlledPhase(int control, int target, float theta) {
    runTwoQubitKernelWithParam(m_controlledPhaseKernel, control, target, theta);
}

// Three-qubit gates
void OpenCLQuantumAccelerator::applyToffoli(int control1, int control2, int target) {
    cl_mem inBuffer = getCurrentBuffer();
    cl_mem outBuffer = getOtherBuffer();

    clSetKernelArg(m_toffoliKernel, 0, sizeof(cl_mem), &inBuffer);
    clSetKernelArg(m_toffoliKernel, 1, sizeof(cl_mem), &outBuffer);
    clSetKernelArg(m_toffoliKernel, 2, sizeof(int), &control1);
    clSetKernelArg(m_toffoliKernel, 3, sizeof(int), &control2);
    clSetKernelArg(m_toffoliKernel, 4, sizeof(int), &target);
    clSetKernelArg(m_toffoliKernel, 5, sizeof(int), &m_numQubits);

    size_t globalSize = m_stateSize;
    clEnqueueNDRangeKernel(m_queue, m_toffoliKernel, 1, nullptr, &globalSize, nullptr, 0, nullptr, nullptr);
    clFinish(m_queue);

    swapBuffers();
}

void OpenCLQuantumAccelerator::applyFredkin(int control, int target1, int target2) {
    // Fredkin = controlled-SWAP = CNOT(t2,t1) * Toffoli(c,t1,t2) * CNOT(t2,t1)
    applyCNOT(target2, target1);
    applyToffoli(control, target1, target2);
    applyCNOT(target2, target1);
}

// Measurement
std::vector<float> OpenCLQuantumAccelerator::getProbabilities() {
    cl_mem buffer = getCurrentBuffer();

    clSetKernelArg(m_computeProbKernel, 0, sizeof(cl_mem), &buffer);
    clSetKernelArg(m_computeProbKernel, 1, sizeof(cl_mem), &m_probBuffer);
    clSetKernelArg(m_computeProbKernel, 2, sizeof(int), &m_numQubits);

    size_t globalSize = m_stateSize;
    clEnqueueNDRangeKernel(m_queue, m_computeProbKernel, 1, nullptr, &globalSize, nullptr, 0, nullptr, nullptr);

    std::vector<float> probabilities(m_stateSize);
    clEnqueueReadBuffer(m_queue, m_probBuffer, CL_TRUE, 0,
                        m_stateSize * sizeof(float), probabilities.data(), 0, nullptr, nullptr);

    return probabilities;
}

std::vector<int> OpenCLQuantumAccelerator::measureAll() {
    auto probabilities = getProbabilities();

    // Sample from distribution
    std::uniform_real_distribution<float> dist(0.0f, 1.0f);
    float r = dist(m_rng);

    float cumulative = 0.0f;
    size_t measuredState = 0;
    for (size_t i = 0; i < m_stateSize; ++i) {
        cumulative += probabilities[i];
        if (r <= cumulative) {
            measuredState = i;
            break;
        }
    }

    // Convert to bitstring
    std::vector<int> result(m_numQubits);
    for (int i = 0; i < m_numQubits; ++i) {
        result[i] = (measuredState >> i) & 1;
    }

    // Collapse state
    initializeState(m_numQubits);
    for (int i = 0; i < m_numQubits; ++i) {
        if (result[i]) {
            applyPauliX(i);
        }
    }

    return result;
}

int OpenCLQuantumAccelerator::measureQubit(int qubit) {
    auto probabilities = getProbabilities();

    // Calculate P(qubit=0) and P(qubit=1)
    float p0 = 0.0f, p1 = 0.0f;
    size_t mask = 1UL << qubit;

    for (size_t i = 0; i < m_stateSize; ++i) {
        if (i & mask) {
            p1 += probabilities[i];
        } else {
            p0 += probabilities[i];
        }
    }

    // Sample
    std::uniform_real_distribution<float> dist(0.0f, 1.0f);
    int result = (dist(m_rng) < p0) ? 0 : 1;

    // TODO: Collapse state (would require another kernel)

    return result;
}

void OpenCLQuantumAccelerator::normalize() {
    auto probabilities = getProbabilities();

    float norm = 0.0f;
    for (float p : probabilities) {
        norm += p;
    }

    if (norm > 0.0f) {
        float invNorm = 1.0f / std::sqrt(norm);

        cl_mem buffer = getCurrentBuffer();
        clSetKernelArg(m_normalizeKernel, 0, sizeof(cl_mem), &buffer);
        clSetKernelArg(m_normalizeKernel, 1, sizeof(float), &invNorm);
        clSetKernelArg(m_normalizeKernel, 2, sizeof(int), &m_numQubits);

        size_t globalSize = m_stateSize;
        clEnqueueNDRangeKernel(m_queue, m_normalizeKernel, 1, nullptr, &globalSize, nullptr, 0, nullptr, nullptr);
        clFinish(m_queue);
    }
}

std::vector<Complex> OpenCLQuantumAccelerator::getStateVector() {
    std::vector<Complex> state(m_stateSize);
    cl_mem buffer = getCurrentBuffer();
    clEnqueueReadBuffer(m_queue, buffer, CL_TRUE, 0,
                        m_stateSize * sizeof(Complex), state.data(), 0, nullptr, nullptr);
    return state;
}

void OpenCLQuantumAccelerator::setStateVector(const std::vector<Complex>& state) {
    if (state.size() != m_stateSize) return;

    cl_mem buffer = getCurrentBuffer();
    clEnqueueWriteBuffer(m_queue, buffer, CL_TRUE, 0,
                         m_stateSize * sizeof(Complex), state.data(), 0, nullptr, nullptr);
}

BenchmarkResult OpenCLQuantumAccelerator::benchmark(int qubits, int gates) {
    initializeState(qubits);
    initializeSuperposition();

    auto start = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < gates; ++i) {
        int q = i % qubits;
        switch (i % 6) {
            case 0: applyHadamard(q); break;
            case 1: applyPauliX(q); break;
            case 2: applyRy(q, 0.5f); break;
            case 3: if (qubits > 1) applyCNOT(q, (q + 1) % qubits); break;
            case 4: applyRz(q, 0.3f); break;
            case 5: if (qubits > 1) applyCZ(q, (q + 1) % qubits); break;
        }
    }

    clFinish(m_queue);

    auto end = std::chrono::high_resolution_clock::now();
    double elapsed = std::chrono::duration<double>(end - start).count();

    return BenchmarkResult{
        .gatesPerSecond = gates / elapsed,
        .totalTime = elapsed,
        .gates = gates,
        .qubits = qubits
    };
}

// =============================================================================
// FACTORY FUNCTION FOR LINUX
// =============================================================================

std::unique_ptr<IQuantumAccelerator> createOpenCLAccelerator() {
    auto accelerator = std::make_unique<OpenCLQuantumAccelerator>();
    if (accelerator->initialize()) {
        return accelerator;
    }
    return nullptr;
}

bool isOpenCLAvailable() {
    cl_uint numPlatforms;
    cl_int err = clGetPlatformIDs(0, nullptr, &numPlatforms);
    return (err == CL_SUCCESS && numPlatforms > 0);
}

}  // namespace Quantum
}  // namespace Echoelmusic

#endif  // __linux__
