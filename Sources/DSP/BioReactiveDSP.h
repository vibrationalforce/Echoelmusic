#pragma once

#include <JuceHeader.h>

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
            float f = 2.0f * std::sin(juce::MathConstants<float>::pi * cutoff / sampleRate);
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

        // Block processing version (faster - reduces function call overhead)
        void processBlock(float* buffer, int numSamples)
        {
            // Cache coefficients (constant for entire block)
            const float f = 2.0f * std::sin(juce::MathConstants<float>::pi * cutoff / sampleRate);
            const float q = 1.0f - resonance;

            for (int i = 0; i < numSamples; ++i)
            {
                lowpass += f * bandpass;
                highpass = buffer[i] - lowpass - q * bandpass;
                bandpass += f * highpass;

                // Flush denormals every 8 samples (reduces overhead)
                if ((i & 7) == 7)
                {
                    lowpass = BioReactiveDSP::flushDenormals(lowpass);
                    bandpass = BioReactiveDSP::flushDenormals(bandpass);
                    highpass = BioReactiveDSP::flushDenormals(highpass);
                }

                buffer[i] = lowpass;
            }

            // Final denormal flush
            lowpass = BioReactiveDSP::flushDenormals(lowpass);
            bandpass = BioReactiveDSP::flushDenormals(bandpass);
            highpass = BioReactiveDSP::flushDenormals(highpass);
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
        if (sample > threshold)
            return threshold + (sample - threshold) / (1.0f + std::pow((sample - threshold) / (1.0f - threshold), 2.0f));
        else if (sample < -threshold)
            return -threshold + (sample + threshold) / (1.0f + std::pow((sample + threshold) / (1.0f - threshold), 2.0f));
        else
            return sample;
    }

    // Block processing version (SIMD-friendly for distortion amount >= 0.01)
    void softClipBlock(float* buffer, int numSamples)
    {
        if (distortionAmount < 0.01f)
            return; // No processing needed

        const float threshold = 1.0f - distortionAmount;
        const float oneMinusThreshold = 1.0f - threshold;

        for (int i = 0; i < numSamples; ++i)
        {
            float sample = buffer[i];

            if (sample > threshold)
            {
                float excess = sample - threshold;
                buffer[i] = threshold + excess / (1.0f + (excess * excess) / (oneMinusThreshold * oneMinusThreshold));
            }
            else if (sample < -threshold)
            {
                float excess = sample + threshold;
                buffer[i] = -threshold + excess / (1.0f + (excess * excess) / (oneMinusThreshold * oneMinusThreshold));
            }
            // else: sample unchanged
        }
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
            float inputLevel = 20.0f * std::log10(std::abs(input) + 1e-10f);

            // Envelope follower
            float targetEnvelope = inputLevel;
            float coeff = (targetEnvelope > envelope) ?
                          std::exp(-1.0f / (attack * sampleRate)) :
                          std::exp(-1.0f / (release * sampleRate));

            envelope = coeff * envelope + (1.0f - coeff) * targetEnvelope;

            // Gain reduction
            float gainReduction = 0.0f;
            if (envelope > threshold)
            {
                float excess = envelope - threshold;
                gainReduction = excess * (1.0f - 1.0f / ratio);
            }

            // Apply gain reduction
            float outputGain = std::pow(10.0f, -gainReduction / 20.0f);
            return input * outputGain;
        }

        // Block processing version (optimizes coefficient calculation)
        void processBlock(float* buffer, int numSamples)
        {
            // Pre-calculate attack/release coefficients (constant for block)
            const float attackCoeff = std::exp(-1.0f / (attack * sampleRate));
            const float releaseCoeff = std::exp(-1.0f / (release * sampleRate));
            const float oneMinusAttack = 1.0f - attackCoeff;
            const float oneMinusRelease = 1.0f - releaseCoeff;
            const float invRatio = 1.0f / ratio;

            for (int i = 0; i < numSamples; ++i)
            {
                float input = buffer[i];
                float inputLevel = 20.0f * std::log10(std::abs(input) + 1e-10f);

                // Envelope follower (state-dependent, cannot vectorize)
                float targetEnvelope = inputLevel;
                if (targetEnvelope > envelope)
                    envelope = attackCoeff * envelope + oneMinusAttack * targetEnvelope;
                else
                    envelope = releaseCoeff * envelope + oneMinusRelease * targetEnvelope;

                // Gain reduction (branchless when possible)
                float excess = envelope - threshold;
                float gainReduction = (excess > 0.0f) ? excess * (1.0f - invRatio) : 0.0f;

                // Apply gain reduction
                float outputGain = std::pow(10.0f, -gainReduction / 20.0f);
                buffer[i] = input * outputGain;
            }
        }
    };

    SimpleCompressor compressorL, compressorR;

    //==============================================================================
    // Sample Rate
    double currentSampleRate = 44100.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (BioReactiveDSP)
};
