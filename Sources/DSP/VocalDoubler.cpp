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

    // Store dry signal
    juce::AudioBuffer<float> dryBuffer(numChannels, numSamples);
    for (int ch = 0; ch < numChannels; ++ch)
        dryBuffer.copyFrom(ch, 0, buffer, ch, 0, numSamples);

    // Create doubled buffer
    juce::AudioBuffer<float> doublerBuffer(numChannels, numSamples);
    doublerBuffer.clear();

    // Process each voice
    for (int v = 0; v < currentVoices && v < 4; ++v)
    {
        auto& voice = voices[v];

        // Apply pitch and timing variation
        voice.pitchOffset = voice.pitchOffset * currentPitchVariation;
        voice.timingOffset = voice.timingOffset * currentTimingVariation;

        for (int channel = 0; channel < juce::jmin(2, numChannels); ++channel)
        {
            auto* dryData = dryBuffer.getReadPointer(channel);
            auto* doublerData = doublerBuffer.getWritePointer(channel);

            for (int sample = 0; sample < numSamples; ++sample)
            {
                float voiceOutput = voice.process(dryData[sample], channel);

                // Apply stereo positioning
                float panGain = 1.0f;
                if (channel == 0)  // Left
                    panGain = std::cos((voice.panPosition + 1.0f) * juce::MathConstants<float>::pi / 4.0f);
                else  // Right
                    panGain = std::sin((voice.panPosition + 1.0f) * juce::MathConstants<float>::pi / 4.0f);

                panGain *= currentStereoWidth;

                doublerData[sample] += voiceOutput * panGain / static_cast<float>(currentVoices);
            }
        }
    }

    // Mix dry and doubled
    for (int ch = 0; ch < numChannels; ++ch)
    {
        auto* dry = dryBuffer.getReadPointer(ch);
        auto* doubled = doublerBuffer.getReadPointer(ch);
        auto* out = buffer.getWritePointer(ch);

        for (int i = 0; i < numSamples; ++i)
            out[i] = dry[i] * (1.0f - currentMix) + (dry[i] * 0.6f + doubled[i]) * currentMix;
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
}

void VocalDoubler::setMix(float mix)
{
    currentMix = juce::jlimit(0.0f, 1.0f, mix);
}
