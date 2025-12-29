/**
 * EchoelSIMDUtils.h
 *
 * ============================================================================
 *   RALPH WIGGUM GENIUS ULTRATHINK MODE - SIMD UTILITIES
 * ============================================================================
 *
 * Cross-platform SIMD utilities for maximum performance:
 * - SSE2/SSE4/AVX/AVX2/AVX-512 (x86)
 * - NEON/NEON64 (ARM)
 * - Automatic runtime dispatch
 * - Aligned memory allocations
 * - Vectorized math operations
 * - DSP primitives
 */

#pragma once

#include <array>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cmath>

// Platform detection
#if defined(__x86_64__) || defined(_M_X64) || defined(__i386__) || defined(_M_IX86)
    #define ECHOEL_X86 1
    #include <immintrin.h>
#elif defined(__aarch64__) || defined(_M_ARM64)
    #define ECHOEL_ARM64 1
    #include <arm_neon.h>
#elif defined(__arm__) || defined(_M_ARM)
    #define ECHOEL_ARM32 1
    #include <arm_neon.h>
#endif

namespace Echoel { namespace SIMD {

//==============================================================================
// Constants
//==============================================================================

static constexpr size_t SIMD_ALIGNMENT = 32;  // AVX alignment
static constexpr size_t CACHE_LINE_SIZE = 64;

//==============================================================================
// CPU Feature Detection
//==============================================================================

struct CPUFeatures
{
    bool hasSSE2 = false;
    bool hasSSE3 = false;
    bool hasSSSE3 = false;
    bool hasSSE41 = false;
    bool hasSSE42 = false;
    bool hasAVX = false;
    bool hasAVX2 = false;
    bool hasAVX512F = false;
    bool hasFMA = false;
    bool hasNEON = false;

    static CPUFeatures detect()
    {
        CPUFeatures features;

        #ifdef ECHOEL_X86
        #ifdef _MSC_VER
        int cpuInfo[4];
        __cpuid(cpuInfo, 1);
        features.hasSSE2 = (cpuInfo[3] & (1 << 26)) != 0;
        features.hasSSE3 = (cpuInfo[2] & (1 << 0)) != 0;
        features.hasSSSE3 = (cpuInfo[2] & (1 << 9)) != 0;
        features.hasSSE41 = (cpuInfo[2] & (1 << 19)) != 0;
        features.hasSSE42 = (cpuInfo[2] & (1 << 20)) != 0;
        features.hasAVX = (cpuInfo[2] & (1 << 28)) != 0;
        features.hasFMA = (cpuInfo[2] & (1 << 12)) != 0;

        __cpuid(cpuInfo, 7);
        features.hasAVX2 = (cpuInfo[1] & (1 << 5)) != 0;
        features.hasAVX512F = (cpuInfo[1] & (1 << 16)) != 0;
        #else
        __builtin_cpu_init();
        features.hasSSE2 = __builtin_cpu_supports("sse2");
        features.hasSSE3 = __builtin_cpu_supports("sse3");
        features.hasSSSE3 = __builtin_cpu_supports("ssse3");
        features.hasSSE41 = __builtin_cpu_supports("sse4.1");
        features.hasSSE42 = __builtin_cpu_supports("sse4.2");
        features.hasAVX = __builtin_cpu_supports("avx");
        features.hasAVX2 = __builtin_cpu_supports("avx2");
        features.hasFMA = __builtin_cpu_supports("fma");
        #endif
        #endif

        #if defined(ECHOEL_ARM64) || defined(ECHOEL_ARM32)
        features.hasNEON = true;
        #endif

        return features;
    }
};

inline CPUFeatures& getCPUFeatures()
{
    static CPUFeatures features = CPUFeatures::detect();
    return features;
}

//==============================================================================
// Aligned Memory
//==============================================================================

inline void* alignedAlloc(size_t size, size_t alignment = SIMD_ALIGNMENT)
{
    #ifdef _MSC_VER
    return _aligned_malloc(size, alignment);
    #else
    void* ptr = nullptr;
    if (posix_memalign(&ptr, alignment, size) != 0)
        return nullptr;
    return ptr;
    #endif
}

inline void alignedFree(void* ptr)
{
    #ifdef _MSC_VER
    _aligned_free(ptr);
    #else
    free(ptr);
    #endif
}

template<typename T>
class AlignedBuffer
{
public:
    AlignedBuffer() = default;

    explicit AlignedBuffer(size_t count)
        : size_(count)
    {
        data_ = static_cast<T*>(alignedAlloc(count * sizeof(T)));
    }

    ~AlignedBuffer()
    {
        if (data_)
            alignedFree(data_);
    }

    AlignedBuffer(const AlignedBuffer& other)
        : size_(other.size_)
    {
        data_ = static_cast<T*>(alignedAlloc(size_ * sizeof(T)));
        std::memcpy(data_, other.data_, size_ * sizeof(T));
    }

    AlignedBuffer(AlignedBuffer&& other) noexcept
        : data_(other.data_), size_(other.size_)
    {
        other.data_ = nullptr;
        other.size_ = 0;
    }

    AlignedBuffer& operator=(AlignedBuffer other)
    {
        std::swap(data_, other.data_);
        std::swap(size_, other.size_);
        return *this;
    }

    void resize(size_t count)
    {
        if (data_)
            alignedFree(data_);
        size_ = count;
        data_ = static_cast<T*>(alignedAlloc(count * sizeof(T)));
    }

    void clear()
    {
        std::memset(data_, 0, size_ * sizeof(T));
    }

    T* data() { return data_; }
    const T* data() const { return data_; }
    size_t size() const { return size_; }
    T& operator[](size_t i) { return data_[i]; }
    const T& operator[](size_t i) const { return data_[i]; }

private:
    T* data_ = nullptr;
    size_t size_ = 0;
};

//==============================================================================
// SIMD Vector Types (Platform Independent Wrappers)
//==============================================================================

#ifdef ECHOEL_X86

// 128-bit (SSE)
struct Float4
{
    __m128 v;

    Float4() : v(_mm_setzero_ps()) {}
    Float4(__m128 val) : v(val) {}
    Float4(float x) : v(_mm_set1_ps(x)) {}
    Float4(float a, float b, float c, float d) : v(_mm_set_ps(d, c, b, a)) {}

    static Float4 load(const float* ptr) { return _mm_load_ps(ptr); }
    static Float4 loadu(const float* ptr) { return _mm_loadu_ps(ptr); }
    void store(float* ptr) const { _mm_store_ps(ptr, v); }
    void storeu(float* ptr) const { _mm_storeu_ps(ptr, v); }

    Float4 operator+(Float4 other) const { return _mm_add_ps(v, other.v); }
    Float4 operator-(Float4 other) const { return _mm_sub_ps(v, other.v); }
    Float4 operator*(Float4 other) const { return _mm_mul_ps(v, other.v); }
    Float4 operator/(Float4 other) const { return _mm_div_ps(v, other.v); }

    Float4& operator+=(Float4 other) { v = _mm_add_ps(v, other.v); return *this; }
    Float4& operator-=(Float4 other) { v = _mm_sub_ps(v, other.v); return *this; }
    Float4& operator*=(Float4 other) { v = _mm_mul_ps(v, other.v); return *this; }

    float sum() const
    {
        __m128 t = _mm_hadd_ps(v, v);
        t = _mm_hadd_ps(t, t);
        return _mm_cvtss_f32(t);
    }

    Float4 sqrt() const { return _mm_sqrt_ps(v); }
    Float4 abs() const { return _mm_and_ps(v, _mm_castsi128_ps(_mm_set1_epi32(0x7FFFFFFF))); }
    Float4 min(Float4 other) const { return _mm_min_ps(v, other.v); }
    Float4 max(Float4 other) const { return _mm_max_ps(v, other.v); }
};

// 256-bit (AVX)
struct Float8
{
    __m256 v;

    Float8() : v(_mm256_setzero_ps()) {}
    Float8(__m256 val) : v(val) {}
    Float8(float x) : v(_mm256_set1_ps(x)) {}

    static Float8 load(const float* ptr) { return _mm256_load_ps(ptr); }
    static Float8 loadu(const float* ptr) { return _mm256_loadu_ps(ptr); }
    void store(float* ptr) const { _mm256_store_ps(ptr, v); }
    void storeu(float* ptr) const { _mm256_storeu_ps(ptr, v); }

    Float8 operator+(Float8 other) const { return _mm256_add_ps(v, other.v); }
    Float8 operator-(Float8 other) const { return _mm256_sub_ps(v, other.v); }
    Float8 operator*(Float8 other) const { return _mm256_mul_ps(v, other.v); }
    Float8 operator/(Float8 other) const { return _mm256_div_ps(v, other.v); }

    Float8& operator+=(Float8 other) { v = _mm256_add_ps(v, other.v); return *this; }
    Float8& operator-=(Float8 other) { v = _mm256_sub_ps(v, other.v); return *this; }
    Float8& operator*=(Float8 other) { v = _mm256_mul_ps(v, other.v); return *this; }

    float sum() const
    {
        __m128 lo = _mm256_castps256_ps128(v);
        __m128 hi = _mm256_extractf128_ps(v, 1);
        lo = _mm_add_ps(lo, hi);
        lo = _mm_hadd_ps(lo, lo);
        lo = _mm_hadd_ps(lo, lo);
        return _mm_cvtss_f32(lo);
    }

    Float8 sqrt() const { return _mm256_sqrt_ps(v); }
    Float8 abs() const { return _mm256_and_ps(v, _mm256_castsi256_ps(_mm256_set1_epi32(0x7FFFFFFF))); }
    Float8 min(Float8 other) const { return _mm256_min_ps(v, other.v); }
    Float8 max(Float8 other) const { return _mm256_max_ps(v, other.v); }
};

#elif defined(ECHOEL_ARM64) || defined(ECHOEL_ARM32)

struct Float4
{
    float32x4_t v;

    Float4() : v(vdupq_n_f32(0.0f)) {}
    Float4(float32x4_t val) : v(val) {}
    Float4(float x) : v(vdupq_n_f32(x)) {}
    Float4(float a, float b, float c, float d) { float arr[4] = {a, b, c, d}; v = vld1q_f32(arr); }

    static Float4 load(const float* ptr) { return vld1q_f32(ptr); }
    static Float4 loadu(const float* ptr) { return vld1q_f32(ptr); }
    void store(float* ptr) const { vst1q_f32(ptr, v); }
    void storeu(float* ptr) const { vst1q_f32(ptr, v); }

    Float4 operator+(Float4 other) const { return vaddq_f32(v, other.v); }
    Float4 operator-(Float4 other) const { return vsubq_f32(v, other.v); }
    Float4 operator*(Float4 other) const { return vmulq_f32(v, other.v); }

    float sum() const
    {
        float32x2_t t = vadd_f32(vget_low_f32(v), vget_high_f32(v));
        t = vpadd_f32(t, t);
        return vget_lane_f32(t, 0);
    }

    Float4 sqrt() const { return vsqrtq_f32(v); }
    Float4 abs() const { return vabsq_f32(v); }
    Float4 min(Float4 other) const { return vminq_f32(v, other.v); }
    Float4 max(Float4 other) const { return vmaxq_f32(v, other.v); }
};

// ARM doesn't have 256-bit, so Float8 uses two Float4
struct Float8
{
    Float4 lo, hi;

    Float8() = default;
    Float8(float x) : lo(x), hi(x) {}

    static Float8 load(const float* ptr) { Float8 r; r.lo = Float4::load(ptr); r.hi = Float4::load(ptr + 4); return r; }
    void store(float* ptr) const { lo.store(ptr); hi.store(ptr + 4); }

    Float8 operator+(Float8 other) const { Float8 r; r.lo = lo + other.lo; r.hi = hi + other.hi; return r; }
    Float8 operator*(Float8 other) const { Float8 r; r.lo = lo * other.lo; r.hi = hi * other.hi; return r; }

    float sum() const { return lo.sum() + hi.sum(); }
};

#else
// Fallback scalar implementation
struct Float4
{
    alignas(16) float v[4];

    Float4() : v{0, 0, 0, 0} {}
    Float4(float x) : v{x, x, x, x} {}
    Float4(float a, float b, float c, float d) : v{a, b, c, d} {}

    static Float4 load(const float* ptr) { Float4 r; std::memcpy(r.v, ptr, 16); return r; }
    void store(float* ptr) const { std::memcpy(ptr, v, 16); }

    Float4 operator+(Float4 o) const { return Float4(v[0]+o.v[0], v[1]+o.v[1], v[2]+o.v[2], v[3]+o.v[3]); }
    Float4 operator*(Float4 o) const { return Float4(v[0]*o.v[0], v[1]*o.v[1], v[2]*o.v[2], v[3]*o.v[3]); }

    float sum() const { return v[0] + v[1] + v[2] + v[3]; }
};

struct Float8
{
    Float4 lo, hi;
    Float8() = default;
    Float8(float x) : lo(x), hi(x) {}
    static Float8 load(const float* ptr) { Float8 r; r.lo = Float4::load(ptr); r.hi = Float4::load(ptr + 4); return r; }
    void store(float* ptr) const { lo.store(ptr); hi.store(ptr + 4); }
    Float8 operator+(Float8 o) const { Float8 r; r.lo = lo + o.lo; r.hi = hi + o.hi; return r; }
    Float8 operator*(Float8 o) const { Float8 r; r.lo = lo * o.lo; r.hi = hi * o.hi; return r; }
    float sum() const { return lo.sum() + hi.sum(); }
};
#endif

//==============================================================================
// Vectorized DSP Operations
//==============================================================================

/**
 * Vector add: out[i] = a[i] + b[i]
 */
inline void vectorAdd(const float* a, const float* b, float* out, size_t count)
{
    size_t i = 0;

    #ifdef ECHOEL_X86
    if (getCPUFeatures().hasAVX)
    {
        for (; i + 8 <= count; i += 8)
        {
            Float8 va = Float8::load(a + i);
            Float8 vb = Float8::load(b + i);
            (va + vb).store(out + i);
        }
    }
    #endif

    for (; i + 4 <= count; i += 4)
    {
        Float4 va = Float4::load(a + i);
        Float4 vb = Float4::load(b + i);
        (va + vb).store(out + i);
    }

    for (; i < count; ++i)
    {
        out[i] = a[i] + b[i];
    }
}

/**
 * Vector multiply: out[i] = a[i] * b[i]
 */
inline void vectorMul(const float* a, const float* b, float* out, size_t count)
{
    size_t i = 0;

    #ifdef ECHOEL_X86
    if (getCPUFeatures().hasAVX)
    {
        for (; i + 8 <= count; i += 8)
        {
            Float8 va = Float8::load(a + i);
            Float8 vb = Float8::load(b + i);
            (va * vb).store(out + i);
        }
    }
    #endif

    for (; i + 4 <= count; i += 4)
    {
        Float4 va = Float4::load(a + i);
        Float4 vb = Float4::load(b + i);
        (va * vb).store(out + i);
    }

    for (; i < count; ++i)
    {
        out[i] = a[i] * b[i];
    }
}

/**
 * Vector multiply-add: out[i] = a[i] * b[i] + c[i]
 */
inline void vectorMulAdd(const float* a, const float* b, const float* c,
                         float* out, size_t count)
{
    size_t i = 0;

    #ifdef ECHOEL_X86
    if (getCPUFeatures().hasFMA && getCPUFeatures().hasAVX)
    {
        for (; i + 8 <= count; i += 8)
        {
            __m256 va = _mm256_load_ps(a + i);
            __m256 vb = _mm256_load_ps(b + i);
            __m256 vc = _mm256_load_ps(c + i);
            __m256 result = _mm256_fmadd_ps(va, vb, vc);
            _mm256_store_ps(out + i, result);
        }
    }
    #endif

    for (; i < count; ++i)
    {
        out[i] = a[i] * b[i] + c[i];
    }
}

/**
 * Vector scale: out[i] = a[i] * scale
 */
inline void vectorScale(const float* a, float scale, float* out, size_t count)
{
    size_t i = 0;

    #ifdef ECHOEL_X86
    if (getCPUFeatures().hasAVX)
    {
        Float8 vscale(scale);
        for (; i + 8 <= count; i += 8)
        {
            Float8 va = Float8::load(a + i);
            (va * vscale).store(out + i);
        }
    }
    #endif

    Float4 vscale4(scale);
    for (; i + 4 <= count; i += 4)
    {
        Float4 va = Float4::load(a + i);
        (va * vscale4).store(out + i);
    }

    for (; i < count; ++i)
    {
        out[i] = a[i] * scale;
    }
}

/**
 * Dot product
 */
inline float vectorDot(const float* a, const float* b, size_t count)
{
    float result = 0.0f;
    size_t i = 0;

    #ifdef ECHOEL_X86
    if (getCPUFeatures().hasAVX)
    {
        Float8 sum(0.0f);
        for (; i + 8 <= count; i += 8)
        {
            Float8 va = Float8::load(a + i);
            Float8 vb = Float8::load(b + i);
            sum += va * vb;
        }
        result = sum.sum();
    }
    #endif

    if (i == 0)
    {
        Float4 sum(0.0f);
        for (; i + 4 <= count; i += 4)
        {
            Float4 va = Float4::load(a + i);
            Float4 vb = Float4::load(b + i);
            sum += va * vb;
        }
        result = sum.sum();
    }

    for (; i < count; ++i)
    {
        result += a[i] * b[i];
    }

    return result;
}

/**
 * Sum of vector
 */
inline float vectorSum(const float* a, size_t count)
{
    float result = 0.0f;
    size_t i = 0;

    #ifdef ECHOEL_X86
    if (getCPUFeatures().hasAVX)
    {
        Float8 sum(0.0f);
        for (; i + 8 <= count; i += 8)
        {
            sum += Float8::load(a + i);
        }
        result = sum.sum();
    }
    #endif

    Float4 sum4(0.0f);
    for (; i + 4 <= count; i += 4)
    {
        sum4 += Float4::load(a + i);
    }
    result += sum4.sum();

    for (; i < count; ++i)
    {
        result += a[i];
    }

    return result;
}

/**
 * RMS (Root Mean Square)
 */
inline float vectorRMS(const float* a, size_t count)
{
    float sumSq = 0.0f;
    size_t i = 0;

    #ifdef ECHOEL_X86
    if (getCPUFeatures().hasAVX)
    {
        Float8 sum(0.0f);
        for (; i + 8 <= count; i += 8)
        {
            Float8 va = Float8::load(a + i);
            sum += va * va;
        }
        sumSq = sum.sum();
    }
    #endif

    Float4 sum4(0.0f);
    for (; i + 4 <= count; i += 4)
    {
        Float4 va = Float4::load(a + i);
        sum4 += va * va;
    }
    sumSq += sum4.sum();

    for (; i < count; ++i)
    {
        sumSq += a[i] * a[i];
    }

    return std::sqrt(sumSq / count);
}

/**
 * Find max value
 */
inline float vectorMax(const float* a, size_t count)
{
    if (count == 0) return 0.0f;

    float result = a[0];
    size_t i = 1;

    #ifdef ECHOEL_X86
    if (getCPUFeatures().hasAVX && count >= 8)
    {
        Float8 vmax = Float8::load(a);
        for (i = 8; i + 8 <= count; i += 8)
        {
            vmax = vmax.max(Float8::load(a + i));
        }
        // Reduce
        alignas(32) float temp[8];
        vmax.store(temp);
        for (int j = 0; j < 8; ++j)
            result = std::max(result, temp[j]);
    }
    #endif

    for (; i < count; ++i)
    {
        result = std::max(result, a[i]);
    }

    return result;
}

/**
 * Find min value
 */
inline float vectorMin(const float* a, size_t count)
{
    if (count == 0) return 0.0f;

    float result = a[0];
    size_t i = 1;

    for (; i < count; ++i)
    {
        result = std::min(result, a[i]);
    }

    return result;
}

/**
 * Clamp values to range
 */
inline void vectorClamp(const float* a, float minVal, float maxVal,
                        float* out, size_t count)
{
    size_t i = 0;

    #ifdef ECHOEL_X86
    if (getCPUFeatures().hasAVX)
    {
        Float8 vmin(minVal);
        Float8 vmax(maxVal);
        for (; i + 8 <= count; i += 8)
        {
            Float8 va = Float8::load(a + i);
            va.max(vmin).min(vmax).store(out + i);
        }
    }
    #endif

    Float4 vmin4(minVal);
    Float4 vmax4(maxVal);
    for (; i + 4 <= count; i += 4)
    {
        Float4 va = Float4::load(a + i);
        va.max(vmin4).min(vmax4).store(out + i);
    }

    for (; i < count; ++i)
    {
        out[i] = std::max(minVal, std::min(maxVal, a[i]));
    }
}

//==============================================================================
// Fast Math Approximations
//==============================================================================

/**
 * Fast approximate sine using lookup table
 */
class FastSinTable
{
public:
    static constexpr size_t TABLE_SIZE = 4096;
    static constexpr float TWO_PI = 6.28318530718f;

    FastSinTable()
    {
        for (size_t i = 0; i < TABLE_SIZE; ++i)
        {
            float angle = (static_cast<float>(i) / TABLE_SIZE) * TWO_PI;
            table_[i] = std::sin(angle);
        }
    }

    float sin(float x) const
    {
        // Normalize to 0-1
        float normalized = x / TWO_PI;
        normalized = normalized - std::floor(normalized);
        int index = static_cast<int>(normalized * TABLE_SIZE) & (TABLE_SIZE - 1);
        return table_[index];
    }

    float cos(float x) const
    {
        return sin(x + 1.5707963f);  // pi/2
    }

private:
    alignas(CACHE_LINE_SIZE) float table_[TABLE_SIZE];
};

inline FastSinTable& getFastSinTable()
{
    static FastSinTable table;
    return table;
}

inline float fastSin(float x)
{
    return getFastSinTable().sin(x);
}

inline float fastCos(float x)
{
    return getFastSinTable().cos(x);
}

/**
 * Fast approximate inverse square root (Quake III style, improved)
 */
inline float fastInvSqrt(float x)
{
    float xhalf = 0.5f * x;
    int i = *reinterpret_cast<int*>(&x);
    i = 0x5f375a86 - (i >> 1);
    x = *reinterpret_cast<float*>(&i);
    x = x * (1.5f - xhalf * x * x);  // Newton iteration
    x = x * (1.5f - xhalf * x * x);  // Second iteration for more precision
    return x;
}

/**
 * Fast approximate exp
 */
inline float fastExp(float x)
{
    // Schraudolph's algorithm
    x = 1.0f + x / 256.0f;
    x *= x; x *= x; x *= x; x *= x;
    x *= x; x *= x; x *= x; x *= x;
    return x;
}

/**
 * Fast approximate tanh
 */
inline float fastTanh(float x)
{
    if (x < -3.0f) return -1.0f;
    if (x > 3.0f) return 1.0f;
    float x2 = x * x;
    return x * (27.0f + x2) / (27.0f + 9.0f * x2);
}

//==============================================================================
// Complex Number Operations (for FFT)
//==============================================================================

struct Complex
{
    float real;
    float imag;

    Complex() : real(0), imag(0) {}
    Complex(float r, float i = 0) : real(r), imag(i) {}

    Complex operator+(Complex other) const
    {
        return Complex(real + other.real, imag + other.imag);
    }

    Complex operator-(Complex other) const
    {
        return Complex(real - other.real, imag - other.imag);
    }

    Complex operator*(Complex other) const
    {
        return Complex(
            real * other.real - imag * other.imag,
            real * other.imag + imag * other.real
        );
    }

    float magnitude() const
    {
        return std::sqrt(real * real + imag * imag);
    }

    float phase() const
    {
        return std::atan2(imag, real);
    }

    Complex conjugate() const
    {
        return Complex(real, -imag);
    }
};

}} // namespace Echoel::SIMD
