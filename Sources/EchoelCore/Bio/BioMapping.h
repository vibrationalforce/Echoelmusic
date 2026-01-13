#pragma once
/**
 * EchoelCore - BioMapping
 *
 * Declarative bio→audio parameter mapping system.
 * Maps biometric signals to audio parameters with configurable curves.
 *
 * MIT License - Echoelmusic 2026
 */

#include "BioState.h"
#include <array>
#include <cmath>
#include <functional>

namespace EchoelCore {

//==============================================================================
// Mapping Curve Types
//==============================================================================

enum class MapCurve {
    Linear,        // y = x
    Exponential,   // y = x^2
    Logarithmic,   // y = sqrt(x)
    SCurve,        // Smooth S-curve (sigmoid)
    Sine,          // y = sin(x * pi/2)
    InverseLinear, // y = 1 - x
    Stepped,       // Quantized steps
    Threshold      // Binary on/off
};

//==============================================================================
// Bio Source Types
//==============================================================================

enum class BioSource {
    HRV,              // Heart rate variability (0-1)
    Coherence,        // HRV coherence score (0-1)
    HeartRate,        // Heart rate normalized (0-1)
    HeartRateRaw,     // Heart rate in BPM
    BreathPhase,      // Breathing cycle position (0-1)
    BreathLFO,        // Breath as LFO (-1 to +1)
    BreathRate,       // Breaths per minute
    GSR,              // Galvanic skin response (0-1)
    Temperature,      // Skin temperature
    Arousal,          // Computed arousal score (0-1)
    Relaxation        // Computed relaxation score (0-1)
};

//==============================================================================
// BioMapping - Single mapping definition
//==============================================================================

struct BioMapping {
    BioSource source;     // Which bio signal to use
    uint32_t paramId;     // Target parameter ID
    MapCurve curve;       // Mapping curve type
    float depth;          // Modulation depth (0-1)
    float minValue;       // Minimum output value
    float maxValue;       // Maximum output value
    bool bipolar;         // Center around midpoint vs unipolar

    constexpr BioMapping(
        BioSource src,
        uint32_t param,
        MapCurve crv = MapCurve::Linear,
        float d = 0.5f,
        float minVal = 0.0f,
        float maxVal = 1.0f,
        bool bi = false
    ) noexcept
        : source(src)
        , paramId(param)
        , curve(crv)
        , depth(d)
        , minValue(minVal)
        , maxValue(maxVal)
        , bipolar(bi)
    {}
};

//==============================================================================
// BioMapper - Maps bio state to parameters
//==============================================================================

class BioMapper {
public:
    static constexpr size_t kMaxMappings = 32;

    BioMapper() noexcept : mNumMappings(0) {}

    /**
     * Add a mapping.
     */
    void addMapping(const BioMapping& mapping) noexcept {
        if (mNumMappings < kMaxMappings) {
            mMappings[mNumMappings++] = mapping;
        }
    }

    /**
     * Clear all mappings.
     */
    void clearMappings() noexcept {
        mNumMappings = 0;
    }

    /**
     * Get the number of active mappings.
     */
    size_t getNumMappings() const noexcept {
        return mNumMappings;
    }

    /**
     * Compute modulated value for a parameter.
     * Call from audio thread.
     *
     * @param paramId The parameter ID to compute
     * @param baseValue The parameter's base (unmodulated) value
     * @param bio The current bio state
     * @return The modulated parameter value
     */
    float computeModulatedValue(
        uint32_t paramId,
        float baseValue,
        const BioState& bio
    ) const noexcept {
        float modulation = 0.0f;
        bool found = false;

        for (size_t i = 0; i < mNumMappings; ++i) {
            const auto& mapping = mMappings[i];
            if (mapping.paramId == paramId) {
                float bioValue = getBioValue(bio, mapping.source);
                float curvedValue = applyCurve(bioValue, mapping.curve);
                float scaledValue = mapping.minValue +
                    curvedValue * (mapping.maxValue - mapping.minValue);

                if (mapping.bipolar) {
                    modulation += (scaledValue - 0.5f) * 2.0f * mapping.depth;
                } else {
                    modulation += scaledValue * mapping.depth;
                }
                found = true;
            }
        }

        if (!found) {
            return baseValue;
        }

        return baseValue + modulation * (1.0f - baseValue);
    }

    /**
     * Get all modulation values at once.
     * More efficient than computing individually.
     *
     * @param bio The current bio state
     * @param outValues Array to fill with modulation values (indexed by paramId)
     * @param maxParams Maximum parameter ID + 1
     */
    void computeAllModulations(
        const BioState& bio,
        float* outValues,
        size_t maxParams
    ) const noexcept {
        // Initialize to zero
        for (size_t i = 0; i < maxParams; ++i) {
            outValues[i] = 0.0f;
        }

        // Accumulate modulations
        for (size_t i = 0; i < mNumMappings; ++i) {
            const auto& mapping = mMappings[i];
            if (mapping.paramId >= maxParams) continue;

            float bioValue = getBioValue(bio, mapping.source);
            float curvedValue = applyCurve(bioValue, mapping.curve);
            float scaledValue = mapping.minValue +
                curvedValue * (mapping.maxValue - mapping.minValue);

            if (mapping.bipolar) {
                outValues[mapping.paramId] += (scaledValue - 0.5f) * 2.0f * mapping.depth;
            } else {
                outValues[mapping.paramId] += scaledValue * mapping.depth;
            }
        }
    }

private:
    std::array<BioMapping, kMaxMappings> mMappings;
    size_t mNumMappings;

    /**
     * Get bio value from state.
     */
    static float getBioValue(const BioState& bio, BioSource source) noexcept {
        switch (source) {
            case BioSource::HRV:           return bio.getHRV();
            case BioSource::Coherence:     return bio.getCoherence();
            case BioSource::HeartRate:     return bio.getHeartRateNormalized();
            case BioSource::HeartRateRaw:  return bio.getHeartRate() / 200.0f;
            case BioSource::BreathPhase:   return bio.getBreathPhase();
            case BioSource::BreathLFO:     return (bio.getBreathLFO() + 1.0f) * 0.5f;
            case BioSource::BreathRate:    return bio.getBreathRate() / 30.0f;
            case BioSource::GSR:           return bio.getGSR();
            case BioSource::Temperature:   return (bio.getTemperature() - 35.0f) / 5.0f;
            case BioSource::Arousal:       return bio.getArousal();
            case BioSource::Relaxation:    return bio.getRelaxation();
            default:                       return 0.5f;
        }
    }

    /**
     * Apply mapping curve.
     */
    static float applyCurve(float x, MapCurve curve) noexcept {
        x = std::clamp(x, 0.0f, 1.0f);

        switch (curve) {
            case MapCurve::Linear:
                return x;

            case MapCurve::Exponential:
                return x * x;

            case MapCurve::Logarithmic:
                return std::sqrt(x);

            case MapCurve::SCurve:
                // Smooth S-curve using smoothstep
                return x * x * (3.0f - 2.0f * x);

            case MapCurve::Sine:
                return std::sin(x * 1.5707963267948966f); // pi/2

            case MapCurve::InverseLinear:
                return 1.0f - x;

            case MapCurve::Stepped:
                // 8 discrete steps
                return std::floor(x * 8.0f) / 7.0f;

            case MapCurve::Threshold:
                return x > 0.5f ? 1.0f : 0.0f;

            default:
                return x;
        }
    }
};

//==============================================================================
// Preset Mapping Configurations
//==============================================================================

namespace Presets {

/**
 * Meditation preset - smooth, calming modulations
 */
inline void loadMeditationMappings(BioMapper& mapper) {
    mapper.clearMappings();
    mapper.addMapping({BioSource::Coherence, 0, MapCurve::SCurve, 0.5f});    // Reverb
    mapper.addMapping({BioSource::BreathLFO, 1, MapCurve::Sine, 0.3f, 0.0f, 1.0f, true}); // Filter
    mapper.addMapping({BioSource::HRV, 2, MapCurve::Logarithmic, 0.4f});     // Warmth
    mapper.addMapping({BioSource::Relaxation, 3, MapCurve::Linear, 0.6f});   // Spaciousness
}

/**
 * Energetic preset - responsive, dynamic modulations
 */
inline void loadEnergeticMappings(BioMapper& mapper) {
    mapper.clearMappings();
    mapper.addMapping({BioSource::HeartRate, 0, MapCurve::Exponential, 0.7f}); // Tempo sync
    mapper.addMapping({BioSource::Arousal, 1, MapCurve::Linear, 0.5f});        // Intensity
    mapper.addMapping({BioSource::GSR, 2, MapCurve::SCurve, 0.4f});            // Drive
    mapper.addMapping({BioSource::BreathPhase, 3, MapCurve::Sine, 0.3f, 0.0f, 1.0f, true}); // Movement
}

/**
 * Performance preset - subtle, professional modulations
 */
inline void loadPerformanceMappings(BioMapper& mapper) {
    mapper.clearMappings();
    mapper.addMapping({BioSource::Coherence, 0, MapCurve::Threshold, 0.2f});  // Gate
    mapper.addMapping({BioSource::HRV, 1, MapCurve::Linear, 0.15f});          // Subtle filter
    mapper.addMapping({BioSource::HeartRate, 2, MapCurve::Stepped, 0.1f});    // Quantized LFO
}

} // namespace Presets

} // namespace EchoelCore
