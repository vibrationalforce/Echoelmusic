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

    // ✅ OPTIMIZATION: Pre-allocate buffers to avoid audio thread allocation
    dryBuffer.setSize(2, maximumBlockSize);
    dryBuffer.clear();
    harmonyBuffer.setSize(2, maximumBlockSize);
    harmonyBuffer.clear();
    for (auto& voiceBuf : voiceBuffers)
    {
        voiceBuf.setSize(2, maximumBlockSize);
        voiceBuf.clear();
    }

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

    // ✅ OPTIMIZATION: Use pre-allocated buffers (no audio thread allocation)
    const int safeChannels = juce::jmin(numChannels, 2);

    // Store dry signal
    for (int ch = 0; ch < safeChannels; ++ch)
        dryBuffer.copyFrom(ch, 0, buffer, ch, 0, numSamples);

    // Clear harmony buffer
    harmonyBuffer.clear();

    // Process each voice
    for (int v = 0; v < voiceCount && v < 4; ++v)
    {
        auto& voice = voices[v];
        if (!voice.active)
            continue;

        // Quantize interval to scale if needed
        int quantizedInterval = intervalQuantizer.quantizeInterval(voice.semitones);

        // ✅ OPTIMIZATION: Use pre-allocated voice buffer
        auto& voiceBuffer = voiceBuffers[v];

        for (int channel = 0; channel < safeChannels; ++channel)
        {
            const auto* dryData = dryBuffer.getReadPointer(channel);
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

        // Mix voice into harmony buffer using SIMD
        for (int ch = 0; ch < safeChannels; ++ch)
            juce::FloatVectorOperations::add(harmonyBuffer.getWritePointer(ch),
                                              voiceBuffer.getReadPointer(ch), numSamples);
    }

    // Mix dry and harmony with SIMD optimization
    for (int ch = 0; ch < safeChannels; ++ch)
    {
        const auto* dry = dryBuffer.getReadPointer(ch);
        const auto* harmony = harmonyBuffer.getReadPointer(ch);
        auto* out = buffer.getWritePointer(ch);

        // ✅ OPTIMIZATION: SIMD mixing
        // out = dry * (1-mix) + (dry * 0.3 + harmony) * mix
        //     = dry * (1-mix + 0.3*mix) + harmony * mix
        //     = dry * (1 - 0.7*mix) + harmony * mix
        const float dryGain = 1.0f - 0.7f * currentMix;
        const float harmonyGain = currentMix;

        juce::FloatVectorOperations::copyWithMultiply(out, dry, dryGain, numSamples);
        juce::FloatVectorOperations::addWithMultiply(out, harmony, harmonyGain, numSamples);
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
