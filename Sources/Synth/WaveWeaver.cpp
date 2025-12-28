#include "WaveWeaver.h"
#include "../Core/DSPOptimizations.h"

//==============================================================================
// Constructor
//==============================================================================

WaveWeaver::WaveWeaver()
{
    // Initialize default wavetables
    initializeDefaultWavetables();

    // Add voices
    for (int i = 0; i < 16; ++i)
    {
        addVoice(new WaveWeaverVoice(*this));
    }

    // Add a sound that responds to all notes
    addSound(new WaveWeaverSound());
}

//==============================================================================
// Wavetable Management
//==============================================================================

bool WaveWeaver::loadWavetable(const juce::File& file, int slot)
{
    if (!file.existsAsFile())
        return false;

    juce::AudioFormatManager formatManager;
    formatManager.registerBasicFormats();

    std::unique_ptr<juce::AudioFormatReader> reader(formatManager.createReaderFor(file));
    if (reader == nullptr)
        return false;

    // Create wavetable
    auto wavetable = std::make_unique<Wavetable>();
    wavetable->name = file.getFileNameWithoutExtension();

    // Load audio data and split into frames
    const int totalSamples = wavetableSize * wavetableFrames;
    std::vector<float> audioData(static_cast<size_t>(reader->lengthInSamples));

    reader->read(&audioData, 0, static_cast<int>(reader->lengthInSamples), 0, true, false);

    // Resample/reshape into wavetable format
    for (int frame = 0; frame < wavetableFrames; ++frame)
    {
        for (int i = 0; i < wavetableSize; ++i)
        {
            int srcIndex = static_cast<int>((frame * wavetableSize + i) *
                                            reader->lengthInSamples / totalSamples);
            srcIndex = juce::jlimit(0, static_cast<int>(audioData.size()) - 1, srcIndex);

            wavetable->data[frame * wavetableSize + i] = audioData[srcIndex];
        }
    }

    // Add to collection
    if (slot >= 0 && slot < static_cast<int>(wavetables.size()))
    {
        wavetables[slot] = std::move(wavetable);
    }
    else
    {
        wavetables.push_back(std::move(wavetable));
    }

    return true;
}

void WaveWeaver::generateWavetable(int slot, std::function<float(float)> waveformFunc)
{
    auto wavetable = std::make_unique<Wavetable>();
    wavetable->name = "Custom";

    // Generate waveforms
    for (int frame = 0; frame < wavetableFrames; ++frame)
    {
        for (int i = 0; i < wavetableSize; ++i)
        {
            float phase = static_cast<float>(i) / wavetableSize;
            wavetable->data[frame * wavetableSize + i] = waveformFunc(phase);
        }
    }

    // Add to collection
    if (slot >= 0 && slot < static_cast<int>(wavetables.size()))
    {
        wavetables[slot] = std::move(wavetable);
    }
    else
    {
        wavetables.push_back(std::move(wavetable));
    }
}

//==============================================================================
// Oscillator Parameters
//==============================================================================

WaveWeaver::Oscillator& WaveWeaver::getOscillator(int index)
{
    jassert(index >= 0 && index < 2);
    return oscillators[index];
}

const WaveWeaver::Oscillator& WaveWeaver::getOscillator(int index) const
{
    jassert(index >= 0 && index < 2);
    return oscillators[index];
}

void WaveWeaver::setOscillator(int index, const Oscillator& osc)
{
    jassert(index >= 0 && index < 2);
    oscillators[index] = osc;
}

//==============================================================================
// Sub Oscillator / Noise
//==============================================================================

void WaveWeaver::setSubOscillatorEnabled(bool enabled)
{
    subEnabled = enabled;
}

void WaveWeaver::setSubOscillatorLevel(float level)
{
    subLevel = juce::jlimit(0.0f, 1.0f, level);
}

void WaveWeaver::setSubOscillatorOctave(int octave)
{
    subOctave = juce::jlimit(-2, -1, octave);
}

void WaveWeaver::setNoiseEnabled(bool enabled)
{
    noiseEnabled = enabled;
}

void WaveWeaver::setNoiseLevel(float level)
{
    noiseLevel = juce::jlimit(0.0f, 1.0f, level);
}

void WaveWeaver::setNoiseColor(float color)
{
    noiseColor = juce::jlimit(0.0f, 1.0f, color);
}

//==============================================================================
// Filter Parameters
//==============================================================================

WaveWeaver::Filter& WaveWeaver::getFilter(int index)
{
    jassert(index >= 0 && index < 2);
    return filters[index];
}

const WaveWeaver::Filter& WaveWeaver::getFilter(int index) const
{
    jassert(index >= 0 && index < 2);
    return filters[index];
}

void WaveWeaver::setFilter(int index, const Filter& filter)
{
    jassert(index >= 0 && index < 2);
    filters[index] = filter;
}

//==============================================================================
// Envelope Parameters
//==============================================================================

WaveWeaver::Envelope& WaveWeaver::getEnvelope(int index)
{
    jassert(index >= 0 && index < 4);
    return envelopes[index];
}

const WaveWeaver::Envelope& WaveWeaver::getEnvelope(int index) const
{
    jassert(index >= 0 && index < 4);
    return envelopes[index];
}

void WaveWeaver::setEnvelope(int index, const Envelope& envelope)
{
    jassert(index >= 0 && index < 4);
    envelopes[index] = envelope;
}

//==============================================================================
// LFO Parameters
//==============================================================================

WaveWeaver::LFO& WaveWeaver::getLFO(int index)
{
    jassert(index >= 0 && index < 8);
    return lfos[index];
}

const WaveWeaver::LFO& WaveWeaver::getLFO(int index) const
{
    jassert(index >= 0 && index < 8);
    return lfos[index];
}

void WaveWeaver::setLFO(int index, const LFO& lfo)
{
    jassert(index >= 0 && index < 8);
    lfos[index] = lfo;
}

//==============================================================================
// Modulation Matrix
//==============================================================================

WaveWeaver::ModulationRoute& WaveWeaver::getModulationRoute(int index)
{
    jassert(index >= 0 && index < 16);
    return modulationMatrix[index];
}

const WaveWeaver::ModulationRoute& WaveWeaver::getModulationRoute(int index) const
{
    jassert(index >= 0 && index < 16);
    return modulationMatrix[index];
}

void WaveWeaver::setModulationRoute(int index, const ModulationRoute& route)
{
    jassert(index >= 0 && index < 16);
    modulationMatrix[index] = route;
}

//==============================================================================
// Global Parameters
//==============================================================================

void WaveWeaver::setMasterVolume(float volume)
{
    masterVolume = juce::jlimit(0.0f, 1.0f, volume);
}

void WaveWeaver::setMasterTune(float cents)
{
    masterTune = juce::jlimit(-100.0f, 100.0f, cents);
}

void WaveWeaver::setPortamentoTime(float seconds)
{
    portamentoTime = juce::jlimit(0.0f, 5.0f, seconds);
}

void WaveWeaver::setVoiceCount(int count)
{
    clearVoices();
    for (int i = 0; i < juce::jlimit(1, 32, count); ++i)
    {
        addVoice(new WaveWeaverVoice(*this));
    }
}

//==============================================================================
// Processing
//==============================================================================

void WaveWeaver::prepare(double sampleRate, int maxBlockSize)
{
    juce::ignoreUnused(maxBlockSize);
    currentSampleRate = sampleRate;
    setCurrentPlaybackSampleRate(sampleRate);
}

void WaveWeaver::reset()
{
    allNotesOff(0, false);
}

//==============================================================================
// Utility Methods
//==============================================================================

void WaveWeaver::initializeDefaultWavetables()
{
    // Create basic waveforms

    // 1. Sine wave
    generateWavetable(0, [](float phase) {
        return std::sin(phase * juce::MathConstants<float>::twoPi);
    });

    // 2. Saw wave
    generateWavetable(1, [](float phase) {
        return 2.0f * phase - 1.0f;
    });

    // 3. Square wave
    generateWavetable(2, [](float phase) {
        return phase < 0.5f ? 1.0f : -1.0f;
    });

    // 4. Triangle wave
    generateWavetable(3, [](float phase) {
        if (phase < 0.25f)
            return 4.0f * phase;
        else if (phase < 0.75f)
            return 2.0f - 4.0f * phase;
        else
            return 4.0f * phase - 4.0f;
    });
}

float WaveWeaver::interpolateWavetable(const Wavetable& wt, float phase, float position)
{
    // Normalize phase [0, 1]
    while (phase >= 1.0f) phase -= 1.0f;
    while (phase < 0.0f) phase += 1.0f;

    // Get frame indices for interpolation
    float frameFloat = position * (wavetableFrames - 1);
    int frame1 = static_cast<int>(frameFloat);
    int frame2 = (frame1 + 1) % wavetableFrames;
    float frameFrac = frameFloat - frame1;

    // Get sample index
    float sampleFloat = phase * wavetableSize;
    int sample1 = static_cast<int>(sampleFloat);
    int sample2 = (sample1 + 1) % wavetableSize;
    float sampleFrac = sampleFloat - sample1;

    // Bilinear interpolation
    float val11 = wt.data[frame1 * wavetableSize + sample1];
    float val12 = wt.data[frame1 * wavetableSize + sample2];
    float val21 = wt.data[frame2 * wavetableSize + sample1];
    float val22 = wt.data[frame2 * wavetableSize + sample2];

    float interp1 = val11 + (val12 - val11) * sampleFrac;
    float interp2 = val21 + (val22 - val21) * sampleFrac;

    return interp1 + (interp2 - interp1) * frameFrac;
}

//==============================================================================
// Voice Implementation
//==============================================================================

WaveWeaver::WaveWeaverVoice::WaveWeaverVoice(WaveWeaver& parent)
    : owner(parent)
{
    // Initialize oscillator phases for unison
    for (auto& osc : oscStates)
    {
        osc.phases.resize(16, 0.0f);
    }
}

bool WaveWeaver::WaveWeaverVoice::canPlaySound(juce::SynthesiserSound* sound)
{
    return dynamic_cast<WaveWeaverSound*>(sound) != nullptr;
}

void WaveWeaver::WaveWeaverVoice::startNote(int midiNoteNumber, float vel,
                                            juce::SynthesiserSound*, int)
{
    currentNote = midiNoteNumber;
    velocity = vel;

    // Calculate base frequency
    float baseFreq = juce::MidiMessage::getMidiNoteInHertz(midiNoteNumber);

    // Apply master tune
    baseFreq *= std::pow(2.0f, owner.masterTune / 1200.0f);

    for (auto& osc : oscStates)
    {
        osc.baseFrequency = baseFreq;
    }

    // Reset envelopes
    for (auto& env : envelopeStates)
    {
        env.stage = EnvelopeState::Stage::Attack;
        env.value = 0.0f;
    }

    // Reset LFOs
    for (auto& phase : lfoPhases)
    {
        phase = 0.0f;
    }

    // Reset sub oscillator
    subPhase = 0.0f;
}

void WaveWeaver::WaveWeaverVoice::stopNote(float, bool allowTailOff)
{
    if (allowTailOff)
    {
        // Move envelopes to release stage
        for (auto& env : envelopeStates)
        {
            if (env.stage != EnvelopeState::Stage::Off)
            {
                env.stage = EnvelopeState::Stage::Release;
            }
        }
    }
    else
    {
        clearCurrentNote();
    }
}

void WaveWeaver::WaveWeaverVoice::pitchWheelMoved(int newValue)
{
    pitchBend = (newValue - 8192) / 8192.0f;  // -1.0 to +1.0
}

void WaveWeaver::WaveWeaverVoice::controllerMoved(int controllerNumber, int newValue)
{
    if (controllerNumber == 1)  // Mod wheel
    {
        modWheel = newValue / 127.0f;
    }
}

void WaveWeaver::WaveWeaverVoice::renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                                                   int startSample, int numSamples)
{
    if (!isVoiceActive())
        return;

    const float sampleRate = static_cast<float>(getSampleRate());

    for (int i = 0; i < numSamples; ++i)
    {
        // Process envelopes
        float ampEnv = processEnvelope(0, sampleRate);  // Envelope 0 = Amp

        // Check if voice should be stopped
        if (envelopeStates[0].stage == EnvelopeState::Stage::Off && ampEnv <= 0.001f)
        {
            clearCurrentNote();
            break;
        }

        // Process LFOs
        for (int lfo = 0; lfo < 8; ++lfo)
        {
            processLFO(lfo, sampleRate);
        }

        // Render oscillators
        float leftSample = 0.0f;
        float rightSample = 0.0f;

        for (int osc = 0; osc < 2; ++osc)
        {
            const auto& oscConfig = owner.oscillators[osc];
            if (!oscConfig.enabled)
                continue;

            auto& oscState = oscStates[osc];

            // Calculate frequency with pitch modulation
            float freq = oscState.baseFrequency;
            freq *= std::pow(2.0f, oscConfig.semitones / 12.0f);
            freq *= std::pow(2.0f, oscConfig.cents / 1200.0f);
            freq *= std::pow(2.0f, pitchBend / 12.0f);  // ±1 semitone

            // Unison processing
            const int numVoices = juce::jlimit(1, 16, oscConfig.unisonVoices);

            for (int v = 0; v < numVoices; ++v)
            {
                // Detune per voice
                float detune = 0.0f;
                if (numVoices > 1)
                {
                    float spread = (v - (numVoices - 1) * 0.5f) / (numVoices - 1);
                    detune = spread * oscConfig.unisonDetune * 0.01f;  // ±1%
                }

                float voiceFreq = freq * (1.0f + detune);
                float phaseInc = voiceFreq / sampleRate;

                // Read wavetable
                float sample = readWavetable(osc, oscState.phases[v], oscConfig.wavetablePosition);

                // Advance phase
                oscState.phases[v] += phaseInc;
                while (oscState.phases[v] >= 1.0f)
                    oscState.phases[v] -= 1.0f;

                // Stereo spread for unison
                float pan = oscConfig.pan;
                if (numVoices > 1)
                {
                    float spreadAmount = (v - (numVoices - 1) * 0.5f) / (numVoices - 1);
                    pan = juce::jlimit(0.0f, 1.0f, pan + spreadAmount * oscConfig.unisonSpread * 0.5f);
                }

                leftSample += sample * (1.0f - pan) * oscConfig.level / numVoices;
                rightSample += sample * pan * oscConfig.level / numVoices;
            }
        }

        // Sub oscillator
        if (owner.subEnabled)
        {
            float subFreq = oscStates[0].baseFrequency * std::pow(2.0f, owner.subOctave);
            float subSample = std::sin(subPhase * juce::MathConstants<float>::twoPi);
            subPhase += subFreq / sampleRate;
            while (subPhase >= 1.0f) subPhase -= 1.0f;

            leftSample += subSample * owner.subLevel;
            rightSample += subSample * owner.subLevel;
        }

        // Noise
        if (owner.noiseEnabled)
        {
            float noiseSample = (std::rand() / static_cast<float>(RAND_MAX)) * 2.0f - 1.0f;
            // Apply color (simple lowpass for pink/red noise)
            // (Simplified - proper pink noise needs more sophisticated filtering)
            leftSample += noiseSample * owner.noiseLevel;
            rightSample += noiseSample * owner.noiseLevel;
        }

        // Apply filters
        float filterEnv = processEnvelope(1, sampleRate);  // Envelope 1 = Filter
        for (int flt = 0; flt < 2; ++flt)
        {
            if (owner.filters[flt].enabled)
            {
                float cutoffMod = owner.filters[flt].envelopeAmount * filterEnv;
                leftSample = processFilter(flt, 0, leftSample, cutoffMod);
                rightSample = processFilter(flt, 1, rightSample, cutoffMod);
            }
        }

        // Apply amplitude envelope
        leftSample *= ampEnv * velocity;
        rightSample *= ampEnv * velocity;

        // Apply master volume
        leftSample *= owner.masterVolume;
        rightSample *= owner.masterVolume;

        // Write to output
        outputBuffer.addSample(0, startSample + i, leftSample);
        if (outputBuffer.getNumChannels() > 1)
        {
            outputBuffer.addSample(1, startSample + i, rightSample);
        }
    }
}

//==============================================================================
// Voice Helper Methods
//==============================================================================

float WaveWeaver::WaveWeaverVoice::readWavetable(int oscIndex, float phase, float position)
{
    const auto& osc = owner.oscillators[oscIndex];

    if (osc.wavetableIndex < 0 || osc.wavetableIndex >= owner.getNumWavetables())
        return 0.0f;

    const auto& wt = *owner.wavetables[osc.wavetableIndex];
    return owner.interpolateWavetable(wt, phase, position);
}

float WaveWeaver::WaveWeaverVoice::processFilter(int filterIndex, int channel,
                                                  float input, float cutoffMod)
{
    const auto& filter = owner.filters[filterIndex];
    auto& state = filterStates[filterIndex][channel];

    // Calculate modulated cutoff
    float cutoff = filter.cutoff * (1.0f + cutoffMod);
    cutoff = juce::jlimit(20.0f, 20000.0f, cutoff);

    // Simple biquad lowpass (placeholder - implement other types)
    // OPTIMIZATION: Use fast trig lookup for filter coefficients
    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
    const float omega = juce::MathConstants<float>::twoPi * cutoff / static_cast<float>(getSampleRate());
    const float q = 0.707f + filter.resonance * 9.0f;  // Q: 0.707 to ~10
    const float sinOmega = trigTables.fastSinRad(omega);
    const float cosOmega = trigTables.fastCosRad(omega);
    const float alpha = sinOmega / (2.0f * q);

    const float b0 = (1.0f - cosOmega) / 2.0f;
    const float b1 = 1.0f - cosOmega;
    const float b2 = (1.0f - cosOmega) / 2.0f;
    const float a0 = 1.0f + alpha;
    const float a1 = -2.0f * cosOmega;
    const float a2 = 1.0f - alpha;

    // Apply filter (direct form 2)
    float output = (b0 / a0) * input + state.z1;
    state.z1 = (b1 / a0) * input - (a1 / a0) * output + state.z2;
    state.z2 = (b2 / a0) * input - (a2 / a0) * output;

    return output;
}

float WaveWeaver::WaveWeaverVoice::processEnvelope(int envIndex, float sampleRate)
{
    auto& env = envelopeStates[envIndex];
    const auto& config = owner.envelopes[envIndex];

    switch (env.stage)
    {
        case EnvelopeState::Stage::Attack:
            env.value += 1.0f / (config.attack * sampleRate);
            if (env.value >= 1.0f)
            {
                env.value = 1.0f;
                env.stage = EnvelopeState::Stage::Decay;
            }
            break;

        case EnvelopeState::Stage::Decay:
            env.value -= (1.0f - config.sustain) / (config.decay * sampleRate);
            if (env.value <= config.sustain)
            {
                env.value = config.sustain;
                env.stage = EnvelopeState::Stage::Sustain;
            }
            break;

        case EnvelopeState::Stage::Sustain:
            env.value = config.sustain;
            break;

        case EnvelopeState::Stage::Release:
            env.value -= env.value / (config.release * sampleRate);
            if (env.value <= 0.001f)
            {
                env.value = 0.0f;
                env.stage = EnvelopeState::Stage::Off;
            }
            break;

        case EnvelopeState::Stage::Off:
            env.value = 0.0f;
            break;
    }

    return env.value;
}

float WaveWeaver::WaveWeaverVoice::processLFO(int lfoIndex, float sampleRate)
{
    const auto& lfo = owner.lfos[lfoIndex];
    if (!lfo.enabled)
        return 0.0f;

    auto& phase = lfoPhases[lfoIndex];

    // Calculate phase increment
    float phaseInc = lfo.rate / sampleRate;

    // Generate LFO value
    float value = 0.0f;
    switch (lfo.shape)
    {
        case LFOShape::Sine:
            value = std::sin(phase * juce::MathConstants<float>::twoPi);
            break;

        case LFOShape::Triangle:
            value = (phase < 0.5f) ? (4.0f * phase - 1.0f) : (3.0f - 4.0f * phase);
            break;

        case LFOShape::Saw:
            value = 2.0f * phase - 1.0f;
            break;

        case LFOShape::Square:
            value = (phase < 0.5f) ? 1.0f : -1.0f;
            break;

        default:
            value = 0.0f;
            break;
    }

    // Advance phase
    phase += phaseInc;
    while (phase >= 1.0f) phase -= 1.0f;

    return value * lfo.depth;
}

void WaveWeaver::WaveWeaverVoice::applyModulation(float& value, ModDestination dest)
{
    juce::ignoreUnused(value, dest);
    // Implement modulation matrix routing
    // (Placeholder for full implementation)
}
