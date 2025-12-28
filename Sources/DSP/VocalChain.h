#pragma once

#include <JuceHeader.h>

/**
 * VocalChain - Professional Vocal Processing Chain
 *
 * Complete vocal processor with all essential processing:
 * 1. High-Pass Filter (rumble removal)
 * 2. De-Esser (sibilance control)
 * 3. Compressor (dynamics)
 * 4. EQ (tone shaping - parametric)
 * 5. Saturation (warmth & presence)
 * 6. Reverb (space)
 * 7. Delay (depth)
 *
 * Presets for:
 * - Modern Pop Vocal
 * - Warm R&B
 * - Aggressive Rap
 * - Intimate Singer-Songwriter
 * - Broadcast/Podcast
 * - Choir/Background
 */
class VocalChain
{
public:
    VocalChain();
    ~VocalChain();

    //==============================================================================
    // DSP Lifecycle
    void prepare(double sampleRate, int maximumBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

    //==============================================================================
    // Module Bypass
    void setHighPassEnabled(bool enabled);
    void setDeEsserEnabled(bool enabled);
    void setCompressorEnabled(bool enabled);
    void setEQEnabled(bool enabled);
    void setSaturationEnabled(bool enabled);
    void setReverbEnabled(bool enabled);
    void setDelayEnabled(bool enabled);

    //==============================================================================
    // High-Pass Filter Parameters
    void setHighPassFreq(float freq);  // 20-500 Hz

    //==============================================================================
    // De-Esser Parameters
    void setDeEsserThreshold(float threshold);  // dB
    void setDeEsserFreq(float freq);  // 4000-10000 Hz

    //==============================================================================
    // Compressor Parameters
    void setCompressorThreshold(float threshold);  // -40 to 0 dB
    void setCompressorRatio(float ratio);  // 1:1 to 20:1
    void setCompressorAttack(float ms);  // 0.1-100 ms
    void setCompressorRelease(float ms);  // 10-1000 ms
    void setCompressorMakeup(float dB);  // 0-24 dB

    //==============================================================================
    // EQ Parameters (3-band: Low, Mid, High)
    void setEQLowGain(float dB);  // ±15 dB @ 200 Hz
    void setEQMidGain(float dB);  // ±15 dB @ 2000 Hz
    void setEQHighGain(float dB);  // ±15 dB @ 8000 Hz

    //==============================================================================
    // Saturation Parameters
    void setSaturationDrive(float drive);  // 0-1
    void setSaturationTone(float tone);  // 0-1 (dark to bright)

    //==============================================================================
    // Reverb Parameters
    void setReverbSize(float size);  // 0-1
    void setReverbMix(float mix);  // 0-1

    //==============================================================================
    // Delay Parameters
    void setDelayTime(float ms);  // 0-2000 ms
    void setDelayFeedback(float feedback);  // 0-0.9
    void setDelayMix(float mix);  // 0-1

    //==============================================================================
    // Presets
    enum class Preset
    {
        ModernPop,
        WarmRnB,
        AggressiveRap,
        IntimateSingerSongwriter,
        BroadcastPodcast,
        ChoirBackground
    };

    void loadPreset(Preset preset);

private:
    //==============================================================================
    // High-Pass Filter (State Variable) - OPTIMIZED: cached coefficients
    struct HighPassFilter
    {
        float cutoff = 80.0f;
        float sampleRate = 44100.0f;
        float x1 = 0.0f, x2 = 0.0f;
        float y1 = 0.0f, y2 = 0.0f;

        // Cached coefficients (avoid per-sample sin/cos)
        float b0_a0 = 0.0f, b1_a0 = 0.0f, b2_a0 = 0.0f;
        float a1_a0 = 0.0f, a2_a0 = 0.0f;
        bool coeffsDirty = true;

        void setSampleRate(float sr) { sampleRate = sr; coeffsDirty = true; }
        void setCutoff(float freq) {
            float newCutoff = juce::jlimit(20.0f, 500.0f, freq);
            if (newCutoff != cutoff) { cutoff = newCutoff; coeffsDirty = true; }
        }

        void updateCoefficients()
        {
            if (!coeffsDirty) return;

            // 2nd order Butterworth high-pass
            float w0 = 2.0f * juce::MathConstants<float>::pi * cutoff / sampleRate;
            float Q = 0.707f;
            float alpha = std::sin(w0) / (2.0f * Q);
            float cosw0 = std::cos(w0);

            float b0 = (1.0f + cosw0) / 2.0f;
            float b1 = -(1.0f + cosw0);
            float b2 = (1.0f + cosw0) / 2.0f;
            float a0 = 1.0f + alpha;
            float a1 = -2.0f * cosw0;
            float a2 = 1.0f - alpha;

            // Pre-divide by a0
            float invA0 = 1.0f / a0;
            b0_a0 = b0 * invA0;
            b1_a0 = b1 * invA0;
            b2_a0 = b2 * invA0;
            a1_a0 = a1 * invA0;
            a2_a0 = a2 * invA0;

            coeffsDirty = false;
        }

        float process(float input)
        {
            // Coefficients already cached - just apply filter
            float output = b0_a0 * input + b1_a0 * x1 + b2_a0 * x2
                          - a1_a0 * y1 - a2_a0 * y2;

            x2 = x1;
            x1 = input;
            y2 = y1;
            y1 = output;

            return output;
        }

        void reset() { x1 = x2 = y1 = y2 = 0.0f; }
    };

    HighPassFilter hpfL, hpfR;

    //==============================================================================
    // De-Esser (Dynamic EQ at high frequency) - OPTIMIZED: cached coefficients
    struct SimpleDeEsser
    {
        float threshold = -20.0f;  // dB
        float freq = 7000.0f;
        float sampleRate = 44100.0f;
        float envelope = 0.0f;

        // Cached coefficients (avoid per-sample exp())
        float attackCoeff = 0.0f;
        float releaseCoeff = 0.0f;

        void setSampleRate(float sr) {
            sampleRate = sr;
            updateCoefficients();
        }

        void updateCoefficients() {
            attackCoeff = 1.0f - std::exp(-1.0f / (0.001f * sampleRate));   // 1ms attack
            releaseCoeff = 1.0f - std::exp(-1.0f / (0.1f * sampleRate));    // 100ms release
        }

        float process(float input)
        {
            // Detect high-frequency energy (simplified)
            float detection = std::abs(input);

            if (detection > envelope)
                envelope += attackCoeff * (detection - envelope);
            else
                envelope += releaseCoeff * (detection - envelope);

            float envelopeDB = juce::Decibels::gainToDecibels(envelope + 0.00001f);

            // Compute gain reduction
            float reduction = 1.0f;
            if (envelopeDB > threshold)
            {
                float excess = envelopeDB - threshold;
                reduction = juce::Decibels::decibelsToGain(-excess * 0.7f);  // 70% reduction
            }

            return input * reduction;
        }

        void reset() { envelope = 0.0f; }
    };

    SimpleDeEsser deEsserL, deEsserR;

    //==============================================================================
    // Compressor - OPTIMIZED: cached coefficients
    struct SimpleCompressor
    {
        float threshold = -20.0f;
        float ratio = 4.0f;
        float attack = 10.0f;  // ms
        float release = 100.0f;  // ms
        float makeup = 0.0f;  // dB
        float sampleRate = 44100.0f;
        float envelope = 0.0f;

        // Cached coefficients (avoid per-sample exp())
        float attackCoeff = 0.0f;
        float releaseCoeff = 0.0f;
        bool coeffsDirty = true;

        void setSampleRate(float sr) { sampleRate = sr; coeffsDirty = true; }

        void setAttack(float ms) { attack = ms; coeffsDirty = true; }
        void setRelease(float ms) { release = ms; coeffsDirty = true; }

        void updateCoefficients() {
            if (!coeffsDirty) return;
            attackCoeff = 1.0f - std::exp(-1.0f / (attack * 0.001f * sampleRate));
            releaseCoeff = 1.0f - std::exp(-1.0f / (release * 0.001f * sampleRate));
            coeffsDirty = false;
        }

        float process(float input)
        {
            float inputLevel = juce::Decibels::gainToDecibels(std::abs(input) + 0.00001f);

            if (inputLevel > envelope)
                envelope += attackCoeff * (inputLevel - envelope);
            else
                envelope += releaseCoeff * (inputLevel - envelope);

            float gainReduction = 0.0f;
            if (envelope > threshold)
            {
                float excess = envelope - threshold;
                gainReduction = excess * (1.0f - 1.0f / ratio);
            }

            float gain = juce::Decibels::decibelsToGain(-gainReduction + makeup);
            return input * gain;
        }

        void reset() { envelope = 0.0f; }
    };

    SimpleCompressor compressorL, compressorR;

    //==============================================================================
    // 3-Band EQ
    std::array<juce::dsp::IIR::Filter<float>, 6> eqFilters;  // 3 bands × 2 channels

    //==============================================================================
    // Saturation
    struct Saturation
    {
        float drive = 0.5f;
        float tone = 0.5f;

        float process(float input)
        {
            // Soft clipping with tone control
            float driven = input * (1.0f + drive * 3.0f);
            float saturated = std::tanh(driven);

            // Tone: 0=dark (lowpass), 1=bright (highpass)
            return saturated * (0.5f + tone * 0.5f);
        }
    };

    Saturation satL, satR;

    //==============================================================================
    // Reverb & Delay
    juce::dsp::Reverb reverb;
    juce::dsp::DelayLine<float, juce::dsp::DelayLineInterpolationTypes::Linear> delayLine;

    // Pre-allocated buffer for reverb (avoid per-frame allocation)
    juce::AudioBuffer<float> reverbBuffer;

    //==============================================================================
    // Module Enables
    bool highPassEnabled = true;
    bool deEsserEnabled = true;
    bool compressorEnabled = true;
    bool eqEnabled = true;
    bool saturationEnabled = true;
    bool reverbEnabled = true;
    bool delayEnabled = true;

    //==============================================================================
    // Parameters
    float hpFreq = 80.0f;
    float deEsserThresh = -20.0f;
    float deEsserFreq = 7000.0f;
    float compThreshold = -20.0f;
    float compRatio = 4.0f;
    float compAttack = 10.0f;
    float compRelease = 100.0f;
    float compMakeup = 6.0f;
    float eqLowGain = 0.0f;
    float eqMidGain = 0.0f;
    float eqHighGain = 0.0f;
    float satDrive = 0.3f;
    float satTone = 0.5f;
    float reverbSize = 0.3f;
    float reverbMix = 0.2f;
    float delayTime = 250.0f;  // ms
    float delayFeedback = 0.3f;
    float delayMix = 0.15f;

    double currentSampleRate = 44100.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (VocalChain)
};
