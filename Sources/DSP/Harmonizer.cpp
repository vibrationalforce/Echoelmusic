#include "Harmonizer.h"

Harmonizer::Harmonizer()
{
    // Initialize voices with default intervals
    voices[0].semitones = 4;   // Major 3rd
    voices[0].level = 0.7f;
    voices[0].pan = -0.5f;     // Left
    voices[0].active = false;

    voices[1].semitones = 7;   // Perfect 5th
    voices[1].level = 0.6f;
    voices[1].pan = 0.5f;      // Right
    voices[1].active = false;

    voices[2].semitones = 12;  // Octave up
    voices[2].level = 0.5f;
    voices[2].pan = 0.0f;      // Center
    voices[2].active = false;

    voices[3].semitones = -12; // Octave down
    voices[3].level = 0.4f;
    voices[3].pan = 0.0f;      // Center
    voices[3].active = false;
}

Harmonizer::~Harmonizer()
{
}

void Harmonizer::prepare(double sampleRate, int maximumBlockSize)
{
    currentSampleRate = sampleRate;

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = static_cast<uint32_t>(maximumBlockSize);
    spec.numChannels = 2;

    // Prepare all voices
    for (auto& voice : voices)
        voice.prepare(spec);

    reset();
}

void Harmonizer::reset()
{
    for (auto& voice : voices)
        voice.reset();
}

void Harmonizer::process(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    if (numChannels == 0 || numSamples == 0 || voiceCount == 0)
        return;

    // Store dry signal
    juce::AudioBuffer<float> dryBuffer(numChannels, numSamples);
    for (int ch = 0; ch < numChannels; ++ch)
        dryBuffer.copyFrom(ch, 0, buffer, ch, 0, numSamples);

    // Create harmony buffer
    juce::AudioBuffer<float> harmonyBuffer(numChannels, numSamples);
    harmonyBuffer.clear();

    // Process each voice
    for (int v = 0; v < voiceCount && v < 4; ++v)
    {
        auto& voice = voices[v];
        if (!voice.active)
            continue;

        // Quantize interval to scale if needed
        int quantizedInterval = intervalQuantizer.quantizeInterval(voice.semitones);

        juce::AudioBuffer<float> voiceBuffer(numChannels, numSamples);

        for (int channel = 0; channel < juce::jmin(2, numChannels); ++channel)
        {
            auto* dryData = dryBuffer.getReadPointer(channel);
            auto* voiceData = voiceBuffer.getWritePointer(channel);

            // Temporarily update voice semitones
            int originalSemitones = voice.semitones;
            voice.semitones = quantizedInterval;

            for (int sample = 0; sample < numSamples; ++sample)
            {
                voiceData[sample] = voice.process(dryData[sample], channel);
            }

            // Restore original
            voice.semitones = originalSemitones;
        }

        // Mix voice into harmony buffer
        for (int ch = 0; ch < numChannels; ++ch)
            harmonyBuffer.addFrom(ch, 0, voiceBuffer, ch, 0, numSamples);
    }

    // Mix dry and harmony
    for (int ch = 0; ch < numChannels; ++ch)
    {
        auto* dry = dryBuffer.getReadPointer(ch);
        auto* harmony = harmonyBuffer.getReadPointer(ch);
        auto* out = buffer.getWritePointer(ch);

        for (int i = 0; i < numSamples; ++i)
            out[i] = dry[i] * (1.0f - currentMix) + (dry[i] * 0.3f + harmony[i]) * currentMix;
    }
}

//==============================================================================
void Harmonizer::setVoiceCount(int count)
{
    voiceCount = juce::jlimit(0, 4, count);

    // Activate/deactivate voices
    for (int i = 0; i < 4; ++i)
        voices[i].active = (i < voiceCount);
}

void Harmonizer::setVoiceInterval(int voiceIndex, int semitones)
{
    if (voiceIndex >= 0 && voiceIndex < 4)
    {
        voices[voiceIndex].semitones = juce::jlimit(-24, 24, semitones);
    }
}

void Harmonizer::setVoiceLevel(int voiceIndex, float level)
{
    if (voiceIndex >= 0 && voiceIndex < 4)
    {
        voices[voiceIndex].level = juce::jlimit(0.0f, 1.0f, level);
    }
}

void Harmonizer::setVoicePan(int voiceIndex, float pan)
{
    if (voiceIndex >= 0 && voiceIndex < 4)
    {
        voices[voiceIndex].pan = juce::jlimit(-1.0f, 1.0f, pan);
    }
}

void Harmonizer::setScaleMode(int mode)
{
    scaleMode = juce::jlimit(0, 2, mode);
    intervalQuantizer.scaleMode = mode;
    applyPresetIntervals();
}

void Harmonizer::setRootNote(int note)
{
    rootNote = juce::jlimit(0, 11, note);
    intervalQuantizer.rootNote = note;
}

void Harmonizer::setFormantPreservation(bool enabled)
{
    formantPreservation = enabled;
}

void Harmonizer::setMix(float mix)
{
    currentMix = juce::jlimit(0.0f, 1.0f, mix);
}
