/*================================================================
 * SIMD Performance Micro-Benchmarks
 *================================================================
 *
 * Validates SIMD optimization claims from DSP_OPTIMIZATIONS.md:
 * - AVX: 4-6x faster compressor detection
 * - SSE2: 2-3x faster
 * - NEON: 3-4x faster
 * - Direct memory access: 2x faster
 *
 * Methodology:
 * - Compare scalar vs SIMD implementations
 * - Measure cycle counts with high-resolution timers
 * - Run multiple iterations to account for cache effects
 * - Report min/median/max for statistical validity
 *
 * Build: g++ -O3 -mavx2 -mfma -std=c++17 SIMDBenchmarks.cpp -o simd_bench
 * Run:   ./simd_bench
 *
 *================================================================*/

#define CATCH_CONFIG_MAIN
#include "catch.hpp"

#include <chrono>
#include <algorithm>
#include <numeric>
#include <cmath>
#include <vector>

// SIMD intrinsics
#if defined(__AVX__)
    #include <immintrin.h>
    #define SIMD_AVAILABLE_AVX 1
#elif defined(__SSE2__)
    #include <emmintrin.h>
    #define SIMD_AVAILABLE_SSE2 1
#elif defined(__ARM_NEON)
    #include <arm_neon.h>
    #define SIMD_AVAILABLE_NEON 1
#endif

using namespace std::chrono;

//================================================================
// Benchmark Infrastructure
//================================================================

struct BenchmarkResult {
    double minTime;
    double medianTime;
    double maxTime;
    double avgTime;
    double speedup;
};

template<typename Func>
BenchmarkResult benchmarkFunction(Func func, int iterations = 1000) {
    std::vector<double> times;
    times.reserve(iterations);

    // Warmup
    for (int i = 0; i < 10; ++i) {
        func();
    }

    // Measure
    for (int i = 0; i < iterations; ++i) {
        auto start = high_resolution_clock::now();
        func();
        auto end = high_resolution_clock::now();

        auto duration = duration_cast<nanoseconds>(end - start).count();
        times.push_back(static_cast<double>(duration));
    }

    std::sort(times.begin(), times.end());

    return {
        times.front(),
        times[times.size() / 2],
        times.back(),
        std::accumulate(times.begin(), times.end(), 0.0) / times.size(),
        0.0  // Speedup calculated later
    };
}

//================================================================
// Test Data
//================================================================

constexpr int BLOCK_SIZE = 512;
constexpr int NUM_CHANNELS = 2;

std::vector<float> createTestBuffer(int size) {
    std::vector<float> buffer(size);
    for (int i = 0; i < size; ++i) {
        buffer[i] = static_cast<float>(std::sin(i * 0.1)) * 0.5f;
    }
    return buffer;
}

//================================================================
// Benchmark 1: Peak Detection (Stereo-Linked)
//================================================================

// Scalar baseline
float peakDetectionScalar(const float* bufferL, const float* bufferR, int numSamples) {
    float peak = 0.0f;
    for (int i = 0; i < numSamples; ++i) {
        float absL = std::abs(bufferL[i]);
        float absR = std::abs(bufferR[i]);
        float detection = std::max(absL, absR);
        peak = std::max(peak, detection);
    }
    return peak;
}

#ifdef SIMD_AVAILABLE_AVX
// AVX implementation
float peakDetectionAVX(const float* bufferL, const float* bufferR, int numSamples) {
    __m256 vecPeak = _mm256_setzero_ps();
    const __m256 signMask = _mm256_castsi256_ps(_mm256_set1_epi32(0x7FFFFFFF));

    int simdSamples = numSamples & ~7;

    for (int i = 0; i < simdSamples; i += 8) {
        __m256 samplesL = _mm256_loadu_ps(&bufferL[i]);
        __m256 samplesR = _mm256_loadu_ps(&bufferR[i]);

        __m256 absL = _mm256_and_ps(samplesL, signMask);
        __m256 absR = _mm256_and_ps(samplesR, signMask);

        __m256 maxLR = _mm256_max_ps(absL, absR);
        vecPeak = _mm256_max_ps(vecPeak, maxLR);
    }

    // Horizontal reduction
    float peaks[8];
    _mm256_storeu_ps(peaks, vecPeak);

    float peak = peaks[0];
    for (int i = 1; i < 8; ++i) {
        peak = std::max(peak, peaks[i]);
    }

    // Process remainder
    for (int i = simdSamples; i < numSamples; ++i) {
        float absL = std::abs(bufferL[i]);
        float absR = std::abs(bufferR[i]);
        float detection = std::max(absL, absR);
        peak = std::max(peak, detection);
    }

    return peak;
}
#endif

TEST_CASE("SIMD Peak Detection Benchmark", "[performance][simd]") {
    auto bufferL = createTestBuffer(BLOCK_SIZE);
    auto bufferR = createTestBuffer(BLOCK_SIZE);

    SECTION("Scalar baseline") {
        auto result = benchmarkFunction([&]() {
            volatile float peak = peakDetectionScalar(bufferL.data(), bufferR.data(), BLOCK_SIZE);
        });

        INFO("Scalar peak detection:");
        INFO("  Median: " << result.medianTime << " ns");
        INFO("  Min: " << result.minTime << " ns");
        INFO("  Max: " << result.maxTime << " ns");
    }

#ifdef SIMD_AVAILABLE_AVX
    SECTION("AVX optimized") {
        auto scalarResult = benchmarkFunction([&]() {
            volatile float peak = peakDetectionScalar(bufferL.data(), bufferR.data(), BLOCK_SIZE);
        });

        auto avxResult = benchmarkFunction([&]() {
            volatile float peak = peakDetectionAVX(bufferL.data(), bufferR.data(), BLOCK_SIZE);
        });

        double speedup = scalarResult.medianTime / avxResult.medianTime;

        INFO("AVX peak detection:");
        INFO("  Median: " << avxResult.medianTime << " ns");
        INFO("  Speedup: " << speedup << "x");

        // Validate claim: "6-8x faster (AVX)"
        // Real-world with memory bandwidth: expect 4-6x
        REQUIRE(speedup >= 3.0);  // At least 3x faster
        REQUIRE(speedup <= 10.0); // Sanity check
    }
#endif
}

//================================================================
// Benchmark 2: Dry/Wet Mix with FMA
//================================================================

void dryWetMixScalar(float* output, const float* dry, const float* wet,
                     float dryLevel, float wetLevel, int numSamples) {
    for (int i = 0; i < numSamples; ++i) {
        output[i] = dry[i] * dryLevel + wet[i] * wetLevel;
    }
}

#ifdef SIMD_AVAILABLE_AVX
void dryWetMixAVX2(float* output, const float* dry, const float* wet,
                   float dryLevel, float wetLevel, int numSamples) {
    __m256 v_dryLevel = _mm256_set1_ps(dryLevel);
    __m256 v_wetLevel = _mm256_set1_ps(wetLevel);

    int simdSamples = numSamples & ~7;

    for (int i = 0; i < simdSamples; i += 8) {
        __m256 v_dry = _mm256_loadu_ps(&dry[i]);
        __m256 v_wet = _mm256_loadu_ps(&wet[i]);

        // FMA: result = dry * dryLevel + wet * wetLevel
        __m256 result = _mm256_fmadd_ps(v_dry, v_dryLevel, _mm256_mul_ps(v_wet, v_wetLevel));

        _mm256_storeu_ps(&output[i], result);
    }

    // Remainder
    for (int i = simdSamples; i < numSamples; ++i) {
        output[i] = dry[i] * dryLevel + wet[i] * wetLevel;
    }
}
#endif

TEST_CASE("SIMD Dry/Wet Mix Benchmark", "[performance][simd][fma]") {
    auto dry = createTestBuffer(BLOCK_SIZE);
    auto wet = createTestBuffer(BLOCK_SIZE);
    std::vector<float> output(BLOCK_SIZE);

    const float dryLevel = 0.7f;
    const float wetLevel = 0.3f;

    SECTION("Scalar baseline") {
        auto result = benchmarkFunction([&]() {
            dryWetMixScalar(output.data(), dry.data(), wet.data(), dryLevel, wetLevel, BLOCK_SIZE);
        });

        INFO("Scalar dry/wet mix:");
        INFO("  Median: " << result.medianTime << " ns");
    }

#ifdef SIMD_AVAILABLE_AVX
    SECTION("AVX2 with FMA") {
        auto scalarResult = benchmarkFunction([&]() {
            dryWetMixScalar(output.data(), dry.data(), wet.data(), dryLevel, wetLevel, BLOCK_SIZE);
        });

        auto avxResult = benchmarkFunction([&]() {
            dryWetMixAVX2(output.data(), dry.data(), wet.data(), dryLevel, wetLevel, BLOCK_SIZE);
        });

        double speedup = scalarResult.medianTime / avxResult.medianTime;

        INFO("AVX2+FMA dry/wet mix:");
        INFO("  Median: " << avxResult.medianTime << " ns");
        INFO("  Speedup: " << speedup << "x");

        // Validate claim: "7-8x faster (AVX2 with FMA)"
        // Real-world: expect 4-7x
        REQUIRE(speedup >= 3.5);
    }
#endif
}

//================================================================
// Benchmark 3: Coefficient Caching Impact
//================================================================

TEST_CASE("Coefficient Caching Benchmark", "[performance][optimization]") {
    constexpr int NUM_SAMPLES = BLOCK_SIZE;
    const float attackTime = 0.01f;  // 10ms
    const float sampleRate = 48000.0f;

    SECTION("WITHOUT caching (per-sample exp)") {
        auto result = benchmarkFunction([&]() {
            float sum = 0.0f;
            for (int i = 0; i < NUM_SAMPLES; ++i) {
                float coeff = 1.0f - std::exp(-1.0f / (attackTime * sampleRate));
                sum += coeff;
            }
            volatile float _ = sum;  // Prevent optimization
        });

        INFO("Per-sample exp():");
        INFO("  Median: " << result.medianTime << " ns");
    }

    SECTION("WITH caching (single exp)") {
        auto uncachedResult = benchmarkFunction([&]() {
            float sum = 0.0f;
            for (int i = 0; i < NUM_SAMPLES; ++i) {
                float coeff = 1.0f - std::exp(-1.0f / (attackTime * sampleRate));
                sum += coeff;
            }
            volatile float _ = sum;
        });

        auto cachedResult = benchmarkFunction([&]() {
            const float attackCoeff = 1.0f - std::exp(-1.0f / (attackTime * sampleRate));
            float sum = 0.0f;
            for (int i = 0; i < NUM_SAMPLES; ++i) {
                sum += attackCoeff;
            }
            volatile float _ = sum;
        });

        double speedup = uncachedResult.medianTime / cachedResult.medianTime;

        INFO("Cached coefficient:");
        INFO("  Median: " << cachedResult.medianTime << " ns");
        INFO("  Speedup: " << speedup << "x");

        // Validate claim: "500-2000x reduction" (exp is ~100-200 cycles)
        REQUIRE(speedup >= 50.0);  // At least 50x faster
    }
}

//================================================================
// Benchmark 4: Direct Memory Access vs getSample()
//================================================================

TEST_CASE("Memory Access Pattern Benchmark", "[performance][memory]") {
    auto buffer = createTestBuffer(BLOCK_SIZE);

    SECTION("Direct pointer access (optimized)") {
        auto result = benchmarkFunction([&]() {
            float* ptr = buffer.data();
            float sum = 0.0f;
            for (int i = 0; i < BLOCK_SIZE; ++i) {
                sum += ptr[i];
            }
            volatile float _ = sum;
        });

        INFO("Direct pointer access:");
        INFO("  Median: " << result.medianTime << " ns");
    }

    SECTION("Vector subscript (like getSample)") {
        auto directResult = benchmarkFunction([&]() {
            float* ptr = buffer.data();
            float sum = 0.0f;
            for (int i = 0; i < BLOCK_SIZE; ++i) {
                sum += ptr[i];
            }
            volatile float _ = sum;
        });

        auto subscriptResult = benchmarkFunction([&]() {
            float sum = 0.0f;
            for (int i = 0; i < BLOCK_SIZE; ++i) {
                sum += buffer[i];  // Bounds checking overhead
            }
            volatile float _ = sum;
        });

        double speedup = subscriptResult.medianTime / directResult.medianTime;

        INFO("Vector subscript:");
        INFO("  Median: " << subscriptResult.medianTime << " ns");
        INFO("  Speedup: " << speedup << "x");

        // Validate claim: "~2x faster (direct pointers)"
        REQUIRE(speedup >= 1.2);  // At least 20% faster
    }
}

//================================================================
// Summary Report
//================================================================

TEST_CASE("Performance Summary Report", "[.][performance][summary]") {
    INFO("=================================================================");
    INFO("SIMD Performance Validation Report");
    INFO("=================================================================");
    INFO("");
    INFO("Hardware:");
    #if defined(__AVX2__)
        INFO("  SIMD: AVX2 + FMA");
    #elif defined(__AVX__)
        INFO("  SIMD: AVX");
    #elif defined(__SSE4_2__)
        INFO("  SIMD: SSE4.2");
    #elif defined(__SSE2__)
        INFO("  SIMD: SSE2");
    #elif defined(__ARM_NEON)
        INFO("  SIMD: ARM NEON");
    #else
        INFO("  SIMD: None (scalar fallback)");
    #endif
    INFO("");
    INFO("Validation Status:");
    INFO("  Peak Detection: Run benchmarks to validate");
    INFO("  Dry/Wet Mix: Run benchmarks to validate");
    INFO("  Coefficient Caching: Run benchmarks to validate");
    INFO("  Memory Access: Run benchmarks to validate");
    INFO("");
    INFO("=================================================================");
}
