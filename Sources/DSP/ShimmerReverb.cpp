#include "ShimmerReverb.h"

ShimmerReverb::ShimmerReverb()
{
    // Initialize reverb for shimmer
    reverbParams.roomSize = 0.85f;
    reverbParams.damping = 0.4f;
    reverbParams.wetLevel = 0.7f;
    reverbParams.dryLevel = 0.0f;
    reverbParams.width = 1.0f;
    reverbParams.freezeMode = 0.0f;

    reverb.setParameters(reverbParams);
}

ShimmerReverb::~ShimmerReverb()
{
}

void ShimmerReverb::prepare(double sampleRate, int maximumBlockSize)
{
    currentSampleRate = sampleRate;

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = static_cast<uint32_t>(maximumBlockSize);
    spec.numChannels = 2;

    // Prepare reverb (JUCE 7 API)
    reverb.prepare(spec);
    reverb.reset();

    // Prepare pitch shifters
    pitchShifterL.prepare(spec);
    pitchShifterR.prepare(spec);

    // Prepare pre-delay
    preDelayLine.prepare(spec);
    preDelayLine.setMaximumDelayInSamples(static_cast<int>(0.2f * sampleRate));  // 200ms max

    reset();
}

void ShimmerReverb::reset()
{
    reverb.reset();
    pitchShifterL.reset();
    pitchShifterR.reset();
    preDelayLine.reset();
}

void ShimmerReverb::process(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    if (numChannels == 0 || numSamples == 0)
        return;

    // Store dry signal
    juce::AudioBuffer<float> dryBuffer(numChannels, numSamples);
    for (int ch = 0; ch < numChannels; ++ch)
        dryBuffer.copyFrom(ch, 0, buffer, ch, 0, numSamples);

    // 1. Apply pre-delay
    float preDelaySamples = currentPreDelay * 0.001f * static_cast<float>(currentSampleRate);
    for (int channel = 0; channel < juce::jmin(2, numChannels); ++channel)
    {
        auto* data = buffer.getWritePointer(channel);
        for (int i = 0; i < numSamples; ++i)
        {
            float input = data[i];
            preDelayLine.pushSample(channel, input);
            data[i] = preDelayLine.popSample(channel, preDelaySamples);
        }
    }

    // 2. Apply reverb (JUCE 7 API)
    juce::dsp::AudioBlock<float> block(buffer);
    juce::dsp::ProcessContextReplacing<float> context(block);
    reverb.process(context);

    // 3. Apply shimmer (pitch-shifted feedback)
    if (currentShimmer > 0.01f && currentOctaveMode > 0)
    {
        // Set pitch ratio based on octave mode
        float pitchRatio = (currentOctaveMode == 1) ? 2.0f : 4.0f;  // +1oct or +2oct
        pitchShifterL.setPitchRatio(pitchRatio);
        pitchShifterR.setPitchRatio(pitchRatio);

        juce::AudioBuffer<float> shimmerBuffer(numChannels, numSamples);

        for (int channel = 0; channel < juce::jmin(2, numChannels); ++channel)
        {
            auto* reverbData = buffer.getReadPointer(channel);
            auto* shimmerData = shimmerBuffer.getWritePointer(channel);
            auto& shifter = (channel == 0) ? pitchShifterL : pitchShifterR;

            for (int i = 0; i < numSamples; ++i)
            {
                shimmerData[i] = shifter.process(reverbData[i], channel);
            }
        }

        // Mix shimmer back into reverb
        for (int ch = 0; ch < numChannels; ++ch)
        {
            buffer.addFrom(ch, 0, shimmerBuffer, ch, 0, numSamples, currentShimmer);
        }
    }

    // 4. Mix dry/wet
    for (int ch = 0; ch < numChannels; ++ch)
    {
        auto* wet = buffer.getReadPointer(ch);
        auto* dry = dryBuffer.getReadPointer(ch);
        auto* out = buffer.getWritePointer(ch);

        for (int i = 0; i < numSamples; ++i)
            out[i] = dry[i] * (1.0f - currentMix) + wet[i] * currentMix;
    }
}

//==============================================================================
void ShimmerReverb::setShimmer(float amount)
{
    currentShimmer = juce::jlimit(0.0f, 1.0f, amount);
}

void ShimmerReverb::setSize(float size)
{
    currentSize = juce::jlimit(0.0f, 1.0f, size);
    reverbParams.roomSize = juce::jmap(size, 0.0f, 1.0f, 0.5f, 0.95f);
    reverb.setParameters(reverbParams);
}

void ShimmerReverb::setDecay(float decay)
{
    currentDecay = juce::jlimit(0.0f, 1.0f, decay);
    reverbParams.damping = juce::jmap(decay, 0.0f, 1.0f, 0.7f, 0.1f);  // Less damping = longer decay
    reverb.setParameters(reverbParams);
}

void ShimmerReverb::setModulation(float modulation)
{
    currentModulation = juce::jlimit(0.0f, 1.0f, modulation);
    reverbParams.width = juce::jmap(modulation, 0.0f, 1.0f, 0.5f, 1.0f);
    reverb.setParameters(reverbParams);
}

void ShimmerReverb::setOctaveMode(int mode)
{
    currentOctaveMode = juce::jlimit(0, 2, mode);
}

void ShimmerReverb::setPreDelay(float ms)
{
    currentPreDelay = juce::jlimit(0.0f, 200.0f, ms);
}

void ShimmerReverb::setMix(float mix)
{
    currentMix = juce::jlimit(0.0f, 1.0f, mix);
}
