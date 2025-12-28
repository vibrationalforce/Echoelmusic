#include "SampleEngine.h"
#include "../Core/DSPOptimizations.h"
#include <cmath>

//==============================================================================
// SampleEngine Implementation

SampleEngine::SampleEngine()
{
    // Add voices
    for (int i = 0; i < 16; ++i)
        addVoice(new SampleEngineVoice(*this));

    // Add sound
    addSound(new SampleEngineSound());
}

SampleEngine::~SampleEngine() {}

void SampleEngine::prepare(double sr, int samplesPerBlock, int numChannels)
{
    currentSampleRate = sr;
    currentNumChannels = numChannels;
    setCurrentPlaybackSampleRate(sr);
}

void SampleEngine::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages)
{
    // Update LFO
    lfoPhase += lfoRate * buffer.getNumSamples() / currentSampleRate;
    if (lfoPhase >= 1.0f)
        lfoPhase -= std::floor(lfoPhase);

    // Render voices
    renderNextBlock(buffer, midiMessages, 0, buffer.getNumSamples());

    // Apply master volume
    buffer.applyGain(masterVolume);
}

//==============================================================================
// Sample Management

void SampleEngine::loadSample(const juce::File& audioFile, int rootNote)
{
    juce::AudioFormatManager formatManager;
    formatManager.registerBasicFormats();

    std::unique_ptr<juce::AudioFormatReader> reader(formatManager.createReaderFor(audioFile));

    if (reader != nullptr)
    {
        Sample sample;
        sample.name = audioFile.getFileNameWithoutExtension().toStdString();
        sample.sourceSampleRate = reader->sampleRate;
        sample.rootNote = rootNote;

        sample.audioData.setSize(static_cast<int>(reader->numChannels),
                                static_cast<int>(reader->lengthInSamples));

        reader->read(&sample.audioData, 0, static_cast<int>(reader->lengthInSamples), 0, true, true);

        // Set default loop points
        sample.loopStart = 0;
        sample.loopEnd = static_cast<int>(reader->lengthInSamples);
        sample.loopEnabled = false;

        samples.push_back(std::move(sample));
    }
}

void SampleEngine::loadSample(const juce::AudioBuffer<float>& buffer, double sourceSampleRate, int rootNote)
{
    Sample sample;
    sample.name = "Sample " + juce::String(samples.size() + 1).toStdString();
    sample.sourceSampleRate = sourceSampleRate;
    sample.rootNote = rootNote;
    sample.audioData = buffer;
    sample.loopStart = 0;
    sample.loopEnd = buffer.getNumSamples();
    sample.loopEnabled = false;

    samples.push_back(std::move(sample));
}

void SampleEngine::clearSamples()
{
    samples.clear();
}

int SampleEngine::getNumSamples() const
{
    return static_cast<int>(samples.size());
}

int SampleEngine::findSampleForNote(int midiNote, int velocity) const
{
    if (samples.empty())
        return -1;

    // Find best matching sample based on key and velocity ranges
    for (int i = 0; i < static_cast<int>(samples.size()); ++i)
    {
        const auto& sample = samples[i];

        if (midiNote >= sample.keyRangeLow && midiNote <= sample.keyRangeHigh &&
            velocity >= sample.velocityRangeLow && velocity <= sample.velocityRangeHigh)
        {
            return i;
        }
    }

    // If no exact match, return closest by root note
    int closestIndex = 0;
    int smallestDiff = std::abs(midiNote - samples[0].rootNote);

    for (int i = 1; i < static_cast<int>(samples.size()); ++i)
    {
        int diff = std::abs(midiNote - samples[i].rootNote);
        if (diff < smallestDiff)
        {
            smallestDiff = diff;
            closestIndex = i;
        }
    }

    return closestIndex;
}

//==============================================================================
// OPTIMIZATION: Consolidated setters using template helper
// Reduces 25+ repetitive jlimit calls to single-line implementations
//==============================================================================

// Playback Controls
void SampleEngine::setSampleStart(float position) { setClampedValue(sampleStart, position, 0.0f, 1.0f); }
void SampleEngine::setSampleEnd(float position) { setClampedValue(sampleEnd, position, 0.0f, 1.0f); }
void SampleEngine::setLoopEnabled(bool enabled) { loopEnabled = enabled; }
void SampleEngine::setLoopStart(float position) { setClampedValue(loopStart, position, 0.0f, 1.0f); }
void SampleEngine::setLoopEnd(float position) { setClampedValue(loopEnd, position, 0.0f, 1.0f); }
void SampleEngine::setLoopMode(LoopMode mode) { loopMode = mode; }

// Time-Stretching & Pitch
void SampleEngine::setPitchShift(float semitones) { setClampedValue(pitchShift, semitones, -24.0f, 24.0f); }
void SampleEngine::setTimeStretch(float ratio) { setClampedValue(timeStretch, ratio, 0.5f, 2.0f); }
void SampleEngine::setFormantPreserve(bool preserve) { formantPreserve = preserve; }

// Filter Controls
void SampleEngine::setFilterType(FilterType type) { filterType = type; }
void SampleEngine::setFilterCutoff(float frequency) { setClampedValue(filterCutoff, frequency, 20.0f, 20000.0f); }
void SampleEngine::setFilterResonance(float resonance) { setClampedValue(filterResonance, resonance, 0.0f, 1.0f); }
void SampleEngine::setFilterEnvAmount(float amount) { setClampedValue(filterEnvAmount, amount, -1.0f, 1.0f); }

// Envelope Controls (Amp)
void SampleEngine::setAmpAttack(float timeMs) { setClampedValue(ampAttack, timeMs, 0.1f, 5000.0f); }
void SampleEngine::setAmpDecay(float timeMs) { setClampedValue(ampDecay, timeMs, 1.0f, 5000.0f); }
void SampleEngine::setAmpSustain(float level) { setClampedValue(ampSustain, level, 0.0f, 1.0f); }
void SampleEngine::setAmpRelease(float timeMs) { setClampedValue(ampRelease, timeMs, 1.0f, 10000.0f); }

// Envelope Controls (Filter)
void SampleEngine::setFilterAttack(float timeMs) { setClampedValue(filterAttack, timeMs, 0.1f, 5000.0f); }
void SampleEngine::setFilterDecay(float timeMs) { setClampedValue(filterDecay, timeMs, 1.0f, 5000.0f); }
void SampleEngine::setFilterSustain(float level) { setClampedValue(filterSustain, level, 0.0f, 1.0f); }
void SampleEngine::setFilterRelease(float timeMs) { setClampedValue(filterRelease, timeMs, 1.0f, 10000.0f); }

// LFO Controls
void SampleEngine::setLFORate(float hz) { setClampedValue(lfoRate, hz, 0.01f, 20.0f); }
void SampleEngine::setLFOToPitch(float amount) { setClampedValue(lfoToPitch, amount, 0.0f, 1.0f); }
void SampleEngine::setLFOToFilter(float amount) { setClampedValue(lfoToFilter, amount, 0.0f, 1.0f); }
void SampleEngine::setLFOToSampleStart(float amount) { setClampedValue(lfoToSampleStart, amount, 0.0f, 1.0f); }

// Master Controls
void SampleEngine::setMasterVolume(float volume) { setClampedValue(masterVolume, volume, 0.0f, 1.0f); }

void SampleEngine::setPolyphony(int voices)
{
    voices = juce::jlimit(1, 32, voices);
    clearVoices();
    for (int i = 0; i < voices; ++i)
        addVoice(new SampleEngineVoice(*this));
}

//==============================================================================
// Internal Helpers

float SampleEngine::getLFOValue()
{
    // Using fast trig for audio-thread LFO
    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
    return trigTables.fastSin(lfoPhase);
}

//==============================================================================
// Presets

void SampleEngine::loadPreset(Preset preset)
{
    switch (preset)
    {
        case Preset::Init:
            setSampleStart(0.0f);
            setSampleEnd(1.0f);
            setLoopEnabled(false);
            setPitchShift(0.0f);
            setTimeStretch(1.0f);
            setFilterCutoff(5000.0f);
            setFilterResonance(0.3f);
            setAmpAttack(5.0f);
            setAmpRelease(200.0f);
            break;

        case Preset::Piano:
            setFilterType(FilterType::LowPass);
            setFilterCutoff(8000.0f);
            setFilterResonance(0.2f);
            setAmpAttack(1.0f);
            setAmpDecay(500.0f);
            setAmpSustain(0.6f);
            setAmpRelease(800.0f);
            break;

        case Preset::Strings:
            setLoopEnabled(true);
            setLoopStart(0.1f);
            setLoopEnd(0.9f);
            setLoopMode(LoopMode::Forward);
            setFilterCutoff(6000.0f);
            setFilterResonance(0.3f);
            setAmpAttack(200.0f);
            setAmpDecay(300.0f);
            setAmpSustain(0.8f);
            setAmpRelease(600.0f);
            setLFORate(5.0f);
            setLFOToPitch(0.2f);
            break;

        case Preset::Drums:
            setFilterType(FilterType::HighPass);
            setFilterCutoff(80.0f);
            setFilterResonance(0.5f);
            setAmpAttack(0.5f);
            setAmpDecay(300.0f);
            setAmpSustain(0.0f);
            setAmpRelease(50.0f);
            break;

        case Preset::LoFiTexture:
            setTimeStretch(0.75f);
            setFilterType(FilterType::BandPass);
            setFilterCutoff(1500.0f);
            setFilterResonance(0.6f);
            setAmpAttack(50.0f);
            setAmpRelease(400.0f);
            setLFORate(0.5f);
            setLFOToFilter(0.5f);
            break;

        case Preset::Choir:
            setLoopEnabled(true);
            setLoopStart(0.2f);
            setLoopEnd(0.8f);
            setLoopMode(LoopMode::Forward);
            setFilterType(FilterType::LowPass);
            setFilterCutoff(5000.0f);
            setFilterResonance(0.3f);
            setFilterEnvAmount(0.2f);
            setFilterAttack(300.0f);
            setFilterDecay(400.0f);
            setFilterSustain(0.6f);
            setAmpAttack(400.0f);
            setAmpDecay(500.0f);
            setAmpSustain(0.8f);
            setAmpRelease(1000.0f);
            setLFORate(4.0f);
            setLFOToPitch(0.1f);
            break;

        case Preset::GranularPad:
            setSampleStart(0.0f);
            setSampleEnd(1.0f);
            setLoopEnabled(true);
            setLoopStart(0.1f);
            setLoopEnd(0.9f);
            setLoopMode(LoopMode::PingPong);
            setTimeStretch(0.5f);  // Slow down to 50%
            setFilterType(FilterType::LowPass);
            setFilterCutoff(3000.0f);
            setFilterResonance(0.4f);
            setFilterEnvAmount(0.5f);
            setFilterAttack(600.0f);
            setFilterDecay(800.0f);
            setFilterSustain(0.5f);
            setAmpAttack(600.0f);
            setAmpDecay(1000.0f);
            setAmpSustain(0.7f);
            setAmpRelease(1500.0f);
            setLFORate(0.2f);
            setLFOToFilter(0.4f);
            setLFOToSampleStart(0.3f);  // Granular-like sample position modulation
            break;

        default:
            loadPreset(Preset::Init);
            break;
    }
}

//==============================================================================
// SampleEngineVoice Implementation

SampleEngine::SampleEngineVoice::SampleEngineVoice(SampleEngine& parent)
    : synthRef(parent)
{
}

bool SampleEngine::SampleEngineVoice::canPlaySound(juce::SynthesiserSound* sound)
{
    return dynamic_cast<SampleEngineSound*>(sound) != nullptr;
}

void SampleEngine::SampleEngineVoice::startNote(int midiNoteNumber, float velocity,
                                                juce::SynthesiserSound*, int /*currentPitchWheelPosition*/)
{
    currentMidiNote = midiNoteNumber;
    currentVelocity = velocity;

    // Find appropriate sample
    currentSampleIndex = synthRef.findSampleForNote(midiNoteNumber, static_cast<int>(velocity * 127));

    if (currentSampleIndex < 0)
    {
        clearCurrentNote();
        return;
    }

    const auto& sample = synthRef.samples[currentSampleIndex];

    // Calculate playback speed (pitch shift) - using fast pow
    int noteDiff = midiNoteNumber - sample.rootNote;
    playbackSpeed = static_cast<double>(Echoel::DSP::FastMath::fastPow(2.0f, static_cast<float>(noteDiff + synthRef.pitchShift) / 12.0f));

    // Apply time-stretch (affects speed independently of pitch)
    playbackSpeed /= synthRef.timeStretch;

    // Set initial playback position
    playbackPosition = synthRef.sampleStart * sample.audioData.getNumSamples();

    // Reset envelopes
    ampEnv.stage = EnvelopeState::Stage::Attack;
    ampEnv.level = 0.0f;
    filterEnv.stage = EnvelopeState::Stage::Attack;
    filterEnv.level = 0.0f;

    loopingForward = true;
}

void SampleEngine::SampleEngineVoice::stopNote(float /*velocity*/, bool allowTailOff)
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

void SampleEngine::SampleEngineVoice::pitchWheelMoved(int /*newPitchWheelValue*/) {}
void SampleEngine::SampleEngineVoice::controllerMoved(int /*controllerNumber*/, int /*newControllerValue*/) {}

void SampleEngine::SampleEngineVoice::renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                                                      int startSample, int numSamples)
{
    if (ampEnv.stage == EnvelopeState::Stage::Idle || currentSampleIndex < 0)
        return;

    if (currentSampleIndex >= static_cast<int>(synthRef.samples.size()))
    {
        clearCurrentNote();
        return;
    }

    const auto& sample = synthRef.samples[currentSampleIndex];

    if (sample.audioData.getNumSamples() == 0)
    {
        clearCurrentNote();
        return;
    }

    float lfoValue = synthRef.getLFOValue();

    // Calculate sample boundaries
    int sampleStartPos = static_cast<int>(synthRef.sampleStart * sample.audioData.getNumSamples());
    int sampleEndPos = static_cast<int>(synthRef.sampleEnd * sample.audioData.getNumSamples());
    int loopStartPos = static_cast<int>(synthRef.loopStart * sample.audioData.getNumSamples());
    int loopEndPos = static_cast<int>(synthRef.loopEnd * sample.audioData.getNumSamples());

    for (int i = 0; i < numSamples; ++i)
    {
        // LFO modulation to sample start
        double modulatedPosition = playbackPosition + lfoValue * synthRef.lfoToSampleStart * 1000.0;

        // Read sample with interpolation
        float sampleValue = readSample(sample, modulatedPosition);

        // Update envelopes
        updateEnvelope(ampEnv, synthRef.ampAttack, synthRef.ampDecay, synthRef.ampSustain, synthRef.ampRelease);
        updateEnvelope(filterEnv, synthRef.filterAttack, synthRef.filterDecay, synthRef.filterSustain, synthRef.filterRelease);

        // Process filter
        float filteredSample = processFilter(sampleValue);

        // Apply amp envelope and velocity
        float finalSample = filteredSample * ampEnv.level * currentVelocity;

        // Write to output
        for (int channel = 0; channel < outputBuffer.getNumChannels(); ++channel)
        {
            outputBuffer.addSample(channel, startSample + i, finalSample);
        }

        // Advance playback position
        playbackPosition += playbackSpeed;

        // Handle looping
        if (synthRef.loopEnabled && synthRef.loopMode != LoopMode::Off)
        {
            switch (synthRef.loopMode)
            {
                case LoopMode::Forward:
                    if (playbackPosition >= loopEndPos)
                        playbackPosition = loopStartPos;
                    break;

                case LoopMode::Backward:
                    if (playbackPosition < loopStartPos)
                        playbackPosition = loopEndPos;
                    break;

                case LoopMode::PingPong:
                    if (loopingForward && playbackPosition >= loopEndPos)
                    {
                        loopingForward = false;
                        playbackSpeed = -std::abs(playbackSpeed);
                    }
                    else if (!loopingForward && playbackPosition <= loopStartPos)
                    {
                        loopingForward = true;
                        playbackSpeed = std::abs(playbackSpeed);
                    }
                    break;

                default:
                    break;
            }
        }

        // Check if reached end of sample (no looping)
        if (!synthRef.loopEnabled && (playbackPosition >= sampleEndPos || playbackPosition < 0))
        {
            ampEnv.stage = EnvelopeState::Stage::Release;
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

float SampleEngine::SampleEngineVoice::readSample(const Sample& sample, double position)
{
    int pos1 = static_cast<int>(position);
    int pos2 = pos1 + 1;

    // Bounds checking
    if (pos1 < 0 || pos1 >= sample.audioData.getNumSamples())
        return 0.0f;

    if (pos2 >= sample.audioData.getNumSamples())
        pos2 = sample.audioData.getNumSamples() - 1;

    // Linear interpolation
    float frac = static_cast<float>(position - pos1);

    float value = 0.0f;
    const int numChannels = sample.audioData.getNumChannels();

    // OPTIMIZATION: Cache pointers for interpolation
    for (int channel = 0; channel < numChannels; ++channel)
    {
        const float* channelPtr = sample.audioData.getReadPointer(channel);
        float sample1 = channelPtr[pos1];
        float sample2 = channelPtr[pos2];
        value += sample1 + frac * (sample2 - sample1);
    }

    // Average channels if stereo
    if (numChannels > 0)
        value /= static_cast<float>(numChannels);

    return value;
}

float SampleEngine::SampleEngineVoice::processFilter(float sample)
{
    auto sampleRate = static_cast<float>(getSampleRate());
    float lfoValue = synthRef.getLFOValue();

    float cutoff = synthRef.filterCutoff + filterEnv.level * synthRef.filterEnvAmount * 5000.0f
                   + lfoValue * synthRef.lfoToFilter * 3000.0f;
    cutoff = juce::jlimit(20.0f, 20000.0f, cutoff);

    float fc = cutoff / sampleRate;
    fc = juce::jlimit(0.0001f, 0.45f, fc);
    float f = fc * 1.16f;
    float fb = synthRef.filterResonance * 4.0f;

    // Ladder filter
    sample -= filterState[3] * fb;
    sample *= 0.35f * (f * f) * (f * f);

    filterState[0] = sample + 0.3f * filterState[0];
    filterState[1] = filterState[0] + 0.3f * filterState[1];
    filterState[2] = filterState[1] + 0.3f * filterState[2];
    filterState[3] = filterState[2] + 0.3f * filterState[3];

    switch (synthRef.filterType)
    {
        case FilterType::LowPass:
            return filterState[3];

        case FilterType::HighPass:
            return sample - filterState[3];

        case FilterType::BandPass:
            return filterState[1] - filterState[3];

        case FilterType::Notch:
            return sample - filterState[1];

        default:
            return filterState[3];
    }
}

void SampleEngine::SampleEngineVoice::updateEnvelope(EnvelopeState& env, float attack, float decay, float sustain, float release)
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
