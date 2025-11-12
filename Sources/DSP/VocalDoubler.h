#pragma once

#include <JuceHeader.h>

/**
 * VocalDoubler - Professional Vocal Doubling/Thickening
 *
 * Creates natural-sounding vocal doubles without phase issues:
 * - Micro-pitch shifting (±10 cents)
 * - Micro-timing variations (0-30ms)
 * - Stereo widening
 * - Formant preservation
 * - Multiple voices (1-4)
 *
 * Used on: 90% of modern pop vocals, choir stacking, harmonies
 */
class VocalDoubler
{
public:
    VocalDoubler();
    ~VocalDoubler();

    //==============================================================================
    // DSP Lifecycle
    void prepare(double sampleRate, int maximumBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

    //==============================================================================
    // Parameters

    /** Set number of voices (1-4): more = thicker */
    void setVoices(int numVoices);

    /** Set pitch variation (0-1): subtle detuning */
    void setPitchVariation(float variation);

    /** Set timing variation (0-1): humanization */
    void setTimingVariation(float variation);

    /** Set stereo width (0-1): spread voices in stereo field */
    void setStereoWidth(float width);

    /** Set mix (0-1): original vs doubled signal */
    void setMix(float mix);

private:
    //==============================================================================
    // Simple Pitch Shifter (per voice)
    struct VoiceProcessor
    {
        juce::dsp::DelayLine<float, juce::dsp::DelayLineInterpolationTypes::Linear> delayLine;
        float pitchOffset = 0.0f;  // cents
        float timingOffset = 0.0f;  // samples
        float panPosition = 0.0f;  // -1 to +1
        float phase = 0.0f;
        float sampleRate = 44100.0f;

        void prepare(const juce::dsp::ProcessSpec& spec)
        {
            sampleRate = static_cast<float>(spec.sampleRate);
            delayLine.prepare(spec);
            delayLine.setMaximumDelayInSamples(static_cast<int>(0.05f * sampleRate));  // 50ms
        }

        void reset()
        {
            delayLine.reset();
            phase = 0.0f;
        }

        float process(float input, int channel)
        {
            // Pitch shift using delay modulation
            float pitchRatio = std::pow(2.0f, pitchOffset / 1200.0f);  // cents to ratio
            float modulation = std::sin(phase) * 0.001f * pitchRatio;  // Subtle LFO

            delayLine.pushSample(channel, input);
            float delayed = delayLine.popSample(channel, timingOffset + modulation * sampleRate);

            phase += 0.001f;  // Slow LFO
            if (phase > juce::MathConstants<float>::twoPi)
                phase -= juce::MathConstants<float>::twoPi;

            return delayed;
        }
    };

    std::array<VoiceProcessor, 4> voices;

    //==============================================================================
    // Parameters
    int currentVoices = 2;
    float currentPitchVariation = 0.3f;
    float currentTimingVariation = 0.4f;
    float currentStereoWidth = 0.7f;
    float currentMix = 0.5f;

    double currentSampleRate = 44100.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (VocalDoubler)
};
