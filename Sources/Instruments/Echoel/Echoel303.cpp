#include "Echoel303.h"
#include <cmath>

//==============================================================================
// Constructor
//==============================================================================

Echoel303::Echoel303()
{
    // Initialize with classic acid sound
    loadPreset(Preset::ClassicAcid);
}

//==============================================================================
// Audio Processing
//==============================================================================

void Echoel303::prepare(double sr, int samplesPerBlock_)
{
    sampleRate = sr;
    samplesPerBlock = samplesPerBlock_;

    // Initialize delay buffer (max 1 second)
    delayBuffer.resize(static_cast<size_t>(sampleRate), 0.0f);
    delayWritePos = 0;

    reset();
}

void Echoel303::reset()
{
    voice = Voice();
    voiceActive = false;
    currentStep = 0;
    samplesUntilNextStep = 0;
    chorusPhase = 0.0f;
    std::fill(delayBuffer.begin(), delayBuffer.end(), 0.0f);
}

void Echoel303::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages)
{
    const int numSamples = buffer.getNumSamples();

    // Process MIDI
    for (const auto metadata : midiMessages)
    {
        handleMidiMessage(metadata.getMessage());
    }

    // Process sequencer if enabled
    if (sequencerEnabled)
    {
        processSequencer(numSamples);
    }

    // Generate audio
    for (int i = 0; i < numSamples; ++i)
    {
        float sample = 0.0f;

        if (voiceActive || voice.active)
        {
            // Update envelopes
            updateEnvelopes();

            // Update biometric modulation
            if (biometricEnabled)
            {
                updateBiometricModulation();
            }

            // Generate oscillator
            float oscSample = generateOscillator();

            // Process filter (18dB/oct diode ladder - TB-303 character)
            float filteredSample = processDiodeLadderFilter(oscSample);

            // Apply amp envelope
            sample = filteredSample * voice.ampEnv;

            // Apply modern effects
            if (distortionAmount > 0.01f || overdriveAmount > 0.01f)
            {
                sample = applyDistortion(sample);
            }

            if (chorusDepth > 0.01f)
            {
                sample = applyChorus(sample);
            }

            if (delayFeedback > 0.01f)
            {
                sample = applyDelay(sample);
            }
        }

        // Write to buffer (mono to stereo)
        for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
        {
            buffer.setSample(channel, i, sample * 0.5f);
        }
    }
}

//==============================================================================
// MIDI Handling
//==============================================================================

void Echoel303::handleMidiMessage(const juce::MidiMessage& message)
{
    if (message.isNoteOn())
    {
        noteOn(message.getNoteNumber(), message.getFloatVelocity(), false, false);
    }
    else if (message.isNoteOff())
    {
        noteOff();
    }
}

void Echoel303::noteOn(int midiNote, float velocity, bool slide, bool accent)
{
    voice.currentNote = midiNote;
    voice.targetFrequency = static_cast<float>(juce::MidiMessage::getMidiNoteInHertz(midiNote));
    voice.velocity = velocity;
    voice.isAccented = accent;

    // Handle slide
    if (slide && voiceActive && slideTime > 1.0f)
    {
        voice.isSliding = true;
        voice.slideFrequency = voice.currentFrequency;
    }
    else
    {
        voice.currentFrequency = voice.targetFrequency;
        voice.slideFrequency = voice.targetFrequency;
        voice.isSliding = false;
    }

    // Retrigger envelopes
    voice.ampEnv = 1.0f;
    voice.filterEnv = 1.0f;
    voice.active = true;
    voiceActive = true;
}

void Echoel303::noteOff()
{
    voice.ampEnv = 0.0f;
    voice.filterEnv = 0.0f;
}

//==============================================================================
// Oscillator
//==============================================================================

float Echoel303::generateOscillator()
{
    // Handle slide (portamento)
    if (voice.isSliding)
    {
        float slideCoeff = 1.0f - std::exp(-1.0f / (slideTime * 0.001f * static_cast<float>(sampleRate)));
        voice.currentFrequency += slideCoeff * (voice.targetFrequency - voice.currentFrequency);

        if (std::abs(voice.currentFrequency - voice.targetFrequency) < 0.1f)
        {
            voice.currentFrequency = voice.targetFrequency;
            voice.isSliding = false;
        }
    }

    // Apply tuning
    float freq = voice.currentFrequency * std::pow(2.0f, tuning / 1200.0f);

    // Phase accumulation
    float phaseIncrement = freq / static_cast<float>(sampleRate);
    voice.phase += phaseIncrement;
    if (voice.phase >= 1.0f)
        voice.phase -= 1.0f;

    float output = 0.0f;

    if (waveformType == 0)  // Sawtooth (classic TB-303)
    {
        output = 2.0f * voice.phase - 1.0f;
    }
    else  // Square
    {
        output = voice.phase < 0.5f ? 1.0f : -1.0f;
    }

    return output;
}

//==============================================================================
// Diode Ladder Filter (TB-303 characteristic 18dB/oct)
//==============================================================================

float Echoel303::processDiodeLadderFilter(float input)
{
    // Calculate modulated cutoff
    float envMod = voice.filterEnv * envModAmount * 8000.0f;
    float accentMod = voice.isAccented ? filterAccentAmount * 2000.0f : 0.0f;
    currentCutoff = juce::jlimit(20.0f, 20000.0f, filterCutoff + envMod + accentMod);

    currentResonance = filterResonance;

    // Normalize cutoff frequency
    float fc = currentCutoff / static_cast<float>(sampleRate);
    fc = juce::jlimit(0.0001f, 0.45f, fc);

    // TB-303 diode ladder filter characteristics
    float f = fc * 1.16f;
    float fb = currentResonance * (1.0f - 0.15f * f * f) * 4.2f;  // Self-oscillation at high resonance

    // Non-linear feedback (diode clipping behavior)
    float feedback = std::tanh(voice.filterStage[2] * fb);

    // Input with feedback
    float inputWithFeedback = input - feedback;

    // Diode clipping (non-linear saturation)
    inputWithFeedback = std::tanh(inputWithFeedback * 1.5f);

    // Three-pole ladder (18dB/oct)
    for (int i = 0; i < 3; ++i)
    {
        float g = 0.9892f - fc * 0.4342f;  // One-pole coefficient
        voice.filterStage[i] = g * voice.filterStage[i] + fc * std::tanh(inputWithFeedback);
        inputWithFeedback = voice.filterStage[i];
    }

    return voice.filterStage[2];
}

//==============================================================================
// Envelopes
//==============================================================================

void Echoel303::updateEnvelopes()
{
    float sampleTime = 1.0f / static_cast<float>(sampleRate);

    // Amp envelope (simple exponential decay)
    float ampDecay = envDecayTime * 0.001f;
    if (voice.ampEnv > 0.001f)
    {
        voice.ampEnv *= std::exp(-sampleTime / ampDecay);
    }
    else
    {
        voice.ampEnv = 0.0f;
        voice.active = false;
    }

    // Filter envelope (separate decay)
    float filterDecay = filterDecayTime * 0.001f;
    if (voice.filterEnv > 0.001f)
    {
        voice.filterEnv *= std::exp(-sampleTime / filterDecay);
    }
    else
    {
        voice.filterEnv = 0.0f;
    }
}

//==============================================================================
// Biometric Modulation
//==============================================================================

void Echoel303::updateBiometricModulation()
{
    // Heart rate modulates filter cutoff wobble
    float hrMod = std::sin(heartRate / 60.0f * juce::MathConstants<float>::twoPi *
                          static_cast<float>(voice.phase));
    filterCutoff += hrMod * heartRateVariability * 200.0f;

    // Coherence adds resonance
    filterResonance = juce::jlimit(0.0f, 0.95f, filterResonance + coherence * 0.2f);
}

//==============================================================================
// Sequencer
//==============================================================================

void Echoel303::processSequencer(int numSamples)
{
    samplesUntilNextStep -= numSamples;

    if (samplesUntilNextStep <= 0)
    {
        // Calculate step time with shuffle
        float stepTime = (60.0f / tempo) / 4.0f;  // 16th notes
        float swingAmount = shuffle * 0.25f;  // 0-25% swing

        bool isOffBeat = (currentStep % 2) == 1;
        if (isOffBeat)
        {
            stepTime *= (1.0f + swingAmount);
        }

        samplesUntilNextStep = static_cast<int>(stepTime * sampleRate);

        // Trigger note if step is active
        const Step& step = pattern[currentStep];
        if (step.active)
        {
            int note = step.note;
            if (step.octave) note += 12;

            noteOn(note, 1.0f, step.slide, step.accent);
        }

        // Advance step
        currentStep = (currentStep + 1) % 16;
    }
}

//==============================================================================
// Modern Effects
//==============================================================================

float Echoel303::applyDistortion(float sample)
{
    // Soft clipping distortion
    float driven = sample * (1.0f + distortionAmount * 5.0f);
    float distorted = std::tanh(driven);

    // Add tube-style overdrive
    if (overdriveAmount > 0.01f)
    {
        float overdriven = driven * (1.0f + overdriveAmount * 2.0f);
        overdriven = overdriven / (1.0f + std::abs(overdriven) * 0.5f);
        distorted = distorted * (1.0f - overdriveAmount) + overdriven * overdriveAmount;
    }

    return distorted * (1.0f / (1.0f + distortionAmount * 0.5f));  // Compensate gain
}

float Echoel303::applyChorus(float sample)
{
    // Simple stereo chorus
    chorusPhase += chorusRate / static_cast<float>(sampleRate);
    if (chorusPhase >= 1.0f)
        chorusPhase -= 1.0f;

    float lfo = std::sin(chorusPhase * juce::MathConstants<float>::twoPi);
    float modulation = lfo * chorusDepth * 0.005f;  // 5ms max delay

    // Mix dry and modulated signal
    return sample * (1.0f - chorusDepth * 0.5f) + sample * modulation;
}

float Echoel303::applyDelay(float sample)
{
    // Read from delay buffer
    int delaySamples = static_cast<int>(delayTime * sampleRate);
    delaySamples = juce::jlimit(0, static_cast<int>(delayBuffer.size()) - 1, delaySamples);

    int readPos = delayWritePos - delaySamples;
    if (readPos < 0)
        readPos += static_cast<int>(delayBuffer.size());

    float delayedSample = delayBuffer[readPos];

    // Write to delay buffer (with feedback)
    delayBuffer[delayWritePos] = sample + delayedSample * delayFeedback;
    delayWritePos = (delayWritePos + 1) % static_cast<int>(delayBuffer.size());

    return sample + delayedSample * 0.5f;
}

//==============================================================================
// Parameter Setters
//==============================================================================

void Echoel303::setWaveform(int waveform)
{
    waveformType = juce::jlimit(0, 1, waveform);
}

void Echoel303::setTuning(float cents)
{
    tuning = juce::jlimit(-50.0f, 50.0f, cents);
}

void Echoel303::setFilterCutoff(float frequency)
{
    filterCutoff = juce::jlimit(20.0f, 20000.0f, frequency);
}

void Echoel303::setFilterResonance(float resonance)
{
    filterResonance = juce::jlimit(0.0f, 0.95f, resonance);
}

void Echoel303::setEnvMod(float amount)
{
    envModAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void Echoel303::setFilterDecay(float timeMs)
{
    filterDecayTime = juce::jlimit(10.0f, 2000.0f, timeMs);
}

void Echoel303::setFilterAccent(float amount)
{
    filterAccentAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void Echoel303::setEnvDecay(float timeMs)
{
    envDecayTime = juce::jlimit(10.0f, 2000.0f, timeMs);
}

void Echoel303::setAccent(float amount)
{
    accentAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void Echoel303::setSlideTime(float timeMs)
{
    slideTime = juce::jlimit(0.0f, 500.0f, timeMs);
}

void Echoel303::setDistortion(float amount)
{
    distortionAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void Echoel303::setOverdrive(float amount)
{
    overdriveAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void Echoel303::setChorus(float depth, float rate)
{
    chorusDepth = juce::jlimit(0.0f, 1.0f, depth);
    chorusRate = juce::jlimit(0.1f, 10.0f, rate);
}

void Echoel303::setDelay(float time, float feedback)
{
    delayTime = juce::jlimit(0.0f, 1.0f, time);
    delayFeedback = juce::jlimit(0.0f, 0.95f, feedback);
}

//==============================================================================
// Pattern Sequencer
//==============================================================================

void Echoel303::setPattern(const std::array<Step, 16>& newPattern)
{
    pattern = newPattern;
}

void Echoel303::setPatternStep(int step, const Step& data)
{
    if (step >= 0 && step < 16)
    {
        pattern[step] = data;
    }
}

Echoel303::Step Echoel303::getPatternStep(int step) const
{
    if (step >= 0 && step < 16)
    {
        return pattern[step];
    }
    return Step();
}

void Echoel303::clearPattern()
{
    for (auto& step : pattern)
    {
        step = Step();
    }
}

void Echoel303::setSequencerEnabled(bool enabled)
{
    sequencerEnabled = enabled;
    if (enabled)
    {
        currentStep = 0;
        samplesUntilNextStep = 0;
    }
}

void Echoel303::setTempo(float bpm)
{
    tempo = juce::jlimit(60.0f, 200.0f, bpm);
}

void Echoel303::setShuffle(float amount)
{
    shuffle = juce::jlimit(0.0f, 1.0f, amount);
}

//==============================================================================
// Biometric
//==============================================================================

void Echoel303::setHeartRate(float bpm)
{
    heartRate = juce::jlimit(40.0f, 200.0f, bpm);
}

void Echoel303::setHeartRateVariability(float hrv)
{
    heartRateVariability = juce::jlimit(0.0f, 1.0f, hrv);
}

void Echoel303::setCoherence(float coh)
{
    coherence = juce::jlimit(0.0f, 1.0f, coh);
}

void Echoel303::enableBiometricModulation(bool enable)
{
    biometricEnabled = enable;
}

//==============================================================================
// Presets
//==============================================================================

void Echoel303::loadPreset(Preset preset)
{
    switch (preset)
    {
        case Preset::ClassicAcid:
            setWaveform(0);  // Sawtooth
            setFilterCutoff(500.0f);
            setFilterResonance(0.85f);
            setEnvMod(0.8f);
            setFilterDecay(150.0f);
            setEnvDecay(150.0f);
            setSlideTime(60.0f);
            setAccent(0.8f);
            setDistortion(0.0f);
            break;

        case Preset::DeepBass:
            setWaveform(0);
            setFilterCutoff(200.0f);
            setFilterResonance(0.6f);
            setEnvMod(0.5f);
            setFilterDecay(300.0f);
            setEnvDecay(400.0f);
            setSlideTime(100.0f);
            break;

        case Preset::SquelchLead:
            setWaveform(0);
            setFilterCutoff(1200.0f);
            setFilterResonance(0.92f);
            setEnvMod(0.95f);
            setFilterDecay(100.0f);
            setEnvDecay(200.0f);
            setSlideTime(20.0f);
            break;

        case Preset::ResonantStab:
            setWaveform(1);  // Square
            setFilterCutoff(800.0f);
            setFilterResonance(0.9f);
            setEnvMod(0.7f);
            setFilterDecay(80.0f);
            setEnvDecay(80.0f);
            setSlideTime(0.0f);
            break;

        case Preset::BiometricGroove:
            setWaveform(0);
            setFilterCutoff(600.0f);
            setFilterResonance(0.75f);
            setEnvMod(0.7f);
            setFilterDecay(180.0f);
            setEnvDecay(180.0f);
            enableBiometricModulation(true);
            break;

        case Preset::DistortedAcid:
            setWaveform(0);
            setFilterCutoff(700.0f);
            setFilterResonance(0.88f);
            setEnvMod(0.85f);
            setFilterDecay(120.0f);
            setEnvDecay(150.0f);
            setDistortion(0.4f);
            setOverdrive(0.3f);
            break;

        default:
            loadPreset(Preset::ClassicAcid);
            break;
    }
}
