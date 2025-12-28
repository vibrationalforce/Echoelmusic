#include "EchoSynth.h"
#include "../Core/DSPOptimizations.h"
#include <cmath>

//==============================================================================
// EchoSynth Implementation

EchoSynth::EchoSynth()
{
    // Add voices
    for (int i = 0; i < 8; ++i)
        addVoice(new EchoSynthVoice(*this));

    // Add sound
    addSound(new EchoSynthSound());
}

EchoSynth::~EchoSynth() {}

void EchoSynth::prepare(double sr, int samplesPerBlock, int numChannels)
{
    currentSampleRate = sr;
    currentSamplesPerBlock = samplesPerBlock;
    currentNumChannels = numChannels;

    setCurrentPlaybackSampleRate(sr);
}

void EchoSynth::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages)
{
    // Update LFO
    lfoPhaseAccumulator += lfoRate * buffer.getNumSamples() / currentSampleRate;
    if (lfoPhaseAccumulator >= 1.0f)
        lfoPhaseAccumulator -= std::floor(lfoPhaseAccumulator);

    // Render voices
    renderNextBlock(buffer, midiMessages, 0, buffer.getNumSamples());

    // Apply master volume and warmth
    for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
    {
        auto* channelData = buffer.getWritePointer(channel);
        for (int i = 0; i < buffer.getNumSamples(); ++i)
        {
            channelData[i] = applyAnalogWarmth(channelData[i] * masterVolume);
        }
    }
}

//==============================================================================
// Oscillator Controls

void EchoSynth::setOsc1Waveform(Waveform waveform) { osc1Waveform = waveform; }
void EchoSynth::setOsc2Waveform(Waveform waveform) { osc2Waveform = waveform; }
void EchoSynth::setOsc1Octave(int octave) { osc1Octave = juce::jlimit(-2, 2, octave); }
void EchoSynth::setOsc2Octave(int octave) { osc2Octave = juce::jlimit(-2, 2, octave); }
void EchoSynth::setOsc1Semitones(int semitones) { osc1Semitones = juce::jlimit(-12, 12, semitones); }
void EchoSynth::setOsc2Semitones(int semitones) { osc2Semitones = juce::jlimit(-12, 12, semitones); }
void EchoSynth::setOsc1Detune(float cents) { osc1Detune = juce::jlimit(-100.0f, 100.0f, cents); }
void EchoSynth::setOsc2Detune(float cents) { osc2Detune = juce::jlimit(-100.0f, 100.0f, cents); }
void EchoSynth::setOsc2Mix(float mix) { osc2Mix = juce::jlimit(0.0f, 1.0f, mix); }
void EchoSynth::setPulseWidth(float width) { pulseWidth = juce::jlimit(0.1f, 0.9f, width); }

//==============================================================================
// Filter Controls

void EchoSynth::setFilterType(FilterType type) { filterType = type; }
void EchoSynth::setFilterCutoff(float frequency) { filterCutoff = juce::jlimit(20.0f, 20000.0f, frequency); }
void EchoSynth::setFilterResonance(float resonance) { filterResonance = juce::jlimit(0.0f, 1.0f, resonance); }
void EchoSynth::setFilterEnvAmount(float amount) { filterEnvAmount = juce::jlimit(-1.0f, 1.0f, amount); }

//==============================================================================
// Envelope Controls

void EchoSynth::setAmpAttack(float timeMs) { ampAttack = juce::jlimit(0.1f, 5000.0f, timeMs); }
void EchoSynth::setAmpDecay(float timeMs) { ampDecay = juce::jlimit(1.0f, 5000.0f, timeMs); }
void EchoSynth::setAmpSustain(float level) { ampSustain = juce::jlimit(0.0f, 1.0f, level); }
void EchoSynth::setAmpRelease(float timeMs) { ampRelease = juce::jlimit(1.0f, 10000.0f, timeMs); }

void EchoSynth::setFilterAttack(float timeMs) { filterAttack = juce::jlimit(0.1f, 5000.0f, timeMs); }
void EchoSynth::setFilterDecay(float timeMs) { filterDecay = juce::jlimit(1.0f, 5000.0f, timeMs); }
void EchoSynth::setFilterSustain(float level) { filterSustain = juce::jlimit(0.0f, 1.0f, level); }
void EchoSynth::setFilterRelease(float timeMs) { filterRelease = juce::jlimit(1.0f, 10000.0f, timeMs); }

//==============================================================================
// LFO Controls

void EchoSynth::setLFOWaveform(LFOWaveform waveform) { lfoWaveform = waveform; }
void EchoSynth::setLFORate(float hz) { lfoRate = juce::jlimit(0.01f, 20.0f, hz); }
void EchoSynth::setLFOToPitch(float amount) { lfoToPitch = juce::jlimit(0.0f, 1.0f, amount); }
void EchoSynth::setLFOToFilter(float amount) { lfoToFilter = juce::jlimit(0.0f, 1.0f, amount); }
void EchoSynth::setLFOToAmp(float amount) { lfoToAmp = juce::jlimit(0.0f, 1.0f, amount); }
void EchoSynth::setLFOPhase(float phase) { lfoPhase = juce::jlimit(0.0f, 1.0f, phase); }

//==============================================================================
// Unison & Character

void EchoSynth::setUnisonVoices(int voices) { unisonVoices = juce::jlimit(1, 8, voices); }
void EchoSynth::setUnisonDetune(float cents) { unisonDetune = juce::jlimit(0.0f, 50.0f, cents); }
void EchoSynth::setUnisonSpread(float amount) { unisonSpread = juce::jlimit(0.0f, 1.0f, amount); }
void EchoSynth::setAnalogDrift(float amount) { analogDrift = juce::jlimit(0.0f, 1.0f, amount); }
void EchoSynth::setAnalogWarmth(float amount) { analogWarmth = juce::jlimit(0.0f, 1.0f, amount); }

//==============================================================================
// Master Controls

void EchoSynth::setMasterVolume(float volume) { masterVolume = juce::jlimit(0.0f, 1.0f, volume); }
void EchoSynth::setGlideTime(float timeMs) { glideTime = juce::jlimit(0.0f, 2000.0f, timeMs); }

void EchoSynth::setPolyphony(int voices)
{
    voices = juce::jlimit(1, 16, voices);
    clearVoices();
    for (int i = 0; i < voices; ++i)
        addVoice(new EchoSynthVoice(*this));
}

//==============================================================================
// Internal Helpers

float EchoSynth::getLFOValue()
{
    float phase = lfoPhaseAccumulator + lfoPhase;
    if (phase >= 1.0f) phase -= 1.0f;

    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
    switch (lfoWaveform)
    {
        case LFOWaveform::Sine:
            return trigTables.fastSin(phase);

        case LFOWaveform::Triangle:
            return phase < 0.5f ? (4.0f * phase - 1.0f) : (3.0f - 4.0f * phase);

        case LFOWaveform::Sawtooth:
            return 2.0f * phase - 1.0f;

        case LFOWaveform::Square:
            return phase < 0.5f ? 1.0f : -1.0f;

        case LFOWaveform::SampleAndHold:
        {
            static float lastValue = 0.0f;
            static float lastPhase = 0.0f;
            if (phase < lastPhase)  // Reset detected
                lastValue = juce::Random::getSystemRandom().nextFloat() * 2.0f - 1.0f;
            lastPhase = phase;
            return lastValue;
        }

        default:
            return 0.0f;
    }
}

float EchoSynth::applyAnalogWarmth(float sample)
{
    if (analogWarmth < 0.01f)
        return sample;

    // Soft saturation (tube-style)
    float drive = 1.0f + analogWarmth * 2.0f;
    float x = sample * drive;

    // Soft clipping with harmonic content
    float saturated = x / (1.0f + std::abs(x) * 0.5f);
    saturated += analogWarmth * 0.15f * x * x;  // Even harmonics

    return saturated / drive;
}

//==============================================================================
// Presets

void EchoSynth::loadPreset(Preset preset)
{
    switch (preset)
    {
        case Preset::Init:
            setOsc1Waveform(Waveform::Sawtooth);
            setOsc2Waveform(Waveform::Sawtooth);
            setOsc2Mix(0.0f);
            setFilterCutoff(2000.0f);
            setFilterResonance(0.3f);
            setAmpAttack(5.0f);
            setAmpDecay(100.0f);
            setAmpSustain(0.7f);
            setAmpRelease(200.0f);
            break;

        case Preset::FatBass:
            setOsc1Waveform(Waveform::Sawtooth);
            setOsc2Waveform(Waveform::Square);
            setOsc2Octave(-1);
            setOsc2Mix(0.6f);
            setFilterType(FilterType::LowPass24);
            setFilterCutoff(400.0f);
            setFilterResonance(0.6f);
            setFilterEnvAmount(0.5f);
            setAmpAttack(5.0f);
            setAmpRelease(50.0f);
            setUnisonVoices(3);
            setUnisonDetune(15.0f);
            break;

        case Preset::LeadSynth:
            setOsc1Waveform(Waveform::Sawtooth);
            setOsc2Waveform(Waveform::Square);
            setOsc2Detune(8.0f);
            setOsc2Mix(0.7f);
            setFilterCutoff(3000.0f);
            setFilterResonance(0.5f);
            setFilterEnvAmount(0.7f);
            setFilterAttack(10.0f);
            setFilterDecay(200.0f);
            setAmpAttack(10.0f);
            setAmpSustain(0.9f);
            setLFORate(5.0f);
            setLFOToPitch(0.3f);
            break;

        case Preset::Pad:
            setOsc1Waveform(Waveform::Sawtooth);
            setOsc2Waveform(Waveform::Triangle);
            setOsc2Detune(12.0f);
            setOsc2Mix(0.8f);
            setFilterCutoff(1500.0f);
            setFilterResonance(0.2f);
            setAmpAttack(500.0f);
            setAmpDecay(300.0f);
            setAmpSustain(0.7f);
            setAmpRelease(1000.0f);
            setUnisonVoices(5);
            setUnisonDetune(20.0f);
            setAnalogWarmth(0.4f);
            break;

        case Preset::Pluck:
            setOsc1Waveform(Waveform::Sawtooth);
            setOsc2Mix(0.0f);
            setFilterType(FilterType::LowPass12);
            setFilterCutoff(2500.0f);
            setFilterResonance(0.4f);
            setFilterEnvAmount(0.8f);
            setFilterAttack(1.0f);
            setFilterDecay(150.0f);
            setFilterSustain(0.0f);
            setAmpAttack(1.0f);
            setAmpDecay(300.0f);
            setAmpSustain(0.0f);
            setAmpRelease(10.0f);
            break;

        case Preset::Brass:
            setOsc1Waveform(Waveform::Sawtooth);
            setOsc2Waveform(Waveform::Sawtooth);
            setOsc2Detune(5.0f);
            setOsc2Mix(0.6f);
            setFilterCutoff(2000.0f);
            setFilterResonance(0.5f);
            setAmpAttack(100.0f);
            setAmpSustain(0.8f);
            setLFORate(5.0f);
            setLFOToFilter(0.4f);
            setAnalogWarmth(0.6f);
            break;

        case Preset::AcidBass:
            setOsc1Waveform(Waveform::Sawtooth);
            setOsc2Mix(0.0f);
            setFilterType(FilterType::LowPass24);
            setFilterCutoff(800.0f);
            setFilterResonance(0.8f);
            setFilterEnvAmount(0.9f);
            setFilterAttack(5.0f);
            setFilterDecay(200.0f);
            setFilterSustain(0.2f);
            setAmpAttack(1.0f);
            setAmpDecay(150.0f);
            setAmpSustain(0.6f);
            setGlideTime(50.0f);
            break;

        case Preset::Strings:
            setOsc1Waveform(Waveform::Sawtooth);
            setOsc2Waveform(Waveform::Sawtooth);
            setOsc2Octave(-1);
            setOsc2Detune(8.0f);
            setOsc2Mix(0.7f);
            setFilterType(FilterType::LowPass12);
            setFilterCutoff(3500.0f);
            setFilterResonance(0.25f);
            setFilterEnvAmount(0.3f);
            setFilterAttack(400.0f);
            setFilterDecay(600.0f);
            setFilterSustain(0.6f);
            setAmpAttack(300.0f);
            setAmpDecay(400.0f);
            setAmpSustain(0.8f);
            setAmpRelease(800.0f);
            setUnisonVoices(6);
            setUnisonDetune(12.0f);
            setAnalogWarmth(0.3f);
            setLFORate(5.5f);
            setLFOToPitch(0.15f);
            break;

        case Preset::VintageKeys:
            setOsc1Waveform(Waveform::Square);
            setOsc2Waveform(Waveform::Square);
            setOsc2Octave(-1);
            setOsc2Mix(0.5f);
            setFilterType(FilterType::LowPass12);
            setFilterCutoff(4000.0f);
            setFilterResonance(0.2f);
            setFilterEnvAmount(0.4f);
            setFilterAttack(10.0f);
            setFilterDecay(500.0f);
            setFilterSustain(0.3f);
            setAmpAttack(5.0f);
            setAmpDecay(600.0f);
            setAmpSustain(0.4f);
            setAmpRelease(400.0f);
            setAnalogWarmth(0.7f);
            setAnalogDrift(0.5f);
            break;

        case Preset::SquareLead:
            setOsc1Waveform(Waveform::Square);
            setOsc2Waveform(Waveform::Square);
            setOsc2Detune(12.0f);
            setOsc2Mix(0.6f);
            setFilterType(FilterType::LowPass24);
            setFilterCutoff(2500.0f);
            setFilterResonance(0.6f);
            setFilterEnvAmount(0.8f);
            setFilterAttack(5.0f);
            setFilterDecay(300.0f);
            setFilterSustain(0.4f);
            setAmpAttack(5.0f);
            setAmpSustain(0.9f);
            setAmpRelease(100.0f);
            setLFORate(6.0f);
            setLFOToPitch(0.2f);
            setUnisonVoices(2);
            setUnisonDetune(10.0f);
            break;

        case Preset::HooverSynth:
            setOsc1Waveform(Waveform::Sawtooth);
            setOsc2Waveform(Waveform::Sawtooth);
            setOsc2Semitones(7);  // Perfect fifth
            setOsc2Mix(0.8f);
            setFilterType(FilterType::LowPass24);
            setFilterCutoff(1800.0f);
            setFilterResonance(0.7f);
            setFilterEnvAmount(0.6f);
            setFilterAttack(20.0f);
            setFilterDecay(400.0f);
            setFilterSustain(0.5f);
            setAmpAttack(20.0f);
            setAmpSustain(0.9f);
            setAmpRelease(300.0f);
            setUnisonVoices(7);
            setUnisonDetune(30.0f);
            setUnisonSpread(0.8f);
            setLFORate(6.5f);
            setLFOToFilter(0.5f);
            setAnalogWarmth(0.4f);
            break;

        case Preset::Wobble:
            setOsc1Waveform(Waveform::Sawtooth);
            setOsc2Waveform(Waveform::Square);
            setOsc2Octave(-1);
            setOsc2Mix(0.7f);
            setFilterType(FilterType::LowPass24);
            setFilterCutoff(300.0f);
            setFilterResonance(0.85f);
            setFilterEnvAmount(0.0f);  // No envelope, LFO controls filter
            setAmpAttack(5.0f);
            setAmpSustain(1.0f);
            setAmpRelease(100.0f);
            setLFORate(4.0f);  // Wobble speed (quarter notes at 120 BPM)
            setLFOWaveform(LFOWaveform::Sine);
            setLFOToFilter(1.0f);  // Maximum filter modulation
            setUnisonVoices(4);
            setUnisonDetune(20.0f);
            setAnalogWarmth(0.6f);
            break;

        default:
            loadPreset(Preset::Init);
            break;
    }
}

//==============================================================================
// EchoSynthVoice Implementation

EchoSynth::EchoSynthVoice::EchoSynthVoice(EchoSynth& parent)
    : synthRef(parent)
{
}

bool EchoSynth::EchoSynthVoice::canPlaySound(juce::SynthesiserSound* sound)
{
    return dynamic_cast<EchoSynthSound*>(sound) != nullptr;
}

void EchoSynth::EchoSynthVoice::startNote(int midiNoteNumber, float velocity,
                                         juce::SynthesiserSound*, int /*currentPitchWheelPosition*/)
{
    currentMidiNote = midiNoteNumber;
    currentVelocity = velocity;
    currentFrequency = juce::MidiMessage::getMidiNoteInHertz(midiNoteNumber);
    glideTargetFrequency = currentFrequency;

    // Initialize glide
    if (synthRef.glideTime > 0.1f && glideCurrentFrequency > 0.0f)
    {
        // Continue from current frequency (portamento)
    }
    else
    {
        glideCurrentFrequency = currentFrequency;
    }

    // Reset envelopes
    ampEnv.stage = EnvelopeState::Stage::Attack;
    ampEnv.level = 0.0f;
    filterEnv.stage = EnvelopeState::Stage::Attack;
    filterEnv.level = 0.0f;

    // Random drift offset for analog character
    driftOffset = (juce::Random::getSystemRandom().nextFloat() * 2.0f - 1.0f) * synthRef.analogDrift * 0.02f;
}

void EchoSynth::EchoSynthVoice::stopNote(float /*velocity*/, bool allowTailOff)
{
    if (allowTailOff)
    {
        ampEnv.stage = EnvelopeState::Stage::Release;
        filterEnv.stage = EnvelopeState::Stage::Release;
    }
    else
    {
        clearCurrentNote();
        ampEnv.stage = EnvelopeState::Stage::Idle;
        filterEnv.stage = EnvelopeState::Stage::Idle;
    }
}

void EchoSynth::EchoSynthVoice::pitchWheelMoved(int /*newPitchWheelValue*/)
{
    // Could implement pitch bend here
}

void EchoSynth::EchoSynthVoice::controllerMoved(int /*controllerNumber*/, int /*newControllerValue*/)
{
    // Could implement CC mapping here
}

void EchoSynth::EchoSynthVoice::renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                                               int startSample, int numSamples)
{
    if (ampEnv.stage == EnvelopeState::Stage::Idle)
        return;

    auto sampleRate = static_cast<float>(getSampleRate());

    for (int i = 0; i < numSamples; ++i)
    {
        // Glide (portamento) using fast exp
        if (synthRef.glideTime > 0.1f)
        {
            float glideCoeff = 1.0f - Echoel::DSP::FastMath::fastExp(-1.0f / (synthRef.glideTime * 0.001f * sampleRate));
            glideCurrentFrequency += glideCoeff * (glideTargetFrequency - glideCurrentFrequency);
        }
        else
        {
            glideCurrentFrequency = glideTargetFrequency;
        }

        // Analog drift (slow random pitch modulation) using fast sin
        const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
        driftPhase += 0.5f / sampleRate;  // 0.5Hz drift rate
        if (driftPhase >= 1.0f) driftPhase -= 1.0f;
        float drift = driftOffset * trigTables.fastSin(driftPhase);

        // LFO modulation
        float lfoValue = synthRef.getLFOValue();
        float pitchMod = 1.0f + lfoValue * synthRef.lfoToPitch * 0.05f;  // ±5% pitch
        float ampMod = 1.0f - synthRef.lfoToAmp * 0.5f * (1.0f - lfoValue);

        // Calculate oscillator frequencies using fast pow
        float osc1Freq = glideCurrentFrequency * Echoel::DSP::FastMath::fastPow(2.0f, synthRef.osc1Octave + synthRef.osc1Semitones / 12.0f + synthRef.osc1Detune / 1200.0f + drift);
        float osc2Freq = glideCurrentFrequency * Echoel::DSP::FastMath::fastPow(2.0f, synthRef.osc2Octave + synthRef.osc2Semitones / 12.0f + synthRef.osc2Detune / 1200.0f + drift);

        osc1Freq *= pitchMod;
        osc2Freq *= pitchMod;

        // Generate oscillators with PolyBLEP anti-aliasing
        float osc1PhaseInc = osc1Freq / sampleRate;
        float osc2PhaseInc = osc2Freq / sampleRate;
        float osc1Sample = generateOscillator(synthRef.osc1Waveform, osc1Phase, synthRef.pulseWidth, osc1PhaseInc);
        float osc2Sample = generateOscillator(synthRef.osc2Waveform, osc2Phase, synthRef.pulseWidth, osc2PhaseInc);

        // Mix oscillators
        float mixedSample = osc1Sample * (1.0f - synthRef.osc2Mix) + osc2Sample * synthRef.osc2Mix;

        // Update oscillator phases
        osc1Phase += osc1Freq / sampleRate;
        osc2Phase += osc2Freq / sampleRate;
        if (osc1Phase >= 1.0f) osc1Phase -= 1.0f;
        if (osc2Phase >= 1.0f) osc2Phase -= 1.0f;

        // Update envelopes
        updateEnvelope(ampEnv, synthRef.ampAttack, synthRef.ampDecay, synthRef.ampSustain, synthRef.ampRelease);
        updateEnvelope(filterEnv, synthRef.filterAttack, synthRef.filterDecay, synthRef.filterSustain, synthRef.filterRelease);

        float ampEnvLevel = getEnvelopeLevel(ampEnv);
        float filterEnvLevel = getEnvelopeLevel(filterEnv);

        // Apply filter envelope to cutoff
        float envCutoffMod = filterEnvLevel * synthRef.filterEnvAmount * 8000.0f;
        float lfoFilterMod = lfoValue * synthRef.lfoToFilter * 2000.0f;
        filterCutoffSmooth = synthRef.filterCutoff + envCutoffMod + lfoFilterMod;
        filterCutoffSmooth = juce::jlimit(20.0f, 20000.0f, filterCutoffSmooth);

        // Process filter
        float filteredSample = processFilter(mixedSample);

        // Apply amp envelope and velocity
        float finalSample = filteredSample * ampEnvLevel * currentVelocity * ampMod;

        // Write to output buffer
        for (int channel = 0; channel < outputBuffer.getNumChannels(); ++channel)
        {
            outputBuffer.addSample(channel, startSample + i, finalSample);
        }

        // Check if voice should be released
        if (ampEnv.stage == EnvelopeState::Stage::Release && ampEnv.level < 0.001f)
        {
            clearCurrentNote();
            ampEnv.stage = EnvelopeState::Stage::Idle;
            break;
        }
    }
}

float EchoSynth::EchoSynthVoice::generateOscillator(Waveform waveform, float phase, float pulseWidth, float phaseIncrement)
{
    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
    switch (waveform)
    {
        case Waveform::Sine:
            return trigTables.fastSin(phase);

        case Waveform::Triangle:
            // Triangle wave with PolyBLEP at peaks
            return phase < 0.5f ? (4.0f * phase - 1.0f) : (3.0f - 4.0f * phase);

        case Waveform::Sawtooth:
        {
            // PolyBLEP anti-aliased sawtooth - eliminates aliasing artifacts
            float saw = 2.0f * phase - 1.0f;
            if (phaseIncrement > 0.0f)
            {
                saw -= polyBLEP(phase, phaseIncrement);
            }
            return saw;
        }

        case Waveform::Square:
        {
            // PolyBLEP anti-aliased square wave
            float square = phase < 0.5f ? 1.0f : -1.0f;
            if (phaseIncrement > 0.0f)
            {
                // Apply PolyBLEP at both edges (0 and 0.5)
                square += polyBLEP(phase, phaseIncrement);
                square -= polyBLEP(std::fmod(phase + 0.5f, 1.0f), phaseIncrement);
            }
            return square;
        }

        case Waveform::Pulse:
        {
            // PolyBLEP anti-aliased pulse wave
            float pulse = phase < pulseWidth ? 1.0f : -1.0f;
            if (phaseIncrement > 0.0f)
            {
                pulse += polyBLEP(phase, phaseIncrement);
                pulse -= polyBLEP(std::fmod(phase + (1.0f - pulseWidth), 1.0f), phaseIncrement);
            }
            return pulse;
        }

        case Waveform::Noise:
            noiseState = juce::Random::getSystemRandom().nextFloat() * 2.0f - 1.0f;
            return noiseState;

        default:
            return 0.0f;
    }
}

float EchoSynth::EchoSynthVoice::processFilter(float sample)
{
    // Moog-style 4-pole ladder filter (24dB/oct lowpass)
    auto sampleRate = static_cast<float>(getSampleRate());
    float cutoff = juce::jlimit(20.0f, 20000.0f, filterCutoffSmooth);
    float resonance = synthRef.filterResonance;

    // Calculate filter coefficients
    float fc = cutoff / sampleRate;
    fc = juce::jlimit(0.0001f, 0.45f, fc);
    float f = fc * 1.16f;
    float fb = resonance * (1.0f - 0.15f * f * f) * 4.1f;

    // Process 4 stages
    sample -= filterState[3] * fb;
    sample *= 0.35013f * (f * f) * (f * f);

    filterState[0] = sample + 0.3f * filterState[0];
    filterState[1] = filterState[0] + 0.3f * filterState[1];
    filterState[2] = filterState[1] + 0.3f * filterState[2];
    filterState[3] = filterState[2] + 0.3f * filterState[3];

    // Return based on filter type
    switch (synthRef.filterType)
    {
        case FilterType::LowPass24:
            return filterState[3];

        case FilterType::LowPass12:
            return filterState[1];

        case FilterType::HighPass24:
            return sample - filterState[3];

        case FilterType::HighPass12:
            return sample - filterState[1];

        case FilterType::BandPass:
            return filterState[1] - filterState[3];

        case FilterType::Notch:
            return sample - filterState[1];

        default:
            return filterState[3];
    }
}

void EchoSynth::EchoSynthVoice::updateEnvelope(EnvelopeState& env, float attack, float decay, float sustain, float release)
{
    auto sampleRate = static_cast<float>(getSampleRate());

    switch (env.stage)
    {
        case EnvelopeState::Stage::Attack:
            env.increment = 1.0f / (attack * 0.001f * sampleRate);
            env.level += env.increment;
            if (env.level >= 1.0f)
            {
                env.level = 1.0f;
                env.stage = EnvelopeState::Stage::Decay;
            }
            break;

        case EnvelopeState::Stage::Decay:
            env.increment = (sustain - 1.0f) / (decay * 0.001f * sampleRate);
            env.level += env.increment;
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
            env.increment = -env.level / (release * 0.001f * sampleRate);
            env.level += env.increment;
            if (env.level <= 0.0f)
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

float EchoSynth::EchoSynthVoice::getEnvelopeLevel(EnvelopeState& env)
{
    return env.level;
}
