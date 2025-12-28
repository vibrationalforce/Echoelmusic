#include "WaveForge.h"
#include "../Core/DSPOptimizations.h"
#include <cmath>

//==============================================================================
// WaveForge Implementation

WaveForge::WaveForge()
{
    initializeWavetables();

    // Add voices
    for (int i = 0; i < 8; ++i)
        addVoice(new WaveForgeVoice(*this));

    // Add sound
    addSound(new WaveForgeSound());
}

WaveForge::~WaveForge() {}

void WaveForge::prepare(double sr, int samplesPerBlock, int numChannels)
{
    currentSampleRate = sr;
    currentNumChannels = numChannels;
    setCurrentPlaybackSampleRate(sr);
}

void WaveForge::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages)
{
    // Update LFO
    lfoPhase += lfoRate * buffer.getNumSamples() / currentSampleRate;
    // OPTIMIZATION: Fast floor for phase wrap
    if (lfoPhase >= 1.0f)
        lfoPhase -= static_cast<float>(static_cast<int>(lfoPhase));

    // Render voices
    renderNextBlock(buffer, midiMessages, 0, buffer.getNumSamples());

    // Apply master effects
    for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
    {
        auto* channelData = buffer.getWritePointer(channel);
        for (int i = 0; i < buffer.getNumSamples(); ++i)
        {
            float sample = channelData[i];

            // Apply distortion
            if (distortion > 0.01f)
                sample = applyDistortion(sample);

            channelData[i] = sample * masterVolume;
        }
    }
}

//==============================================================================
// Wavetable Controls

void WaveForge::setWavetable(WavetableType type, int index)
{
    juce::ignoreUnused(type);
    currentWavetableIndex = juce::jlimit(0, static_cast<int>(wavetables.size()) - 1, index);
}

void WaveForge::loadCustomWavetable(const float* data, int numSamples)
{
    juce::ignoreUnused(data, numSamples);
    // Would load custom wavetable data
}

void WaveForge::setWavetablePosition(float position) { wavetablePosition = juce::jlimit(0.0f, 1.0f, position); }
void WaveForge::setWavetableMorph(float amount) { wavetableMorph = juce::jlimit(0.0f, 1.0f, amount); }
void WaveForge::setWavetableBend(float amount) { wavetableBend = juce::jlimit(-1.0f, 1.0f, amount); }

//==============================================================================
// Oscillator Controls

void WaveForge::setOscPitch(float semitones) { oscPitch = juce::jlimit(-24.0f, 24.0f, semitones); }
void WaveForge::setOscFine(float cents) { oscFine = juce::jlimit(-100.0f, 100.0f, cents); }
void WaveForge::setOscPhase(float phase) { oscPhase = juce::jlimit(0.0f, 1.0f, phase); }
void WaveForge::setOscLevel(float level) { oscLevel = juce::jlimit(0.0f, 1.0f, level); }

//==============================================================================
// Filter Controls

void WaveForge::setFilterType(FilterType type) { filterType = type; }
void WaveForge::setFilterCutoff(float frequency) { filterCutoff = juce::jlimit(20.0f, 20000.0f, frequency); }
void WaveForge::setFilterResonance(float resonance) { filterResonance = juce::jlimit(0.0f, 1.0f, resonance); }
void WaveForge::setFilterDrive(float drive) { filterDrive = juce::jlimit(0.0f, 1.0f, drive); }
void WaveForge::setFilterEnvAmount(float amount) { filterEnvAmount = juce::jlimit(-1.0f, 1.0f, amount); }

//==============================================================================
// Envelope Controls

void WaveForge::setAmpAttack(float timeMs) { ampAttack = juce::jlimit(0.1f, 5000.0f, timeMs); }
void WaveForge::setAmpDecay(float timeMs) { ampDecay = juce::jlimit(1.0f, 5000.0f, timeMs); }
void WaveForge::setAmpSustain(float level) { ampSustain = juce::jlimit(0.0f, 1.0f, level); }
void WaveForge::setAmpRelease(float timeMs) { ampRelease = juce::jlimit(1.0f, 10000.0f, timeMs); }

void WaveForge::setModAttack(float timeMs) { modAttack = juce::jlimit(0.1f, 5000.0f, timeMs); }
void WaveForge::setModDecay(float timeMs) { modDecay = juce::jlimit(1.0f, 5000.0f, timeMs); }
void WaveForge::setModSustain(float level) { modSustain = juce::jlimit(0.0f, 1.0f, level); }
void WaveForge::setModRelease(float timeMs) { modRelease = juce::jlimit(1.0f, 10000.0f, timeMs); }

//==============================================================================
// LFO Controls

void WaveForge::setLFORate(float hz) { lfoRate = juce::jlimit(0.01f, 20.0f, hz); }
void WaveForge::setLFOShape(float shape) { lfoShape = juce::jlimit(0.0f, 1.0f, shape); }
void WaveForge::setLFOToWavetable(float amount) { lfoToWavetable = juce::jlimit(0.0f, 1.0f, amount); }
void WaveForge::setLFOToFilter(float amount) { lfoToFilter = juce::jlimit(0.0f, 1.0f, amount); }
void WaveForge::setLFOToPitch(float amount) { lfoToPitch = juce::jlimit(0.0f, 1.0f, amount); }

//==============================================================================
// Effects Controls

void WaveForge::setUnisonVoices(int voices) { unisonVoices = juce::jlimit(1, 16, voices); }
void WaveForge::setUnisonDetune(float cents) { unisonDetune = juce::jlimit(0.0f, 100.0f, cents); }
void WaveForge::setUnisonSpread(float amount) { unisonSpread = juce::jlimit(0.0f, 1.0f, amount); }
void WaveForge::setUnisonBlend(float amount) { unisonBlend = juce::jlimit(0.0f, 1.0f, amount); }
void WaveForge::setDistortion(float amount) { distortion = juce::jlimit(0.0f, 1.0f, amount); }
void WaveForge::setDistortionType(int type) { distortionType = juce::jlimit(0, 5, type); }

//==============================================================================
// Master Controls

void WaveForge::setMasterVolume(float volume) { masterVolume = juce::jlimit(0.0f, 1.0f, volume); }

void WaveForge::setPolyphony(int voices)
{
    voices = juce::jlimit(1, 16, voices);
    clearVoices();
    for (int i = 0; i < voices; ++i)
        addVoice(new WaveForgeVoice(*this));
}

//==============================================================================
// Wavetable Generation

void WaveForge::initializeWavetables()
{
    generateBasicWavetables();
    generateAnalogWavetables();
    generateDigitalWavetables();
}

void WaveForge::generateBasicWavetables()
{
    // Sine wavetable (single frame)
    {
        Wavetable wt;
        wt.name = "Sine";
        wt.frames.resize(1);

        for (int i = 0; i < WAVETABLE_SIZE; ++i)
        {
            float phase = static_cast<float>(i) / WAVETABLE_SIZE;
            wt.frames[0][i] = std::sin(phase * juce::MathConstants<float>::twoPi);
        }

        wavetables.push_back(wt);
    }

    // Sawtooth with multiple frames (bandlimited)
    {
        Wavetable wt;
        wt.name = "Sawtooth";
        wt.frames.resize(16);

        for (int frame = 0; frame < 16; ++frame)
        {
            int maxHarmonics = 1 + frame * 4;  // Progressive harmonic content

            for (int i = 0; i < WAVETABLE_SIZE; ++i)
            {
                float phase = static_cast<float>(i) / WAVETABLE_SIZE;
                float sample = 0.0f;

                // Additive synthesis (bandlimited saw)
                for (int h = 1; h <= maxHarmonics; ++h)
                {
                    sample += std::sin(phase * juce::MathConstants<float>::twoPi * h) / h;
                }

                wt.frames[frame][i] = sample * 0.5f;
            }
        }

        wavetables.push_back(wt);
    }

    // Square wave (odd harmonics only)
    {
        Wavetable wt;
        wt.name = "Square";
        wt.frames.resize(16);

        for (int frame = 0; frame < 16; ++frame)
        {
            int maxHarmonics = 1 + frame * 2;

            for (int i = 0; i < WAVETABLE_SIZE; ++i)
            {
                float phase = static_cast<float>(i) / WAVETABLE_SIZE;
                float sample = 0.0f;

                for (int h = 1; h <= maxHarmonics; h += 2)  // Odd harmonics only
                {
                    sample += std::sin(phase * juce::MathConstants<float>::twoPi * h) / h;
                }

                wt.frames[frame][i] = sample * 0.7f;
            }
        }

        wavetables.push_back(wt);
    }
}

void WaveForge::generateAnalogWavetables()
{
    // Analog-style evolving waveform
    Wavetable wt;
    wt.name = "Analog Evolution";
    wt.frames.resize(32);

    for (int frame = 0; frame < 32; ++frame)
    {
        float evolution = static_cast<float>(frame) / 32.0f;

        for (int i = 0; i < WAVETABLE_SIZE; ++i)
        {
            float phase = static_cast<float>(i) / WAVETABLE_SIZE;

            // Start as saw, evolve to square with analog drift
            float saw = 2.0f * phase - 1.0f;
            float square = phase < 0.5f ? 1.0f : -1.0f;

            // Add harmonic content based on evolution
            float harmonics = 0.0f;
            for (int h = 2; h <= 8; ++h)
            {
                harmonics += std::sin(phase * juce::MathConstants<float>::twoPi * h) / (h * h) * evolution;
            }

            float sample = saw * (1.0f - evolution) + square * evolution + harmonics * 0.3f;
            wt.frames[frame][i] = sample * 0.6f;
        }
    }

    wavetables.push_back(wt);
}

void WaveForge::generateDigitalWavetables()
{
    // Digital/FM-style inharmonic waveform
    Wavetable wt;
    wt.name = "Digital FM";
    wt.frames.resize(32);

    for (int frame = 0; frame < 32; ++frame)
    {
        float modIndex = static_cast<float>(frame) / 8.0f;  // FM modulation index

        for (int i = 0; i < WAVETABLE_SIZE; ++i)
        {
            float phase = static_cast<float>(i) / WAVETABLE_SIZE;

            // FM synthesis: carrier modulated by operator
            float modulator = std::sin(phase * juce::MathConstants<float>::twoPi * 3.0f);
            float carrier = std::sin(phase * juce::MathConstants<float>::twoPi + modIndex * modulator);

            wt.frames[frame][i] = carrier * 0.8f;
        }
    }

    wavetables.push_back(wt);
}

//==============================================================================
// Internal Helpers

float WaveForge::getLFOValue()
{
    // Morphing LFO shape - using fast trig for audio thread
    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
    float sine = trigTables.fastSin(lfoPhase);
    float triangle = lfoPhase < 0.5f ? (4.0f * lfoPhase - 1.0f) : (3.0f - 4.0f * lfoPhase);

    return sine * (1.0f - lfoShape) + triangle * lfoShape;
}

float WaveForge::applyDistortion(float sample)
{
    float drive = 1.0f + distortion * 10.0f;
    float x = sample * drive;

    switch (distortionType)
    {
        case 0:  // Soft clip - using fast tanh
            return Echoel::DSP::FastMath::fastTanh(x) / drive;

        case 1:  // Hard clip
            return juce::jlimit(-1.0f, 1.0f, x) / drive;

        case 2:  // Wavefold
            while (std::abs(x) > 1.0f)
                x = x > 0.0f ? 2.0f - x : -2.0f - x;
            return x / drive;

        case 3:  // Bit crush
        {
            int bits = 4 + static_cast<int>((1.0f - distortion) * 12);
            int steps = 1 << bits;
            return std::round(x * steps) / steps / drive;
        }

        default:
            return sample;
    }
}

//==============================================================================
// Presets

void WaveForge::loadPreset(Preset preset)
{
    switch (preset)
    {
        case Preset::Init:
            setWavetable(WavetableType::Basic, 0);  // Sine
            setWavetablePosition(0.5f);
            setFilterCutoff(5000.0f);
            setFilterResonance(0.3f);
            setAmpAttack(5.0f);
            setAmpRelease(200.0f);
            break;

        case Preset::EDMPluck:
            setWavetable(WavetableType::Basic, 1);  // Sawtooth
            setFilterType(FilterType::LowPass);
            setFilterCutoff(3000.0f);
            setFilterResonance(0.5f);
            setFilterEnvAmount(0.8f);
            setModAttack(1.0f);
            setModDecay(150.0f);
            setModSustain(0.0f);
            setAmpAttack(1.0f);
            setAmpDecay(300.0f);
            setAmpSustain(0.0f);
            setUnisonVoices(3);
            setUnisonDetune(15.0f);
            break;

        case Preset::Supersaw:
            setWavetable(WavetableType::Basic, 1);  // Sawtooth
            setWavetablePosition(0.8f);
            setFilterCutoff(8000.0f);
            setFilterResonance(0.2f);
            setUnisonVoices(7);
            setUnisonDetune(25.0f);
            setUnisonSpread(0.8f);
            setAmpAttack(10.0f);
            setAmpSustain(0.9f);
            break;

        case Preset::ReeseBass:
            setWavetable(WavetableType::Basic, 1);  // Sawtooth
            setOscPitch(-12.0f);  // One octave down
            setFilterType(FilterType::LowPass);
            setFilterCutoff(500.0f);
            setFilterResonance(0.4f);
            setUnisonVoices(8);
            setUnisonDetune(40.0f);
            setUnisonSpread(0.6f);
            setAmpAttack(20.0f);
            setAmpRelease(100.0f);
            break;

        case Preset::VocalPad:
            setWavetable(WavetableType::Vocal, 0);  // Vocal formants
            setWavetablePosition(0.5f);
            setFilterType(FilterType::BandPass);
            setFilterCutoff(1200.0f);
            setFilterResonance(0.5f);
            setFilterEnvAmount(0.3f);
            setModAttack(600.0f);
            setModDecay(400.0f);
            setModSustain(0.6f);
            setAmpAttack(500.0f);
            setAmpSustain(0.8f);
            setAmpRelease(1200.0f);
            setLFORate(0.3f);
            setLFOToWavetable(0.5f);
            setUnisonVoices(5);
            setUnisonDetune(18.0f);
            break;

        case Preset::BellLead:
            setWavetable(WavetableType::Metallic, 0);  // Metallic resonance
            setWavetablePosition(0.7f);
            setFilterType(FilterType::HighPass);
            setFilterCutoff(800.0f);
            setFilterResonance(0.4f);
            setFilterEnvAmount(0.6f);
            setModAttack(5.0f);
            setModDecay(800.0f);
            setModSustain(0.2f);
            setAmpAttack(5.0f);
            setAmpDecay(1200.0f);
            setAmpSustain(0.3f);
            setAmpRelease(1500.0f);
            setDistortion(0.15f);
            setDistortionType(0);  // Soft clip
            setUnisonVoices(3);
            setUnisonDetune(8.0f);
            break;

        case Preset::EvolvingPad:
            setWavetable(WavetableType::Analog, 0);  // Analog Evolution
            setWavetablePosition(0.3f);
            setLFORate(0.2f);
            setLFOToWavetable(0.7f);
            setFilterCutoff(2000.0f);
            setFilterResonance(0.3f);
            setAmpAttack(800.0f);
            setAmpRelease(1500.0f);
            setUnisonVoices(6);
            setUnisonDetune(20.0f);
            break;

        case Preset::AggressiveLead:
            setWavetable(WavetableType::Digital, 0);  // Digital FM
            setWavetablePosition(0.9f);
            setFilterType(FilterType::LowPass);
            setFilterCutoff(4000.0f);
            setFilterResonance(0.7f);
            setFilterDrive(0.8f);
            setFilterEnvAmount(0.9f);
            setModAttack(5.0f);
            setModDecay(200.0f);
            setModSustain(0.4f);
            setAmpAttack(5.0f);
            setAmpSustain(0.95f);
            setAmpRelease(100.0f);
            setLFORate(7.0f);
            setLFOToPitch(0.15f);
            setDistortion(0.6f);
            setDistortionType(2);  // Wavefold
            setUnisonVoices(2);
            setUnisonDetune(12.0f);
            break;

        case Preset::SubBass:
            setWavetable(WavetableType::Basic, 0);  // Sine
            setOscPitch(-12.0f);  // One octave down
            setFilterType(FilterType::LowPass);
            setFilterCutoff(200.0f);
            setFilterResonance(0.1f);
            setFilterEnvAmount(0.2f);
            setModAttack(10.0f);
            setModDecay(100.0f);
            setModSustain(0.0f);
            setAmpAttack(5.0f);
            setAmpSustain(1.0f);
            setAmpRelease(80.0f);
            setDistortion(0.3f);
            setDistortionType(0);  // Soft clip for warmth
            break;

        case Preset::OrganicTexture:
            setWavetable(WavetableType::Organic, 0);  // Natural/acoustic textures
            setWavetablePosition(0.4f);
            setFilterType(FilterType::Formant);
            setFilterCutoff(1500.0f);
            setFilterResonance(0.6f);
            setFilterEnvAmount(0.4f);
            setModAttack(300.0f);
            setModDecay(600.0f);
            setModSustain(0.5f);
            setAmpAttack(200.0f);
            setAmpDecay(400.0f);
            setAmpSustain(0.7f);
            setAmpRelease(800.0f);
            setLFORate(0.15f);
            setLFOShape(0.6f);
            setLFOToWavetable(0.6f);
            setLFOToFilter(0.3f);
            setUnisonVoices(4);
            setUnisonDetune(15.0f);
            setDistortion(0.2f);
            break;

        default:
            loadPreset(Preset::Init);
            break;
    }
}

//==============================================================================
// WaveForgeVoice Implementation

WaveForge::WaveForgeVoice::WaveForgeVoice(WaveForge& parent)
    : synthRef(parent)
{
}

bool WaveForge::WaveForgeVoice::canPlaySound(juce::SynthesiserSound* sound)
{
    return dynamic_cast<WaveForgeSound*>(sound) != nullptr;
}

void WaveForge::WaveForgeVoice::startNote(int midiNoteNumber, float velocity,
                                          juce::SynthesiserSound*, int /*currentPitchWheelPosition*/)
{
    currentMidiNote = midiNoteNumber;
    currentVelocity = velocity;
    currentFrequency = juce::MidiMessage::getMidiNoteInHertz(midiNoteNumber);

    phase = synthRef.oscPhase;

    ampEnv.stage = EnvelopeState::Stage::Attack;
    ampEnv.level = 0.0f;
    modEnv.stage = EnvelopeState::Stage::Attack;
    modEnv.level = 0.0f;
}

void WaveForge::WaveForgeVoice::stopNote(float /*velocity*/, bool allowTailOff)
{
    if (allowTailOff)
    {
        ampEnv.stage = EnvelopeState::Stage::Release;
        modEnv.stage = EnvelopeState::Stage::Release;
    }
    else
    {
        clearCurrentNote();
        ampEnv.stage = EnvelopeState::Stage::Idle;
        modEnv.stage = EnvelopeState::Stage::Idle;
    }
}

void WaveForge::WaveForgeVoice::pitchWheelMoved(int /*newPitchWheelValue*/) {}
void WaveForge::WaveForgeVoice::controllerMoved(int /*controllerNumber*/, int /*newControllerValue*/) {}

void WaveForge::WaveForgeVoice::renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                                               int startSample, int numSamples)
{
    if (ampEnv.stage == EnvelopeState::Stage::Idle)
        return;

    auto sampleRate = static_cast<float>(getSampleRate());

    for (int i = 0; i < numSamples; ++i)
    {
        // Calculate pitch with modulation - using fast pow
        float lfoValue = synthRef.getLFOValue();
        float pitchMod = 1.0f + lfoValue * synthRef.lfoToPitch * 0.05f;
        float frequency = currentFrequency * Echoel::DSP::FastMath::fastPow(2.0f, (synthRef.oscPitch + synthRef.oscFine / 100.0f) / 12.0f) * pitchMod;

        // Update phase
        phase += frequency / sampleRate;
        if (phase >= 1.0f) phase -= 1.0f;

        // Calculate wavetable position with modulation
        float wtPosition = synthRef.wavetablePosition + lfoValue * synthRef.lfoToWavetable * 0.3f;
        wtPosition = juce::jlimit(0.0f, 1.0f, wtPosition);

        // Calculate frame index
        if (synthRef.wavetables.empty() || synthRef.currentWavetableIndex >= static_cast<int>(synthRef.wavetables.size()))
            continue;

        auto& wavetable = synthRef.wavetables[synthRef.currentWavetableIndex];
        int numFrames = static_cast<int>(wavetable.frames.size());
        float frameFloat = wtPosition * (numFrames - 1);
        int frame1 = static_cast<int>(frameFloat);
        int frame2 = juce::jmin(frame1 + 1, numFrames - 1);
        float frameFrac = frameFloat - frame1;

        // Read wavetable with interpolation
        float sample1 = readWavetable(phase, frame1);
        float sample2 = readWavetable(phase, frame2);
        float sample = sample1 + frameFrac * (sample2 - sample1);

        // Apply level
        sample *= synthRef.oscLevel;

        // Update envelopes
        updateEnvelope(ampEnv, synthRef.ampAttack, synthRef.ampDecay, synthRef.ampSustain, synthRef.ampRelease);
        updateEnvelope(modEnv, synthRef.modAttack, synthRef.modDecay, synthRef.modSustain, synthRef.modRelease);

        // Apply filter (simplified)
        float filteredSample = processFilter(sample);

        // Apply amp envelope and velocity
        float finalSample = filteredSample * ampEnv.level * currentVelocity;

        // Write to output
        for (int channel = 0; channel < outputBuffer.getNumChannels(); ++channel)
        {
            outputBuffer.addSample(channel, startSample + i, finalSample);
        }

        // Check for note end
        if (ampEnv.stage == EnvelopeState::Stage::Release && ampEnv.level < 0.001f)
        {
            clearCurrentNote();
            ampEnv.stage = EnvelopeState::Stage::Idle;
            break;
        }
    }
}

float WaveForge::WaveForgeVoice::readWavetable(float position, int frame)
{
    if (synthRef.wavetables.empty() || synthRef.currentWavetableIndex >= static_cast<int>(synthRef.wavetables.size()))
        return 0.0f;

    auto& wavetable = synthRef.wavetables[synthRef.currentWavetableIndex];

    if (frame < 0 || frame >= static_cast<int>(wavetable.frames.size()))
        return 0.0f;

    // Linear interpolation between samples
    // OPTIMIZATION: Fast floor for wavetable interpolation
    float indexFloat = position * WaveForge::WAVETABLE_SIZE;
    int index1 = static_cast<int>(indexFloat) % WaveForge::WAVETABLE_SIZE;
    int index2 = (index1 + 1) % WaveForge::WAVETABLE_SIZE;
    float frac = indexFloat - static_cast<float>(static_cast<int>(indexFloat));

    return wavetable.frames[frame][index1] + frac * (wavetable.frames[frame][index2] - wavetable.frames[frame][index1]);
}

float WaveForge::WaveForgeVoice::processFilter(float sample)
{
    // Simplified filter (reuses EchoSynth filter logic)
    auto sampleRate = static_cast<float>(getSampleRate());
    float lfoValue = synthRef.getLFOValue();

    float cutoff = synthRef.filterCutoff + modEnv.level * synthRef.filterEnvAmount * 5000.0f
                   + lfoValue * synthRef.lfoToFilter * 3000.0f;
    cutoff = juce::jlimit(20.0f, 20000.0f, cutoff);

    float fc = cutoff / sampleRate;
    fc = juce::jlimit(0.0001f, 0.45f, fc);
    float f = fc * 1.16f;
    float fb = synthRef.filterResonance * 4.0f;

    // Apply drive - using fast tanh
    if (synthRef.filterDrive > 0.01f)
        sample = Echoel::DSP::FastMath::fastTanh(sample * (1.0f + synthRef.filterDrive * 3.0f));

    // Ladder filter
    sample -= filterState[3] * fb;
    sample *= 0.35f * (f * f) * (f * f);

    filterState[0] = sample + 0.3f * filterState[0];
    filterState[1] = filterState[0] + 0.3f * filterState[1];
    filterState[2] = filterState[1] + 0.3f * filterState[2];
    filterState[3] = filterState[2] + 0.3f * filterState[3];

    return filterState[3];
}

void WaveForge::WaveForgeVoice::updateEnvelope(EnvelopeState& env, float attack, float decay, float sustain, float release)
{
    auto sampleRate = static_cast<float>(getSampleRate());

    switch (env.stage)
    {
        case EnvelopeState::Stage::Attack:
            env.level += 1.0f / (attack * 0.001f * sampleRate);
            if (env.level >= 1.0f)
            {
                env.level = 1.0f;
                env.stage = EnvelopeState::Stage::Decay;
            }
            break;

        case EnvelopeState::Stage::Decay:
            env.level += (sustain - 1.0f) / (decay * 0.001f * sampleRate);
            if (env.level <= sustain)
            {
                env.level = sustain;
                env.stage = EnvelopeState::Stage::Sustain;
            }
            break;

        case EnvelopeState::Stage::Sustain:
            env.level = sustain;
            break;

        case EnvelopeState::Stage::Release:
            env.level -= env.level / (release * 0.001f * sampleRate);
            if (env.level <= 0.001f)
            {
                env.level = 0.0f;
                env.stage = EnvelopeState::Stage::Idle;
            }
            break;

        case EnvelopeState::Stage::Idle:
            env.level = 0.0f;
            break;
    }
}
