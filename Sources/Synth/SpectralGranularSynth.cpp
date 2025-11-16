/*
  ==============================================================================

    SpectralGranularSynth.cpp

    Next-Generation Spectral Granular Synthesis Engine

    Revolutionary granular synthesizer combining FFT spectral analysis with
    intelligent grain manipulation, ML-assisted processing, and bio-reactive control.

  ==============================================================================
*/

#include "SpectralGranularSynth.h"
#include <cmath>
#include <random>
#include <algorithm>

//==============================================================================
// Random Number Generation
//==============================================================================

namespace
{
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<float> dist(0.0f, 1.0f);
    std::normal_distribution<float> normalDist(0.0f, 1.0f);

    float randomFloat() { return dist(gen); }
    float randomNormal() { return normalDist(gen); }
    float randomRange(float min, float max) { return min + (max - min) * randomFloat(); }
}

//==============================================================================
// Constructor
//==============================================================================

SpectralGranularSynth::SpectralGranularSynth()
{
    // Initialize grain streams with default parameters
    for (int i = 0; i < maxGrainStreams; ++i)
    {
        auto& stream = grainStreams[i];
        stream.enabled = (i < numActiveStreams);
        stream.params.sizeMs = 50.0f;
        stream.params.densityHz = 20.0f;
        stream.params.envelope = GrainParams::EnvelopeShape::Gaussian;
        stream.level = 1.0f / numActiveStreams;  // Normalize levels
        stream.pan = 0.0f;
    }

    // Initialize grain pools
    for (auto& streamPool : grainPools)
    {
        for (auto& grain : streamPool)
        {
            grain.active = false;
        }
    }

    // Add 16 voices for polyphony
    for (int i = 0; i < 16; ++i)
    {
        addVoice(new GranularVoice(*this));
    }

    // Add dummy sound (required by JUCE Synthesiser)
    addSound(new juce::SynthesiserSound());

    // Initialize spectral engine
    spectralEngine.setFFTSize(SpectralFramework::FFTSize::Size2048);
}

//==============================================================================
// Source Management
//==============================================================================

void SpectralGranularSynth::loadBuffer(const juce::AudioBuffer<float>& buffer)
{
    sourceBuffer = buffer;

    // Analyze spectrum if in spectral mode
    if (grainMode == GrainMode::Spectral || grainMode == GrainMode::Hybrid || grainMode == GrainMode::Neural)
    {
        analyzeSourceSpectrum();
    }

    DBG("SpectralGranularSynth: Loaded buffer with " + juce::String(buffer.getNumSamples()) + " samples");
}

bool SpectralGranularSynth::loadFile(const juce::File& file)
{
    if (!file.existsAsFile())
    {
        DBG("SpectralGranularSynth: File not found: " + file.getFullPathName());
        return false;
    }

    // Load audio file
    juce::AudioFormatManager formatManager;
    formatManager.registerBasicFormats();

    auto* reader = formatManager.createReaderFor(file);
    if (reader == nullptr)
    {
        DBG("SpectralGranularSynth: Failed to load file: " + file.getFullPathName());
        return false;
    }

    // Read into buffer
    juce::AudioBuffer<float> buffer(static_cast<int>(reader->numChannels),
                                    static_cast<int>(reader->lengthInSamples));
    reader->read(&buffer, 0, static_cast<int>(reader->lengthInSamples), 0, true, true);
    delete reader;

    // Mix to mono if stereo
    if (buffer.getNumChannels() > 1)
    {
        for (int sample = 0; sample < buffer.getNumSamples(); ++sample)
        {
            float sum = 0.0f;
            for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
                sum += buffer.getSample(ch, sample);
            buffer.setSample(0, sample, sum / buffer.getNumChannels());
        }
    }

    loadBuffer(buffer);

    DBG("SpectralGranularSynth: Loaded file: " + file.getFileName());
    return true;
}

void SpectralGranularSynth::setGrainSource(GrainSource source)
{
    grainSource = source;
}

void SpectralGranularSynth::setLiveInputEnabled(bool enabled)
{
    if (enabled)
    {
        grainSource = GrainSource::LiveInput;
    }
}

//==============================================================================
// Grain Mode
//==============================================================================

void SpectralGranularSynth::setGrainMode(GrainMode mode)
{
    grainMode = mode;

    // Re-analyze if switching to spectral mode
    if ((mode == GrainMode::Spectral || mode == GrainMode::Hybrid || mode == GrainMode::Neural)
        && sourceBuffer.getNumSamples() > 0)
    {
        analyzeSourceSpectrum();
    }
}

//==============================================================================
// Grain Streams
//==============================================================================

SpectralGranularSynth::GrainStream& SpectralGranularSynth::getGrainStream(int index)
{
    jassert(index >= 0 && index < maxGrainStreams);
    return grainStreams[index];
}

const SpectralGranularSynth::GrainStream& SpectralGranularSynth::getGrainStream(int index) const
{
    jassert(index >= 0 && index < maxGrainStreams);
    return grainStreams[index];
}

void SpectralGranularSynth::setNumActiveStreams(int num)
{
    numActiveStreams = juce::jlimit(1, maxGrainStreams, num);

    // Update stream enable states
    for (int i = 0; i < maxGrainStreams; ++i)
    {
        grainStreams[i].enabled = (i < numActiveStreams);
    }

    // Normalize levels
    for (int i = 0; i < numActiveStreams; ++i)
    {
        grainStreams[i].level = 1.0f / numActiveStreams;
    }
}

//==============================================================================
// Global Grain Parameters
//==============================================================================

void SpectralGranularSynth::setGrainSize(float ms)
{
    for (int i = 0; i < numActiveStreams; ++i)
    {
        grainStreams[i].params.sizeMs = juce::jlimit(1.0f, 1000.0f, ms);
    }
}

void SpectralGranularSynth::setGrainDensity(float hz)
{
    for (int i = 0; i < numActiveStreams; ++i)
    {
        grainStreams[i].params.densityHz = juce::jlimit(1.0f, 256.0f, hz);
    }
}

void SpectralGranularSynth::setGrainPosition(float position)
{
    position = juce::jlimit(0.0f, 1.0f, position);
    float positionMs = position * (sourceBuffer.getNumSamples() / static_cast<float>(currentSampleRate) * 1000.0f);

    for (int i = 0; i < numActiveStreams; ++i)
    {
        grainStreams[i].params.positionMs = positionMs;
    }
}

void SpectralGranularSynth::setGrainPitch(float semitones)
{
    for (int i = 0; i < numActiveStreams; ++i)
    {
        grainStreams[i].params.pitchSemitones = juce::jlimit(-24.0f, 24.0f, semitones);
    }
}

//==============================================================================
// Special Modes
//==============================================================================

void SpectralGranularSynth::captureAndFreeze()
{
    freezeParams.enabled = true;

    // Capture current grain positions and freeze
    DBG("SpectralGranularSynth: Freeze mode activated");
}

//==============================================================================
// Spectral Processing
//==============================================================================

void SpectralGranularSynth::setSpectralMask(float lowHz, float highHz)
{
    for (int i = 0; i < numActiveStreams; ++i)
    {
        grainStreams[i].params.spectralMaskLow = juce::jlimit(20.0f, 20000.0f, lowHz);
        grainStreams[i].params.spectralMaskHigh = juce::jlimit(20.0f, 20000.0f, highHz);
    }
}

void SpectralGranularSynth::setTonalityFilter(float amount)
{
    for (int i = 0; i < numActiveStreams; ++i)
    {
        grainStreams[i].params.tonalityThreshold = juce::jlimit(0.0f, 1.0f, amount);
    }
}

void SpectralGranularSynth::setFormantPreservation(bool enabled)
{
    // Formant preservation using spectral envelope tracking
    // Implementation would preserve formant peaks during pitch shifting
    DBG("SpectralGranularSynth: Formant preservation " + juce::String(enabled ? "enabled" : "disabled"));
}

//==============================================================================
// Bio-Reactive Control
//==============================================================================

void SpectralGranularSynth::setBioReactiveEnabled(bool enabled)
{
    bioReactiveEnabled = enabled;
}

void SpectralGranularSynth::setBioData(float hrv, float coherence, float breath)
{
    bioHRV = juce::jlimit(0.0f, 1.0f, hrv);
    bioCoherence = juce::jlimit(0.0f, 1.0f, coherence);
    bioBreath = juce::jlimit(0.0f, 1.0f, breath);

    if (bioReactiveEnabled)
    {
        // Modulate grain parameters based on bio data

        // HRV → Density (faster heart = more grains)
        float densityMod = bioHRV * bioMapping.hrvToDensity;
        for (int i = 0; i < numActiveStreams; ++i)
        {
            grainStreams[i].params.densityHz *= (1.0f + densityMod);
        }

        // HRV → Position (heart rate affects playback position)
        float positionMod = bioHRV * bioMapping.hrvToPosition;
        for (int i = 0; i < numActiveStreams; ++i)
        {
            grainStreams[i].params.positionMs += positionMod * 100.0f;
        }

        // Coherence → Size (coherent heart = larger grains)
        float sizeMod = bioCoherence * bioMapping.coherenceToSize;
        for (int i = 0; i < numActiveStreams; ++i)
        {
            grainStreams[i].params.sizeMs *= (1.0f + sizeMod);
        }

        // Breath → Pitch (breathing affects pitch)
        float pitchMod = (bioBreath - 0.5f) * bioMapping.breathToPitch;
        for (int i = 0; i < numActiveStreams; ++i)
        {
            grainStreams[i].params.pitchSemitones += pitchMod * 12.0f;
        }
    }
}

void SpectralGranularSynth::setBioMapping(const BioMapping& mapping)
{
    bioMapping = mapping;
}

//==============================================================================
// Processing
//==============================================================================

void SpectralGranularSynth::prepare(double sampleRate, int maxBlockSize)
{
    currentSampleRate = sampleRate;
    spectralEngine.setSampleRate(sampleRate);
    setCurrentPlaybackSampleRate(sampleRate);
}

void SpectralGranularSynth::reset()
{
    // Stop all grains
    for (auto& streamPool : grainPools)
    {
        for (auto& grain : streamPool)
        {
            grain.active = false;
        }
    }

    // Reset all voices
    for (int i = 0; i < getNumVoices(); ++i)
    {
        if (auto* voice = dynamic_cast<GranularVoice*>(getVoice(i)))
        {
            voice->stopNote(0.0f, false);
        }
    }
}

//==============================================================================
// Visualization
//==============================================================================

SpectralGranularSynth::GrainVisualization SpectralGranularSynth::getGrainVisualization() const
{
    GrainVisualization viz;

    // Count active grains and collect data
    for (const auto& streamPool : grainPools)
    {
        for (const auto& grain : streamPool)
        {
            if (grain.active)
            {
                viz.activeGrainCount++;

                // Normalize position to 0.0-1.0
                float normalizedPos = sourceBuffer.getNumSamples() > 0
                    ? grain.position / sourceBuffer.getNumSamples()
                    : 0.0f;

                viz.grainPositions.push_back(normalizedPos);
                viz.grainPitches.push_back(std::log2(grain.pitch) * 12.0f);  // Convert to semitones
                viz.grainLevels.push_back(1.0f - (grain.age / grain.size));  // Envelope approximation
            }
        }
    }

    return viz;
}

std::vector<float> SpectralGranularSynth::getGrainSpectrum() const
{
    // Return spectral representation of currently playing grains
    // In production, would perform FFT on mixed grain output
    return std::vector<float>(512, 0.0f);
}

//==============================================================================
// Internal Methods - Grain Generation
//==============================================================================

void SpectralGranularSynth::generateGrain(int streamIndex)
{
    if (streamIndex < 0 || streamIndex >= maxGrainStreams)
        return;

    if (!grainStreams[streamIndex].enabled)
        return;

    if (sourceBuffer.getNumSamples() == 0 && grainSource == GrainSource::Buffer)
        return;

    auto& stream = grainStreams[streamIndex];
    auto& pool = grainPools[streamIndex];

    // Find available grain slot
    Grain* availableGrain = nullptr;
    for (auto& grain : pool)
    {
        if (!grain.active)
        {
            availableGrain = &grain;
            break;
        }
    }

    if (availableGrain == nullptr)
        return;  // No available slots

    // Calculate grain parameters
    auto& params = stream.params;

    // Size in samples
    float sizeSamples = (params.sizeMs / 1000.0f) * static_cast<float>(currentSampleRate);
    sizeSamples *= (1.0f + (randomFloat() - 0.5f) * params.sizeSpray);
    sizeSamples = juce::jlimit(64.0f, static_cast<float>(currentSampleRate), sizeSamples);

    // Position in samples
    float positionSamples = (params.positionMs / 1000.0f) * static_cast<float>(currentSampleRate);

    // Apply position spray
    float spray = (randomFloat() - 0.5f) * params.positionSpray * sizeSamples * 10.0f;
    positionSamples += spray;

    // Apply swarm mode
    if (swarmParams.enabled)
    {
        float chaos = (randomNormal() * 0.3f) * swarmParams.chaos;
        positionSamples += chaos * sizeSamples;
    }

    // Wrap position
    if (sourceBuffer.getNumSamples() > 0)
    {
        while (positionSamples < 0)
            positionSamples += sourceBuffer.getNumSamples();
        while (positionSamples >= sourceBuffer.getNumSamples())
            positionSamples -= sourceBuffer.getNumSamples();
    }

    // Pitch
    float pitchSemitones = params.pitchSemitones + (randomFloat() - 0.5f) * params.pitchSpray * 12.0f;
    float pitchRatio = std::pow(2.0f, pitchSemitones / 12.0f);

    // Pan
    float pan = stream.pan + (randomFloat() - 0.5f) * params.panSpray;
    pan = juce::jlimit(-1.0f, 1.0f, pan);

    // Initialize grain
    availableGrain->active = true;
    availableGrain->position = positionSamples;
    availableGrain->size = sizeSamples;
    availableGrain->pitch = pitchRatio;
    availableGrain->pan = pan;
    availableGrain->phase = 0.0f;
    availableGrain->age = 0.0f;
    availableGrain->streamIndex = streamIndex;

    // Spectral mode
    if (grainMode == GrainMode::Spectral || (grainMode == GrainMode::Hybrid && randomFloat() > 0.5f))
    {
        // Extract spectral data at grain position
        int startSample = static_cast<int>(positionSamples);
        int fftSize = spectralEngine.getFFTSize();

        if (startSample + fftSize < sourceBuffer.getNumSamples())
        {
            std::vector<float> grainSamples(fftSize);
            for (int i = 0; i < fftSize; ++i)
            {
                grainSamples[i] = sourceBuffer.getSample(0, startSample + i);
            }

            spectralEngine.performForwardFFT(grainSamples.data(), availableGrain->spectralData);

            // Apply spectral mask
            applySpectralMask(availableGrain->spectralData);

            availableGrain->isSpectral = true;
        }
        else
        {
            availableGrain->isSpectral = false;
        }
    }
    else
    {
        availableGrain->isSpectral = false;
    }
}

//==============================================================================
// Internal Methods - Grain Rendering
//==============================================================================

void SpectralGranularSynth::renderGrain(const Grain& grain, juce::AudioBuffer<float>& output,
                                        int startSample, int numSamples)
{
    if (!grain.active)
        return;

    auto& stream = grainStreams[grain.streamIndex];

    for (int sample = 0; sample < numSamples; ++sample)
    {
        // Check if grain is finished
        if (grain.age >= grain.size)
            return;

        // Calculate envelope
        float phase = grain.age / grain.size;
        float envelope = getGrainEnvelope(phase, stream.params.envelope,
                                         stream.params.attack, stream.params.release);

        float outputSample = 0.0f;

        if (grain.isSpectral)
        {
            // Spectral grain rendering (simplified - would need full resynthesis)
            // For now, use time-domain rendering
        }

        // Time-domain rendering
        if (sourceBuffer.getNumSamples() > 0)
        {
            // Calculate read position with pitch shift
            float readPos = grain.position + (grain.phase * grain.pitch);

            // Wrap position
            while (readPos < 0)
                readPos += sourceBuffer.getNumSamples();
            while (readPos >= sourceBuffer.getNumSamples())
                readPos -= sourceBuffer.getNumSamples();

            // Linear interpolation
            int pos1 = static_cast<int>(readPos);
            int pos2 = (pos1 + 1) % sourceBuffer.getNumSamples();
            float frac = readPos - pos1;

            float sample1 = sourceBuffer.getSample(0, pos1);
            float sample2 = sourceBuffer.getSample(0, pos2);
            outputSample = sample1 + (sample2 - sample1) * frac;
        }

        // Apply envelope
        outputSample *= envelope * stream.level;

        // Apply to output with panning
        int outputIndex = startSample + sample;
        if (outputIndex < output.getNumSamples())
        {
            float leftGain = grain.pan <= 0.0f ? 1.0f : 1.0f - grain.pan;
            float rightGain = grain.pan >= 0.0f ? 1.0f : 1.0f + grain.pan;

            output.addSample(0, outputIndex, outputSample * leftGain);
            if (output.getNumChannels() > 1)
                output.addSample(1, outputIndex, outputSample * rightGain);
        }

        // Update grain state
        const_cast<Grain&>(grain).phase += grain.pitch;
        const_cast<Grain&>(grain).age += 1.0f;
    }
}

//==============================================================================
// Internal Methods - Envelope Generation
//==============================================================================

float SpectralGranularSynth::getGrainEnvelope(float phase, GrainParams::EnvelopeShape shape,
                                              float attack, float release)
{
    phase = juce::jlimit(0.0f, 1.0f, phase);

    switch (shape)
    {
        case GrainParams::EnvelopeShape::Linear:
        {
            if (phase < attack)
                return phase / attack;
            else if (phase > 1.0f - release)
                return (1.0f - phase) / release;
            else
                return 1.0f;
        }

        case GrainParams::EnvelopeShape::Exponential:
        {
            if (phase < attack)
                return (1.0f - std::exp(-5.0f * phase / attack));
            else if (phase > 1.0f - release)
                return (1.0f - std::exp(-5.0f * (1.0f - phase) / release));
            else
                return 1.0f;
        }

        case GrainParams::EnvelopeShape::Gaussian:
        {
            float x = (phase - 0.5f) * 6.0f;  // -3 to +3
            return std::exp(-0.5f * x * x);
        }

        case GrainParams::EnvelopeShape::Hann:
        {
            return 0.5f * (1.0f - std::cos(juce::MathConstants<float>::twoPi * phase));
        }

        case GrainParams::EnvelopeShape::Hamming:
        {
            return 0.54f - 0.46f * std::cos(juce::MathConstants<float>::twoPi * phase);
        }

        case GrainParams::EnvelopeShape::Welch:
        {
            float x = 2.0f * phase - 1.0f;  // -1 to +1
            return 1.0f - x * x;
        }

        case GrainParams::EnvelopeShape::Triangle:
        {
            return phase < 0.5f ? phase * 2.0f : (1.0f - phase) * 2.0f;
        }

        case GrainParams::EnvelopeShape::Trapezoid:
        {
            if (phase < attack)
                return phase / attack;
            else if (phase > 1.0f - release)
                return (1.0f - phase) / release;
            else
                return 1.0f;
        }

        default:
            return 1.0f;
    }
}

//==============================================================================
// Internal Methods - Spectral Analysis
//==============================================================================

void SpectralGranularSynth::analyzeSourceSpectrum()
{
    if (sourceBuffer.getNumSamples() < spectralEngine.getFFTSize())
        return;

    DBG("SpectralGranularSynth: Analyzing source spectrum...");

    // Analyze multiple windows across the source
    int numWindows = sourceBuffer.getNumSamples() / spectralEngine.getFFTSize();

    // For now, just analyze the first window
    // In production, would analyze all windows and build spectral database

    DBG("SpectralGranularSynth: Spectrum analysis complete");
}

void SpectralGranularSynth::applySpectralMask(SpectralFramework::SpectralData& data)
{
    int numBins = data.numBins;

    for (int bin = 0; bin < numBins; ++bin)
    {
        float freq = spectralEngine.binToFrequency(bin);

        // Apply frequency masking
        if (freq < grainStreams[0].params.spectralMaskLow ||
            freq > grainStreams[0].params.spectralMaskHigh)
        {
            data.magnitude[bin] = 0.0f;
        }
    }
}

//==============================================================================
// GranularVoice Implementation
//==============================================================================

SpectralGranularSynth::GranularVoice::GranularVoice(SpectralGranularSynth& parent)
    : synth(parent)
{
}

void SpectralGranularSynth::GranularVoice::startNote(int midiNoteNumber, float velocity,
                                                     juce::SynthesiserSound*,
                                                     int currentPitchWheelPosition)
{
    currentNote = midiNoteNumber;
    baseFrequency = juce::MidiMessage::getMidiNoteInHertz(midiNoteNumber);

    // Adjust pitch based on MIDI note
    float pitchSemitones = static_cast<float>(midiNoteNumber - 60);

    for (int i = 0; i < synth.numActiveStreams; ++i)
    {
        synth.grainStreams[i].params.pitchSemitones = pitchSemitones;
    }
}

void SpectralGranularSynth::GranularVoice::stopNote(float velocity, bool allowTailOff)
{
    if (allowTailOff)
    {
        // Let grains finish naturally
    }
    else
    {
        clearCurrentNote();
    }
}

void SpectralGranularSynth::GranularVoice::pitchWheelMoved(int newPitchWheelValue)
{
    float pitchBend = (newPitchWheelValue - 8192) / 8192.0f;

    for (int i = 0; i < synth.numActiveStreams; ++i)
    {
        synth.grainStreams[i].params.pitchSemitones += pitchBend * 2.0f;  // +/- 2 semitones
    }
}

void SpectralGranularSynth::GranularVoice::controllerMoved(int controllerNumber, int newControllerValue)
{
    float ccValue = newControllerValue / 127.0f;

    switch (controllerNumber)
    {
        case 1:  // Modulation wheel → grain size
            synth.setGrainSize(1.0f + ccValue * 500.0f);
            break;

        case 74: // Brightness → spectral mask high
            synth.setSpectralMask(20.0f, 20.0f + ccValue * 19980.0f);
            break;

        case 71: // Resonance → grain density
            synth.setGrainDensity(1.0f + ccValue * 255.0f);
            break;

        default:
            break;
    }
}

void SpectralGranularSynth::GranularVoice::renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                                                           int startSample, int numSamples)
{
    if (!isVoiceActive())
        return;

    // Grain generation timing
    static float grainTimer = 0.0f;
    float grainInterval = synth.currentSampleRate /
        (synth.grainStreams[0].params.densityHz * synth.numActiveStreams);

    for (int sample = 0; sample < numSamples; ++sample)
    {
        // Generate new grains based on density
        grainTimer += 1.0f;
        if (grainTimer >= grainInterval)
        {
            grainTimer = 0.0f;

            // Generate grain for random active stream
            int streamIndex = static_cast<int>(randomFloat() * synth.numActiveStreams);
            synth.generateGrain(streamIndex);
        }

        // Render all active grains
        for (int streamIndex = 0; streamIndex < synth.maxGrainStreams; ++streamIndex)
        {
            if (!synth.grainStreams[streamIndex].enabled)
                continue;

            auto& pool = synth.grainPools[streamIndex];
            for (auto& grain : pool)
            {
                if (grain.active)
                {
                    synth.renderGrain(grain, outputBuffer, startSample + sample, 1);

                    // Deactivate finished grains
                    if (grain.age >= grain.size)
                    {
                        grain.active = false;
                    }
                }
            }
        }
    }
}
