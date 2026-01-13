#pragma once
/**
 * EchoelCore - BioState
 *
 * Lock-free biometric state container for real-time audio modulation.
 * Uses atomic operations for safe cross-thread access.
 *
 * MIT License - Echoelmusic 2026
 */

#include <atomic>
#include <cmath>
#include <algorithm>

namespace EchoelCore {

/**
 * BioState - Atomic biometric state container
 *
 * Thread Safety:
 * - Sensor thread writes via update()
 * - Audio thread reads via get*() methods
 * - All operations are lock-free
 *
 * Usage:
 *   BioState bio;
 *
 *   // Sensor thread
 *   bio.update(hrv, coherence, heartRate, breathPhase);
 *
 *   // Audio thread
 *   float filterMod = bio.getHRV() * 0.3f;
 *   float reverbMix = bio.getCoherence() * 0.5f;
 */
class BioState {
public:
    //==========================================================================
    // Constants
    //==========================================================================

    // HRV normalization (typical range 20-100ms SDNN)
    static constexpr float kHRVMin = 20.0f;
    static constexpr float kHRVMax = 100.0f;

    // Heart rate range (typical human)
    static constexpr float kHRMin = 40.0f;
    static constexpr float kHRMax = 200.0f;

    // Breathing rate range (breaths per minute)
    static constexpr float kBreathRateMin = 4.0f;
    static constexpr float kBreathRateMax = 30.0f;

    // Optimal coherence breathing rate (resonance frequency)
    static constexpr float kOptimalBreathRate = 6.0f; // 0.1 Hz

    //==========================================================================
    // Constructor
    //==========================================================================

    BioState() noexcept
        : mHRV(0.5f)
        , mCoherence(0.5f)
        , mHeartRate(70.0f)
        , mBreathPhase(0.0f)
        , mBreathRate(kOptimalBreathRate)
        , mGSR(0.5f)
        , mTemperature(36.5f)
        , mTimestamp(0)
    {}

    //==========================================================================
    // Sensor Thread Methods (Writers)
    //==========================================================================

    /**
     * Update all bio values at once.
     * Call from sensor/HealthKit thread.
     */
    void update(float hrv, float coherence, float heartRate, float breathPhase) noexcept {
        mHRV.store(std::clamp(hrv, 0.0f, 1.0f), std::memory_order_relaxed);
        mCoherence.store(std::clamp(coherence, 0.0f, 1.0f), std::memory_order_relaxed);
        mHeartRate.store(std::clamp(heartRate, kHRMin, kHRMax), std::memory_order_relaxed);
        mBreathPhase.store(std::fmod(breathPhase, 1.0f), std::memory_order_relaxed);
        mTimestamp.fetch_add(1, std::memory_order_release);
    }

    /**
     * Update HRV (0-1 normalized)
     */
    void setHRV(float hrv) noexcept {
        mHRV.store(std::clamp(hrv, 0.0f, 1.0f), std::memory_order_relaxed);
    }

    /**
     * Update HRV from raw SDNN value in milliseconds
     */
    void setHRVFromSDNN(float sdnnMs) noexcept {
        float normalized = (sdnnMs - kHRVMin) / (kHRVMax - kHRVMin);
        mHRV.store(std::clamp(normalized, 0.0f, 1.0f), std::memory_order_relaxed);
    }

    /**
     * Update coherence (0-1, HeartMath style)
     */
    void setCoherence(float coherence) noexcept {
        mCoherence.store(std::clamp(coherence, 0.0f, 1.0f), std::memory_order_relaxed);
    }

    /**
     * Update heart rate in BPM
     */
    void setHeartRate(float bpm) noexcept {
        mHeartRate.store(std::clamp(bpm, kHRMin, kHRMax), std::memory_order_relaxed);
    }

    /**
     * Update breath phase (0-1 cycle)
     */
    void setBreathPhase(float phase) noexcept {
        mBreathPhase.store(std::fmod(phase, 1.0f), std::memory_order_relaxed);
    }

    /**
     * Update breath rate in breaths per minute
     */
    void setBreathRate(float rate) noexcept {
        mBreathRate.store(std::clamp(rate, kBreathRateMin, kBreathRateMax),
                         std::memory_order_relaxed);
    }

    /**
     * Update GSR (galvanic skin response, 0-1 normalized)
     */
    void setGSR(float gsr) noexcept {
        mGSR.store(std::clamp(gsr, 0.0f, 1.0f), std::memory_order_relaxed);
    }

    /**
     * Update skin temperature in Celsius
     */
    void setTemperature(float tempC) noexcept {
        mTemperature.store(std::clamp(tempC, 30.0f, 42.0f), std::memory_order_relaxed);
    }

    //==========================================================================
    // Audio Thread Methods (Readers) - All lock-free
    //==========================================================================

    /** Get HRV (0-1 normalized) */
    float getHRV() const noexcept {
        return mHRV.load(std::memory_order_relaxed);
    }

    /** Get coherence (0-1) */
    float getCoherence() const noexcept {
        return mCoherence.load(std::memory_order_relaxed);
    }

    /** Get heart rate in BPM */
    float getHeartRate() const noexcept {
        return mHeartRate.load(std::memory_order_relaxed);
    }

    /** Get breath phase (0-1) */
    float getBreathPhase() const noexcept {
        return mBreathPhase.load(std::memory_order_relaxed);
    }

    /** Get breath rate in breaths per minute */
    float getBreathRate() const noexcept {
        return mBreathRate.load(std::memory_order_relaxed);
    }

    /** Get GSR (0-1 normalized) */
    float getGSR() const noexcept {
        return mGSR.load(std::memory_order_relaxed);
    }

    /** Get skin temperature in Celsius */
    float getTemperature() const noexcept {
        return mTemperature.load(std::memory_order_relaxed);
    }

    /** Get update timestamp (monotonic counter) */
    uint64_t getTimestamp() const noexcept {
        return mTimestamp.load(std::memory_order_acquire);
    }

    //==========================================================================
    // Derived Values (Computed on Audio Thread)
    //==========================================================================

    /**
     * Get breathing LFO value (sine wave based on breath phase)
     * Returns -1 to +1
     */
    float getBreathLFO() const noexcept {
        float phase = mBreathPhase.load(std::memory_order_relaxed);
        return std::sin(phase * 2.0f * 3.14159265358979f);
    }

    /**
     * Get heart rate as tempo (BPM)
     * Useful for syncing audio effects to heartbeat
     */
    float getHeartTempo() const noexcept {
        return mHeartRate.load(std::memory_order_relaxed);
    }

    /**
     * Get normalized heart rate (0-1 range)
     */
    float getHeartRateNormalized() const noexcept {
        float hr = mHeartRate.load(std::memory_order_relaxed);
        return (hr - kHRMin) / (kHRMax - kHRMin);
    }

    /**
     * Get combined arousal score (0-1)
     * Higher = more aroused/stressed
     * Based on HR, GSR, and inverse HRV
     */
    float getArousal() const noexcept {
        float hr = getHeartRateNormalized();
        float gsr = mGSR.load(std::memory_order_relaxed);
        float hrvInverse = 1.0f - mHRV.load(std::memory_order_relaxed);
        return (hr * 0.4f + gsr * 0.3f + hrvInverse * 0.3f);
    }

    /**
     * Get combined relaxation score (0-1)
     * Higher = more relaxed/coherent
     */
    float getRelaxation() const noexcept {
        float coh = mCoherence.load(std::memory_order_relaxed);
        float hrv = mHRV.load(std::memory_order_relaxed);
        float hrLow = 1.0f - getHeartRateNormalized();
        return (coh * 0.5f + hrv * 0.3f + hrLow * 0.2f);
    }

    /**
     * Check if bio data is recent (updated within threshold)
     */
    bool isRecent(uint64_t currentTimestamp, uint64_t threshold = 100) const noexcept {
        uint64_t lastUpdate = mTimestamp.load(std::memory_order_acquire);
        return (currentTimestamp - lastUpdate) < threshold;
    }

private:
    // All atomics use relaxed ordering for performance
    // The timestamp uses acquire/release to ensure visibility
    std::atomic<float> mHRV;
    std::atomic<float> mCoherence;
    std::atomic<float> mHeartRate;
    std::atomic<float> mBreathPhase;
    std::atomic<float> mBreathRate;
    std::atomic<float> mGSR;
    std::atomic<float> mTemperature;
    std::atomic<uint64_t> mTimestamp;
};

} // namespace EchoelCore
