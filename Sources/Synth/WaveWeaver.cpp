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

    // Initialize effects buffers
    initializeEffects();

    // Initialize macro names
    for (int i = 0; i < numMacros; ++i)
    {
        macros[i].name = "Macro " + juce::String(i + 1);
    }
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

    // Cache sample rate reciprocal
    invSampleRate = 1.0f / 48000.0f;  // Default, updated when setSampleRate is called
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

    // Apply master tune (OPTIMIZATION: fastPow2 instead of std::pow)
    baseFreq *= Echoel::DSP::FastMath::fastPow2(owner.masterTune / 1200.0f);

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
    // OPTIMIZATION: Update cached reciprocal if sample rate changed
    invSampleRate = 1.0f / sampleRate;

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

            // OPTIMIZATION: Calculate frequency with single combined pow2
            // Combined: semitones/12 + cents/1200 + pitchBend/12
            float pitchMod = oscConfig.semitones / 12.0f + oscConfig.cents / 1200.0f + pitchBend / 12.0f;
            float freq = oscState.baseFrequency * Echoel::DSP::FastMath::fastPow2(pitchMod);

            // Unison processing
            const int numVoices = juce::jlimit(1, 16, oscConfig.unisonVoices);
            // OPTIMIZATION: Pre-compute reciprocal for division-free per-voice processing
            const float invNumVoices = 1.0f / static_cast<float>(numVoices);

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
                // OPTIMIZATION: Use cached reciprocal instead of division
                float phaseInc = voiceFreq * invSampleRate;

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

                // OPTIMIZATION: Use pre-computed reciprocal instead of division
                leftSample += sample * (1.0f - pan) * oscConfig.level * invNumVoices;
                rightSample += sample * pan * oscConfig.level * invNumVoices;
            }
        }

        // Sub oscillator
        if (owner.subEnabled)
        {
            // OPTIMIZATION: fastPow2 for octave shift
            float subFreq = oscStates[0].baseFrequency * Echoel::DSP::FastMath::fastPow2(owner.subOctave);
            // OPTIMIZATION: Use lookup table instead of std::sin (~20x faster)
            float subSample = Echoel::DSP::TrigLookupTables::getInstance().fastSin(subPhase);
            // OPTIMIZATION: Use cached reciprocal instead of division
            subPhase += subFreq * invSampleRate;
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
            // OPTIMIZATION: Use lookup table instead of std::sin (~20x faster)
            value = Echoel::DSP::TrigLookupTables::getInstance().fastSin(phase);
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
    // Get cached modulation value from owner and apply
    float modValue = owner.getModulationValue(dest);
    value += modValue;
}

//==============================================================================
// Modulation Matrix Implementation (NEW)
//==============================================================================

void WaveWeaver::computeModulation()
{
    // Reset modulation cache
    modCache.values.fill(0.0f);

    // Compute LFO values
    for (int i = 0; i < 8; ++i)
    {
        if (lfos[i].enabled)
        {
            // LFO computation is done per-voice, but we cache master LFO for global modulation
            modCache.lfoValues[i] = 0.0f;  // Will be overridden per-voice
        }
    }

    // Compute macro modulation
    for (int m = 0; m < numMacros; ++m)
    {
        modCache.macroValues[m] = macros[m].value;
    }

    // Apply modulation routes
    for (const auto& route : modulationMatrix)
    {
        if (route.source == ModSource::None || route.destination == ModDestination::None)
            continue;

        float sourceValue = getModSourceValue(route.source, 1.0f, 60, 0.0f, 0.0f, 0.0f);
        int destIndex = static_cast<int>(route.destination);
        if (destIndex < numModDestinations)
        {
            modCache.values[destIndex] += sourceValue * route.amount;
        }
    }

    // Apply macro targets
    applyMacroModulation();
}

float WaveWeaver::getModulationValue(ModDestination dest) const
{
    int index = static_cast<int>(dest);
    if (index >= 0 && index < numModDestinations)
    {
        return modCache.values[index];
    }
    return 0.0f;
}

float WaveWeaver::getModSourceValue(ModSource source, float velocity, int noteNumber,
                                     float pitchBend, float modWheel, float aftertouch) const
{
    switch (source)
    {
        case ModSource::None:      return 0.0f;
        case ModSource::LFO1:      return modCache.lfoValues[0];
        case ModSource::LFO2:      return modCache.lfoValues[1];
        case ModSource::LFO3:      return modCache.lfoValues[2];
        case ModSource::LFO4:      return modCache.lfoValues[3];
        case ModSource::LFO5:      return modCache.lfoValues[4];
        case ModSource::LFO6:      return modCache.lfoValues[5];
        case ModSource::LFO7:      return modCache.lfoValues[6];
        case ModSource::LFO8:      return modCache.lfoValues[7];
        case ModSource::Envelope1: return modCache.envValues[0];
        case ModSource::Envelope2: return modCache.envValues[1];
        case ModSource::Envelope3: return modCache.envValues[2];
        case ModSource::Envelope4: return modCache.envValues[3];
        case ModSource::Velocity:  return velocity;
        case ModSource::ModWheel:  return modWheel;
        case ModSource::PitchBend: return pitchBend;
        case ModSource::Aftertouch: return aftertouch;
        case ModSource::KeyTrack:  return (noteNumber - 60) / 60.0f;  // C4 = 0
        case ModSource::Random:    return (std::rand() / static_cast<float>(RAND_MAX)) * 2.0f - 1.0f;
        case ModSource::Constant:  return 1.0f;
        case ModSource::Macro1:    return modCache.macroValues[0];
        case ModSource::Macro2:    return modCache.macroValues[1];
        case ModSource::Macro3:    return modCache.macroValues[2];
        case ModSource::Macro4:    return modCache.macroValues[3];
        case ModSource::Macro5:    return modCache.macroValues[4];
        case ModSource::Macro6:    return modCache.macroValues[5];
        case ModSource::Macro7:    return modCache.macroValues[6];
        case ModSource::Macro8:    return modCache.macroValues[7];
        case ModSource::VectorX:   return vectorPad.x * 2.0f - 1.0f;
        case ModSource::VectorY:   return vectorPad.y * 2.0f - 1.0f;
        default:                   return 0.0f;
    }
}

void WaveWeaver::applyMacroModulation()
{
    for (int m = 0; m < numMacros; ++m)
    {
        const auto& macro = macros[m];
        float macroVal = macro.value;

        for (int t = 0; t < macro.numTargets; ++t)
        {
            const auto& target = macro.targets[t];
            if (target.destination != ModDestination::None)
            {
                int destIndex = static_cast<int>(target.destination);
                if (destIndex < numModDestinations)
                {
                    modCache.values[destIndex] += macroVal * target.amount;
                }
            }
        }
    }
}

//==============================================================================
// Vector Synthesis Implementation (NEW)
//==============================================================================

std::array<float, 4> WaveWeaver::computeVectorWeights(float x, float y) const
{
    // Bilinear interpolation for 4 corners
    // A(0,0), B(1,0), C(0,1), D(1,1)
    float oneMinusX = 1.0f - x;
    float oneMinusY = 1.0f - y;

    return {{
        oneMinusX * oneMinusY,  // A (bottom-left)
        x * oneMinusY,          // B (bottom-right)
        oneMinusX * y,          // C (top-left)
        x * y                   // D (top-right)
    }};
}

float WaveWeaver::readVectorSample(float phase, const std::array<float, 4>& weights) const
{
    float sample = 0.0f;

    for (int corner = 0; corner < 4; ++corner)
    {
        if (weights[corner] > 0.001f)
        {
            int wtIndex = vectorPad.wavetableSlots[corner];
            float wtPos = vectorPad.wavetablePositions[corner];

            if (wtIndex >= 0 && wtIndex < static_cast<int>(wavetables.size()))
            {
                sample += interpolateWavetable(*wavetables[wtIndex], phase, wtPos) * weights[corner];
            }
        }
    }

    return sample;
}

void WaveWeaver::setVectorPosition(float x, float y)
{
    vectorPad.x = juce::jlimit(0.0f, 1.0f, x);
    vectorPad.y = juce::jlimit(0.0f, 1.0f, y);
}

void WaveWeaver::setVectorWavetable(int corner, int wavetableIndex, float position)
{
    if (corner >= 0 && corner < 4)
    {
        vectorPad.wavetableSlots[corner] = wavetableIndex;
        vectorPad.wavetablePositions[corner] = juce::jlimit(0.0f, 1.0f, position);
    }
}

void WaveWeaver::setVectorPad(const VectorPad& pad)
{
    vectorPad = pad;
}

//==============================================================================
// Macro Controls Implementation (NEW)
//==============================================================================

WaveWeaver::Macro& WaveWeaver::getMacro(int index)
{
    jassert(index >= 0 && index < numMacros);
    return macros[index];
}

const WaveWeaver::Macro& WaveWeaver::getMacro(int index) const
{
    jassert(index >= 0 && index < numMacros);
    return macros[index];
}

void WaveWeaver::setMacro(int index, const Macro& macro)
{
    if (index >= 0 && index < numMacros)
    {
        macros[index] = macro;
    }
}

void WaveWeaver::setMacroValue(int index, float value)
{
    if (index >= 0 && index < numMacros)
    {
        macros[index].value = juce::jlimit(0.0f, 1.0f, value);
    }
}

float WaveWeaver::getMacroValue(int index) const
{
    if (index >= 0 && index < numMacros)
    {
        return macros[index].value;
    }
    return 0.0f;
}

void WaveWeaver::addMacroTarget(int macroIndex, ModDestination dest, float amount)
{
    if (macroIndex >= 0 && macroIndex < numMacros)
    {
        auto& macro = macros[macroIndex];
        if (macro.numTargets < 8)
        {
            macro.targets[macro.numTargets].destination = dest;
            macro.targets[macro.numTargets].amount = amount;
            macro.numTargets++;
        }
    }
}

void WaveWeaver::clearMacroTargets(int macroIndex)
{
    if (macroIndex >= 0 && macroIndex < numMacros)
    {
        macros[macroIndex].numTargets = 0;
    }
}

//==============================================================================
// Arpeggiator Implementation (NEW)
//==============================================================================

void WaveWeaver::setArpeggiator(const Arpeggiator& arp)
{
    arpeggiator = arp;
}

void WaveWeaver::setArpMode(ArpMode mode)
{
    arpeggiator.mode = mode;
    if (mode == ArpMode::Off)
    {
        arpNotes.clear();
        arpCurrentStep = 0;
        arpCurrentOctave = 0;
    }
}

void WaveWeaver::setArpRate(float bpm)
{
    arpeggiator.rate = juce::jlimit(20.0f, 300.0f, bpm);
}

void WaveWeaver::setArpGate(float gate)
{
    arpeggiator.gate = juce::jlimit(0.1f, 1.0f, gate);
}

void WaveWeaver::setArpOctaveMode(ArpOctaveMode mode)
{
    arpeggiator.octaveMode = mode;
}

void WaveWeaver::sortArpNotes()
{
    if (arpNotes.empty()) return;

    switch (arpeggiator.mode)
    {
        case ArpMode::Up:
        case ArpMode::UpDown:
            std::sort(arpNotes.begin(), arpNotes.end());
            break;

        case ArpMode::Down:
        case ArpMode::DownUp:
            std::sort(arpNotes.begin(), arpNotes.end(), std::greater<int>());
            break;

        case ArpMode::Random:
            std::random_shuffle(arpNotes.begin(), arpNotes.end());
            break;

        default:
            break;  // Order mode keeps original order
    }
}

int WaveWeaver::getNextArpNote()
{
    if (arpNotes.empty()) return -1;

    int note = arpNotes[arpCurrentStep % arpNotes.size()];

    // Apply octave offset
    note += arpCurrentOctave * 12;

    // Advance step
    arpCurrentStep++;
    if (arpCurrentStep >= static_cast<int>(arpNotes.size()))
    {
        arpCurrentStep = 0;

        // Handle octave progression
        switch (arpeggiator.octaveMode)
        {
            case ArpOctaveMode::OctaveUp:
                arpCurrentOctave = (arpCurrentOctave + 1) % 2;
                break;

            case ArpOctaveMode::OctaveDown:
                arpCurrentOctave = (arpCurrentOctave - 1 + 2) % 2 - 1;
                break;

            case ArpOctaveMode::OctaveUpDown:
                if (arpDirection)
                {
                    arpCurrentOctave++;
                    if (arpCurrentOctave >= 2)
                    {
                        arpDirection = false;
                    }
                }
                else
                {
                    arpCurrentOctave--;
                    if (arpCurrentOctave <= 0)
                    {
                        arpDirection = true;
                    }
                }
                break;

            case ArpOctaveMode::TwoOctavesUp:
                arpCurrentOctave = (arpCurrentOctave + 1) % 3;
                break;

            case ArpOctaveMode::ThreeOctavesUp:
                arpCurrentOctave = (arpCurrentOctave + 1) % 4;
                break;

            default:
                arpCurrentOctave = 0;
                break;
        }
    }

    return note;
}

int WaveWeaver::processArpeggiator(double sampleRate)
{
    if (arpeggiator.mode == ArpMode::Off || arpNotes.empty())
        return -1;

    // Calculate samples per step
    double beatsPerSecond = arpeggiator.rate / 60.0;
    double stepsPerSecond = beatsPerSecond / arpeggiator.division;
    double samplesPerStep = sampleRate / stepsPerSecond;

    arpAccumulator++;
    if (arpAccumulator >= samplesPerStep)
    {
        arpAccumulator -= samplesPerStep;
        return getNextArpNote();
    }

    return -1;
}

//==============================================================================
// Effects Chain Implementation (NEW)
//==============================================================================

void WaveWeaver::initializeEffects()
{
    // Initialize chorus delay lines (max 50ms at 48kHz = 2400 samples)
    int maxChorusDelay = static_cast<int>(currentSampleRate * 0.05);
    for (auto& line : chorusState.delayLines)
    {
        line.resize(maxChorusDelay, 0.0f);
    }

    // Initialize delay lines (max 2 seconds)
    int maxDelayTime = static_cast<int>(currentSampleRate * 2.0);
    for (auto& line : delayState.delayLines)
    {
        line.resize(maxDelayTime, 0.0f);
    }

    // Initialize reverb comb filters (different prime lengths)
    const std::array<float, 4> combTimes = {{0.0297f, 0.0371f, 0.0411f, 0.0437f}};
    for (int i = 0; i < 4; ++i)
    {
        int size = static_cast<int>(currentSampleRate * combTimes[i]);
        reverbState.combL[i].resize(size, 0.0f);
        reverbState.combR[i].resize(size + 23, 0.0f);  // Slightly different for stereo
    }

    // Initialize allpass filters
    const std::array<float, 2> allpassTimes = {{0.005f, 0.0017f}};
    for (int i = 0; i < 2; ++i)
    {
        int size = static_cast<int>(currentSampleRate * allpassTimes[i]);
        reverbState.allpassL[i].resize(size, 0.0f);
        reverbState.allpassR[i].resize(size + 7, 0.0f);
    }

    // Predelay (max 100ms)
    int predelaySize = static_cast<int>(currentSampleRate * 0.1);
    reverbState.predelayL.resize(predelaySize, 0.0f);
    reverbState.predelayR.resize(predelaySize, 0.0f);
}

void WaveWeaver::processEffects(float& left, float& right)
{
    // Process effects in configured order
    for (int i = 0; i < 4; ++i)
    {
        switch (effectsChain.order[i])
        {
            case 0:  // Distortion
                if (effectsChain.distortion.enabled)
                {
                    processDistortion(left);
                    processDistortion(right);
                }
                break;

            case 1:  // Chorus
                if (effectsChain.chorus.enabled)
                {
                    processChorus(left, right);
                }
                break;

            case 2:  // Delay
                if (effectsChain.delay.enabled)
                {
                    processDelay(left, right);
                }
                break;

            case 3:  // Reverb
                if (effectsChain.reverb.enabled)
                {
                    processReverb(left, right);
                }
                break;
        }
    }
}

void WaveWeaver::processChorus(float& left, float& right)
{
    const auto& chorus = effectsChain.chorus;
    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();

    float dryL = left, dryR = right;
    float wetL = 0.0f, wetR = 0.0f;

    int numVoices = chorus.voices;
    // OPTIMIZATION: Pre-compute reciprocals
    const float invSampleRate = 1.0f / static_cast<float>(currentSampleRate);
    const float invNumVoices = 1.0f / static_cast<float>(numVoices);
    float baseDelay = static_cast<float>(currentSampleRate) * 0.007f;  // 7ms base delay
    float modDepth = static_cast<float>(currentSampleRate) * 0.003f * chorus.depth;  // 3ms max mod

    for (int v = 0; v < numVoices; ++v)
    {
        // Update LFO phase - OPTIMIZATION: Use pre-computed reciprocal
        chorusState.lfoPhases[v] += chorus.rate * invSampleRate;
        while (chorusState.lfoPhases[v] >= 1.0f) chorusState.lfoPhases[v] -= 1.0f;

        float lfoVal = trigTables.fastSin(chorusState.lfoPhases[v]);
        float delay = baseDelay + lfoVal * modDepth;

        // Read from delay line with linear interpolation
        auto& line = chorusState.delayLines[v];
        int lineSize = static_cast<int>(line.size());
        if (lineSize == 0) continue;

        float readPos = static_cast<float>(chorusState.writePos[v]) - delay;
        while (readPos < 0) readPos += lineSize;
        int idx0 = static_cast<int>(readPos) % lineSize;
        int idx1 = (idx0 + 1) % lineSize;
        float frac = readPos - std::floor(readPos);

        float delayed = line[idx0] + frac * (line[idx1] - line[idx0]);

        // Write to delay line
        float input = (v % 2 == 0) ? left : right;
        line[chorusState.writePos[v]] = input + delayed * chorus.feedback;
        chorusState.writePos[v] = (chorusState.writePos[v] + 1) % lineSize;

        // Stereo spread - OPTIMIZATION: Use pre-computed reciprocal
        float panL = 0.5f - chorus.stereoSpread * 0.5f * (v - numVoices * 0.5f) * invNumVoices;
        float panR = 1.0f - panL;
        wetL += delayed * panL * invNumVoices;
        wetR += delayed * panR * invNumVoices;
    }

    // Mix wet/dry
    left = dryL * (1.0f - chorus.mix) + wetL * chorus.mix;
    right = dryR * (1.0f - chorus.mix) + wetR * chorus.mix;
}

void WaveWeaver::processDelay(float& left, float& right)
{
    const auto& delay = effectsChain.delay;

    // Calculate delay times in samples
    int delaySamplesL = static_cast<int>(delay.timeL * currentSampleRate);
    int delaySamplesR = static_cast<int>(delay.timeR * currentSampleRate);

    auto& lineL = delayState.delayLines[0];
    auto& lineR = delayState.delayLines[1];
    int lineSizeL = static_cast<int>(lineL.size());
    int lineSizeR = static_cast<int>(lineR.size());

    if (lineSizeL == 0 || lineSizeR == 0) return;

    delaySamplesL = std::min(delaySamplesL, lineSizeL - 1);
    delaySamplesR = std::min(delaySamplesR, lineSizeR - 1);

    // Read delayed samples
    int readPosL = (delayState.writePos[0] - delaySamplesL + lineSizeL) % lineSizeL;
    int readPosR = (delayState.writePos[1] - delaySamplesR + lineSizeR) % lineSizeR;

    float delayedL = lineL[readPosL];
    float delayedR = lineR[readPosR];

    // Apply feedback filter (tone control)
    float filterCoeff = 0.3f + delay.filter * 0.6f;
    delayState.filterState[0] = delayState.filterState[0] + filterCoeff * (delayedL - delayState.filterState[0]);
    delayState.filterState[1] = delayState.filterState[1] + filterCoeff * (delayedR - delayState.filterState[1]);
    delayedL = delayState.filterState[0];
    delayedR = delayState.filterState[1];

    // Write to delay line with crossfeed (ping-pong)
    lineL[delayState.writePos[0]] = left + (delayedL * (1.0f - delay.crossfeed) + delayedR * delay.crossfeed) * delay.feedback;
    lineR[delayState.writePos[1]] = right + (delayedR * (1.0f - delay.crossfeed) + delayedL * delay.crossfeed) * delay.feedback;

    delayState.writePos[0] = (delayState.writePos[0] + 1) % lineSizeL;
    delayState.writePos[1] = (delayState.writePos[1] + 1) % lineSizeR;

    // Mix
    left = left * (1.0f - delay.mix) + delayedL * delay.mix;
    right = right * (1.0f - delay.mix) + delayedR * delay.mix;
}

void WaveWeaver::processReverb(float& left, float& right)
{
    const auto& reverb = effectsChain.reverb;
    float dryL = left, dryR = right;

    // Pre-delay
    int predelaySamples = static_cast<int>(reverb.predelay * currentSampleRate);
    int predelaySize = static_cast<int>(reverbState.predelayL.size());
    if (predelaySize == 0) return;
    predelaySamples = std::min(predelaySamples, predelaySize - 1);

    int predelayRead = (reverbState.predelayPos - predelaySamples + predelaySize) % predelaySize;
    float inputL = reverbState.predelayL[predelayRead];
    float inputR = reverbState.predelayR[predelayRead];

    reverbState.predelayL[reverbState.predelayPos] = left;
    reverbState.predelayR[reverbState.predelayPos] = right;
    reverbState.predelayPos = (reverbState.predelayPos + 1) % predelaySize;

    // Comb filters (parallel)
    float combOutL = 0.0f, combOutR = 0.0f;
    float feedback = reverb.size * 0.85f + 0.1f;
    float damp = reverb.damping * 0.4f;

    for (int c = 0; c < 4; ++c)
    {
        auto& combL = reverbState.combL[c];
        auto& combR = reverbState.combR[c];
        int sizeL = static_cast<int>(combL.size());
        int sizeR = static_cast<int>(combR.size());
        if (sizeL == 0 || sizeR == 0) continue;

        // Read
        float outL = combL[reverbState.combPosL[c]];
        float outR = combR[reverbState.combPosR[c]];

        // Damping filter
        reverbState.combFilterL[c] = outL + damp * (reverbState.combFilterL[c] - outL);
        reverbState.combFilterR[c] = outR + damp * (reverbState.combFilterR[c] - outR);

        // Write
        combL[reverbState.combPosL[c]] = inputL + reverbState.combFilterL[c] * feedback;
        combR[reverbState.combPosR[c]] = inputR + reverbState.combFilterR[c] * feedback;

        reverbState.combPosL[c] = (reverbState.combPosL[c] + 1) % sizeL;
        reverbState.combPosR[c] = (reverbState.combPosR[c] + 1) % sizeR;

        combOutL += outL;
        combOutR += outR;
    }

    combOutL *= 0.25f;
    combOutR *= 0.25f;

    // Allpass filters (series)
    for (int a = 0; a < 2; ++a)
    {
        auto& apL = reverbState.allpassL[a];
        auto& apR = reverbState.allpassR[a];
        int sizeL = static_cast<int>(apL.size());
        int sizeR = static_cast<int>(apR.size());
        if (sizeL == 0 || sizeR == 0) continue;

        const float g = 0.5f;

        float bufL = apL[reverbState.allpassPosL[a]];
        float bufR = apR[reverbState.allpassPosR[a]];

        float newL = combOutL + bufL * g;
        float newR = combOutR + bufR * g;

        apL[reverbState.allpassPosL[a]] = combOutL - bufL * g;
        apR[reverbState.allpassPosR[a]] = combOutR - bufR * g;

        combOutL = newL;
        combOutR = newR;

        reverbState.allpassPosL[a] = (reverbState.allpassPosL[a] + 1) % sizeL;
        reverbState.allpassPosR[a] = (reverbState.allpassPosR[a] + 1) % sizeR;
    }

    // Stereo width
    float mid = (combOutL + combOutR) * 0.5f;
    float side = (combOutL - combOutR) * 0.5f * reverb.width;
    combOutL = mid + side;
    combOutR = mid - side;

    // Mix
    left = dryL * (1.0f - reverb.mix) + combOutL * reverb.mix;
    right = dryR * (1.0f - reverb.mix) + combOutR * reverb.mix;
}

void WaveWeaver::processDistortion(float& sample)
{
    const auto& dist = effectsChain.distortion;
    float dry = sample;
    float wet = sample;

    // Apply drive
    wet *= 1.0f + dist.drive * 10.0f;

    // Apply DC bias for asymmetric
    wet += dist.bias;

    switch (dist.type)
    {
        case DistortionEffect::Type::Soft:
            wet = Echoel::DSP::FastMath::fastTanh(wet);
            break;

        case DistortionEffect::Type::Hard:
            wet = juce::jlimit(-1.0f, 1.0f, wet);
            break;

        case DistortionEffect::Type::Fold:
            while (std::abs(wet) > 1.0f)
            {
                if (wet > 1.0f) wet = 2.0f - wet;
                else if (wet < -1.0f) wet = -2.0f - wet;
            }
            break;

        case DistortionEffect::Type::Asymmetric:
            if (wet > 0) wet = Echoel::DSP::FastMath::fastTanh(wet);
            else wet = Echoel::DSP::FastMath::fastTanh(wet * 0.5f) * 2.0f;
            break;

        case DistortionEffect::Type::Tube:
            wet = (wet >= 0) ? (1.0f - std::exp(-wet)) : (-1.0f + std::exp(wet));
            break;

        case DistortionEffect::Type::Digital:
            wet = std::floor(wet * 8.0f) / 8.0f;  // 3-bit quantization
            break;

        case DistortionEffect::Type::Bitcrush:
            {
                int bits = 4 + static_cast<int>((1.0f - dist.drive) * 12);
                float levels = static_cast<float>(1 << bits);
                wet = std::floor(wet * levels) / levels;
            }
            break;
    }

    // Remove DC bias
    wet -= dist.bias;

    // Mix
    sample = dry * (1.0f - dist.mix) + wet * dist.mix;
}

//==============================================================================
// Effects Control Methods (NEW)
//==============================================================================

void WaveWeaver::setEffectsChain(const EffectsChain& chain)
{
    effectsChain = chain;
}

void WaveWeaver::setChorusEnabled(bool enabled)
{
    effectsChain.chorus.enabled = enabled;
}

void WaveWeaver::setChorusRate(float hz)
{
    effectsChain.chorus.rate = juce::jlimit(0.1f, 5.0f, hz);
}

void WaveWeaver::setChorusDepth(float depth)
{
    effectsChain.chorus.depth = juce::jlimit(0.0f, 1.0f, depth);
}

void WaveWeaver::setChorusMix(float mix)
{
    effectsChain.chorus.mix = juce::jlimit(0.0f, 1.0f, mix);
}

void WaveWeaver::setDelayEnabled(bool enabled)
{
    effectsChain.delay.enabled = enabled;
}

void WaveWeaver::setDelayTime(float timeL, float timeR)
{
    effectsChain.delay.timeL = juce::jlimit(0.001f, 2.0f, timeL);
    effectsChain.delay.timeR = juce::jlimit(0.001f, 2.0f, timeR);
}

void WaveWeaver::setDelayFeedback(float feedback)
{
    effectsChain.delay.feedback = juce::jlimit(0.0f, 0.95f, feedback);
}

void WaveWeaver::setDelayMix(float mix)
{
    effectsChain.delay.mix = juce::jlimit(0.0f, 1.0f, mix);
}

void WaveWeaver::setDelaySync(bool sync)
{
    effectsChain.delay.sync = sync;
}

void WaveWeaver::setReverbEnabled(bool enabled)
{
    effectsChain.reverb.enabled = enabled;
}

void WaveWeaver::setReverbSize(float size)
{
    effectsChain.reverb.size = juce::jlimit(0.0f, 1.0f, size);
}

void WaveWeaver::setReverbDecay(float decay)
{
    effectsChain.reverb.decay = juce::jlimit(0.0f, 1.0f, decay);
}

void WaveWeaver::setReverbMix(float mix)
{
    effectsChain.reverb.mix = juce::jlimit(0.0f, 1.0f, mix);
}

void WaveWeaver::setDistortionEnabled(bool enabled)
{
    effectsChain.distortion.enabled = enabled;
}

void WaveWeaver::setDistortionType(DistortionEffect::Type type)
{
    effectsChain.distortion.type = type;
}

void WaveWeaver::setDistortionDrive(float drive)
{
    effectsChain.distortion.drive = juce::jlimit(0.0f, 1.0f, drive);
}

void WaveWeaver::setDistortionMix(float mix)
{
    effectsChain.distortion.mix = juce::jlimit(0.0f, 1.0f, mix);
}

void WaveWeaver::setEffectsOrder(const std::array<int, 4>& order)
{
    effectsChain.order = order;
}

//==============================================================================
// Advanced Filter Implementations (NEW)
//==============================================================================

float WaveWeaver::processMoogLadder(float input, float cutoff, float resonance,
                                     std::array<float, 4>& state) const
{
    // Moog ladder filter (Antti Huovilainen model)
    const float fc = cutoff / static_cast<float>(currentSampleRate);
    const float fc2 = fc * fc;
    const float fc3 = fc2 * fc;

    // Compute coefficients
    const float g = 0.9892f * fc - 0.4342f * fc2 + 0.1381f * fc3 - 0.0202f * fc3 * fc;
    const float res = resonance * (1.0029f + 0.0526f * fc - 0.926f * fc2 + 0.0218f * fc3);

    // Feedback
    float feedback = res * 4.0f * (state[3] - input * 0.5f);
    input -= feedback;

    // Apply tanh saturation
    input = Echoel::DSP::FastMath::fastTanh(input);

    // 4-pole cascade
    for (int i = 0; i < 4; ++i)
    {
        float s = state[i];
        state[i] = s + g * (input - s);
        input = state[i];
    }

    return state[3];
}

float WaveWeaver::processStateVariable(float input, float cutoff, float resonance,
                                        FilterType subType, std::array<float, 2>& state) const
{
    // State-variable filter (Chamberlin)
    const float f = 2.0f * Echoel::DSP::TrigLookupTables::getInstance().fastSinRad(
        juce::MathConstants<float>::pi * cutoff / static_cast<float>(currentSampleRate));
    const float q = 1.0f / (1.0f + resonance * 0.5f);
    const float scale = Echoel::DSP::FastMath::fastSqrt(q);

    // Low, band, high outputs
    float low = state[0] + f * state[1];
    float high = scale * input - low - q * state[1];
    float band = f * high + state[1];

    state[0] = low;
    state[1] = band;

    // Return based on filter type
    switch (subType)
    {
        case FilterType::LowPass12dB:
        case FilterType::LowPass24dB:
            return low;
        case FilterType::HighPass12dB:
        case FilterType::HighPass24dB:
            return high;
        case FilterType::BandPass:
            return band;
        case FilterType::Notch:
            return low + high;
        default:
            return low;
    }
}

float WaveWeaver::processFormant(float input, float morph, std::array<float, 10>& state) const
{
    // 5 vowel formants: A, E, I, O, U
    // Each vowel has 3 formant frequencies
    static const float formants[5][3] = {
        {800.0f, 1150.0f, 2900.0f},   // A
        {350.0f, 2000.0f, 2800.0f},   // E
        {270.0f, 2140.0f, 2950.0f},   // I
        {450.0f, 800.0f, 2830.0f},    // O
        {325.0f, 700.0f, 2700.0f}     // U
    };

    // Interpolate between vowels based on morph
    int vowel1 = static_cast<int>(morph * 4.0f);
    int vowel2 = std::min(vowel1 + 1, 4);
    float blend = morph * 4.0f - vowel1;
    vowel1 = std::max(0, std::min(vowel1, 4));

    float output = 0.0f;

    // Process 3 formant bands
    for (int f = 0; f < 3; ++f)
    {
        float freq = formants[vowel1][f] * (1.0f - blend) + formants[vowel2][f] * blend;
        float bw = freq * 0.1f;  // Bandwidth = 10% of frequency

        // Simple resonant filter per formant
        float w0 = 2.0f * juce::MathConstants<float>::pi * freq / static_cast<float>(currentSampleRate);
        float alpha = Echoel::DSP::TrigLookupTables::getInstance().fastSinRad(w0) / (2.0f * (freq / bw));

        float b0 = alpha;
        float a0 = 1.0f + alpha;
        float a1 = -2.0f * Echoel::DSP::TrigLookupTables::getInstance().fastCosRad(w0);
        float a2 = 1.0f - alpha;

        // Direct form 1
        float y = (b0/a0) * input - (a1/a0) * state[f*2] - (a2/a0) * state[f*2+1];
        state[f*2+1] = state[f*2];
        state[f*2] = y;

        output += y;
    }

    return output * 0.33f;  // Normalize
}

float WaveWeaver::processAcidFilter(float input, float cutoff, float resonance,
                                     float accent, std::array<float, 4>& state) const
{
    // TB-303 style filter with accent-controlled resonance spike
    float fc = cutoff / static_cast<float>(currentSampleRate);
    fc = std::min(fc, 0.45f);

    // Increase resonance with accent
    float q = resonance + accent * 0.5f;
    q = std::min(q, 0.99f);

    const float k = 4.0f * q;
    const float g = fc;

    // Apply feedback with saturation
    float feedback = k * Echoel::DSP::FastMath::fastTanh(state[3]);
    float s = input - feedback;

    // 4-pole cascade with per-stage saturation
    for (int i = 0; i < 4; ++i)
    {
        float v = g * (Echoel::DSP::FastMath::fastTanh(s) - Echoel::DSP::FastMath::fastTanh(state[i]));
        float y = v + state[i];
        state[i] = y + v;
        s = y;
    }

    return state[3];
}
