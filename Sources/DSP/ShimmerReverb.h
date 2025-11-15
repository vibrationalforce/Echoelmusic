#pragma once

#include <JuceHeader.h>

/**
 * ShimmerReverb - Reverb with Octave-Up Pitch Shifting
 *
 * Creates ethereal, shimmering textures by feeding reverb through
 * pitch shifters. Made famous by Brian Eno, used extensively in:
 * - Ambient music
 * - Post-rock (Explosions in the Sky, Sigur Rós)
 * - Cinematic soundscapes
 *
 * Features:
 * - Dense reverb with modulation
 * - +1 octave pitch shifter in feedback loop
 * - Optional +2 octaves for extreme shimmer
 * - Stereo width control
 * - Pre-delay for definition
 */
class ShimmerReverb
{
public:
    ShimmerReverb();
    ~ShimmerReverb();

    //==============================================================================
    // DSP Lifecycle
    void prepare(double sampleRate, int maximumBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

    //==============================================================================
    // Parameters

    /** Set shimmer amount (0-1): intensity of pitched feedback */
    void setShimmer(float amount);

    /** Set reverb size (0-1): room size */
    void setSize(float size);

    /** Set decay time (0-1): reverb tail length */
    void setDecay(float decay);

    /** Set modulation (0-1): chorus-like movement */
    void setModulation(float modulation);

    /** Set octave mode: 0=off, 1=+1oct, 2=+2oct */
    void setOctaveMode(int mode);

    /** Set pre-delay (0-200ms): clarity before reverb */
    void setPreDelay(float ms);

    /** Set mix (0-1): dry/wet blend */
    void setMix(float mix);

private:
    //==============================================================================
    // Reverb Engine
    juce::dsp::Reverb reverb;
    juce::dsp::Reverb::Parameters reverbParams;

    //==============================================================================
    // Pitch Shifter (Simple grain-based)
    struct SimplePitchShifter
    {
        juce::dsp::DelayLine<float, juce::dsp::DelayLineInterpolationTypes::Linear> delayLine;
        float writePos = 0.0f;
        float readPos1 = 0.0f;
        float readPos2 = 0.0f;
        float grainSize = 0.05f;  // 50ms grains
        float sampleRate = 44100.0f;
        float pitchRatio = 2.0f;  // +1 octave

        void prepare(const juce::dsp::ProcessSpec& spec)
        {
            sampleRate = static_cast<float>(spec.sampleRate);
            delayLine.prepare(spec);
            delayLine.setMaximumDelayInSamples(static_cast<int>(grainSize * sampleRate * 4));
            reset();
        }

        void reset()
        {
            delayLine.reset();
            writePos = 0.0f;
            readPos1 = 0.0f;
            readPos2 = grainSize * sampleRate * 0.5f;
        }

        void setPitchRatio(float ratio)
        {
            pitchRatio = juce::jlimit(0.5f, 4.0f, ratio);
        }

        float process(float input, int channel)
        {
            // Write input
            delayLine.pushSample(channel, input);

            // Read two grains with crossfade
            float delay1 = readPos1;
            float delay2 = readPos2;

            float sample1 = delayLine.popSample(channel, delay1);
            float sample2 = delayLine.popSample(channel, delay2);

            // Crossfade between grains (triangular window)
            float grainSamples = grainSize * sampleRate;
            float fade1 = 1.0f - std::abs(std::fmod(readPos1, grainSamples) / grainSamples - 0.5f) * 2.0f;
            float fade2 = 1.0f - std::abs(std::fmod(readPos2, grainSamples) / grainSamples - 0.5f) * 2.0f;

            float output = sample1 * fade1 + sample2 * fade2;

            // Advance read positions
            readPos1 += pitchRatio;
            readPos2 += pitchRatio;

            float maxDelay = grainSamples * 2.0f;
            if (readPos1 > maxDelay) readPos1 -= maxDelay;
            if (readPos2 > maxDelay) readPos2 -= maxDelay;

            return output * 0.5f;
        }
    };

    SimplePitchShifter pitchShifterL, pitchShifterR;

    //==============================================================================
    // Pre-Delay
    juce::dsp::DelayLine<float, juce::dsp::DelayLineInterpolationTypes::Linear> preDelayLine;

    //==============================================================================
    // Parameters
    float currentShimmer = 0.5f;
    float currentSize = 0.7f;
    float currentDecay = 0.7f;
    float currentModulation = 0.3f;
    int currentOctaveMode = 1;  // +1 octave
    float currentPreDelay = 50.0f;  // ms
    float currentMix = 0.5f;

    double currentSampleRate = 44100.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (ShimmerReverb)
};
