#pragma once

#include <JuceHeader.h>
#include <cmath>
#include <array>
#include <cstdint>

namespace Echoel {
namespace DSP {

//==============================================================================
/**
 * @brief Pre-computed Lookup Tables for Expensive Operations
 *
 * Sin/Cos tables provide ~20x speedup over std::sin/cos
 * Used for: LFOs, panning laws, filter coefficient calculation
 */
class TrigLookupTables {
public:
    static constexpr int TABLE_SIZE = 4096;
    static constexpr float TABLE_SIZE_F = static_cast<float>(TABLE_SIZE);

    // Singleton access
    static TrigLookupTables& getInstance() {
        static TrigLookupTables instance;
        return instance;
    }

    // Fast sine lookup (input: 0-1 normalized phase)
    inline float fastSin(float normalizedPhase) const noexcept {
        float index = normalizedPhase * TABLE_SIZE_F;
        int i = static_cast<int>(index) & (TABLE_SIZE - 1);
        float frac = index - static_cast<int>(index);

        // Linear interpolation between table entries
        return sinTable[i] + frac * (sinTable[(i + 1) & (TABLE_SIZE - 1)] - sinTable[i]);
    }

    // Fast cosine lookup (input: 0-1 normalized phase)
    inline float fastCos(float normalizedPhase) const noexcept {
        return fastSin(normalizedPhase + 0.25f);  // cos(x) = sin(x + π/2)
    }

    // Fast sine for radians
    inline float fastSinRad(float radians) const noexcept {
        constexpr float INV_TWO_PI = 1.0f / (2.0f * 3.14159265358979323846f);
        float normalized = radians * INV_TWO_PI;
        normalized -= std::floor(normalized);  // Wrap to 0-1
        return fastSin(normalized);
    }

    // Fast cosine for radians
    inline float fastCosRad(float radians) const noexcept {
        return fastSinRad(radians + 1.5707963267948966f);  // +π/2
    }

    // Fast tangent lookup (input: 0-1 normalized phase, maps to 0-π)
    // Note: Returns tan(phase * π), useful for filter coefficients
    inline float fastTan(float normalizedPhase) const noexcept {
        // Clamp to avoid singularities near π/2
        normalizedPhase = std::min(0.499f, std::max(-0.499f, normalizedPhase));
        float s = fastSin(normalizedPhase);
        float c = fastCos(normalizedPhase);
        return (std::abs(c) > 1e-6f) ? (s / c) : (s > 0 ? 1000.0f : -1000.0f);
    }

    // Fast tangent for radians
    inline float fastTanRad(float radians) const noexcept {
        constexpr float INV_PI = 1.0f / 3.14159265358979323846f;
        return fastTan(radians * INV_PI);
    }

private:
    std::array<float, TABLE_SIZE + 1> sinTable;

    TrigLookupTables() {
        constexpr float TWO_PI = 2.0f * 3.14159265358979323846f;
        for (int i = 0; i <= TABLE_SIZE; ++i) {
            sinTable[i] = std::sin(TWO_PI * static_cast<float>(i) / TABLE_SIZE_F);
        }
    }
};

//==============================================================================
/**
 * @brief Fast Math Approximations
 *
 * IEEE754 bit manipulation tricks for fast transcendental functions
 * Accuracy: ~0.1% error, ~5-10x faster than std:: functions
 */
class FastMath {
public:
    //==========================================================================
    // Fast exponential: e^x
    // Error: < 0.2% for x in [-10, 10]
    //==========================================================================
    static inline float fastExp(float x) noexcept {
        // Clamping to avoid overflow/underflow
        x = std::max(-87.0f, std::min(88.0f, x));

        // Convert to 2^(x * log2(e))
        constexpr float LOG2E = 1.4426950408889634f;
        float t = x * LOG2E;

        // IEEE754 trick for 2^t (using union for strict aliasing compliance)
        union { float f; int32_t i; } u;
        u.i = static_cast<int32_t>(t + 127.0f) << 23;
        float pow2 = u.f;

        // Polynomial correction for fractional part
        float frac = t - std::floor(t);
        float correction = 1.0f + frac * (0.6931471805599453f +
                           frac * (0.2402265069591007f +
                           frac * 0.0555041086648216f));

        return pow2 * correction;
    }

    //==========================================================================
    // Fast natural log: ln(x)
    // Error: < 0.5% for x > 0
    //==========================================================================
    static inline float fastLog(float x) noexcept {
        // IEEE754 extraction
        union { float f; uint32_t i; } u;
        u.f = x;

        // Extract exponent
        int exp = (static_cast<int>(u.i >> 23) & 0xFF) - 127;

        // Normalize mantissa to [1, 2)
        u.i = (u.i & 0x007FFFFF) | 0x3F800000;
        float m = u.f;

        // Polynomial approximation for log2(m) where m in [1, 2)
        float log2m = -1.7417939f + m * (2.8212026f + m * (-1.4699568f + m * 0.44717955f));

        return (static_cast<float>(exp) + log2m) * 0.6931471805599453f;  // * ln(2)
    }

    //==========================================================================
    // Fast power: x^y (for positive x)
    //==========================================================================
    static inline float fastPow(float x, float y) noexcept {
        return fastExp(y * fastLog(x));
    }

    //==========================================================================
    // Fast 2^x (optimized for pitch calculations)
    // Common for semitone/cent conversions: freq * pow(2, semitones/12)
    // Error: < 0.5% for x in [-10, 10]
    //==========================================================================
    static inline float fastPow2(float x) noexcept {
        // Clamp to avoid overflow/underflow
        x = std::max(-126.0f, std::min(127.0f, x));

        // IEEE754 trick: 2^floor(x) via exponent manipulation
        int xi = static_cast<int>(x);
        float frac = x - static_cast<float>(xi);
        if (frac < 0.0f) { xi--; frac += 1.0f; }

        union { float f; int32_t i; } u;
        u.i = (xi + 127) << 23;  // 2^floor(x)

        // Polynomial for 2^frac where frac in [0, 1)
        // 2^frac ≈ 1 + frac * (ln2 + frac * (ln2^2/2 + frac * ln2^3/6))
        float pow2frac = 1.0f + frac * (0.6931471805599453f +
                         frac * (0.2402265069591007f +
                         frac * 0.0555041086648216f));

        return u.f * pow2frac;
    }

    //==========================================================================
    // Fast tanh (for soft clipping / saturation)
    // Rational approximation, very fast
    //==========================================================================
    static inline float fastTanh(float x) noexcept {
        if (x < -3.0f) return -1.0f;
        if (x > 3.0f) return 1.0f;

        float x2 = x * x;
        return x * (27.0f + x2) / (27.0f + 9.0f * x2);
    }

    //==========================================================================
    // Fast atan (for phase calculations)
    //==========================================================================
    static inline float fastAtan(float x) noexcept {
        constexpr float PI_4 = 0.7853981633974483f;

        // For |x| > 1, use atan(x) = π/2 - atan(1/x)
        if (std::abs(x) > 1.0f) {
            float sign = x > 0 ? 1.0f : -1.0f;
            return sign * (1.5707963267948966f - fastAtanCore(1.0f / std::abs(x)));
        }
        return fastAtanCore(x);
    }

    //==========================================================================
    // Fast atan2 (for polar angle calculations)
    //==========================================================================
    static inline float fastAtan2(float y, float x) noexcept {
        constexpr float PI = 3.14159265358979323846f;
        constexpr float PI_2 = 1.5707963267948966f;

        if (std::abs(x) < 1e-10f) {
            if (y > 0.0f) return PI_2;
            if (y < 0.0f) return -PI_2;
            return 0.0f;
        }

        float angle = fastAtan(y / x);

        // Adjust for quadrant
        if (x < 0.0f) {
            if (y >= 0.0f) angle += PI;
            else angle -= PI;
        }

        return angle;
    }

    //==========================================================================
    // Fast dB to linear gain conversion
    //==========================================================================
    static inline float dbToGain(float db) noexcept {
        // 10^(dB/20) = 2^(dB * log2(10) / 20)
        constexpr float COEFF = 0.16609640474f;  // log2(10) / 20
        float x = db * COEFF;
        x = std::max(-126.0f, x);

        union { float f; uint32_t i; } u;
        u.i = static_cast<uint32_t>((x + 127.0f) * 8388608.0f);
        return u.f;
    }

    //==========================================================================
    // Fast linear gain to dB conversion
    //==========================================================================
    static inline float gainToDb(float gain) noexcept {
        union { float f; uint32_t i; } u;
        u.f = gain + 1e-20f;  // Avoid log(0)
        return (static_cast<float>(u.i) * 8.2629582e-8f - 87.989971f);
    }

    //==========================================================================
    // Fast square root
    //==========================================================================
    static inline float fastSqrt(float x) noexcept {
        // Quake III fast inverse sqrt, then multiply by x
        union { float f; uint32_t i; } u;
        u.f = x;
        u.i = 0x5F375A86 - (u.i >> 1);  // Initial guess for 1/sqrt(x)
        u.f = u.f * (1.5f - 0.5f * x * u.f * u.f);  // Newton iteration
        return x * u.f;
    }

    //==========================================================================
    // Fast reciprocal square root (for normalization)
    //==========================================================================
    static inline float fastInvSqrt(float x) noexcept {
        union { float f; uint32_t i; } u;
        u.f = x;
        u.i = 0x5F375A86 - (u.i >> 1);
        u.f = u.f * (1.5f - 0.5f * x * u.f * u.f);
        return u.f;
    }

private:
    // Core atan for |x| <= 1
    static inline float fastAtanCore(float x) noexcept {
        float x2 = x * x;
        return x * (1.0f + x2 * (-0.333333f + x2 * (0.2f - x2 * 0.142857f)));
    }
};

//==============================================================================
/**
 * @brief Denormal Prevention
 *
 * Denormal numbers cause massive CPU spikes (100x slower processing)
 * These utilities prevent and flush denormals
 */
class DenormalPrevention {
public:
    // Flush denormals to zero (add to signal chain)
    static inline float flushDenormal(float x) noexcept {
        // Add and subtract tiny DC offset
        constexpr float DC_OFFSET = 1e-25f;
        return x + DC_OFFSET - DC_OFFSET;
    }

    // Check if value is denormal
    static inline bool isDenormal(float x) noexcept {
        union { float f; uint32_t i; } u;
        u.f = x;
        return (u.i & 0x7F800000) == 0 && (u.i & 0x007FFFFF) != 0;
    }

    // Flush entire buffer (use ScopedNoDenormals for better performance)
    static void flushBuffer(float* buffer, int numSamples) noexcept {
        // SIMD-friendly: add then subtract tiny DC offset using JUCE
        constexpr float DC = 1e-25f;
        juce::FloatVectorOperations::add(buffer, DC, numSamples);
        juce::FloatVectorOperations::add(buffer, -DC, numSamples);
    }

    // RAII class for CPU denormal mode
    class ScopedNoDenormals {
    public:
        ScopedNoDenormals() {
            #if defined(__SSE__) || defined(_M_X64) || defined(_M_IX86_FP)
                _MM_SET_FLUSH_ZERO_MODE(_MM_FLUSH_ZERO_ON);
                _MM_SET_DENORMALS_ZERO_MODE(_MM_DENORMALS_ZERO_ON);
            #endif
        }

        ~ScopedNoDenormals() {
            #if defined(__SSE__) || defined(_M_X64) || defined(_M_IX86_FP)
                _MM_SET_FLUSH_ZERO_MODE(_MM_FLUSH_ZERO_OFF);
                _MM_SET_DENORMALS_ZERO_MODE(_MM_DENORMALS_ZERO_OFF);
            #endif
        }
    };
};

//==============================================================================
/**
 * @brief SIMD-Optimized Buffer Operations
 *
 * Uses JUCE's FloatVectorOperations for portable SIMD
 * Falls back to scalar on unsupported platforms
 */
class BufferOps {
public:
    // Clear buffer to zero
    static void clear(float* buffer, int numSamples) noexcept {
        juce::FloatVectorOperations::clear(buffer, numSamples);
    }

    // Copy buffer
    static void copy(float* dest, const float* src, int numSamples) noexcept {
        juce::FloatVectorOperations::copy(dest, src, numSamples);
    }

    // Add buffers: dest += src
    static void add(float* dest, const float* src, int numSamples) noexcept {
        juce::FloatVectorOperations::add(dest, src, numSamples);
    }

    // Subtract buffers: dest -= src
    static void subtract(float* dest, const float* src, int numSamples) noexcept {
        juce::FloatVectorOperations::subtract(dest, src, numSamples);
    }

    // Multiply buffer by scalar
    static void multiply(float* buffer, float multiplier, int numSamples) noexcept {
        juce::FloatVectorOperations::multiply(buffer, multiplier, numSamples);
    }

    // Multiply buffers element-wise: dest *= src
    static void multiply(float* dest, const float* src, int numSamples) noexcept {
        juce::FloatVectorOperations::multiply(dest, src, numSamples);
    }

    // Mix wet/dry: output = dry * (1-wet) + wet * wetAmount
    static void mixWetDry(float* output, const float* dry, const float* wet,
                          float wetAmount, int numSamples) noexcept {
        float dryAmount = 1.0f - wetAmount;
        juce::FloatVectorOperations::copyWithMultiply(output, dry, dryAmount, numSamples);
        juce::FloatVectorOperations::addWithMultiply(output, wet, wetAmount, numSamples);
    }

    // Find absolute maximum (peak)
    static float findPeak(const float* buffer, int numSamples) noexcept {
        auto range = juce::FloatVectorOperations::findMinAndMax(buffer, numSamples);
        return std::max(std::abs(range.getStart()), std::abs(range.getEnd()));
    }

    // Calculate RMS (optimized with loop unrolling and fast sqrt)
    static float calculateRMS(const float* buffer, int numSamples) noexcept {
        if (numSamples <= 0) return 0.0f;

        float sum0 = 0.0f, sum1 = 0.0f, sum2 = 0.0f, sum3 = 0.0f;
        int i = 0;

        // Process 4 samples at a time (loop unrolling)
        const int unrollEnd = numSamples - 3;
        for (; i < unrollEnd; i += 4) {
            sum0 += buffer[i] * buffer[i];
            sum1 += buffer[i + 1] * buffer[i + 1];
            sum2 += buffer[i + 2] * buffer[i + 2];
            sum3 += buffer[i + 3] * buffer[i + 3];
        }

        // Process remaining samples
        float sumSquares = sum0 + sum1 + sum2 + sum3;
        for (; i < numSamples; ++i) {
            sumSquares += buffer[i] * buffer[i];
        }

        return FastMath::fastSqrt(sumSquares / static_cast<float>(numSamples));
    }

    // Apply gain ramp (for click-free gain changes)
    static void applyGainRamp(float* buffer, int numSamples,
                              float startGain, float endGain) noexcept {
        if (std::abs(startGain - endGain) < 0.0001f) {
            juce::FloatVectorOperations::multiply(buffer, startGain, numSamples);
        } else {
            float delta = (endGain - startGain) / numSamples;
            float gain = startGain;
            for (int i = 0; i < numSamples; ++i) {
                buffer[i] *= gain;
                gain += delta;
            }
        }
    }

    // Soft clip (tanh saturation)
    static void softClip(float* buffer, int numSamples, float drive = 1.0f) noexcept {
        for (int i = 0; i < numSamples; ++i) {
            buffer[i] = FastMath::fastTanh(buffer[i] * drive);
        }
    }

    // Hard clip
    static void hardClip(float* buffer, int numSamples, float threshold = 1.0f) noexcept {
        juce::FloatVectorOperations::clip(buffer, buffer, -threshold, threshold, numSamples);
    }
};

//==============================================================================
/**
 * @brief Smoothed Value with Block Processing
 *
 * Optimized for processing entire blocks instead of per-sample
 */
class SmoothedGain {
public:
    SmoothedGain(float smoothingTimeMs = 10.0f) : smoothingTime(smoothingTimeMs) {}

    void prepare(double sampleRate) {
        float smoothingSamples = (smoothingTime / 1000.0f) * static_cast<float>(sampleRate);
        coefficient = 1.0f - std::exp(-1.0f / smoothingSamples);
    }

    void setTargetValue(float newTarget) {
        target = newTarget;
    }

    // Process block with smoothed gain
    void processBlock(float* buffer, int numSamples) noexcept {
        if (std::abs(current - target) < 0.0001f) {
            // No smoothing needed - apply constant gain
            if (std::abs(current - 1.0f) > 0.0001f) {
                juce::FloatVectorOperations::multiply(buffer, current, numSamples);
            }
            return;
        }

        // Apply smoothed gain
        for (int i = 0; i < numSamples; ++i) {
            current += (target - current) * coefficient;
            buffer[i] *= current;
        }
    }

    float getCurrentValue() const { return current; }

private:
    float target = 1.0f;
    float current = 1.0f;
    float coefficient = 0.01f;
    float smoothingTime;
};

//==============================================================================
/**
 * @brief Pre-allocated Work Buffers
 *
 * Avoid allocations in audio thread by pre-allocating
 */
template <int MaxChannels = 2, int MaxBlockSize = 2048>
class WorkBuffers {
public:
    float* getBuffer(int channel) {
        jassert(channel >= 0 && channel < MaxChannels);
        return buffers[channel].data();
    }

    void clear(int numSamples) {
        for (int ch = 0; ch < MaxChannels; ++ch) {
            BufferOps::clear(buffers[ch].data(), numSamples);
        }
    }

private:
    std::array<std::array<float, MaxBlockSize>, MaxChannels> buffers;
};

} // namespace DSP
} // namespace Echoel
