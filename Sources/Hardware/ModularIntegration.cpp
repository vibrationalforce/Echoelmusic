#include "ModularIntegration.h"

namespace Echoelmusic {

ModularIntegration::ModularIntegration()
{
    DBG("Modular Integration initialized - Ready for CV/Gate");
}

ModularIntegration::~ModularIntegration()
{
}

// ===========================
// Interface Setup
// ===========================

void ModularIntegration::setAudioInterface(const juce::String& deviceName)
{
    juce::ScopedLock sl(m_lock);
    m_interfaceName = deviceName;
    DBG("CV/Gate interface set to: " << deviceName);
}

void ModularIntegration::mapCVOutput(int outputIndex, int audioChannel, CVStandard standard)
{
    juce::ScopedLock sl(m_lock);

    // Ensure vector is large enough
    if (outputIndex >= m_cvOutputs.size())
        m_cvOutputs.resize(outputIndex + 1);

    CVOutput& output = m_cvOutputs[outputIndex];
    output.channelIndex = audioChannel;
    output.standard = standard;

    DBG("CV Output " << outputIndex << " mapped to audio channel " << audioChannel);
}

void ModularIntegration::mapCVInput(int inputIndex, int audioChannel)
{
    juce::ScopedLock sl(m_lock);

    if (inputIndex >= m_cvInputs.size())
        m_cvInputs.resize(inputIndex + 1);

    CVInput& input = m_cvInputs[inputIndex];
    input.channelIndex = audioChannel;

    DBG("CV Input " << inputIndex << " mapped to audio channel " << audioChannel);
}

std::vector<juce::String> ModularIntegration::getCompatibleInterfaces()
{
    std::vector<juce::String> compatible;

    // List of known DC-coupled audio interfaces
    compatible.push_back("Expert Sleepers ES-3");
    compatible.push_back("Expert Sleepers ES-6");
    compatible.push_back("Expert Sleepers ES-8");
    compatible.push_back("Expert Sleepers ES-9");
    compatible.push_back("MOTU 828mk3");
    compatible.push_back("MOTU 896mk3");
    compatible.push_back("RME HDSPe AIO");
    compatible.push_back("RME UFX");
    compatible.push_back("Native Instruments Komplete Audio 6");
    compatible.push_back("Behringer U-Phoria UMC404HD");
    compatible.push_back("Arturia AudioFuse");

    return compatible;
}

// ===========================
// Calibration
// ===========================

void ModularIntegration::startAutoCalibration(int cvOutputIndex)
{
    if (cvOutputIndex >= m_cvOutputs.size())
        return;

    m_calibrating = true;
    m_calibrationOutput = cvOutputIndex;

    DBG("Starting auto-calibration for CV output " << cvOutputIndex);
    DBG("Please connect to Eurorack oscillator and audio input...");

    // Auto-calibration procedure:
    // 1. Output known voltages (0V, 1V, 2V, 3V, 4V, 5V)
    // 2. Measure oscillator pitch via audio input
    // 3. Calculate calibration offset
    // 4. Store offset

    // This is simplified - real implementation would use FFT to detect pitch
}

void ModularIntegration::setCalibrationOffset(int cvOutputIndex, float offsetVolts)
{
    if (cvOutputIndex >= m_cvOutputs.size())
        return;

    m_cvOutputs[cvOutputIndex].calibrationOffset = offsetVolts;
    DBG("Calibration offset for CV " << cvOutputIndex << ": " << offsetVolts << "V");
}

float ModularIntegration::getCalibrationError(int cvOutputIndex) const
{
    if (cvOutputIndex >= m_cvOutputs.size())
        return 0.0f;

    // Return calibration accuracy in cents (1/100 of semitone)
    // Real implementation would calculate from measurement data
    return 0.5f; // ±0.5 cents (very accurate)
}

// ===========================
// CV Output
// ===========================

void ModularIntegration::setPitchCV(int cvOutputIndex, int midiNote)
{
    if (cvOutputIndex >= m_cvOutputs.size())
        return;

    CVOutput& output = m_cvOutputs[cvOutputIndex];
    float voltage = midiNoteToVoltage(midiNote, output.standard);
    voltage += output.calibrationOffset; // Apply calibration

    setVoltage(cvOutputIndex, voltage);
}

void ModularIntegration::setModulationCV(int cvOutputIndex, float modulation)
{
    // Map 0.0-1.0 to 0V-10V
    modulation = juce::jlimit(0.0f, 1.0f, modulation);
    float voltage = modulation * 10.0f;

    setVoltage(cvOutputIndex, voltage);
}

void ModularIntegration::setVoltage(int cvOutputIndex, float voltage)
{
    if (cvOutputIndex >= m_cvOutputs.size())
        return;

    // Clamp to ±10V (safe range for most interfaces)
    voltage = juce::jlimit(-10.0f, 10.0f, voltage);

    m_cvOutputs[cvOutputIndex].voltage = voltage;
}

void ModularIntegration::setGate(int cvOutputIndex, bool on)
{
    if (cvOutputIndex >= m_cvOutputs.size())
        return;

    m_cvOutputs[cvOutputIndex].isGate = true;
    m_cvOutputs[cvOutputIndex].voltage = on ? 5.0f : 0.0f;
}

void ModularIntegration::sendTrigger(int cvOutputIndex, float durationMs)
{
    if (cvOutputIndex >= m_cvOutputs.size())
        return;

    m_cvOutputs[cvOutputIndex].isTrigger = true;
    m_cvOutputs[cvOutputIndex].voltage = 5.0f;

    // In real implementation, would schedule trigger-off after durationMs
    DBG("Trigger sent: " << durationMs << "ms pulse on CV " << cvOutputIndex);
}

// ===========================
// Envelope & LFO Output
// ===========================

void ModularIntegration::setEnvelopeOutput(int cvOutputIndex, float attack, float decay, float sustain, float release)
{
    if (cvOutputIndex >= m_cvOutputs.size())
        return;

    EnvelopeGenerator& env = m_envelopes[cvOutputIndex];
    env.attack = attack;
    env.decay = decay;
    env.sustain = sustain;
    env.release = release;

    DBG("Envelope set on CV " << cvOutputIndex << ": A=" << attack << " D=" << decay << " S=" << sustain << " R=" << release);
}

void ModularIntegration::triggerEnvelope(int cvOutputIndex)
{
    auto it = m_envelopes.find(cvOutputIndex);
    if (it != m_envelopes.end())
    {
        it->second.triggered = true;
        it->second.gateOn = true;
        it->second.phase = 0.0f;

        DBG("Envelope triggered on CV " << cvOutputIndex);
    }
}

void ModularIntegration::setLFOOutput(int cvOutputIndex, float frequency, juce::dsp::Oscillator<float>::Type waveform)
{
    LFOGenerator& lfo = m_lfos[cvOutputIndex];
    lfo.frequency = frequency;
    lfo.oscillator.initialise([waveform](float x) {
        // Simplified - real implementation would use proper waveform
        return std::sin(x);
    });

    lfo.oscillator.setFrequency(frequency);

    DBG("LFO set on CV " << cvOutputIndex << ": " << frequency << " Hz");
}

// ===========================
// Sequencer → CV
// ===========================

void ModularIntegration::setSequence(int cvOutputIndex, const std::vector<SequenceStep>& steps)
{
    juce::ScopedLock sl(m_lock);
    m_sequence = steps;
    m_sequencePosition = 0;

    DBG("Sequence loaded: " << steps.size() << " steps");
}

void ModularIntegration::startSequencer(bool start)
{
    m_sequencerRunning = start;
    if (start)
    {
        m_sequencePosition = 0;
        m_sequencerPhase = 0.0;
        DBG("Sequencer STARTED");
    }
    else
    {
        DBG("Sequencer STOPPED");
    }
}

void ModularIntegration::setSequencerTempo(double bpm)
{
    m_sequencerTempo = juce::jlimit(20.0, 999.0, bpm);
    DBG("Sequencer tempo: " << bpm << " BPM");
}

// ===========================
// CV Input
// ===========================

float ModularIntegration::readCVInput(int cvInputIndex) const
{
    if (cvInputIndex >= m_cvInputs.size())
        return 0.0f;

    return m_cvInputs[cvInputIndex].voltage;
}

int ModularIntegration::cvToMidiNote(int cvInputIndex) const
{
    if (cvInputIndex >= m_cvInputs.size())
        return 60;

    float voltage = m_cvInputs[cvInputIndex].voltage;
    return voltageToMidiNote(voltage, CVStandard::OneVoltPerOctave);
}

float ModularIntegration::cvToNormalized(int cvInputIndex) const
{
    if (cvInputIndex >= m_cvInputs.size())
        return 0.0f;

    const CVInput& input = m_cvInputs[cvInputIndex];
    return juce::jmap(input.voltage, input.min, input.max, 0.0f, 1.0f);
}

// ===========================
// Audio Processing
// ===========================

void ModularIntegration::processAudio(juce::AudioBuffer<float>& buffer, int numSamples)
{
    juce::ScopedLock sl(m_lock);

    // Update sequencer
    if (m_sequencerRunning && !m_sequence.empty())
        updateSequencer(numSamples);

    // Process each CV output
    for (size_t i = 0; i < m_cvOutputs.size(); ++i)
    {
        CVOutput& output = m_cvOutputs[i];

        if (output.channelIndex >= buffer.getNumChannels())
            continue;

        float* channelData = buffer.getWritePointer(output.channelIndex);

        // Check if this output has an envelope
        auto envIt = m_envelopes.find(i);
        if (envIt != m_envelopes.end())
        {
            float envValue = processEnvelope(envIt->second, numSamples);
            float voltage = envValue * 10.0f; // Scale to 0-10V
            float sample = voltageToSample(voltage);

            for (int s = 0; s < numSamples; ++s)
                channelData[s] = sample;
        }
        // Check if this output has an LFO
        else if (m_lfos.find(i) != m_lfos.end())
        {
            LFOGenerator& lfo = m_lfos[i];

            for (int s = 0; s < numSamples; ++s)
            {
                float lfoValue = lfo.oscillator.processSample(0.0f); // -1 to +1
                float voltage = (lfoValue + 1.0f) * 5.0f; // Scale to 0-10V
                channelData[s] = voltageToSample(voltage);
            }
        }
        // Static voltage output
        else
        {
            float sample = voltageToSample(output.voltage);
            for (int s = 0; s < numSamples; ++s)
                channelData[s] = sample;
        }
    }
}

void ModularIntegration::processCVInputs(const juce::AudioBuffer<float>& buffer, int numSamples)
{
    juce::ScopedLock sl(m_lock);

    for (auto& input : m_cvInputs)
    {
        if (input.channelIndex >= buffer.getNumChannels())
            continue;

        const float* channelData = buffer.getReadPointer(input.channelIndex);

        // Read average voltage over buffer
        float sum = 0.0f;
        for (int s = 0; s < numSamples; ++s)
            sum += channelData[s];

        float avgSample = sum / numSamples;
        float voltage = sampleToVoltage(avgSample);

        // Update voltage and trigger callback if changed significantly
        if (std::abs(voltage - input.voltage) > 0.01f)
        {
            input.voltage = voltage;

            if (onCVInputChanged)
                onCVInputChanged(&input - &m_cvInputs[0], voltage);
        }
    }
}

// ===========================
// Presets
// ===========================

void ModularIntegration::setupForPlaits(int pitchCV, int triggerOut, int modulationCV)
{
    mapCVOutput(pitchCV, 0, CVStandard::OneVoltPerOctave);
    mapCVOutput(triggerOut, 1);
    mapCVOutput(modulationCV, 2, CVStandard::ZeroToTenVolt);

    m_cvOutputs[triggerOut].isGate = false;
    m_cvOutputs[triggerOut].isTrigger = true;

    DBG("Setup for Mutable Instruments Plaits");
    DBG("  Pitch CV: Output " << pitchCV);
    DBG("  Trigger: Output " << triggerOut);
    DBG("  Modulation: Output " << modulationCV);
}

void ModularIntegration::setupForMaths(int cv1, int cv2, int trigger)
{
    mapCVOutput(cv1, 0, CVStandard::ZeroToTenVolt);
    mapCVOutput(cv2, 1, CVStandard::ZeroToTenVolt);
    mapCVOutput(trigger, 2);

    m_cvOutputs[trigger].isTrigger = true;

    DBG("Setup for Make Noise Maths");
}

void ModularIntegration::setupForMetropolis(int clockOut, int resetOut, int pitchCV)
{
    mapCVOutput(clockOut, 0);
    mapCVOutput(resetOut, 1);
    mapCVOutput(pitchCV, 2, CVStandard::OneVoltPerOctave);

    m_cvOutputs[clockOut].isTrigger = true;
    m_cvOutputs[resetOut].isTrigger = true;

    DBG("Setup for Intellijel Metropolis");
}

// ===========================
// Internal Helpers
// ===========================

float ModularIntegration::voltageToSample(float voltage) const
{
    // DC-coupled audio: ±1.0 sample = ±10V (typical)
    return voltage / 10.0f;
}

float ModularIntegration::sampleToVoltage(float sample) const
{
    return sample * 10.0f;
}

float ModularIntegration::midiNoteToVoltage(int midiNote, CVStandard standard) const
{
    switch (standard)
    {
        case CVStandard::OneVoltPerOctave:
        {
            // MIDI note 60 (C4) = 0V
            // Each semitone = 1/12 volt
            return (midiNote - 60) / 12.0f;
        }

        case CVStandard::HzPerVolt:
        {
            // Buchla standard: 1.2V/octave
            return (midiNote - 60) / 10.0f;
        }

        case CVStandard::ZeroToTenVolt:
        default:
        {
            // Map MIDI range 0-127 to 0-10V
            return juce::jmap(static_cast<float>(midiNote), 0.0f, 127.0f, 0.0f, 10.0f);
        }
    }
}

int ModularIntegration::voltageToMidiNote(float voltage, CVStandard standard) const
{
    switch (standard)
    {
        case CVStandard::OneVoltPerOctave:
            return static_cast<int>(voltage * 12.0f + 60.0f);

        case CVStandard::HzPerVolt:
            return static_cast<int>(voltage * 10.0f + 60.0f);

        case CVStandard::ZeroToTenVolt:
        default:
            return static_cast<int>(juce::jmap(voltage, 0.0f, 10.0f, 0.0f, 127.0f));
    }
}

void ModularIntegration::updateSequencer(int numSamples)
{
    if (m_sequence.empty())
        return;

    const double beatsPerSecond = m_sequencerTempo / 60.0;
    const double beatsPerSample = beatsPerSecond / m_sampleRate;
    const double beatAdvancement = beatsPerSample * numSamples;

    m_sequencerPhase += beatAdvancement;

    // Check if we need to advance to next step
    const SequenceStep& currentStep = m_sequence[m_sequencePosition];

    if (m_sequencerPhase >= currentStep.duration)
    {
        m_sequencerPhase -= currentStep.duration;
        m_sequencePosition = (m_sequencePosition + 1) % m_sequence.size();

        // Output next step
        const SequenceStep& nextStep = m_sequence[m_sequencePosition];

        // Update pitch CV (output 0 by default)
        if (!m_cvOutputs.empty())
        {
            if (nextStep.voltage != 0.0f)
                setVoltage(0, nextStep.voltage);
            else
                setPitchCV(0, nextStep.midiNote);
        }

        // Update gate (output 1 by default)
        if (m_cvOutputs.size() > 1)
            setGate(1, nextStep.gate);

        // Send trigger if needed (output 2 by default)
        if (m_cvOutputs.size() > 2 && nextStep.trigger)
            sendTrigger(2);
    }
}

float ModularIntegration::processEnvelope(EnvelopeGenerator& env, int numSamples)
{
    if (!env.triggered)
        return 0.0f;

    float output = 0.0f;

    // Simplified ADSR - real implementation would be sample-accurate
    if (env.gateOn)
    {
        // Attack phase
        if (env.phase < env.attack)
        {
            output = env.phase / env.attack;
            env.phase += (numSamples / m_sampleRate);
        }
        // Decay phase
        else if (env.phase < env.attack + env.decay)
        {
            float decayPhase = (env.phase - env.attack) / env.decay;
            output = 1.0f - (1.0f - env.sustain) * decayPhase;
            env.phase += (numSamples / m_sampleRate);
        }
        // Sustain phase
        else
        {
            output = env.sustain;
        }
    }
    else
    {
        // Release phase
        float releasePhase = env.phase / env.release;
        output = env.sustain * (1.0f - releasePhase);
        env.phase += (numSamples / m_sampleRate);

        if (env.phase >= env.release)
        {
            env.triggered = false;
            env.phase = 0.0f;
            output = 0.0f;
        }
    }

    return output;
}

} // namespace Echoelmusic
