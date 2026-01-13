/**
 * QuantumLightEmulator.hpp
 * Echoelmusic - Cross-Platform Quantum Light System
 *
 * C++17 implementation for Windows, Linux, and macOS desktop
 * 300% Power Mode - Tauchfliegen Edition
 *
 * Created: 2026-01-05
 */

#pragma once

#include <vector>
#include <complex>
#include <cmath>
#include <random>
#include <array>
#include <atomic>
#include <thread>
#include <mutex>
#include <functional>
#include <memory>
#include <chrono>

namespace Echoelmusic {
namespace Quantum {

// ============================================================================
// MARK: - Complex Number Type
// ============================================================================

using ComplexFloat = std::complex<float>;

// ============================================================================
// MARK: - Vector3
// ============================================================================

struct Vector3 {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;

    Vector3() = default;
    Vector3(float x, float y, float z) : x(x), y(y), z(z) {}

    Vector3 operator+(const Vector3& other) const {
        return {x + other.x, y + other.y, z + other.z};
    }

    Vector3 operator-(const Vector3& other) const {
        return {x - other.x, y - other.y, z - other.z};
    }

    Vector3 operator*(float scalar) const {
        return {x * scalar, y * scalar, z * scalar};
    }

    float length() const {
        return std::sqrt(x * x + y * y + z * z);
    }

    Vector3 normalized() const {
        float len = length();
        if (len > 0) return {x / len, y / len, z / len};
        return *this;
    }

    static Vector3 zero() { return {0, 0, 0}; }
    static Vector3 one() { return {1, 1, 1}; }
    static Vector3 up() { return {0, 1, 0}; }
    static Vector3 right() { return {1, 0, 0}; }
    static Vector3 forward() { return {0, 0, 1}; }
};

// ============================================================================
// MARK: - Quantum Audio State
// ============================================================================

class QuantumAudioState {
public:
    explicit QuantumAudioState(int numQubits = 4)
        : numQubits_(numQubits)
        , rng_(std::random_device{}())
    {
        int size = 1 << numQubits; // 2^numQubits
        amplitudes_.resize(size);

        // Initialize to equal superposition
        float amplitude = 1.0f / std::sqrt(static_cast<float>(size));
        for (auto& amp : amplitudes_) {
            amp = ComplexFloat(amplitude, 0.0f);
        }
    }

    // Get probability distribution
    std::vector<float> probabilities() const {
        std::vector<float> probs(amplitudes_.size());
        for (size_t i = 0; i < amplitudes_.size(); ++i) {
            probs[i] = std::norm(amplitudes_[i]); // |amplitude|^2
        }
        return probs;
    }

    // Normalize the state
    void normalize() {
        float total = 0.0f;
        for (const auto& amp : amplitudes_) {
            total += std::norm(amp);
        }
        if (total > 0) {
            float scale = 1.0f / std::sqrt(total);
            for (auto& amp : amplitudes_) {
                amp *= scale;
            }
        }
    }

    // Collapse to a single state
    int collapse() {
        auto probs = probabilities();
        std::uniform_real_distribution<float> dist(0.0f, 1.0f);
        float random = dist(rng_);
        float cumulative = 0.0f;

        for (size_t i = 0; i < probs.size(); ++i) {
            cumulative += probs[i];
            if (random < cumulative) {
                return static_cast<int>(i);
            }
        }
        return static_cast<int>(probs.size() - 1);
    }

    // Apply Hadamard gate to a qubit
    void applyHadamard(int qubit) {
        int size = static_cast<int>(amplitudes_.size());
        int mask = 1 << qubit;
        float sqrtHalf = 1.0f / std::sqrt(2.0f);

        for (int i = 0; i < size; i += mask * 2) {
            for (int j = i; j < i + mask; ++j) {
                auto a = amplitudes_[j];
                auto b = amplitudes_[j + mask];

                amplitudes_[j] = (a + b) * sqrtHalf;
                amplitudes_[j + mask] = (a - b) * sqrtHalf;
            }
        }
    }

    // Apply phase rotation
    void applyPhaseRotation(int qubit, float angle) {
        int mask = 1 << qubit;
        ComplexFloat phase(std::cos(angle), std::sin(angle));

        for (size_t i = 0; i < amplitudes_.size(); ++i) {
            if (i & mask) {
                amplitudes_[i] *= phase;
            }
        }
    }

    // Accessors
    int numQubits() const { return numQubits_; }
    const std::vector<ComplexFloat>& amplitudes() const { return amplitudes_; }
    std::vector<ComplexFloat>& amplitudes() { return amplitudes_; }

private:
    int numQubits_;
    std::vector<ComplexFloat> amplitudes_;
    mutable std::mt19937 rng_;
};

// ============================================================================
// MARK: - Photon
// ============================================================================

struct Photon {
    Vector3 position{0, 0, 0};
    Vector3 velocity{0, 0, 0};
    float wavelength = 550.0f; // nm (visible: 380-780)
    float phase = 0.0f;
    float amplitude = 1.0f;

    Photon() = default;
    Photon(Vector3 pos, Vector3 vel, float wl, float ph, float amp = 1.0f)
        : position(pos), velocity(vel), wavelength(wl), phase(ph), amplitude(amp) {}

    // Convert wavelength to RGB color
    Vector3 color() const {
        float w = std::clamp(wavelength, 380.0f, 780.0f);

        float r = 0, g = 0, b = 0;

        if (w < 440) {
            r = (440 - w) / (440 - 380);
            b = 1.0f;
        } else if (w < 490) {
            g = (w - 440) / (490 - 440);
            b = 1.0f;
        } else if (w < 510) {
            g = 1.0f;
            b = (510 - w) / (510 - 490);
        } else if (w < 580) {
            r = (w - 510) / (580 - 510);
            g = 1.0f;
        } else if (w < 645) {
            r = 1.0f;
            g = (645 - w) / (645 - 580);
        } else {
            r = 1.0f;
        }

        return {r, g, b};
    }

    float frequency() const {
        return 299792458.0f / (wavelength * 1e-9f);
    }

    float energy() const {
        return 6.626e-34f * frequency();
    }
};

// ============================================================================
// MARK: - Light Field Geometry
// ============================================================================

enum class LightFieldGeometry {
    Sphere,
    Grid,
    Fibonacci,
    Helix,
    Torus,
    FlowerOfLife,
    Vortex,
    Line,
    Plane,
    Random
};

// ============================================================================
// MARK: - Light Field
// ============================================================================

class LightField {
public:
    explicit LightField(int photonCount = 100, LightFieldGeometry geometry = LightFieldGeometry::Fibonacci)
        : geometry_(geometry)
        , rng_(std::random_device{}())
    {
        createPhotons(photonCount);
    }

    float fieldCoherence() const {
        if (photons_.size() < 2) return 1.0f;

        float meanPhase = 0.0f;
        for (const auto& p : photons_) {
            meanPhase += p.phase;
        }
        meanPhase /= photons_.size();

        float variance = 0.0f;
        for (const auto& p : photons_) {
            float diff = p.phase - meanPhase;
            variance += diff * diff;
        }

        return 1.0f - std::clamp(variance / photons_.size(), 0.0f, 1.0f);
    }

    float totalEnergy() const {
        float total = 0.0f;
        for (const auto& p : photons_) {
            total += p.energy();
        }
        return total;
    }

    float meanWavelength() const {
        if (photons_.empty()) return 550.0f;
        float total = 0.0f;
        for (const auto& p : photons_) {
            total += p.wavelength;
        }
        return total / photons_.size();
    }

    // Accessors
    std::vector<Photon>& photons() { return photons_; }
    const std::vector<Photon>& photons() const { return photons_; }
    LightFieldGeometry geometry() const { return geometry_; }

private:
    void createPhotons(int count) {
        photons_.clear();
        photons_.reserve(count);

        switch (geometry_) {
            case LightFieldGeometry::Sphere:
                createSpherePhotons(count);
                break;
            case LightFieldGeometry::Grid:
                createGridPhotons(count);
                break;
            case LightFieldGeometry::Fibonacci:
                createFibonacciPhotons(count);
                break;
            case LightFieldGeometry::Helix:
                createHelixPhotons(count);
                break;
            case LightFieldGeometry::Torus:
                createTorusPhotons(count);
                break;
            case LightFieldGeometry::FlowerOfLife:
                createFlowerOfLifePhotons(count);
                break;
            case LightFieldGeometry::Vortex:
                createVortexPhotons(count);
                break;
            case LightFieldGeometry::Line:
                createLinePhotons(count);
                break;
            case LightFieldGeometry::Plane:
                createPlanePhotons(count);
                break;
            case LightFieldGeometry::Random:
                createRandomPhotons(count);
                break;
        }
    }

    void createSpherePhotons(int count) {
        for (int i = 0; i < count; ++i) {
            float phi = std::acos(1.0f - 2.0f * (i + 0.5f) / count);
            float theta = M_PI * (1.0f + std::sqrt(5.0f)) * i;

            photons_.emplace_back(
                Vector3(std::sin(phi) * std::cos(theta),
                       std::sin(phi) * std::sin(theta),
                       std::cos(phi)),
                Vector3::zero(),
                380.0f + 400.0f * i / count,
                std::fmod(theta, 2.0f * M_PI)
            );
        }
    }

    void createGridPhotons(int count) {
        int side = static_cast<int>(std::ceil(std::sqrt(count)));
        for (int i = 0; i < count; ++i) {
            float x = static_cast<float>(i % side) / side - 0.5f;
            float y = static_cast<float>(i / side) / side - 0.5f;

            std::uniform_real_distribution<float> dist(480.0f, 680.0f);
            photons_.emplace_back(
                Vector3(x, y, 0),
                Vector3::zero(),
                dist(rng_),
                (x + y) * M_PI
            );
        }
    }

    void createFibonacciPhotons(int count) {
        float goldenRatio = (1.0f + std::sqrt(5.0f)) / 2.0f;
        for (int i = 0; i < count; ++i) {
            float theta = 2.0f * M_PI * i / goldenRatio;
            float r = std::sqrt(static_cast<float>(i)) * 0.1f;

            photons_.emplace_back(
                Vector3(r * std::cos(theta), r * std::sin(theta), 0),
                Vector3::zero(),
                520.0f + 60.0f * std::sin(theta),
                theta
            );
        }
    }

    void createHelixPhotons(int count) {
        for (int i = 0; i < count; ++i) {
            float t = static_cast<float>(i) / count;
            float theta = t * 4 * M_PI;

            photons_.emplace_back(
                Vector3(std::cos(theta) * 0.5f, t - 0.5f, std::sin(theta) * 0.5f),
                Vector3::up() * 0.01f,
                400.0f + 300.0f * t,
                theta
            );
        }
    }

    void createTorusPhotons(int count) {
        float majorRadius = 0.5f;
        float minorRadius = 0.2f;

        for (int i = 0; i < count; ++i) {
            float u = (i % 20) * 2.0f * M_PI / 20.0f;
            float v = (i / 20) * 2.0f * M_PI / (count / 20);

            photons_.emplace_back(
                Vector3(
                    (majorRadius + minorRadius * std::cos(v)) * std::cos(u),
                    minorRadius * std::sin(v),
                    (majorRadius + minorRadius * std::cos(v)) * std::sin(u)
                ),
                Vector3::zero(),
                450.0f + 250.0f * (std::cos(u) + 1.0f) / 2.0f,
                u + v
            );
        }
    }

    void createFlowerOfLifePhotons(int count) {
        int rings = 3;
        int perRing = count / (rings + 1);

        // Center
        for (int i = 0; i < perRing; ++i) {
            float angle = i * 2.0f * M_PI / perRing;
            photons_.emplace_back(
                Vector3(std::cos(angle) * 0.1f, std::sin(angle) * 0.1f, 0),
                Vector3::zero(),
                550.0f,
                angle
            );
        }

        // Outer rings
        for (int ring = 0; ring < rings; ++ring) {
            float ringRadius = (ring + 1) * 0.2f;
            for (int petal = 0; petal < 6; ++petal) {
                float petalAngle = petal * M_PI / 3.0f;
                float cx = std::cos(petalAngle) * ringRadius;
                float cy = std::sin(petalAngle) * ringRadius;

                for (int i = 0; i < perRing / 6; ++i) {
                    float angle = i * 2.0f * M_PI / (perRing / 6);
                    photons_.emplace_back(
                        Vector3(cx + std::cos(angle) * 0.15f, cy + std::sin(angle) * 0.15f, 0),
                        Vector3::zero(),
                        400.0f + 50.0f * ring + 30.0f * petal,
                        angle + petalAngle
                    );
                }
            }
        }
    }

    void createVortexPhotons(int count) {
        for (int i = 0; i < count; ++i) {
            float t = static_cast<float>(i) / count;
            float r = t * 0.8f;
            float theta = t * 6.0f * M_PI;

            photons_.emplace_back(
                Vector3(r * std::cos(theta), r * std::sin(theta), t - 0.5f),
                Vector3(std::sin(theta), -std::cos(theta), 0.1f) * 0.01f,
                380.0f + 400.0f * t,
                theta
            );
        }
    }

    void createLinePhotons(int count) {
        for (int i = 0; i < count; ++i) {
            float t = static_cast<float>(i) / count - 0.5f;
            photons_.emplace_back(
                Vector3(t, 0, 0),
                Vector3::right() * 0.01f,
                550.0f,
                t * 2.0f * M_PI
            );
        }
    }

    void createPlanePhotons(int count) {
        int side = static_cast<int>(std::ceil(std::sqrt(count)));
        for (int i = 0; i < count; ++i) {
            float x = static_cast<float>(i % side) / side - 0.5f;
            float y = static_cast<float>(i / side) / side - 0.5f;
            photons_.emplace_back(
                Vector3(x, y, 0),
                Vector3::forward() * 0.01f,
                500.0f + std::sin(x * 10.0f) * 100.0f,
                (x * x + y * y) * M_PI
            );
        }
    }

    void createRandomPhotons(int count) {
        std::uniform_real_distribution<float> posDist(-0.5f, 0.5f);
        std::uniform_real_distribution<float> wlDist(380.0f, 780.0f);
        std::uniform_real_distribution<float> phaseDist(0.0f, 2.0f * M_PI);

        for (int i = 0; i < count; ++i) {
            photons_.emplace_back(
                Vector3(posDist(rng_), posDist(rng_), posDist(rng_)),
                Vector3(posDist(rng_), posDist(rng_), posDist(rng_)).normalized() * 0.01f,
                wlDist(rng_),
                phaseDist(rng_)
            );
        }
    }

    std::vector<Photon> photons_;
    LightFieldGeometry geometry_;
    mutable std::mt19937 rng_;
};

// ============================================================================
// MARK: - Emulation Mode
// ============================================================================

enum class EmulationMode {
    Classical,
    QuantumInspired,
    FullQuantum,
    HybridPhotonic,
    BioCoherent
};

// ============================================================================
// MARK: - Quantum Light Emulator
// ============================================================================

class QuantumLightEmulator {
public:
    QuantumLightEmulator()
        : rng_(std::random_device{}())
    {
        quantumState_ = std::make_unique<QuantumAudioState>(numQubits_);
        lightField_ = std::make_unique<LightField>(photonCount_, LightFieldGeometry::Fibonacci);

        // ✅ Initialize cached probabilities for lock-free audio thread access
        cachedProbabilities_ = quantumState_->probabilities();
        cachedFieldCoherence_.store(lightField_->fieldCoherence(), std::memory_order_relaxed);
    }

    ~QuantumLightEmulator() {
        stop();
    }

    // MARK: - Lifecycle

    void start() {
        if (running_.load()) return;
        running_.store(true);

        processingThread_ = std::thread([this]() {
            while (running_.load()) {
                processFrame();
                std::this_thread::sleep_for(std::chrono::milliseconds(16)); // ~60 FPS
            }
        });
    }

    void stop() {
        running_.store(false);
        if (processingThread_.joinable()) {
            processingThread_.join();
        }
    }

    bool isRunning() const { return running_.load(); }

    // MARK: - Mode Control

    void setMode(EmulationMode mode) {
        std::lock_guard<std::mutex> lock(mutex_);
        emulationMode_.store(mode, std::memory_order_relaxed);

        switch (mode) {
            case EmulationMode::Classical:
                numQubits_ = 2;
                photonCount_ = 50;
                break;
            case EmulationMode::QuantumInspired:
                numQubits_ = 4;
                photonCount_ = 100;
                break;
            case EmulationMode::FullQuantum:
                numQubits_ = 8;
                photonCount_ = 200;
                break;
            case EmulationMode::HybridPhotonic:
                numQubits_ = 6;
                photonCount_ = 150;
                break;
            case EmulationMode::BioCoherent:
                numQubits_ = 4;
                photonCount_ = 100;
                break;
        }

        quantumState_ = std::make_unique<QuantumAudioState>(numQubits_);
        lightField_ = std::make_unique<LightField>(photonCount_, geometryForMode(mode));

        // ✅ Update cached probabilities for lock-free audio thread access
        cachedProbabilities_ = quantumState_->probabilities();
        cachedFieldCoherence_.store(lightField_->fieldCoherence(), std::memory_order_relaxed);
    }

    EmulationMode mode() const { return emulationMode_.load(std::memory_order_relaxed); }

    // MARK: - Bio Feedback

    // ✅ LOCK-FREE for parameter updates, uses mutex only for photon modification
    void updateBioFeedback(float coherence, double hrv, double heartRate) {
        // Atomic stores for audio thread access (lock-free)
        hrvCoherence_.store(hrv, std::memory_order_relaxed);
        heartRate_.store(heartRate, std::memory_order_relaxed);

        if (emulationMode_.load(std::memory_order_relaxed) == EmulationMode::BioCoherent) {
            float bioCoherence = std::clamp(coherence * 0.6f + static_cast<float>(hrv) / 100.0f * 0.4f, 0.0f, 1.0f);
            coherenceLevel_.store(bioCoherence, std::memory_order_relaxed);

            // Modulate photon phases based on heart rate (requires mutex for light field access)
            std::lock_guard<std::mutex> lock(mutex_);
            if (lightField_) {
                float heartPhase = static_cast<float>(heartRate / 60.0) * 2.0f * M_PI;
                for (auto& photon : lightField_->photons()) {
                    photon.phase = std::fmod(photon.phase + heartPhase * 0.01f, 2.0f * M_PI);
                }
            }
        }
    }

    // MARK: - Audio Processing

    // ✅ LOCK-FREE: Audio thread safe - uses atomics and cached probabilities
    void processAudio(float* samples, int numSamples) {
        // Read atomic values (relaxed ordering is fine for audio)
        float coherence = coherenceLevel_.load(std::memory_order_relaxed);
        float cachedFieldCoherence = cachedFieldCoherence_.load(std::memory_order_relaxed);
        float hrvCoh = static_cast<float>(hrvCoherence_.load(std::memory_order_relaxed));
        EmulationMode mode = emulationMode_.load(std::memory_order_relaxed);

        // Use cached probabilities (updated by processing thread)
        auto& probs = cachedProbabilities_;
        if (probs.empty()) return;

        for (int i = 0; i < numSamples; ++i) {
            int probIndex = i % probs.size();
            float modulation = probs[probIndex] * coherence;

            switch (mode) {
                case EmulationMode::Classical:
                    // No modification
                    break;
                case EmulationMode::QuantumInspired:
                    samples[i] *= (0.8f + modulation * 0.4f);
                    break;
                case EmulationMode::FullQuantum: {
                    float phaseShift = probs[probIndex] * M_PI * 0.5f;
                    samples[i] *= std::cos(phaseShift);
                    break;
                }
                case EmulationMode::HybridPhotonic: {
                    samples[i] *= cachedFieldCoherence;
                    break;
                }
                case EmulationMode::BioCoherent: {
                    float bioMod = hrvCoh / 100.0f;
                    samples[i] *= (0.7f + bioMod * 0.6f);
                    break;
                }
            }
        }
    }

    // MARK: - Accessors (thread-safe atomic reads)

    float coherenceLevel() const { return coherenceLevel_.load(std::memory_order_relaxed); }
    QuantumAudioState* quantumState() const { return quantumState_.get(); }
    LightField* lightField() const { return lightField_.get(); }
    double hrvCoherence() const { return hrvCoherence_.load(std::memory_order_relaxed); }
    double heartRate() const { return heartRate_.load(std::memory_order_relaxed); }

private:
    void processFrame() {
        std::lock_guard<std::mutex> lock(mutex_);

        if (!quantumState_ || !lightField_) return;

        EmulationMode mode = emulationMode_.load(std::memory_order_relaxed);

        switch (mode) {
            case EmulationMode::Classical:
                processClassical();
                break;
            case EmulationMode::QuantumInspired:
                processQuantumInspired();
                break;
            case EmulationMode::FullQuantum:
                processFullQuantum();
                break;
            case EmulationMode::HybridPhotonic:
                processHybridPhotonic();
                break;
            case EmulationMode::BioCoherent:
                processBioCoherent();
                break;
        }

        // ✅ Update cached values for lock-free audio thread access
        float fieldCoh = lightField_->fieldCoherence();
        coherenceLevel_.store(fieldCoh, std::memory_order_relaxed);
        cachedFieldCoherence_.store(fieldCoh, std::memory_order_relaxed);

        // Update cached probabilities (audio thread reads this)
        cachedProbabilities_ = quantumState_->probabilities();
    }

    void processClassical() {
        for (auto& photon : lightField_->photons()) {
            photon.position = photon.position + photon.velocity;
            photon.phase = std::fmod(photon.phase + 0.1f, 2.0f * M_PI);
        }
    }

    void processQuantumInspired() {
        std::uniform_real_distribution<float> dist(0.0f, 1.0f);
        for (int q = 0; q < quantumState_->numQubits(); ++q) {
            if (dist(rng_) < 0.1f) {
                quantumState_->applyHadamard(q);
            }
        }

        auto probs = quantumState_->probabilities();
        auto& photons = lightField_->photons();
        for (size_t i = 0; i < photons.size(); ++i) {
            int probIndex = i % probs.size();
            photons[i].amplitude = probs[probIndex];
            photons[i].phase = std::fmod(photons[i].phase + probs[probIndex] * 0.5f, 2.0f * M_PI);
        }
    }

    void processFullQuantum() {
        for (int q = 0; q < quantumState_->numQubits(); ++q) {
            quantumState_->applyHadamard(q);
        }

        std::uniform_real_distribution<float> dist(0.0f, 1.0f);
        if (dist(rng_) < 0.05f) {
            int collapsed = quantumState_->collapse();
            auto& amps = quantumState_->amplitudes();
            for (size_t i = 0; i < amps.size(); ++i) {
                amps[i] = (i == static_cast<size_t>(collapsed)) ? ComplexFloat(1.0f, 0.0f) : ComplexFloat(0.0f, 0.0f);
            }
        }

        for (auto& photon : lightField_->photons()) {
            photon.position = photon.position + photon.velocity;
        }
    }

    void processHybridPhotonic() {
        float totalIntensity = 0.0f;
        for (const auto& p : lightField_->photons()) {
            totalIntensity += p.amplitude;
        }

        auto& amps = quantumState_->amplitudes();
        for (size_t i = 0; i < amps.size(); ++i) {
            float modulation = std::sin(totalIntensity * i * 0.1f);
            amps[i] = ComplexFloat(amps[i].real() * (1.0f + modulation * 0.1f), amps[i].imag());
        }
        quantumState_->normalize();

        auto probs = quantumState_->probabilities();
        for (auto& photon : lightField_->photons()) {
            photon.phase = std::fmod(photon.phase + probs[0] * 0.2f, 2.0f * M_PI);
        }
    }

    void processBioCoherent() {
        float hrv = static_cast<float>(hrvCoherence_) / 100.0f;

        auto& amps = quantumState_->amplitudes();
        for (size_t i = 0; i < amps.size(); ++i) {
            float hrvModulation = hrv * std::sin(i * 0.5f);
            amps[i] = ComplexFloat(amps[i].real() + hrvModulation * 0.1f, amps[i].imag());
        }
        quantumState_->normalize();

        for (auto& photon : lightField_->photons()) {
            photon.phase = std::fmod(photon.phase + coherenceLevel_ * 0.1f, 2.0f * M_PI);
        }
    }

    LightFieldGeometry geometryForMode(EmulationMode mode) const {
        switch (mode) {
            case EmulationMode::Classical: return LightFieldGeometry::Grid;
            case EmulationMode::QuantumInspired: return LightFieldGeometry::Sphere;
            case EmulationMode::FullQuantum: return LightFieldGeometry::Fibonacci;
            case EmulationMode::HybridPhotonic: return LightFieldGeometry::Helix;
            case EmulationMode::BioCoherent: return LightFieldGeometry::FlowerOfLife;
        }
        return LightFieldGeometry::Fibonacci;
    }

    // State (protected by mutex_ for complex operations)
    std::unique_ptr<QuantumAudioState> quantumState_;
    std::unique_ptr<LightField> lightField_;

    // Parameters (mutable from different threads)
    int numQubits_ = 4;
    int photonCount_ = 100;

    // ✅ ATOMIC: Thread-safe audio parameters (lock-free read from audio thread)
    std::atomic<float> coherenceLevel_{0.5f};
    std::atomic<double> hrvCoherence_{50.0};
    std::atomic<double> heartRate_{70.0};
    std::atomic<EmulationMode> emulationMode_{EmulationMode::BioCoherent};
    std::atomic<float> cachedFieldCoherence_{1.0f};

    // ✅ CACHED: Pre-computed probabilities for lock-free audio read
    // Updated by processing thread, read by audio thread
    // Using vector is safe here because audio thread only reads, never resizes
    std::vector<float> cachedProbabilities_{16, 0.0625f}; // 1/16 = 0.0625 (equal superposition)

    // Threading
    std::atomic<bool> running_{false};
    std::thread processingThread_;
    mutable std::mutex mutex_;  // Only for setMode() and complex state changes
    std::mt19937 rng_;
};

// ============================================================================
// MARK: - Visualization Types
// ============================================================================

enum class VisualizationType {
    InterferencePattern,
    WaveFunction,
    CoherenceField,
    PhotonFlow,
    SacredGeometry,
    QuantumTunnel,
    BiophotonAura,
    LightMandala,
    HolographicDisplay,
    CosmicWeb
};

} // namespace Quantum
} // namespace Echoelmusic
