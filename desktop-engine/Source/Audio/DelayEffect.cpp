// DelayEffect.cpp

#include "DelayEffect.h"

DelayEffect::DelayEffect()
{
}

DelayEffect::~DelayEffect()
{
}

void DelayEffect::prepare(double sampleRate, int samplesPerBlock)
{
    currentSampleRate = sampleRate;

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = (juce::uint32)samplesPerBlock;
    spec.numChannels = 1;  // Mono delay lines

    // Max delay time: 2 seconds
    delayLineLeft.prepare(spec);
    delayLineRight.prepare(spec);

    delayLineLeft.setMaximumDelayInSamples((int)(sampleRate * 2.0));
    delayLineRight.setMaximumDelayInSamples((int)(sampleRate * 2.0));

    reset();
}

void DelayEffect::process(juce::AudioBuffer<float>& buffer)
{
    auto numSamples = buffer.getNumSamples();
    auto* leftChannel = buffer.getWritePointer(0);
    auto* rightChannel = buffer.getWritePointer(1);

    int delaySamples = (int)((delayTimeMs / 1000.0f) * currentSampleRate);

    delayLineLeft.setDelay((float)delaySamples);
    delayLineRight.setDelay((float)delaySamples);

    for (int i = 0; i < numSamples; ++i)
    {
        // Left channel
        float inputLeft = leftChannel[i];
        float delayedLeft = delayLineLeft.popSample(0);
        delayLineLeft.pushSample(0, inputLeft + (delayedLeft * feedbackAmount));
        leftChannel[i] = inputLeft * (1.0f - wetAmount) + delayedLeft * wetAmount;

        // Right channel
        float inputRight = rightChannel[i];
        float delayedRight = delayLineRight.popSample(0);
        delayLineRight.pushSample(0, inputRight + (delayedRight * feedbackAmount));
        rightChannel[i] = inputRight * (1.0f - wetAmount) + delayedRight * wetAmount;
    }
}

void DelayEffect::reset()
{
    delayLineLeft.reset();
    delayLineRight.reset();
}

void DelayEffect::setDelayTime(float timeMs)
{
    delayTimeMs = juce::jlimit(1.0f, 2000.0f, timeMs);
}

void DelayEffect::setFeedback(float feedback)
{
    feedbackAmount = juce::jlimit(0.0f, 0.95f, feedback);
}

void DelayEffect::setWetness(float wetness)
{
    wetAmount = juce::jlimit(0.0f, 1.0f, wetness);
}
