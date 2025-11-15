// ReverbEffect.cpp

#include "ReverbEffect.h"

ReverbEffect::ReverbEffect()
{
    // Default reverb parameters
    params.roomSize = 0.5f;
    params.damping = 0.5f;
    params.wetLevel = 0.33f;
    params.dryLevel = 0.4f;
    params.width = 1.0f;
    params.freezeMode = 0.0f;

    reverb.setParameters(params);
}

ReverbEffect::~ReverbEffect()
{
}

void ReverbEffect::prepare(double sampleRate, int samplesPerBlock)
{
    currentSampleRate = sampleRate;

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = (juce::uint32)samplesPerBlock;
    spec.numChannels = 2;

    reverb.prepare(spec);

    // Setup smoothing (100ms ramp time)
    smoothedWetness.reset(sampleRate, 0.1);
    smoothedRoomSize.reset(sampleRate, 0.1);

    smoothedWetness.setCurrentAndTargetValue(params.wetLevel);
    smoothedRoomSize.setCurrentAndTargetValue(params.roomSize);
}

void ReverbEffect::process(juce::AudioBuffer<float>& buffer)
{
    // Update smoothed parameters
    if (smoothedWetness.isSmoothing() || smoothedRoomSize.isSmoothing())
    {
        params.wetLevel = smoothedWetness.getNextValue();
        params.roomSize = smoothedRoomSize.getNextValue();
        reverb.setParameters(params);
    }

    // Process
    juce::dsp::AudioBlock<float> block(buffer);
    juce::dsp::ProcessContextReplacing<float> context(block);
    reverb.process(context);
}

void ReverbEffect::reset()
{
    reverb.reset();
}

// Parameter Setters

void ReverbEffect::setWetness(float wetness)
{
    wetness = juce::jlimit(0.0f, 1.0f, wetness);
    smoothedWetness.setTargetValue(wetness);
}

void ReverbEffect::setRoomSize(float size)
{
    size = juce::jlimit(0.0f, 1.0f, size);
    smoothedRoomSize.setTargetValue(size);
}

void ReverbEffect::setDamping(float damping)
{
    params.damping = juce::jlimit(0.0f, 1.0f, damping);
    reverb.setParameters(params);
}

void ReverbEffect::setWidth(float width)
{
    params.width = juce::jlimit(0.0f, 1.0f, width);
    reverb.setParameters(params);
}

// Biofeedback Mapping

void ReverbEffect::setFromHRV(float hrv)
{
    // HRV (0-100ms) → Reverb wetness (0.1-0.8)
    // Higher HRV (relaxed) = More reverb (spacious)

    float normalizedHRV = juce::jlimit(0.0f, 100.0f, hrv) / 100.0f;

    // Map to wetness range
    float wetness = 0.1f + (0.7f * normalizedHRV);

    setWetness(wetness);

    // Also increase room size with HRV
    float roomSize = 0.3f + (0.6f * normalizedHRV);
    setRoomSize(roomSize);

    DBG("🌊 HRV: " + juce::String(hrv, 1) + " ms → Reverb: " +
        juce::String(wetness * 100.0f, 1) + "%");
}
