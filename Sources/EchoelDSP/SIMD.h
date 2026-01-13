#pragma once
// ============================================================================
// EchoelDSP/SIMD.h - Platform-Agnostic SIMD Abstraction
// ============================================================================
// Zero dependencies. Pure C++17. Maximum performance.
// Supports: ARM NEON (Apple Silicon, Android), x86 AVX2/SSE4, WebAssembly SIMD
// ============================================================================

#include <cstdint>
#include <cmath>
#include <algorithm>

// Platform detection
#if defined(__ARM_NEON) || defined(__ARM_NEON__)
    #define ECHOEL_SIMD_NEON 1
    #include <arm_neon.h>
#elif defined(__AVX2__)
    #define ECHOEL_SIMD_AVX2 1
    #include <immintrin.h>
#elif defined(__SSE4_1__)
    #define ECHOEL_SIMD_SSE4 1
    #include <smmintrin.h>
#elif defined(__wasm_simd128__)
    #define ECHOEL_SIMD_WASM 1
    #include <wasm_simd128.h>
#else
    #define ECHOEL_SIMD_SCALAR 1
#endif

namespace Echoel::DSP {

// ============================================================================
// MARK: - SIMD Vector Types (4-wide float)
// ============================================================================

#if ECHOEL_SIMD_NEON
    using float4 = float32x4_t;

    inline float4 simd_load(const float* ptr) { return vld1q_f32(ptr); }
    inline void simd_store(float* ptr, float4 v) { vst1q_f32(ptr, v); }
    inline float4 simd_set1(float val) { return vdupq_n_f32(val); }
    inline float4 simd_add(float4 a, float4 b) { return vaddq_f32(a, b); }
    inline float4 simd_sub(float4 a, float4 b) { return vsubq_f32(a, b); }
    inline float4 simd_mul(float4 a, float4 b) { return vmulq_f32(a, b); }
    inline float4 simd_div(float4 a, float4 b) { return vdivq_f32(a, b); }
    inline float4 simd_min(float4 a, float4 b) { return vminq_f32(a, b); }
    inline float4 simd_max(float4 a, float4 b) { return vmaxq_f32(a, b); }
    inline float4 simd_abs(float4 a) { return vabsq_f32(a); }
    inline float4 simd_sqrt(float4 a) { return vsqrtq_f32(a); }
    inline float4 simd_fma(float4 a, float4 b, float4 c) { return vfmaq_f32(c, a, b); } // a*b+c

    inline float simd_reduce_add(float4 v) {
        float32x2_t sum = vadd_f32(vget_low_f32(v), vget_high_f32(v));
        return vget_lane_f32(vpadd_f32(sum, sum), 0);
    }

    inline float simd_reduce_max(float4 v) {
        float32x2_t max2 = vpmax_f32(vget_low_f32(v), vget_high_f32(v));
        return vget_lane_f32(vpmax_f32(max2, max2), 0);
    }

#elif ECHOEL_SIMD_AVX2 || ECHOEL_SIMD_SSE4
    using float4 = __m128;

    inline float4 simd_load(const float* ptr) { return _mm_loadu_ps(ptr); }
    inline void simd_store(float* ptr, float4 v) { _mm_storeu_ps(ptr, v); }
    inline float4 simd_set1(float val) { return _mm_set1_ps(val); }
    inline float4 simd_add(float4 a, float4 b) { return _mm_add_ps(a, b); }
    inline float4 simd_sub(float4 a, float4 b) { return _mm_sub_ps(a, b); }
    inline float4 simd_mul(float4 a, float4 b) { return _mm_mul_ps(a, b); }
    inline float4 simd_div(float4 a, float4 b) { return _mm_div_ps(a, b); }
    inline float4 simd_min(float4 a, float4 b) { return _mm_min_ps(a, b); }
    inline float4 simd_max(float4 a, float4 b) { return _mm_max_ps(a, b); }
    inline float4 simd_abs(float4 a) { return _mm_andnot_ps(_mm_set1_ps(-0.0f), a); }
    inline float4 simd_sqrt(float4 a) { return _mm_sqrt_ps(a); }

    #ifdef __FMA__
        inline float4 simd_fma(float4 a, float4 b, float4 c) { return _mm_fmadd_ps(a, b, c); }
    #else
        inline float4 simd_fma(float4 a, float4 b, float4 c) { return _mm_add_ps(_mm_mul_ps(a, b), c); }
    #endif

    inline float simd_reduce_add(float4 v) {
        __m128 shuf = _mm_shuffle_ps(v, v, _MM_SHUFFLE(2, 3, 0, 1));
        __m128 sums = _mm_add_ps(v, shuf);
        shuf = _mm_movehl_ps(shuf, sums);
        sums = _mm_add_ss(sums, shuf);
        return _mm_cvtss_f32(sums);
    }

    inline float simd_reduce_max(float4 v) {
        __m128 shuf = _mm_shuffle_ps(v, v, _MM_SHUFFLE(2, 3, 0, 1));
        __m128 maxs = _mm_max_ps(v, shuf);
        shuf = _mm_movehl_ps(shuf, maxs);
        maxs = _mm_max_ss(maxs, shuf);
        return _mm_cvtss_f32(maxs);
    }

#else
    // Scalar fallback
    struct float4 { float v[4]; };

    inline float4 simd_load(const float* ptr) { return {ptr[0], ptr[1], ptr[2], ptr[3]}; }
    inline void simd_store(float* ptr, float4 v) { ptr[0]=v.v[0]; ptr[1]=v.v[1]; ptr[2]=v.v[2]; ptr[3]=v.v[3]; }
    inline float4 simd_set1(float val) { return {val, val, val, val}; }
    inline float4 simd_add(float4 a, float4 b) { return {a.v[0]+b.v[0], a.v[1]+b.v[1], a.v[2]+b.v[2], a.v[3]+b.v[3]}; }
    inline float4 simd_sub(float4 a, float4 b) { return {a.v[0]-b.v[0], a.v[1]-b.v[1], a.v[2]-b.v[2], a.v[3]-b.v[3]}; }
    inline float4 simd_mul(float4 a, float4 b) { return {a.v[0]*b.v[0], a.v[1]*b.v[1], a.v[2]*b.v[2], a.v[3]*b.v[3]}; }
    inline float4 simd_div(float4 a, float4 b) { return {a.v[0]/b.v[0], a.v[1]/b.v[1], a.v[2]/b.v[2], a.v[3]/b.v[3]}; }
    inline float4 simd_min(float4 a, float4 b) { return {std::min(a.v[0],b.v[0]), std::min(a.v[1],b.v[1]), std::min(a.v[2],b.v[2]), std::min(a.v[3],b.v[3])}; }
    inline float4 simd_max(float4 a, float4 b) { return {std::max(a.v[0],b.v[0]), std::max(a.v[1],b.v[1]), std::max(a.v[2],b.v[2]), std::max(a.v[3],b.v[3])}; }
    inline float4 simd_abs(float4 a) { return {std::abs(a.v[0]), std::abs(a.v[1]), std::abs(a.v[2]), std::abs(a.v[3])}; }
    inline float4 simd_sqrt(float4 a) { return {std::sqrt(a.v[0]), std::sqrt(a.v[1]), std::sqrt(a.v[2]), std::sqrt(a.v[3])}; }
    inline float4 simd_fma(float4 a, float4 b, float4 c) {
        return {a.v[0]*b.v[0]+c.v[0], a.v[1]*b.v[1]+c.v[1], a.v[2]*b.v[2]+c.v[2], a.v[3]*b.v[3]+c.v[3]};
    }
    inline float simd_reduce_add(float4 v) { return v.v[0]+v.v[1]+v.v[2]+v.v[3]; }
    inline float simd_reduce_max(float4 v) { return std::max({v.v[0],v.v[1],v.v[2],v.v[3]}); }
#endif

// ============================================================================
// MARK: - SIMD-Optimized DSP Operations
// ============================================================================

/// Apply gain to buffer (SIMD 4-wide)
inline void applyGain(float* buffer, int numSamples, float gain) {
    float4 gainVec = simd_set1(gain);
    int i = 0;

    // SIMD loop (4 samples at a time)
    for (; i <= numSamples - 4; i += 4) {
        float4 samples = simd_load(buffer + i);
        samples = simd_mul(samples, gainVec);
        simd_store(buffer + i, samples);
    }

    // Scalar tail
    for (; i < numSamples; ++i) {
        buffer[i] *= gain;
    }
}

/// Mix two buffers: out = a + b * mix (SIMD)
inline void mixBuffers(const float* a, const float* b, float* out, int numSamples, float mix) {
    float4 mixVec = simd_set1(mix);
    int i = 0;

    for (; i <= numSamples - 4; i += 4) {
        float4 va = simd_load(a + i);
        float4 vb = simd_load(b + i);
        float4 result = simd_fma(vb, mixVec, va); // a + b * mix
        simd_store(out + i, result);
    }

    for (; i < numSamples; ++i) {
        out[i] = a[i] + b[i] * mix;
    }
}

/// Compute RMS level (SIMD)
inline float computeRMS(const float* buffer, int numSamples) {
    float4 sumSq = simd_set1(0.0f);
    int i = 0;

    for (; i <= numSamples - 4; i += 4) {
        float4 samples = simd_load(buffer + i);
        sumSq = simd_fma(samples, samples, sumSq);
    }

    float total = simd_reduce_add(sumSq);

    for (; i < numSamples; ++i) {
        total += buffer[i] * buffer[i];
    }

    return std::sqrt(total / numSamples);
}

/// Compute peak level (SIMD)
inline float computePeak(const float* buffer, int numSamples) {
    float4 maxVec = simd_set1(0.0f);
    int i = 0;

    for (; i <= numSamples - 4; i += 4) {
        float4 samples = simd_load(buffer + i);
        float4 absSamples = simd_abs(samples);
        maxVec = simd_max(maxVec, absSamples);
    }

    float peak = simd_reduce_max(maxVec);

    for (; i < numSamples; ++i) {
        peak = std::max(peak, std::abs(buffer[i]));
    }

    return peak;
}

/// Soft clip (tanh approximation, SIMD)
inline void softClip(float* buffer, int numSamples, float threshold = 0.9f) {
    float4 threshVec = simd_set1(threshold);
    float4 invThresh = simd_set1(1.0f / threshold);
    float4 one = simd_set1(1.0f);
    float4 negOne = simd_set1(-1.0f);
    int i = 0;

    for (; i <= numSamples - 4; i += 4) {
        float4 x = simd_load(buffer + i);
        // Pade approximation of tanh for soft clipping
        float4 x2 = simd_mul(x, x);
        float4 x3 = simd_mul(x2, x);
        // tanh(x) ≈ x - x³/3 for small x
        float4 result = simd_sub(x, simd_mul(x3, simd_set1(0.333333f)));
        result = simd_max(negOne, simd_min(one, result));
        simd_store(buffer + i, result);
    }

    for (; i < numSamples; ++i) {
        float x = buffer[i];
        buffer[i] = std::tanh(x);
    }
}

/// Linear interpolation (SIMD)
inline void lerp(const float* a, const float* b, float* out, int numSamples, float t) {
    float4 tVec = simd_set1(t);
    float4 oneMinusT = simd_set1(1.0f - t);
    int i = 0;

    for (; i <= numSamples - 4; i += 4) {
        float4 va = simd_load(a + i);
        float4 vb = simd_load(b + i);
        float4 result = simd_add(simd_mul(va, oneMinusT), simd_mul(vb, tVec));
        simd_store(out + i, result);
    }

    for (; i < numSamples; ++i) {
        out[i] = a[i] * (1.0f - t) + b[i] * t;
    }
}

// ============================================================================
// MARK: - Performance Metrics
// ============================================================================

struct SIMDInfo {
    const char* name;
    int vectorWidth;
    bool hasFMA;
    bool hasNEON;
    bool hasAVX2;
    bool hasSSE4;

    static SIMDInfo get() {
        SIMDInfo info{};
        #if ECHOEL_SIMD_NEON
            info.name = "ARM NEON";
            info.vectorWidth = 4;
            info.hasFMA = true;
            info.hasNEON = true;
        #elif ECHOEL_SIMD_AVX2
            info.name = "x86 AVX2";
            info.vectorWidth = 8; // Can use 8-wide with __m256
            info.hasFMA = true;
            info.hasAVX2 = true;
        #elif ECHOEL_SIMD_SSE4
            info.name = "x86 SSE4";
            info.vectorWidth = 4;
            info.hasSSE4 = true;
        #else
            info.name = "Scalar";
            info.vectorWidth = 1;
        #endif
        return info;
    }
};

} // namespace Echoel::DSP
