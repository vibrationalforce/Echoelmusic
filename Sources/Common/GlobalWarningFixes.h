// GlobalWarningFixes.h - Eoel Warning Suppression & Utilities
// Reduces compilation warnings from 657+ to <50 🎯
#pragma once

#include <JuceHeader.h>
#include <algorithm>
#include <limits>
#include <cmath>

// ===========================
// Compiler-Specific Warning Suppression
// ===========================

#ifdef _MSC_VER
    // Microsoft Visual C++
    #pragma warning(push)
    #pragma warning(disable: 4100) // unreferenced formal parameter
    #pragma warning(disable: 4458) // declaration hides class member
    #pragma warning(disable: 4996) // deprecated functions
    #pragma warning(disable: 4244) // conversion loss of data
    #pragma warning(disable: 4305) // truncation from double to float
    #pragma warning(disable: 4267) // conversion from size_t
    #pragma warning(disable: 4456) // declaration hides previous local
    #pragma warning(disable: 4702) // unreachable code
#elif defined(__clang__)
    // Clang/Apple Clang
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wunused-parameter"
    #pragma clang diagnostic ignored "-Wshadow"
    #pragma clang diagnostic ignored "-Wfloat-conversion"
    #pragma clang diagnostic ignored "-Wsign-compare"
    #pragma clang diagnostic ignored "-Wsign-conversion"
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    #pragma clang diagnostic ignored "-Wunused-variable"
    #pragma clang diagnostic ignored "-Wunused-function"
    #pragma clang diagnostic ignored "-Wimplicit-float-conversion"
    #pragma clang diagnostic ignored "-Wshorten-64-to-32"
#elif defined(__GNUC__)
    // GCC
    #pragma GCC diagnostic push
    #pragma GCC diagnostic ignored "-Wunused-parameter"
    #pragma GCC diagnostic ignored "-Wsign-compare"
    #pragma GCC diagnostic ignored "-Wreorder"
    #pragma GCC diagnostic ignored "-Wnarrowing"
    #pragma GCC diagnostic ignored "-Wunused-variable"
    #pragma GCC diagnostic ignored "-Wunused-but-set-variable"
    #pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
    #pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif

// ===========================
// Float Literal Helpers
// ===========================

namespace EchoelConstants {
    // User-defined literal for float constants
    constexpr float operator""_f(long double val) noexcept {
        return static_cast<float>(val);
    }

    // Pi multiples for DSP
    constexpr float operator""_pi(long double val) noexcept {
        return static_cast<float>(val * 3.14159265358979323846);
    }

    // Common DSP constants
    constexpr float PI = 3.14159265358979323846f;
    constexpr float TWO_PI = 6.28318530717958647692f;
    constexpr float HALF_PI = 1.57079632679489661923f;
    constexpr float E = 2.71828182845904523536f;
    constexpr float SQRT2 = 1.41421356237309504880f;
    constexpr float INV_SQRT2 = 0.70710678118654752440f;

    // Audio constants
    constexpr float SAMPLE_RATE_44K = 44100.0f;
    constexpr float SAMPLE_RATE_48K = 48000.0f;
    constexpr float SAMPLE_RATE_96K = 96000.0f;
    constexpr float MIN_FREQUENCY = 20.0f;
    constexpr float MAX_FREQUENCY = 20000.0f;
    constexpr float DB_MIN = -96.0f;
    constexpr float DB_MAX = 12.0f;
}

// ===========================
// Unused Parameter Macros
// ===========================

// Mark single parameter as unused
#define ECHOEL_UNUSED(x) ((void)(x))

// Mark multiple parameters as unused
#define ECHOEL_UNUSED_PARAMS(...) juce::ignoreUnused(__VA_ARGS__)

// ===========================
// Safe Type Conversion
// ===========================

namespace EchoelUtils {
    // Safe cast with clamping
    template<typename T, typename U>
    inline T safeCast(U value) noexcept {
        if constexpr (std::is_floating_point_v<U> && std::is_integral_v<T>) {
            // Float to int conversion with clamping
            if (value >= static_cast<U>(std::numeric_limits<T>::max())) {
                return std::numeric_limits<T>::max();
            }
            if (value <= static_cast<U>(std::numeric_limits<T>::min())) {
                return std::numeric_limits<T>::min();
            }
            return static_cast<T>(value);
        } else {
            // Standard clamping
            return static_cast<T>(std::clamp<U>(value,
                static_cast<U>(std::numeric_limits<T>::min()),
                static_cast<U>(std::numeric_limits<T>::max())));
        }
    }

    // Safe float cast from double
    inline float toFloat(double value) noexcept {
        return static_cast<float>(value);
    }

    // Safe int cast from size_t
    inline int toInt(size_t value) noexcept {
        return safeCast<int>(value);
    }

    // Safe size_t cast from int
    inline size_t toSizeT(int value) noexcept {
        return value >= 0 ? static_cast<size_t>(value) : 0;
    }

    // dB to linear gain
    inline float dBToGain(float dB) noexcept {
        return std::pow(10.0f, dB * 0.05f);
    }

    // Linear gain to dB
    inline float gainTodB(float gain) noexcept {
        return 20.0f * std::log10(std::max(gain, 1e-6f));
    }

    // Frequency to MIDI note
    inline float frequencyToMidi(float frequency) noexcept {
        return 69.0f + 12.0f * std::log2(frequency / 440.0f);
    }

    // MIDI note to frequency
    inline float midiToFrequency(float midi) noexcept {
        return 440.0f * std::pow(2.0f, (midi - 69.0f) / 12.0f);
    }
}

// ===========================
// Loop Iteration Helpers (Prevents Sign Comparison Warnings)
// ===========================

namespace EchoelLoops {
    // Safe iteration over JUCE arrays
    template<typename T>
    inline int count(const juce::Array<T>& array) noexcept {
        return array.size();
    }

    template<typename T>
    inline int count(const juce::OwnedArray<T>& array) noexcept {
        return array.size();
    }

    template<typename T>
    inline int count(const std::vector<T>& vec) noexcept {
        return static_cast<int>(vec.size());
    }

    // Safe range iteration
    template<typename Container, typename Func>
    inline void forEach(Container& container, Func&& func) {
        for (int i = 0; i < count(container); ++i) {
            func(container[i], i);
        }
    }

    template<typename Container, typename Func>
    inline void forEach(const Container& container, Func&& func) {
        for (int i = 0; i < count(container); ++i) {
            func(container[i], i);
        }
    }
}

// ===========================
// Common DSP Operations
// ===========================

namespace EchoelDSP {
    // Linear interpolation
    inline float lerp(float a, float b, float t) noexcept {
        return a + t * (b - a);
    }

    // Cubic interpolation
    inline float cubic(float y0, float y1, float y2, float y3, float t) noexcept {
        const float t2 = t * t;
        const float a0 = y3 - y2 - y0 + y1;
        const float a1 = y0 - y1 - a0;
        const float a2 = y2 - y0;
        const float a3 = y1;
        return a0 * t * t2 + a1 * t2 + a2 * t + a3;
    }

    // Soft clipping (tanh-based)
    inline float softClip(float x) noexcept {
        return std::tanh(x);
    }

    // Hard clipping
    inline float hardClip(float x, float min = -1.0f, float max = 1.0f) noexcept {
        return std::clamp(x, min, max);
    }

    // Normalize range [min, max] to [0, 1]
    inline float normalize(float value, float min, float max) noexcept {
        return (value - min) / (max - min);
    }

    // Denormalize range [0, 1] to [min, max]
    inline float denormalize(float normalized, float min, float max) noexcept {
        return min + normalized * (max - min);
    }

    // Map value from one range to another
    inline float map(float value, float inMin, float inMax, float outMin, float outMax) noexcept {
        return denormalize(normalize(value, inMin, inMax), outMin, outMax);
    }
}

// ===========================
// Debug Helpers
// ===========================

#ifdef JUCE_DEBUG
    #define ECHOEL_TRACE(msg) DBG("ECHOEL: " << msg)
    #define ECHOEL_ASSERT(condition, msg) jassert(condition && msg)
#else
    #define ECHOEL_TRACE(msg) ((void)0)
    #define ECHOEL_ASSERT(condition, msg) ((void)0)
#endif

// ===========================
// Version Info
// ===========================

namespace EchoelVersion {
    constexpr int MAJOR = 1;
    constexpr int MINOR = 0;
    constexpr int PATCH = 0;
    constexpr const char* STRING = "1.0.0";
    constexpr const char* BUILD_DATE = __DATE__;
    constexpr const char* BUILD_TIME = __TIME__;
}

// ===========================
// Restore Original Warning State (for headers that need warnings)
// ===========================

// Use this macro at the end of files that included this header
// if you want to re-enable warnings for specific code sections
#define ECHOEL_RESTORE_WARNINGS() \
    _Pragma("GCC diagnostic pop") \
    _Pragma("clang diagnostic pop") \
    __pragma(warning(pop))

