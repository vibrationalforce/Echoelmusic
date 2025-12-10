#pragma once

#include <JuceHeader.h>

/**
 * FormantFilter - Talkbox/Vowel Morphing Effect
 *
 * Creates classic talkbox and vowel filter effects:
 * - 5 formant peaks (F1-F5) modeling human vocal tract
 * - Vowel morphing (A, E, I, O, U) with smooth transitions
 * - LFO modulation for talking/wah effect
 * - Resonance control for character
 * - Gender shift (male/female formant characteristics)
 *
 * Used on: Talkbox effects (Daft Punk, Zapp & Roger), vowel bass (dubstep)
 */
class FormantFilter
{
public:
    FormantFilter();
    ~FormantFilter();

    //==============================================================================
    // DSP Lifecycle
    void prepare(double sampleRate, int maximumBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

    //==============================================================================
    // Parameters

    /** Set vowel (0-4): A, E, I, O, U */
    void setVowel(int vowel);

    /** Set vowel morph (0-1): smooth transition between adjacent vowels */
    void setVowelMorph(float morph);

    /** Set resonance (0-1): formant peak sharpness */
    void setResonance(float resonance);

    /** Set formant shift (-1 to +1): -1=male, 0=neutral, +1=female */
    void setFormantShift(float shift);

    /** Enable LFO modulation */
    void setLFOEnabled(bool enabled);

    /** Set LFO rate (0.1-10 Hz) */
    void setLFORate(float hz);

    /** Set LFO depth (0-1) */
    void setLFODepth(float depth);

    /** Set mix (0-1): dry/wet blend */
    void setMix(float mix);

private:
    //==============================================================================
    // Formant Peak (Bandpass Filter)
    struct FormantPeak
    {
        float freq = 500.0f;     // Center frequency
        float gain = 1.0f;       // Peak gain
        float Q = 10.0f;         // Resonance/bandwidth
        float sampleRate = 44100.0f;

        // Biquad coefficients
        float b0 = 1.0f, b1 = 0.0f, b2 = 0.0f;
        float a1 = 0.0f, a2 = 0.0f;

        // State variables
        float x1 = 0.0f, x2 = 0.0f;
        float y1 = 0.0f, y2 = 0.0f;

        void updateCoefficients()
        {
            // Bandpass filter (constant peak gain)
            float w0 = 2.0f * juce::MathConstants<float>::pi * freq / sampleRate;
            float alpha = std::sin(w0) / (2.0f * Q);
            float cosw0 = std::cos(w0);

            float a0 = 1.0f + alpha;
            b0 = alpha * gain / a0;
            b1 = 0.0f;
            b2 = -alpha * gain / a0;
            a1 = -2.0f * cosw0 / a0;
            a2 = (1.0f - alpha) / a0;
        }

        float process(float input)
        {
            float output = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;

            x2 = x1;
            x1 = input;
            y2 = y1;
            y1 = output;

            return output;
        }

        void reset()
        {
            x1 = x2 = y1 = y2 = 0.0f;
        }

        void setSampleRate(float sr)
        {
            sampleRate = sr;
        }
    };

    //==============================================================================
    // 5 Formants per channel
    std::array<FormantPeak, 5> formantsL;
    std::array<FormantPeak, 5> formantsR;

    //==============================================================================
    // Vowel Formant Data (based on vocal tract analysis)
    struct VowelFormants
    {
        std::array<float, 5> frequencies;  // F1-F5 in Hz
        std::array<float, 5> gains;        // Relative gains
    };

    // Vowel database (male voice reference)
    const std::array<VowelFormants, 5> vowelData = {{
        // A (as in "father")
        {{{730.0f, 1090.0f, 2440.0f, 3400.0f, 4200.0f}},
         {{1.0f, 0.5f, 0.25f, 0.15f, 0.1f}}},

        // E (as in "bed")
        {{{530.0f, 1840.0f, 2480.0f, 3470.0f, 4300.0f}},
         {{1.0f, 0.6f, 0.3f, 0.15f, 0.1f}}},

        // I (as in "feet")
        {{{270.0f, 2290.0f, 3010.0f, 3500.0f, 4400.0f}},
         {{1.0f, 0.7f, 0.35f, 0.2f, 0.1f}}},

        // O (as in "boat")
        {{{570.0f, 840.0f, 2410.0f, 3400.0f, 4200.0f}},
         {{1.0f, 0.55f, 0.28f, 0.16f, 0.1f}}},

        // U (as in "boot")
        {{{300.0f, 870.0f, 2240.0f, 3400.0f, 4200.0f}},
         {{1.0f, 0.5f, 0.25f, 0.15f, 0.1f}}}
    }};

    //==============================================================================
    // LFO for modulation
    struct LFO
    {
        float phase = 0.0f;
        float rate = 2.0f;  // Hz
        float sampleRate = 44100.0f;

        void setSampleRate(float sr) { sampleRate = sr; }
        void setRate(float hz) { rate = juce::jlimit(0.1f, 10.0f, hz); }

        float process()
        {
            float output = std::sin(2.0f * juce::MathConstants<float>::pi * phase);
            phase += rate / sampleRate;
            if (phase >= 1.0f)
                phase -= 1.0f;
            return output;
        }

        void reset() { phase = 0.0f; }
    };

    LFO lfo;

    //==============================================================================
    // Update formants based on vowel and parameters
    void updateFormants()
    {
        // Get current vowel formants
        int vowel1 = currentVowel;
        int vowel2 = (currentVowel + 1) % 5;

        // Interpolate between vowels
        float morph = currentVowelMorph;

        for (int f = 0; f < 5; ++f)
        {
            // Interpolate frequency
            float freq1 = vowelData[vowel1].frequencies[f];
            float freq2 = vowelData[vowel2].frequencies[f];
            float freq = freq1 * (1.0f - morph) + freq2 * morph;

            // Apply formant shift (gender)
            freq *= std::pow(2.0f, currentFormantShift * 0.15f);  // ±15% shift

            // Apply LFO modulation if enabled
            if (lfoEnabled && lfoDepth > 0.01f)
            {
                float lfoValue = lfo.process();
                freq *= 1.0f + lfoValue * lfoDepth * 0.2f;  // ±20% modulation
            }

            // Interpolate gain
            float gain1 = vowelData[vowel1].gains[f];
            float gain2 = vowelData[vowel2].gains[f];
            float gain = gain1 * (1.0f - morph) + gain2 * morph;

            // Update formant peaks
            formantsL[f].freq = freq;
            formantsL[f].gain = gain * (1.0f + currentResonance);
            formantsL[f].Q = 5.0f + currentResonance * 20.0f;
            formantsL[f].updateCoefficients();

            formantsR[f].freq = freq;
            formantsR[f].gain = gain * (1.0f + currentResonance);
            formantsR[f].Q = 5.0f + currentResonance * 20.0f;
            formantsR[f].updateCoefficients();
        }
    }

    //==============================================================================
    // Parameters
    int currentVowel = 0;  // 0=A, 1=E, 2=I, 3=O, 4=U
    float currentVowelMorph = 0.0f;
    float currentResonance = 0.5f;
    float currentFormantShift = 0.0f;
    bool lfoEnabled = false;
    float lfoRate = 2.0f;
    float lfoDepth = 0.5f;
    float currentMix = 0.8f;

    double currentSampleRate = 44100.0;
    int updateCounter = 0;  // Update formants every N samples

    // ✅ OPTIMIZATION: Pre-allocated buffer to avoid audio thread allocation
    juce::AudioBuffer<float> dryBuffer;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (FormantFilter)
};
