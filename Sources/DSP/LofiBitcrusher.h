#pragma once

#include <JuceHeader.h>
#include "../Core/DSPOptimizations.h"

/**
 * LofiBitcrusher - LoFi/Retro Digital Degradation
 *
 * Creates vintage digital artifacts and warm analog imperfections:
 * - Bit depth reduction (1-16 bits)
 * - Sample rate reduction (1-44.1kHz)
 * - Analog noise (vinyl crackle, tape hiss)
 * - Wow & Flutter (tape speed variations)
 * - Soft clipping (analog warmth)
 *
 * Perfect for: Lofi Hip-Hop, Vaporwave, Retro Aesthetics
 */
class LofiBitcrusher
{
public:
    LofiBitcrusher();
    ~LofiBitcrusher();

    //==============================================================================
    // DSP Lifecycle
    void prepare(double sampleRate, int maximumBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

    //==============================================================================
    // Parameters

    /** Set bit depth (1-16): lower = more digital artifacts */
    void setBitDepth(float bits);

    /** Set sample rate reduction (0-1): 0=full quality, 1=extreme */
    void setSampleRateReduction(float amount);

    /** Set noise amount (0-1): vinyl crackle + tape hiss */
    void setNoise(float amount);

    /** Set wow & flutter (0-1): tape speed variations */
    void setWowFlutter(float amount);

    /** Set warmth (0-1): analog-style saturation */
    void setWarmth(float warmth);

    /** Set mix (0-1): dry/wet blend */
    void setMix(float mix);

private:
    //==============================================================================
    // Bit Crusher - using fast pow
    float quantize(float sample, int bits)
    {
        float levels = Echoel::DSP::FastMath::fastPow(2.0f, static_cast<float>(bits)) - 1.0f;
        return std::round(sample * levels) / levels;
    }

    //==============================================================================
    // Sample Rate Reducer
    struct SampleRateReducer
    {
        float sampleRate = 44100.0f;
        float targetRate = 44100.0f;
        float phase = 0.0f;
        float heldSample = 0.0f;

        void setSampleRate(float sr) { sampleRate = sr; }
        void setTargetRate(float tr) { targetRate = juce::jlimit(100.0f, sampleRate, tr); }

        float process(float input)
        {
            phase += targetRate / sampleRate;

            if (phase >= 1.0f)
            {
                phase -= 1.0f;
                heldSample = input;
            }

            return heldSample;
        }

        void reset() { phase = 0.0f; heldSample = 0.0f; }
    };

    SampleRateReducer srrL, srrR;

    //==============================================================================
    // Noise Generator (Vinyl + Tape)
    struct NoiseGenerator
    {
        juce::Random random;

        float generate()
        {
            // Pink noise (1/f spectrum) + occasional pops
            float white = random.nextFloat() * 2.0f - 1.0f;
            float pop = (random.nextFloat() < 0.001f) ? (random.nextFloat() - 0.5f) * 2.0f : 0.0f;
            return white * 0.1f + pop;
        }
    };

    NoiseGenerator noiseGenL, noiseGenR;

    //==============================================================================
    // Wow & Flutter (Pitch Modulation)
    float wowPhase = 0.0f;
    float flutterPhase = 0.0f;
    juce::dsp::DelayLine<float, juce::dsp::DelayLineInterpolationTypes::Linear> wowFlutterDelay;

    //==============================================================================
    // Analog Warmth (Soft Clipping) - using fast tanh
    float softClip(float sample, float drive)
    {
        float driven = sample * (1.0f + drive * 2.0f);
        return Echoel::DSP::FastMath::fastTanh(driven);
    }

    //==============================================================================
    // Dry Buffer (pre-allocated to avoid allocations in audio thread)
    juce::AudioBuffer<float> dryBuffer;

    //==============================================================================
    // Parameters
    float currentBitDepth = 12.0f;  // bits
    float currentSRReduction = 0.3f;
    float currentNoise = 0.2f;
    float currentWowFlutter = 0.3f;
    float currentWarmth = 0.4f;
    float currentMix = 0.7f;

    double currentSampleRate = 44100.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (LofiBitcrusher)
};
