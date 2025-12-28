#pragma once

#include <JuceHeader.h>
#include <array>

/**
 * Transient Designer
 *
 * Professional transient shaping for drums and percussive sounds.
 * Inspired by SPL Transient Designer, Waves Trans-X, Native Instruments Transient Master.
 *
 * Features:
 * - Attack enhancement/reduction (-100% to +100%)
 * - Sustain enhancement/reduction (-100% to +100%)
 * - Independent attack/sustain envelopes
 * - Frequency-dependent processing (multiband)
 * - Zero-latency processing (no look-ahead)
 * - Parallel processing option
 * - Clipping protection
 * - Real-time envelope visualization
 *
 * Perfect for:
 * - Making drums punchier or softer
 * - Tightening bass
 * - Removing room ambience
 * - Creative sound design
 */
class TransientDesigner
{
public:
    //==========================================================================
    // Processing Modes
    //==========================================================================

    enum class Mode
    {
        Normal,      // Standard transient shaping
        Multiband,   // Frequency-dependent (3 bands)
        Parallel     // Blend original with processed
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    TransientDesigner();
    ~TransientDesigner() = default;

    //==========================================================================
    // Parameters
    //==========================================================================

    /** Set attack amount (-100 to +100, 0 = no change) */
    void setAttack(float amount);

    /** Set sustain amount (-100 to +100, 0 = no change) */
    void setSustain(float amount);

    /** Set attack speed (1 to 100 ms) */
    void setAttackSpeed(float speedMs);

    /** Set sustain speed (10 to 500 ms) */
    void setSustainSpeed(float speedMs);

    /** Set processing mode */
    void setMode(Mode mode);

    /** Set dry/wet mix (0.0 to 1.0) */
    void setMix(float mixAmount);

    /** Enable clipping protection */
    void setClippingProtection(bool enabled);

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for processing */
    void prepare(double sampleRate, int maxBlockSize);

    /** Reset state */
    void reset();

    /** Process audio buffer */
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Metering
    //==========================================================================

    /** Get attack envelope value (0.0 to 1.0) */
    float getAttackEnvelope(int channel) const;

    /** Get sustain envelope value (0.0 to 1.0) */
    float getSustainEnvelope(int channel) const;

    /** Get output gain reduction in dB */
    float getGainReduction(int channel) const;

private:
    //==========================================================================
    // Parameters
    //==========================================================================

    float attack = 0.0f;           // -100 to +100
    float sustain = 0.0f;          // -100 to +100
    float attackSpeed = 10.0f;     // ms
    float sustainSpeed = 100.0f;   // ms
    Mode mode = Mode::Normal;
    float mix = 1.0f;              // 0-1
    bool clippingProtection = true;

    double currentSampleRate = 48000.0;

    //==========================================================================
    // Pre-allocated Work Buffers (avoid per-frame allocations)
    //==========================================================================
    juce::AudioBuffer<float> dryBuffer;

    //==========================================================================
    // Envelope Followers
    //==========================================================================

    struct EnvelopeState
    {
        // Fast envelope (for attack detection)
        float fastEnvelope = 0.0f;
        float fastAttackCoeff = 0.0f;
        float fastReleaseCoeff = 0.0f;

        // Slow envelope (for sustain detection)
        float slowEnvelope = 0.0f;
        float slowAttackCoeff = 0.0f;
        float slowReleaseCoeff = 0.0f;

        // Transient detection
        float previousLevel = 0.0f;
        float transientGain = 1.0f;
        float sustainGain = 1.0f;

        // Metering
        float attackEnvelopeDisplay = 0.0f;
        float sustainEnvelopeDisplay = 0.0f;
        float gainReduction = 0.0f;
    };

    std::array<EnvelopeState, 2> channelStates;

    //==========================================================================
    // Multiband Processing
    //==========================================================================

    struct MultibandState
    {
        // 3-band crossover (100Hz, 2kHz)
        struct BiquadState
        {
            float x1 = 0.0f, x2 = 0.0f;
            float y1 = 0.0f, y2 = 0.0f;
        };

        std::array<BiquadState, 2> lowpass1;   // 100Hz
        std::array<BiquadState, 2> highpass1;  // 100Hz
        std::array<BiquadState, 2> lowpass2;   // 2kHz
        std::array<BiquadState, 2> highpass2;  // 2kHz
    };

    MultibandState multibandState;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void updateCoefficients();

    void processNormal(float* leftChannel, float* rightChannel, int numSamples);
    void processMultiband(float* leftChannel, float* rightChannel, int numSamples);

    float processTransient(float input, EnvelopeState& state);
    float calculateTransientGain(float inputLevel, float fastEnv, float slowEnv);

    void applyButterworthFilter(float& sample, float frequency, bool isHighpass,
                                 MultibandState::BiquadState& state);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (TransientDesigner)
};
