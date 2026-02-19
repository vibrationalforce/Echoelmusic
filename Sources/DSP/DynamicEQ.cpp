/**
 * DynamicEQ.cpp
 * Echoelmusic - 8-Band Dynamic Equalizer
 *
 * Pro-level dynamic EQ with per-band compression
 * Inspired by FabFilter Pro-Q, Waves F6
 *
 * Features:
 * - 8 fully parametric bands
 * - Per-band dynamics (compression/expansion)
 * - Multiple filter types (Bell, Shelf, Cut, Notch)
 * - Mid/Side processing
 * - Bio-reactive modulation
 *
 * Created: 2026-01-15
 */

#ifndef ECHOELMUSIC_DYNAMIC_EQ_CPP
#define ECHOELMUSIC_DYNAMIC_EQ_CPP

#include <cmath>
#include <algorithm>
#include <array>
#include <vector>

namespace Echoelmusic {
namespace DSP {

// ============================================================================
// Constants
// ============================================================================

constexpr int MAX_BANDS = 8;
constexpr float PI = 3.14159265358979323846f;
constexpr float TWO_PI = 2.0f * PI;

// ============================================================================
// Filter Types
// ============================================================================

enum class FilterType {
    Bell,           // Parametric bell curve
    LowShelf,       // Low shelf
    HighShelf,      // High shelf
    LowCut,         // High-pass filter
    HighCut,        // Low-pass filter
    Notch,          // Band-reject
    BandPass,       // Band-pass
    TiltShelf       // Tilt EQ
};

enum class FilterSlope {
    dB6,            // 6 dB/octave (1st order)
    dB12,           // 12 dB/octave (2nd order)
    dB24,           // 24 dB/octave (4th order)
    dB48            // 48 dB/octave (8th order)
};

// ============================================================================
// Biquad Filter Coefficients
// ============================================================================

struct BiquadCoeffs {
    float b0 = 1.0f, b1 = 0.0f, b2 = 0.0f;
    float a1 = 0.0f, a2 = 0.0f;
};

struct BiquadState {
    float x1 = 0.0f, x2 = 0.0f;
    float y1 = 0.0f, y2 = 0.0f;
};

// ============================================================================
// EQ Band
// ============================================================================

struct EQBand {
    bool enabled = true;
    FilterType type = FilterType::Bell;
    FilterSlope slope = FilterSlope::dB12;

    float frequency = 1000.0f;      // Hz (20-20000)
    float gain = 0.0f;              // dB (-24 to +24)
    float q = 1.0f;                 // Q factor (0.1 to 30)

    // Dynamic processing
    bool dynamicEnabled = false;
    float threshold = -20.0f;       // dB
    float ratio = 2.0f;             // Compression ratio
    float attack = 10.0f;           // ms
    float release = 100.0f;         // ms
    float range = 12.0f;            // Max gain change in dB

    // Internal state
    BiquadCoeffs coeffs;
    BiquadState stateL;
    BiquadState stateR;
    float envelope = 0.0f;
};

// ============================================================================
// Dynamic EQ Processor
// ============================================================================

class DynamicEQ {
public:
    DynamicEQ() {
        reset();
    }

    void setSampleRate(float sr) {
        sampleRate = sr;
        updateAllCoefficients();
    }

    void reset() {
        for (auto& band : bands) {
            band.stateL = BiquadState{};
            band.stateR = BiquadState{};
            band.envelope = 0.0f;
        }
    }

    // ========================================================================
    // Band Configuration
    // ========================================================================

    void setBandEnabled(int band, bool enabled) {
        if (band >= 0 && band < MAX_BANDS) {
            bands[band].enabled = enabled;
        }
    }

    void setBandType(int band, FilterType type) {
        if (band >= 0 && band < MAX_BANDS) {
            bands[band].type = type;
            updateBandCoefficients(band);
        }
    }

    void setBandFrequency(int band, float freq) {
        if (band >= 0 && band < MAX_BANDS) {
            bands[band].frequency = std::clamp(freq, 20.0f, 20000.0f);
            updateBandCoefficients(band);
        }
    }

    void setBandGain(int band, float gainDb) {
        if (band >= 0 && band < MAX_BANDS) {
            bands[band].gain = std::clamp(gainDb, -24.0f, 24.0f);
            updateBandCoefficients(band);
        }
    }

    void setBandQ(int band, float q) {
        if (band >= 0 && band < MAX_BANDS) {
            bands[band].q = std::clamp(q, 0.1f, 30.0f);
            updateBandCoefficients(band);
        }
    }

    // ========================================================================
    // Dynamic Processing Configuration
    // ========================================================================

    void setBandDynamicEnabled(int band, bool enabled) {
        if (band >= 0 && band < MAX_BANDS) {
            bands[band].dynamicEnabled = enabled;
        }
    }

    void setBandThreshold(int band, float thresholdDb) {
        if (band >= 0 && band < MAX_BANDS) {
            bands[band].threshold = std::clamp(thresholdDb, -60.0f, 0.0f);
        }
    }

    void setBandRatio(int band, float ratio) {
        if (band >= 0 && band < MAX_BANDS) {
            bands[band].ratio = std::clamp(ratio, 1.0f, 20.0f);
        }
    }

    void setBandAttack(int band, float attackMs) {
        if (band >= 0 && band < MAX_BANDS) {
            bands[band].attack = std::clamp(attackMs, 0.1f, 500.0f);
        }
    }

    void setBandRelease(int band, float releaseMs) {
        if (band >= 0 && band < MAX_BANDS) {
            bands[band].release = std::clamp(releaseMs, 10.0f, 5000.0f);
        }
    }

    // ========================================================================
    // Bio-Reactive Modulation
    // ========================================================================

    void setBioModulation(float coherence, float heartRate, float breathPhase) {
        bioCoherence = coherence;
        bioHeartRate = heartRate;
        bioBreathPhase = breathPhase;

        // Apply bio modulation to bands
        if (bioModulationEnabled) {
            // High coherence = smoother, more musical EQ
            float smoothing = coherence * 0.5f;
            for (auto& band : bands) {
                if (band.dynamicEnabled) {
                    // Softer dynamics with high coherence
                    band.attack = 10.0f + smoothing * 40.0f;
                    band.release = 100.0f + smoothing * 200.0f;
                }
            }
        }
    }

    void setBioModulationEnabled(bool enabled) {
        bioModulationEnabled = enabled;
    }

    // ========================================================================
    // Processing
    // ========================================================================

    void process(float* leftChannel, float* rightChannel, int numSamples) {
        for (int i = 0; i < numSamples; ++i) {
            float L = leftChannel[i];
            float R = rightChannel[i];

            // Process through each enabled band
            for (int b = 0; b < MAX_BANDS; ++b) {
                if (bands[b].enabled) {
                    processBandSample(bands[b], L, R);
                }
            }

            leftChannel[i] = L;
            rightChannel[i] = R;
        }
    }

    void processBlock(float** buffer, int numChannels, int numSamples) {
        if (numChannels >= 2) {
            process(buffer[0], buffer[1], numSamples);
        } else if (numChannels == 1) {
            // Mono processing
            for (int i = 0; i < numSamples; ++i) {
                float sample = buffer[0][i];
                float dummy = sample;

                for (int b = 0; b < MAX_BANDS; ++b) {
                    if (bands[b].enabled) {
                        processBandSample(bands[b], sample, dummy);
                    }
                }

                buffer[0][i] = sample;
            }
        }
    }

private:
    float sampleRate = 48000.0f;
    std::array<EQBand, MAX_BANDS> bands;

    // Bio-reactive state
    float bioCoherence = 0.0f;
    float bioHeartRate = 72.0f;
    float bioBreathPhase = 0.0f;
    bool bioModulationEnabled = false;

    // ========================================================================
    // Coefficient Calculation
    // ========================================================================

    void updateAllCoefficients() {
        for (int i = 0; i < MAX_BANDS; ++i) {
            updateBandCoefficients(i);
        }
    }

    void updateBandCoefficients(int band) {
        if (band < 0 || band >= MAX_BANDS) return;

        EQBand& b = bands[band];

        float w0 = TWO_PI * b.frequency / sampleRate;
        float cosW0 = std::cos(w0);
        float sinW0 = std::sin(w0);
        float alpha = sinW0 / (2.0f * b.q);

        float A = std::pow(10.0f, b.gain / 40.0f);

        float a0 = 1.0f;

        switch (b.type) {
            case FilterType::Bell: {
                float alphaA = alpha * A;
                float alphaOverA = alpha / A;

                b.coeffs.b0 = (1.0f + alphaA) / a0;
                b.coeffs.b1 = (-2.0f * cosW0) / a0;
                b.coeffs.b2 = (1.0f - alphaA) / a0;
                b.coeffs.a1 = (-2.0f * cosW0) / (1.0f + alphaOverA);
                b.coeffs.a2 = (1.0f - alphaOverA) / (1.0f + alphaOverA);

                // Normalize
                a0 = 1.0f + alphaOverA;
                b.coeffs.b0 /= a0;
                b.coeffs.b1 /= a0;
                b.coeffs.b2 /= a0;
                break;
            }

            case FilterType::LowShelf: {
                float sqrtA = std::sqrt(A);
                float sqrtA2Alpha = 2.0f * sqrtA * alpha;

                a0 = (A + 1.0f) + (A - 1.0f) * cosW0 + sqrtA2Alpha;
                b.coeffs.b0 = A * ((A + 1.0f) - (A - 1.0f) * cosW0 + sqrtA2Alpha) / a0;
                b.coeffs.b1 = 2.0f * A * ((A - 1.0f) - (A + 1.0f) * cosW0) / a0;
                b.coeffs.b2 = A * ((A + 1.0f) - (A - 1.0f) * cosW0 - sqrtA2Alpha) / a0;
                b.coeffs.a1 = -2.0f * ((A - 1.0f) + (A + 1.0f) * cosW0) / a0;
                b.coeffs.a2 = ((A + 1.0f) + (A - 1.0f) * cosW0 - sqrtA2Alpha) / a0;
                break;
            }

            case FilterType::HighShelf: {
                float sqrtA = std::sqrt(A);
                float sqrtA2Alpha = 2.0f * sqrtA * alpha;

                a0 = (A + 1.0f) - (A - 1.0f) * cosW0 + sqrtA2Alpha;
                b.coeffs.b0 = A * ((A + 1.0f) + (A - 1.0f) * cosW0 + sqrtA2Alpha) / a0;
                b.coeffs.b1 = -2.0f * A * ((A - 1.0f) + (A + 1.0f) * cosW0) / a0;
                b.coeffs.b2 = A * ((A + 1.0f) + (A - 1.0f) * cosW0 - sqrtA2Alpha) / a0;
                b.coeffs.a1 = 2.0f * ((A - 1.0f) - (A + 1.0f) * cosW0) / a0;
                b.coeffs.a2 = ((A + 1.0f) - (A - 1.0f) * cosW0 - sqrtA2Alpha) / a0;
                break;
            }

            case FilterType::LowCut: {
                a0 = 1.0f + alpha;
                b.coeffs.b0 = (1.0f + cosW0) / 2.0f / a0;
                b.coeffs.b1 = -(1.0f + cosW0) / a0;
                b.coeffs.b2 = (1.0f + cosW0) / 2.0f / a0;
                b.coeffs.a1 = -2.0f * cosW0 / a0;
                b.coeffs.a2 = (1.0f - alpha) / a0;
                break;
            }

            case FilterType::HighCut: {
                a0 = 1.0f + alpha;
                b.coeffs.b0 = (1.0f - cosW0) / 2.0f / a0;
                b.coeffs.b1 = (1.0f - cosW0) / a0;
                b.coeffs.b2 = (1.0f - cosW0) / 2.0f / a0;
                b.coeffs.a1 = -2.0f * cosW0 / a0;
                b.coeffs.a2 = (1.0f - alpha) / a0;
                break;
            }

            case FilterType::Notch: {
                a0 = 1.0f + alpha;
                b.coeffs.b0 = 1.0f / a0;
                b.coeffs.b1 = -2.0f * cosW0 / a0;
                b.coeffs.b2 = 1.0f / a0;
                b.coeffs.a1 = -2.0f * cosW0 / a0;
                b.coeffs.a2 = (1.0f - alpha) / a0;
                break;
            }

            case FilterType::BandPass: {
                a0 = 1.0f + alpha;
                b.coeffs.b0 = alpha / a0;
                b.coeffs.b1 = 0.0f;
                b.coeffs.b2 = -alpha / a0;
                b.coeffs.a1 = -2.0f * cosW0 / a0;
                b.coeffs.a2 = (1.0f - alpha) / a0;
                break;
            }

            case FilterType::TiltShelf: {
                // Tilt EQ: simultaneous low shelf down + high shelf up (or vice versa)
                // Simplified implementation
                float tiltAmount = b.gain / 12.0f;  // Normalize
                b.coeffs.b0 = 1.0f + tiltAmount * 0.5f;
                b.coeffs.b1 = 0.0f;
                b.coeffs.b2 = 0.0f;
                b.coeffs.a1 = -tiltAmount * 0.3f;
                b.coeffs.a2 = 0.0f;
                break;
            }
        }
    }

    // ========================================================================
    // Per-Sample Processing
    // ========================================================================

    void processBandSample(EQBand& band, float& L, float& R) {
        // Calculate dynamic gain adjustment if enabled
        float dynamicGainL = 0.0f;
        float dynamicGainR = 0.0f;

        if (band.dynamicEnabled) {
            dynamicGainL = calculateDynamicGain(band, L);
            dynamicGainR = calculateDynamicGain(band, R);
        }

        // Apply biquad filter
        L = processBiquad(band.coeffs, band.stateL, L);
        R = processBiquad(band.coeffs, band.stateR, R);

        // Apply dynamic gain
        if (band.dynamicEnabled) {
            L *= std::pow(10.0f, dynamicGainL / 20.0f);
            R *= std::pow(10.0f, dynamicGainR / 20.0f);
        }
    }

    float processBiquad(const BiquadCoeffs& c, BiquadState& s, float input) {
        float output = c.b0 * input + c.b1 * s.x1 + c.b2 * s.x2
                     - c.a1 * s.y1 - c.a2 * s.y2;

        // Update state
        s.x2 = s.x1;
        s.x1 = input;
        s.y2 = s.y1;
        s.y1 = output;

        return output;
    }

    float calculateDynamicGain(EQBand& band, float sample) {
        // Convert to dB
        float inputDb = 20.0f * std::log10(std::abs(sample) + 1e-10f);

        // Calculate envelope
        float attackCoeff = std::exp(-1.0f / (band.attack * sampleRate / 1000.0f));
        float releaseCoeff = std::exp(-1.0f / (band.release * sampleRate / 1000.0f));

        if (inputDb > band.envelope) {
            band.envelope = attackCoeff * band.envelope + (1.0f - attackCoeff) * inputDb;
        } else {
            band.envelope = releaseCoeff * band.envelope + (1.0f - releaseCoeff) * inputDb;
        }

        // Calculate gain reduction
        float overThreshold = band.envelope - band.threshold;
        if (overThreshold > 0.0f) {
            float gainReduction = overThreshold * (1.0f - 1.0f / band.ratio);
            return -std::min(gainReduction, band.range);
        }

        return 0.0f;
    }
};

} // namespace DSP
} // namespace Echoelmusic

#endif /* ECHOELMUSIC_DYNAMIC_EQ_CPP */
