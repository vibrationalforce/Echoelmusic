#include "RhythmMatrix.h"
#include "../Core/DSPOptimizations.h"

//==============================================================================
// Constructor
//==============================================================================

RhythmMatrix::RhythmMatrix()
{
    // Initialize default pad names
    for (int i = 0; i < 16; ++i)
    {
        pads[i].name = "Pad " + juce::String(i + 1);
    }

    // Allocate voice pool
    voices.resize(maxVoices);
}

//==============================================================================
// Pad Management
//==============================================================================

RhythmMatrix::Pad& RhythmMatrix::getPad(int index)
{
    jassert(index >= 0 && index < 16);
    return pads[index];
}

const RhythmMatrix::Pad& RhythmMatrix::getPad(int index) const
{
    jassert(index >= 0 && index < 16);
    return pads[index];
}

void RhythmMatrix::setPad(int index, const Pad& pad)
{
    jassert(index >= 0 && index < 16);
    pads[index] = pad;
}

//==============================================================================
// Sample Loading
//==============================================================================

bool RhythmMatrix::loadSample(int padIndex, const juce::File& file)
{
    if (padIndex < 0 || padIndex >= 16 || !file.existsAsFile())
        return false;

    juce::AudioFormatManager formatManager;
    formatManager.registerBasicFormats();

    std::unique_ptr<juce::AudioFormatReader> reader(formatManager.createReaderFor(file));
    if (reader == nullptr)
        return false;

    // Create new layer
    SampleLayer layer;
    layer.filePath = file.getFullPathName();
    layer.velocityMin = 0;
    layer.velocityMax = 127;

    // Load audio data
    layer.audioData.setSize(static_cast<int>(reader->numChannels),
                           static_cast<int>(reader->lengthInSamples));

    reader->read(&layer.audioData, 0, static_cast<int>(reader->lengthInSamples), 0, true, true);

    // Add to pad
    auto& pad = pads[padIndex];
    if (pad.layers.empty())
    {
        pad.layers.push_back(std::move(layer));
    }
    else
    {
        // Replace first layer
        pad.layers[0] = std::move(layer);
    }

    return true;
}

bool RhythmMatrix::loadSampleToLayer(int padIndex, int layerIndex, const juce::File& file,
                                     int velocityMin, int velocityMax)
{
    if (padIndex < 0 || padIndex >= 16 || !file.existsAsFile())
        return false;

    juce::AudioFormatManager formatManager;
    formatManager.registerBasicFormats();

    std::unique_ptr<juce::AudioFormatReader> reader(formatManager.createReaderFor(file));
    if (reader == nullptr)
        return false;

    // Create layer
    SampleLayer layer;
    layer.filePath = file.getFullPathName();
    layer.velocityMin = juce::jlimit(0, 127, velocityMin);
    layer.velocityMax = juce::jlimit(0, 127, velocityMax);

    // Load audio data
    layer.audioData.setSize(static_cast<int>(reader->numChannels),
                           static_cast<int>(reader->lengthInSamples));

    reader->read(&layer.audioData, 0, static_cast<int>(reader->lengthInSamples), 0, true, true);

    // Add to pad
    auto& pad = pads[padIndex];
    if (layerIndex >= 0 && layerIndex < static_cast<int>(pad.layers.size()))
    {
        pad.layers[layerIndex] = std::move(layer);
    }
    else
    {
        pad.layers.push_back(std::move(layer));
    }

    return true;
}

void RhythmMatrix::clearPad(int padIndex)
{
    if (padIndex >= 0 && padIndex < 16)
    {
        pads[padIndex].layers.clear();
    }
}

void RhythmMatrix::autoSlice(const juce::File& file, int numSlices, int startPad)
{
    if (!file.existsAsFile() || numSlices < 1 || startPad < 0)
        return;

    juce::AudioFormatManager formatManager;
    formatManager.registerBasicFormats();

    std::unique_ptr<juce::AudioFormatReader> reader(formatManager.createReaderFor(file));
    if (reader == nullptr)
        return;

    // Load full audio
    juce::AudioBuffer<float> fullAudio(static_cast<int>(reader->numChannels),
                                       static_cast<int>(reader->lengthInSamples));

    reader->read(&fullAudio, 0, static_cast<int>(reader->lengthInSamples), 0, true, true);

    // Calculate slice length
    const int sliceLength = fullAudio.getNumSamples() / numSlices;

    // Create slices
    for (int i = 0; i < numSlices && (startPad + i) < 16; ++i)
    {
        const int startSample = i * sliceLength;
        const int endSample = juce::jmin((i + 1) * sliceLength, fullAudio.getNumSamples());
        const int length = endSample - startSample;

        if (length <= 0)
            continue;

        // Create layer with slice
        SampleLayer layer;
        layer.filePath = file.getFullPathName() + " [Slice " + juce::String(i + 1) + "]";
        layer.velocityMin = 0;
        layer.velocityMax = 127;

        layer.audioData.setSize(fullAudio.getNumChannels(), length);
        for (int ch = 0; ch < fullAudio.getNumChannels(); ++ch)
        {
            layer.audioData.copyFrom(ch, 0, fullAudio, ch, startSample, length);
        }

        // Add to pad
        auto& pad = pads[startPad + i];
        pad.layers.clear();
        pad.layers.push_back(std::move(layer));
        pad.name = "Slice " + juce::String(i + 1);
    }
}

//==============================================================================
// Playback Control
//==============================================================================

void RhythmMatrix::triggerPad(int padIndex, float velocity)
{
    if (padIndex < 0 || padIndex >= 16)
        return;

    auto& pad = pads[padIndex];

    // Check mute/solo
    if (pad.muted || (anySoloed && !pad.soloed))
        return;

    // Handle choke groups
    if (pad.chokeGroup > 0)
    {
        handleChokeGroups(padIndex);
    }

    // Allocate voice
    Voice* voice = allocateVoice(padIndex, velocity);
    if (voice == nullptr)
        return;

    // Start playback
    voice->active = true;
    voice->playbackPosition = pad.startPoint * pad.layers[voice->layerIndex].audioData.getNumSamples();
    voice->velocity = velocity;
    voice->envelopeStage = Voice::EnvelopeStage::Attack;
    voice->envelopeValue = 0.0f;
    voice->filterZ1 = 0.0f;
    voice->filterZ2 = 0.0f;
}

void RhythmMatrix::stopPad(int padIndex)
{
    if (padIndex < 0 || padIndex >= 16)
        return;

    // Move all voices for this pad to release stage
    for (auto& voice : voices)
    {
        if (voice.active && voice.padIndex == padIndex)
        {
            voice.envelopeStage = Voice::EnvelopeStage::Release;
        }
    }
}

void RhythmMatrix::stopAll()
{
    for (auto& voice : voices)
    {
        if (voice.active)
        {
            voice.envelopeStage = Voice::EnvelopeStage::Release;
        }
    }
}

bool RhythmMatrix::isPadPlaying(int padIndex) const
{
    if (padIndex < 0 || padIndex >= 16)
        return false;

    for (const auto& voice : voices)
    {
        if (voice.active && voice.padIndex == padIndex &&
            voice.envelopeStage != Voice::EnvelopeStage::Off)
        {
            return true;
        }
    }

    return false;
}

//==============================================================================
// Mute/Solo
//==============================================================================

void RhythmMatrix::setPadMuted(int padIndex, bool muted)
{
    if (padIndex >= 0 && padIndex < 16)
    {
        pads[padIndex].muted = muted;
    }
}

void RhythmMatrix::setPadSoloed(int padIndex, bool soloed)
{
    if (padIndex >= 0 && padIndex < 16)
    {
        pads[padIndex].soloed = soloed;

        // Update solo state
        anySoloed = false;
        for (const auto& pad : pads)
        {
            if (pad.soloed)
            {
                anySoloed = true;
                break;
            }
        }
    }
}

void RhythmMatrix::clearAllSolo()
{
    for (auto& pad : pads)
    {
        pad.soloed = false;
    }
    anySoloed = false;
}

//==============================================================================
// Bio-Reactive Triggering
//==============================================================================

void RhythmMatrix::setBioData(float hrv, float coherence)
{
    bioHRV = juce::jlimit(0.0f, 1.0f, hrv);
    bioCoherence = juce::jlimit(0.0f, 1.0f, coherence);
}

void RhythmMatrix::setBioReactiveTrigger(bool enabled)
{
    bioReactiveTrigger = enabled;
}

//==============================================================================
// Processing
//==============================================================================

void RhythmMatrix::prepare(double sampleRate, int maxBlockSize)
{
    juce::ignoreUnused(maxBlockSize);
    currentSampleRate = sampleRate;
}

void RhythmMatrix::reset()
{
    for (auto& voice : voices)
    {
        voice.active = false;
        voice.envelopeStage = Voice::EnvelopeStage::Off;
    }
}

void RhythmMatrix::process(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();

    // Bio-reactive auto-triggering
    if (bioReactiveTrigger)
    {
        updateBioReactiveTrigger();
    }

    // Process all active voices
    for (auto& voice : voices)
    {
        if (voice.active)
        {
            processVoice(voice, buffer, 0, numSamples);
        }
    }
}

//==============================================================================
// Visualization
//==============================================================================

std::vector<float> RhythmMatrix::getPadWaveform(int padIndex) const
{
    std::vector<float> waveform;

    if (padIndex < 0 || padIndex >= 16)
        return waveform;

    const auto& pad = pads[padIndex];
    if (pad.layers.empty())
        return waveform;

    const auto& layer = pad.layers[0];
    const int numSamples = layer.audioData.getNumSamples();

    if (numSamples == 0)
        return waveform;

    // Downsample to 1024 points for visualization
    waveform.resize(1024);
    const float ratio = numSamples / 1024.0f;

    for (int i = 0; i < 1024; ++i)
    {
        int srcIndex = static_cast<int>(i * ratio);
        srcIndex = juce::jlimit(0, numSamples - 1, srcIndex);

        // Get average of all channels
        float sum = 0.0f;
        for (int ch = 0; ch < layer.audioData.getNumChannels(); ++ch)
        {
            sum += layer.audioData.getSample(ch, srcIndex);
        }
        waveform[i] = sum / layer.audioData.getNumChannels();
    }

    return waveform;
}

float RhythmMatrix::getPadPlaybackPosition(int padIndex) const
{
    if (padIndex < 0 || padIndex >= 16)
        return 0.0f;

    // Find first active voice for this pad
    for (const auto& voice : voices)
    {
        if (voice.active && voice.padIndex == padIndex)
        {
            const auto& pad = pads[padIndex];
            if (pad.layers.empty() || voice.layerIndex >= static_cast<int>(pad.layers.size()))
                return 0.0f;

            const auto& layer = pad.layers[voice.layerIndex];
            return static_cast<float>(voice.playbackPosition) / layer.audioData.getNumSamples();
        }
    }

    return 0.0f;
}

//==============================================================================
// Internal Methods
//==============================================================================

RhythmMatrix::Voice* RhythmMatrix::allocateVoice(int padIndex, float velocity)
{
    auto& pad = pads[padIndex];

    if (pad.layers.empty())
        return nullptr;

    // Find appropriate velocity layer
    int layerIndex = 0;
    const int velocityMIDI = static_cast<int>(velocity * 127.0f);

    for (size_t i = 0; i < pad.layers.size(); ++i)
    {
        const auto& layer = pad.layers[i];
        if (velocityMIDI >= layer.velocityMin && velocityMIDI <= layer.velocityMax)
        {
            layerIndex = static_cast<int>(i);
            break;
        }
    }

    // Find free voice
    Voice* freeVoice = nullptr;
    for (auto& voice : voices)
    {
        if (!voice.active || voice.envelopeStage == Voice::EnvelopeStage::Off)
        {
            freeVoice = &voice;
            break;
        }
    }

    // Steal oldest voice if none available
    if (freeVoice == nullptr)
    {
        freeVoice = &voices[0];
    }

    freeVoice->padIndex = padIndex;
    freeVoice->layerIndex = layerIndex;

    return freeVoice;
}

void RhythmMatrix::processVoice(Voice& voice, juce::AudioBuffer<float>& buffer,
                                int startSample, int numSamples)
{
    const auto& pad = pads[voice.padIndex];

    if (voice.layerIndex >= static_cast<int>(pad.layers.size()))
    {
        voice.active = false;
        return;
    }

    const auto& layer = pad.layers[voice.layerIndex];
    const int layerNumSamples = layer.audioData.getNumSamples();
    const int layerNumChannels = layer.audioData.getNumChannels();

    if (layerNumSamples == 0)
    {
        voice.active = false;
        return;
    }

    for (int i = 0; i < numSamples; ++i)
    {
        // Update envelope
        updateEnvelope(voice, pad);

        // Check if voice finished
        if (voice.envelopeStage == Voice::EnvelopeStage::Off)
        {
            voice.active = false;
            break;
        }

        // Read sample for each channel
        for (int ch = 0; ch < juce::jmin(buffer.getNumChannels(), 2); ++ch)
        {
            float sample = processSample(voice, ch % layerNumChannels);

            // Apply filter
            if (pad.filterEnabled)
            {
                sample = applyFilter(voice, pad, sample);
            }

            // Apply envelope
            sample *= voice.envelopeValue;

            // Apply level and pan
            float panGain = (ch == 0) ? (1.0f - pad.pan) : pad.pan;
            sample *= pad.level * panGain;

            // Add to buffer
            buffer.addSample(ch, startSample + i, sample);
        }

        // Advance playback position
        float pitchRatio = std::pow(2.0f, pad.pitch / 12.0f + pad.fineTune / 1200.0f);
        voice.playbackPosition += pitchRatio * (pad.reverse ? -1.0 : 1.0);

        // Check bounds
        float endPosition = pad.endPoint * layerNumSamples;
        float startPosition = pad.startPoint * layerNumSamples;

        if (pad.oneShot)
        {
            if (voice.playbackPosition >= endPosition || voice.playbackPosition < startPosition)
            {
                voice.envelopeStage = Voice::EnvelopeStage::Release;
            }
        }
        else
        {
            // Loop
            if (voice.playbackPosition >= endPosition)
                voice.playbackPosition = startPosition;
            else if (voice.playbackPosition < startPosition)
                voice.playbackPosition = endPosition;
        }
    }
}

float RhythmMatrix::processSample(Voice& voice, int channel)
{
    const auto& pad = pads[voice.padIndex];
    const auto& layer = pad.layers[voice.layerIndex];

    int sampleIndex = static_cast<int>(voice.playbackPosition);
    sampleIndex = juce::jlimit(0, layer.audioData.getNumSamples() - 1, sampleIndex);

    // Linear interpolation
    float frac = voice.playbackPosition - sampleIndex;
    int nextIndex = juce::jmin(sampleIndex + 1, layer.audioData.getNumSamples() - 1);

    float sample1 = layer.audioData.getSample(channel, sampleIndex);
    float sample2 = layer.audioData.getSample(channel, nextIndex);

    return sample1 + (sample2 - sample1) * frac;
}

void RhythmMatrix::updateEnvelope(Voice& voice, const Pad& pad)
{
    const float sampleRate = static_cast<float>(currentSampleRate);

    switch (voice.envelopeStage)
    {
        case Voice::EnvelopeStage::Attack:
            voice.envelopeValue += 1.0f / (pad.attack * sampleRate);
            if (voice.envelopeValue >= 1.0f)
            {
                voice.envelopeValue = 1.0f;
                voice.envelopeStage = Voice::EnvelopeStage::Decay;
            }
            break;

        case Voice::EnvelopeStage::Decay:
            voice.envelopeValue -= (1.0f - pad.sustain) / (pad.decay * sampleRate);
            if (voice.envelopeValue <= pad.sustain)
            {
                voice.envelopeValue = pad.sustain;
                voice.envelopeStage = Voice::EnvelopeStage::Sustain;
            }
            break;

        case Voice::EnvelopeStage::Sustain:
            voice.envelopeValue = pad.sustain;
            break;

        case Voice::EnvelopeStage::Release:
            voice.envelopeValue -= voice.envelopeValue / (pad.release * sampleRate);
            if (voice.envelopeValue <= 0.001f)
            {
                voice.envelopeValue = 0.0f;
                voice.envelopeStage = Voice::EnvelopeStage::Off;
            }
            break;

        case Voice::EnvelopeStage::Off:
            voice.envelopeValue = 0.0f;
            break;
    }
}

float RhythmMatrix::applyFilter(Voice& voice, const Pad& pad, float input)
{
    // Simple lowpass filter (biquad) - OPTIMIZED with fast trig
    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
    const float omega = juce::MathConstants<float>::twoPi * pad.filterCutoff / static_cast<float>(currentSampleRate);
    const float q = 0.707f + pad.filterResonance * 9.0f;
    const float sinOmega = trigTables.fastSinRad(omega);
    const float cosOmega = trigTables.fastCosRad(omega);
    const float alpha = sinOmega / (2.0f * q);

    const float b0 = (1.0f - cosOmega) / 2.0f;
    const float b1 = 1.0f - cosOmega;
    const float b2 = (1.0f - cosOmega) / 2.0f;
    const float a0 = 1.0f + alpha;
    const float a1 = -2.0f * cosOmega;
    const float a2 = 1.0f - alpha;

    // Direct form 2
    float output = (b0 / a0) * input + voice.filterZ1;
    voice.filterZ1 = (b1 / a0) * input - (a1 / a0) * output + voice.filterZ2;
    voice.filterZ2 = (b2 / a0) * input - (a2 / a0) * output;

    return output;
}

void RhythmMatrix::handleChokeGroups(int padIndex)
{
    const auto& pad = pads[padIndex];

    if (pad.chokeGroup == 0)
        return;

    // Stop all voices in the same choke group
    for (auto& voice : voices)
    {
        if (voice.active && voice.padIndex != padIndex)
        {
            const auto& otherPad = pads[voice.padIndex];
            if (otherPad.chokeGroup == pad.chokeGroup)
            {
                voice.envelopeStage = Voice::EnvelopeStage::Release;
            }
        }
    }
}

void RhythmMatrix::updateBioReactiveTrigger()
{
    // Bio-reactive auto-triggering based on HRV and Coherence
    const float triggerRate = bioHRV * 10.0f;  // 0-10 Hz
    const float sampleRate = static_cast<float>(currentSampleRate);

    bioTriggerPhase += triggerRate / sampleRate;

    if (bioTriggerPhase >= 1.0f)
    {
        bioTriggerPhase -= 1.0f;

        // Trigger random pad based on coherence
        int padIndex = static_cast<int>(bioCoherence * 15.0f);
        float velocity = 0.5f + bioHRV * 0.5f;  // 0.5 to 1.0

        triggerPad(padIndex, velocity);
    }
}
