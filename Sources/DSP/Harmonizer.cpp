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

    // Pre-allocate buffers (avoid per-frame allocations)
    dryBuffer.setSize(2, maximumBlockSize);
    harmonyBuffer.setSize(2, maximumBlockSize);
    for (auto& buf : voiceBuffers)
        buf.setSize(2, maximumBlockSize);

    // Prepare all voices
    for (auto& voice : voices)
        voice.prepare(spec);

    // Cache pan gains
    updatePanGains();

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

    // Ensure buffers are large enough (resize only if needed - rare path)
    if (dryBuffer.getNumSamples() < numSamples)
    {
        dryBuffer.setSize(2, numSamples, false, false, true);
        harmonyBuffer.setSize(2, numSamples, false, false, true);
        for (auto& buf : voiceBuffers)
            buf.setSize(2, numSamples, false, false, true);
    }

    // Store dry signal (use pre-allocated buffer)
    for (int ch = 0; ch < juce::jmin(2, numChannels); ++ch)
        dryBuffer.copyFrom(ch, 0, buffer, ch, 0, numSamples);

    // Clear harmony buffer
    harmonyBuffer.clear();

    // Process each voice using pre-allocated buffers
    for (int v = 0; v < voiceCount && v < 4; ++v)
    {
        auto& voice = voices[v];
        if (!voice.active)
            continue;

        // Quantize interval to scale if needed
        int quantizedInterval = intervalQuantizer.quantizeInterval(voice.semitones);

        // Use pre-allocated voice buffer
        auto& voiceBuffer = voiceBuffers[static_cast<size_t>(v)];

        // Get cached pan gains
        const float panGainL = voicePanGainsL[static_cast<size_t>(v)] * voice.level;
        const float panGainR = voicePanGainsR[static_cast<size_t>(v)] * voice.level;

        for (int channel = 0; channel < juce::jmin(2, numChannels); ++channel)
        {
            const auto* dryData = dryBuffer.getReadPointer(channel);
            auto* voiceData = voiceBuffer.getWritePointer(channel);
            const float panGain = (channel == 0) ? panGainL : panGainR;

            // Temporarily update voice semitones
            int originalSemitones = voice.semitones;
            voice.semitones = quantizedInterval;

            for (int sample = 0; sample < numSamples; ++sample)
            {
                // Process without pan (pan applied via cached gain)
                voiceData[sample] = voice.processNoPan(dryData[sample], channel) * panGain;
            }

            // Restore original
            voice.semitones = originalSemitones;
        }

        // Mix voice into harmony buffer using SIMD
        for (int ch = 0; ch < juce::jmin(2, numChannels); ++ch)
        {
            juce::FloatVectorOperations::add(
                harmonyBuffer.getWritePointer(ch),
                voiceBuffer.getReadPointer(ch),
                numSamples);
        }
    }

    // Mix dry and harmony using SIMD
    const float dryGain = 1.0f - currentMix + currentMix * 0.3f;
    const float wetGain = currentMix;

    for (int ch = 0; ch < juce::jmin(2, numChannels); ++ch)
    {
        auto* out = buffer.getWritePointer(ch);
        const auto* dry = dryBuffer.getReadPointer(ch);
        const auto* harmony = harmonyBuffer.getReadPointer(ch);

        juce::FloatVectorOperations::copyWithMultiply(out, dry, dryGain, numSamples);
        juce::FloatVectorOperations::addWithMultiply(out, harmony, wetGain, numSamples);
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
        updatePanGains();  // Recache pan gains when pan changes
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
