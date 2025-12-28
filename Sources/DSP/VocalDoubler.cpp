#include "VocalDoubler.h"

VocalDoubler::VocalDoubler()
{
}

VocalDoubler::~VocalDoubler()
{
}

void VocalDoubler::prepare(double sampleRate, int maximumBlockSize)
{
    currentSampleRate = sampleRate;

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = static_cast<uint32_t>(maximumBlockSize);
    spec.numChannels = 2;

    // Pre-allocate buffers (avoid per-frame allocations)
    dryBuffer.setSize(2, maximumBlockSize);
    doublerBuffer.setSize(2, maximumBlockSize);

    // Prepare all voices
    for (auto& voice : voices)
        voice.prepare(spec);

    // Initialize voice parameters
    voices[0].pitchOffset = -8.0f;   // -8 cents
    voices[0].timingOffset = 0.015f * static_cast<float>(sampleRate);  // 15ms
    voices[0].panPosition = -0.3f;   // Left

    voices[1].pitchOffset = 6.0f;    // +6 cents
    voices[1].timingOffset = 0.022f * static_cast<float>(sampleRate);  // 22ms
    voices[1].panPosition = 0.3f;    // Right

    voices[2].pitchOffset = -5.0f;   // -5 cents
    voices[2].timingOffset = 0.008f * static_cast<float>(sampleRate);  // 8ms
    voices[2].panPosition = -0.6f;   // Further left

    voices[3].pitchOffset = 9.0f;    // +9 cents
    voices[3].timingOffset = 0.028f * static_cast<float>(sampleRate);  // 28ms
    voices[3].panPosition = 0.6f;    // Further right

    // Pre-compute pan gains (avoid per-sample sin/cos)
    updatePanGains();

    reset();
}

void VocalDoubler::reset()
{
    for (auto& voice : voices)
        voice.reset();
}

void VocalDoubler::process(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    if (numChannels == 0 || numSamples == 0 || currentVoices == 0)
        return;

    // Ensure buffers are large enough (resize only if needed - rare path)
    if (dryBuffer.getNumSamples() < numSamples)
    {
        dryBuffer.setSize(2, numSamples, false, false, true);
        doublerBuffer.setSize(2, numSamples, false, false, true);
    }

    // Store dry signal (use pre-allocated buffer)
    for (int ch = 0; ch < juce::jmin(2, numChannels); ++ch)
        dryBuffer.copyFrom(ch, 0, buffer, ch, 0, numSamples);

    // Clear doubled buffer
    doublerBuffer.clear();

    // Pre-compute voice scale factor (avoid per-sample division)
    const float voiceScale = 1.0f / static_cast<float>(currentVoices);

    // Process each voice with cached pan gains
    for (int v = 0; v < currentVoices && v < 4; ++v)
    {
        auto& voice = voices[v];

        // Cached pan gains (computed once when stereo width changes)
        const float panGainL = panGainsL[static_cast<size_t>(v)] * voiceScale;
        const float panGainR = panGainsR[static_cast<size_t>(v)] * voiceScale;

        for (int channel = 0; channel < juce::jmin(2, numChannels); ++channel)
        {
            const auto* dryData = dryBuffer.getReadPointer(channel);
            auto* doublerData = doublerBuffer.getWritePointer(channel);
            const float panGain = (channel == 0) ? panGainL : panGainR;

            for (int sample = 0; sample < numSamples; ++sample)
            {
                float voiceOutput = voice.process(dryData[sample], channel);
                doublerData[sample] += voiceOutput * panGain;
            }
        }
    }

    // Mix dry and doubled using SIMD-friendly operations
    const float dryGain = 1.0f - currentMix + currentMix * 0.6f;  // Pre-compute
    const float wetGain = currentMix;

    for (int ch = 0; ch < juce::jmin(2, numChannels); ++ch)
    {
        const auto* dry = dryBuffer.getReadPointer(ch);
        const auto* doubled = doublerBuffer.getReadPointer(ch);
        auto* out = buffer.getWritePointer(ch);

        // SIMD-optimized: out = dry * dryGain + doubled * wetGain
        juce::FloatVectorOperations::copyWithMultiply(out, dry, dryGain, numSamples);
        juce::FloatVectorOperations::addWithMultiply(out, doubled, wetGain, numSamples);
    }
}

//==============================================================================
void VocalDoubler::setVoices(int numVoices)
{
    currentVoices = juce::jlimit(1, 4, numVoices);
}

void VocalDoubler::setPitchVariation(float variation)
{
    currentPitchVariation = juce::jlimit(0.0f, 1.0f, variation);
}

void VocalDoubler::setTimingVariation(float variation)
{
    currentTimingVariation = juce::jlimit(0.0f, 1.0f, variation);
}

void VocalDoubler::setStereoWidth(float width)
{
    currentStereoWidth = juce::jlimit(0.0f, 1.0f, width);
    updatePanGains();  // Recache pan gains when width changes
}

void VocalDoubler::updatePanGains()
{
    // Pre-compute sin/cos for pan law (called once when params change, not per-sample)
    for (int v = 0; v < 4; ++v)
    {
        float angle = (voices[static_cast<size_t>(v)].panPosition + 1.0f) * juce::MathConstants<float>::pi / 4.0f;
        panGainsL[static_cast<size_t>(v)] = std::cos(angle) * currentStereoWidth;
        panGainsR[static_cast<size_t>(v)] = std::sin(angle) * currentStereoWidth;
    }
}

void VocalDoubler::setMix(float mix)
{
    currentMix = juce::jlimit(0.0f, 1.0f, mix);
}
