#pragma once

#include <JuceHeader.h>

/**
 * UnderwaterEffect - Aquatic/Submarine Audio Processing
 *
 * Simulates underwater sound propagation with:
 * - Lowpass filtering (sound absorption in water)
 * - Dense reverb (acoustic reflections)
 * - Pitch wobble (Doppler-like effect)
 * - Bubble synthesis (authentic underwater ambience)
 * - Distance attenuation (realistic depth simulation)
 *
 * Based on underwater acoustics research (Journal of Acoustical Society)
 * Perfect for: Ambient, Cinematic, Creative Effects
 */
class UnderwaterEffect
{
public:
    UnderwaterEffect();
    ~UnderwaterEffect();

    //==============================================================================
    // DSP Lifecycle
    void prepare(double sampleRate, int maximumBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

    //==============================================================================
    // Parameters

    /** Set depth (0-1): 0 = shallow, 1 = deep ocean */
    void setDepth(float depth);

    /** Set density (0-1): controls reverb and bubbles */
    void setDensity(float density);

    /** Set wobble amount (0-1): pitch modulation intensity */
    void setWobble(float wobble);

    /** Set bubble amount (0-1): underwater ambience */
    void setBubbles(float bubbles);

    /** Set mix (0-1): dry/wet blend */
    void setMix(float mix);

private:
    //==============================================================================
    // Lowpass Filter (State Variable)
    struct LowpassFilter
    {
        float cutoff = 800.0f;
        float resonance = 0.7f;
        float sampleRate = 44100.0f;

        float lowpass = 0.0f;
        float bandpass = 0.0f;
        float highpass = 0.0f;

        void setSampleRate(float sr) { sampleRate = sr; }
        void setCutoff(float freq) { cutoff = juce::jlimit(100.0f, 5000.0f, freq); }

        float process(float input)
        {
            float f = 2.0f * std::sin(juce::MathConstants<float>::pi * cutoff / sampleRate);
            float q = 1.0f - resonance;

            lowpass += f * bandpass;
            highpass = input - lowpass - q * bandpass;
            bandpass += f * highpass;

            return lowpass;
        }
    };

    LowpassFilter filterL, filterR;

    //==============================================================================
    // Dense Reverb
    juce::dsp::Reverb reverb;
    juce::dsp::Reverb::Parameters reverbParams;

    //==============================================================================
    // Pitch Wobble (LFO)
    float lfoPhase = 0.0f;
    float lfoRate = 0.2f;  // Hz
    juce::dsp::DelayLine<float, juce::dsp::DelayLineInterpolationTypes::Linear> pitchDelay;

    //==============================================================================
    // Bubble Generator
    struct BubbleGenerator
    {
        juce::Random random;
        float phase = 0.0f;
        float nextBubbleTime = 0.0f;
        float sampleRate = 44100.0f;

        void setSampleRate(float sr) { sampleRate = sr; }

        float generate()
        {
            if (nextBubbleTime <= 0.0f)
            {
                // Trigger new bubble
                nextBubbleTime = random.nextFloat() * 0.5f * sampleRate;  // 0-0.5s
                phase = 0.0f;
            }

            nextBubbleTime -= 1.0f;

            // Generate bubble pop (exponentially decaying sine)
            if (phase < 0.1f * sampleRate)  // 100ms bubble
            {
                float freq = 400.0f + random.nextFloat() * 1600.0f;  // 400-2000 Hz
                float envelope = std::exp(-phase / (0.03f * sampleRate));
                float sine = std::sin(2.0f * juce::MathConstants<float>::pi * freq * phase / sampleRate);
                phase += 1.0f;
                return sine * envelope * 0.3f;
            }

            return 0.0f;
        }
    };

    BubbleGenerator bubbleGenL, bubbleGenR;

    //==============================================================================
    // Parameters
    float currentDepth = 0.5f;
    float currentDensity = 0.5f;
    float currentWobble = 0.3f;
    float currentBubbles = 0.2f;
    float currentMix = 0.7f;

    double currentSampleRate = 44100.0;

    //==============================================================================
    // Pre-allocated buffer (avoids per-frame allocation)
    juce::AudioBuffer<float> dryBuffer;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (UnderwaterEffect)
};
