#pragma once

#include <JuceHeader.h>
#include "../Core/DSPOptimizations.h"

/**
 * Bio-Reactive DSP Module
 *
 * Processes audio with parameters modulated by bio-data (HRV, Coherence).
 * Implements professional-grade audio effects that respond to user's physiological state.
 */
class BioReactiveDSP
{
public:
    BioReactiveDSP();
    ~BioReactiveDSP();

    //==============================================================================
    // DSP Lifecycle
    void prepare(const juce::dsp::ProcessSpec& spec);
    void reset();
    void process(juce::AudioBuffer<float>& buffer, float hrv, float coherence);

    //==============================================================================
    // Parameter Control
    void setFilterCutoff(float cutoffHz);
    void setResonance(float resonance);
    void setReverbMix(float mix);
    void setDelayTime(float timeMs);
    void setDistortion(float amount);
    void setCompression(float ratio);

private:
    //==============================================================================
    // Denormal Protection Constant (prevents CPU performance issues)
    static constexpr float kDenormalThreshold = 1.0e-15f;

    // Flush denormals to zero for optimal CPU performance
    static inline float flushDenormals(float value)
    {
        return (std::abs(value) < kDenormalThreshold) ? 0.0f : value;
    }

    //==============================================================================
    // Filter (State Variable Filter)
    struct StateVariableFilter
    {
        float cutoff = 1000.0f;
        float resonance = 0.5f;
        float sampleRate = 44100.0f;

        // Filter state
        float lowpass = 0.0f;
        float bandpass = 0.0f;
        float highpass = 0.0f;

        void setSampleRate(float sr) { sampleRate = sr; }

        float process(float input)
        {
            // Using fast sin for filter coefficient
            const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
            float f = 2.0f * trigTables.fastSinRad(juce::MathConstants<float>::pi * cutoff / sampleRate);
            float q = 1.0f - resonance;

            lowpass += f * bandpass;
            highpass = input - lowpass - q * bandpass;
            bandpass += f * highpass;

            // CRITICAL: Flush denormals to prevent CPU performance degradation
            // Denormal numbers (< 1e-38) cause massive slowdowns in FPU
            lowpass = BioReactiveDSP::flushDenormals(lowpass);
            bandpass = BioReactiveDSP::flushDenormals(bandpass);
            highpass = BioReactiveDSP::flushDenormals(highpass);

            return lowpass; // Return lowpass output
        }
    };

    StateVariableFilter filterL, filterR;

    //==============================================================================
    // Reverb
    juce::dsp::Reverb reverb;
    juce::dsp::Reverb::Parameters reverbParams;
    float reverbMix = 0.3f;

    //==============================================================================
    // Delay
    juce::dsp::DelayLine<float, juce::dsp::DelayLineInterpolationTypes::Linear> delayLine;
    float delayTime = 500.0f;
    float maxDelayTime = 2000.0f;

    //==============================================================================
    // Distortion (Soft Clipping)
    float distortionAmount = 0.0f;

    float softClip(float sample)
    {
        if (distortionAmount < 0.01f)
            return sample;

        float threshold = 1.0f - distortionAmount;
        float invThreshold = 1.0f / (1.0f - threshold + 1e-6f);
        if (sample > threshold) {
            float excess = (sample - threshold) * invThreshold;
            return threshold + (sample - threshold) / (1.0f + excess * excess);
        }
        else if (sample < -threshold) {
            float excess = (sample + threshold) * invThreshold;
            return -threshold + (sample + threshold) / (1.0f + excess * excess);
        }
        else
            return sample;
    }

    //==============================================================================
    // Compression (Simple)
    struct SimpleCompressor
    {
        float ratio = 4.0f;
        float threshold = -20.0f; // dB
        float attack = 0.01f;  // seconds
        float release = 0.1f;  // seconds
        float envelope = 0.0f;
        float sampleRate = 44100.0f;

        void setSampleRate(float sr) { sampleRate = sr; }

        float process(float input)
        {
            // Using fast dB conversion
            float inputLevel = Echoel::DSP::FastMath::gainToDb(std::abs(input) + 1e-10f);

            // Envelope follower - using fast exp
            float targetEnvelope = inputLevel;
            float coeff = (targetEnvelope > envelope) ?
                          Echoel::DSP::FastMath::fastExp(-1.0f / (attack * sampleRate)) :
                          Echoel::DSP::FastMath::fastExp(-1.0f / (release * sampleRate));

            envelope = coeff * envelope + (1.0f - coeff) * targetEnvelope;

            // Gain reduction
            float gainReduction = 0.0f;
            if (envelope > threshold)
            {
                float excess = envelope - threshold;
                gainReduction = excess * (1.0f - 1.0f / ratio);
            }

            // Apply gain reduction - using fast dB to gain
            float outputGain = Echoel::DSP::FastMath::dbToGain(-gainReduction);
            return input * outputGain;
        }
    };

    SimpleCompressor compressorL, compressorR;

    //==============================================================================
    // Sample Rate
    double currentSampleRate = 44100.0;

    //==============================================================================
    // Pre-allocated reverb buffer (OPTIMIZATION: prevents 96MB/sec allocation)
    juce::AudioBuffer<float> reverbBuffer;
    int preparedBlockSize = 0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (BioReactiveDSP)
};
