#include "FrequencyEntrainer.h"
#include <cmath>

//==============================================================================
// Constants
//==============================================================================

static constexpr double PI = 3.14159265358979323846;
static constexpr double TWO_PI = 2.0 * PI;

//==============================================================================
// Constructor / Destructor
//==============================================================================

FrequencyEntrainer::FrequencyEntrainer()
{
    sessionActive = false;
    sessionPaused = false;
    binauralEnabled = false;
    adaptiveEnabled = true;

    currentHRV = 0.5f;
    currentCoherence = 0.5f;
    currentHeartRate = 70.0f;

    currentSampleRate = 48000.0;
    oscillatorPhases[0] = 0.0;
    oscillatorPhases[1] = 0.0;

    // Initialize frequency database
    initializeFrequencyDatabase();

    // Default program: Alpha relaxation
    currentProgram = getPresetProgram(ProgramPreset::Relaxation);

    DBG("FrequencyEntrainer: Evidence-based brainwave entrainment system initialized");
}

//==============================================================================
// Frequency Database Initialization
//==============================================================================

void FrequencyEntrainer::initializeFrequencyDatabase()
{
    // Brainwave frequency ranges (EEG-validated)
    // Reference: Niedermeyer & da Silva (2005) "Electroencephalography"
    brainwaveRanges[BrainwaveState::Delta] = {0.5f, 4.0f};
    brainwaveRanges[BrainwaveState::Theta] = {4.0f, 8.0f};
    brainwaveRanges[BrainwaveState::Alpha] = {8.0f, 13.0f};
    brainwaveRanges[BrainwaveState::Beta] = {13.0f, 30.0f};
    brainwaveRanges[BrainwaveState::Gamma] = {30.0f, 100.0f};

    DBG("FrequencyEntrainer: Frequency database initialized (EEG-validated ranges)");
}

//==============================================================================
// Program Management
//==============================================================================

FrequencyEntrainer::EntrainmentProgram FrequencyEntrainer::getPresetProgram(ProgramPreset preset)
{
    EntrainmentProgram program;

    switch (preset)
    {
        // Sleep & Rest
        case ProgramPreset::DeepSleep:
            program.name = "Deep Sleep (Delta 2 Hz)";
            program.targetState = BrainwaveState::Delta;
            program.beatFrequency = 2.0f;
            program.carrierFrequency = 100.0f;  // Low carrier for sleep
            program.duration = 1800.0f;  // 30 minutes
            program.amplitude = 0.2f;
            break;

        case ProgramPreset::LightSleep:
            program.name = "Light Sleep (Theta 4 Hz)";
            program.targetState = BrainwaveState::Theta;
            program.beatFrequency = 4.0f;
            program.carrierFrequency = 150.0f;
            program.duration = 1200.0f;  // 20 minutes
            program.amplitude = 0.25f;
            break;

        // Relaxation
        case ProgramPreset::Meditation:
            program.name = "Meditation (Theta 6 Hz)";
            program.targetState = BrainwaveState::Theta;
            program.beatFrequency = 6.0f;
            program.carrierFrequency = 200.0f;
            program.duration = 900.0f;  // 15 minutes
            program.amplitude = 0.3f;
            break;

        case ProgramPreset::Relaxation:
            program.name = "Relaxation (Alpha 10 Hz)";
            program.targetState = BrainwaveState::Alpha;
            program.beatFrequency = 10.0f;
            program.carrierFrequency = 200.0f;
            program.duration = 600.0f;  // 10 minutes
            program.amplitude = 0.3f;
            break;

        case ProgramPreset::StressReduction:
            program.name = "Stress Reduction (Alpha-Theta 8 Hz)";
            program.targetState = BrainwaveState::Alpha;
            program.beatFrequency = 8.0f;
            program.carrierFrequency = 180.0f;
            program.amplitudeModulation = 0.1f;  // Gentle breathing rhythm
            program.duration = 900.0f;  // 15 minutes
            program.amplitude = 0.3f;
            break;

        // Focus & Performance
        case ProgramPreset::LearningState:
            program.name = "Learning State (Alpha 11 Hz)";
            program.targetState = BrainwaveState::Alpha;
            program.beatFrequency = 11.0f;
            program.carrierFrequency = 250.0f;
            program.duration = 1200.0f;  // 20 minutes
            program.amplitude = 0.35f;
            break;

        case ProgramPreset::FocusedWork:
            program.name = "Focused Work (Low Beta 14 Hz)";
            program.targetState = BrainwaveState::Beta;
            program.beatFrequency = 14.0f;
            program.carrierFrequency = 300.0f;
            program.duration = 1800.0f;  // 30 minutes
            program.amplitude = 0.35f;
            break;

        case ProgramPreset::ActiveThinking:
            program.name = "Active Thinking (Beta 18 Hz)";
            program.targetState = BrainwaveState::Beta;
            program.beatFrequency = 18.0f;
            program.carrierFrequency = 350.0f;
            program.duration = 1200.0f;  // 20 minutes
            program.amplitude = 0.35f;
            break;

        case ProgramPreset::PeakPerformance:
            program.name = "Peak Performance (Gamma 40 Hz)";
            program.targetState = BrainwaveState::Gamma;
            program.beatFrequency = 40.0f;
            program.carrierFrequency = 400.0f;
            program.duration = 600.0f;  // 10 minutes (gamma sessions shorter)
            program.amplitude = 0.3f;
            break;

        case ProgramPreset::AdaptiveCoherence:
            program.name = "Adaptive Coherence (Biofeedback-Driven)";
            program.targetState = BrainwaveState::Alpha;  // Default, will adapt
            program.beatFrequency = 10.0f;  // Will adapt based on bio-data
            program.carrierFrequency = 200.0f;
            program.duration = 900.0f;  // 15 minutes
            program.amplitude = 0.3f;
            break;
    }

    DBG("FrequencyEntrainer: Created preset program: " << program.name);
    return program;
}

FrequencyEntrainer::EntrainmentProgram FrequencyEntrainer::getBrainwaveProgram(BrainwaveState state)
{
    EntrainmentProgram program;
    program.targetState = state;

    auto it = brainwaveRanges.find(state);
    if (it != brainwaveRanges.end())
    {
        // Use middle of range for beat frequency
        float lowFreq = it->second.first;
        float highFreq = it->second.second;
        program.beatFrequency = (lowFreq + highFreq) / 2.0f;
    }

    // Set program properties based on state
    switch (state)
    {
        case BrainwaveState::Delta:
            program.name = "Delta State (Deep Sleep)";
            program.carrierFrequency = 100.0f;
            program.duration = 1800.0f;
            program.amplitude = 0.2f;
            break;

        case BrainwaveState::Theta:
            program.name = "Theta State (Relaxation)";
            program.carrierFrequency = 150.0f;
            program.duration = 900.0f;
            program.amplitude = 0.25f;
            break;

        case BrainwaveState::Alpha:
            program.name = "Alpha State (Calm Alertness)";
            program.carrierFrequency = 200.0f;
            program.duration = 600.0f;
            program.amplitude = 0.3f;
            break;

        case BrainwaveState::Beta:
            program.name = "Beta State (Active Focus)";
            program.carrierFrequency = 300.0f;
            program.duration = 900.0f;
            program.amplitude = 0.35f;
            break;

        case BrainwaveState::Gamma:
            program.name = "Gamma State (High Cognition)";
            program.carrierFrequency = 400.0f;
            program.duration = 600.0f;
            program.amplitude = 0.3f;
            break;
    }

    DBG("FrequencyEntrainer: Created brainwave program: " << program.name);
    return program;
}

void FrequencyEntrainer::setCustomProgram(const EntrainmentProgram& program)
{
    currentProgram = program;
    DBG("FrequencyEntrainer: Custom program set: " << program.name);
}

//==============================================================================
// Binaural Beats
//==============================================================================

void FrequencyEntrainer::setBinauralBeat(BrainwaveState state)
{
    auto it = brainwaveRanges.find(state);
    if (it != brainwaveRanges.end())
    {
        // Use middle of range
        float lowFreq = it->second.first;
        float highFreq = it->second.second;
        binauralBeatFreq = (lowFreq + highFreq) / 2.0f;
    }

    binauralEnabled = true;

    DBG("FrequencyEntrainer: Binaural beat set to " << (int)state);
    DBG("  Frequency: " << binauralBeatFreq << " Hz");
}

void FrequencyEntrainer::setBinauralBeatFrequency(float frequencyHz)
{
    binauralBeatFreq = juce::jlimit(0.5f, 100.0f, frequencyHz);
    binauralEnabled = true;

    DBG("FrequencyEntrainer: Binaural beat frequency set to " << frequencyHz << " Hz");
}

void FrequencyEntrainer::setBinauralEnabled(bool enabled)
{
    binauralEnabled = enabled;
    DBG("FrequencyEntrainer: Binaural beats "
        << (enabled ? "enabled" : "disabled"));
}

//==============================================================================
// Bio-Feedback Integration
//==============================================================================

void FrequencyEntrainer::setBioData(float hrv, float coherence, float heartRate)
{
    currentHRV = juce::jlimit(0.0f, 1.0f, hrv);
    currentCoherence = juce::jlimit(0.0f, 1.0f, coherence);
    currentHeartRate = juce::jlimit(40.0f, 200.0f, heartRate);

    if (adaptiveEnabled && sessionActive)
    {
        // Adapt amplitude based on coherence
        // Higher coherence = slightly increase intensity
        currentProgram.amplitude = 0.2f + (currentCoherence * 0.2f);

        // Adapt modulation based on heart rate
        // Match breathing rate to heart rate for coherence
        float breathingRate = currentHeartRate / 60.0f * 0.2f;  // ~5 breaths/min optimal
        currentProgram.amplitudeModulation = breathingRate;

        DBG("FrequencyEntrainer: Adaptive entrainment adjusted");
        DBG("  Amplitude: " << currentProgram.amplitude);
        DBG("  Modulation: " << currentProgram.amplitudeModulation << " Hz");
    }
}

void FrequencyEntrainer::setAdaptiveEnabled(bool enabled)
{
    adaptiveEnabled = enabled;
    DBG("FrequencyEntrainer: Adaptive entrainment "
        << (enabled ? "enabled" : "disabled"));
}

FrequencyEntrainer::EntrainmentProgram FrequencyEntrainer::suggestProgramFromBioData()
{
    DBG("FrequencyEntrainer: Suggesting program based on bio-data");
    DBG("  HRV: " << currentHRV);
    DBG("  Coherence: " << currentCoherence);
    DBG("  Heart Rate: " << currentHeartRate);

    // Low coherence -> Stress reduction (Alpha-Theta)
    if (currentCoherence < 0.4f)
    {
        DBG("  Suggested: Stress Reduction (low coherence)");
        return getPresetProgram(ProgramPreset::StressReduction);
    }

    // Low HRV -> Relaxation (Alpha)
    if (currentHRV < 0.4f)
    {
        DBG("  Suggested: Relaxation (low HRV)");
        return getPresetProgram(ProgramPreset::Relaxation);
    }

    // High heart rate -> Meditation (Theta)
    if (currentHeartRate > 80.0f)
    {
        DBG("  Suggested: Meditation (elevated heart rate)");
        return getPresetProgram(ProgramPreset::Meditation);
    }

    // Good vitals -> Focus or learning
    DBG("  Suggested: Learning State (good vitals)");
    return getPresetProgram(ProgramPreset::LearningState);
}

//==============================================================================
// Session Control
//==============================================================================

void FrequencyEntrainer::startSession()
{
    sessionActive = true;
    sessionPaused = false;
    sessionStartTime = juce::Time::getMillisecondCounterHiRes() / 1000.0;
    elapsedTime = 0.0;
    sessionDuration = currentProgram.duration;

    DBG("FrequencyEntrainer: Session started");
    DBG("  Program: " << currentProgram.name);
    DBG("  Duration: " << sessionDuration << " seconds");
    DBG("  Beat Frequency: " << currentProgram.beatFrequency << " Hz");

    if (binauralEnabled)
        DBG("  Binaural: " << binauralBeatFreq << " Hz");
}

void FrequencyEntrainer::stopSession()
{
    if (sessionActive)
    {
        // Save session record
        SessionRecord record;
        record.date = juce::Time::getCurrentTime().toString(true, true);
        record.programName = currentProgram.name;
        record.targetState = currentProgram.targetState;
        record.duration = static_cast<float>(elapsedTime);
        record.avgCoherence = currentCoherence;
        record.startHRV = currentHRV;
        record.endHRV = currentHRV;
        record.completed = (elapsedTime >= sessionDuration * 0.9);  // 90% = completed

        saveSession(record);

        DBG("FrequencyEntrainer: Session stopped");
        DBG("  Duration: " << elapsedTime << " seconds");
        DBG("  Completed: " << (record.completed ? "Yes" : "No"));
    }

    sessionActive = false;
    sessionPaused = false;
}

void FrequencyEntrainer::pauseSession()
{
    sessionPaused = true;
    DBG("FrequencyEntrainer: Session paused");
}

void FrequencyEntrainer::resumeSession()
{
    sessionPaused = false;
    DBG("FrequencyEntrainer: Session resumed");
}

float FrequencyEntrainer::getSessionProgress() const
{
    if (sessionDuration <= 0.0)
        return 0.0f;

    return static_cast<float>(elapsedTime / sessionDuration);
}

double FrequencyEntrainer::getRemainingTime() const
{
    return juce::jmax(0.0, sessionDuration - elapsedTime);
}

//==============================================================================
// Processing
//==============================================================================

void FrequencyEntrainer::prepare(double sampleRate, int maxBlockSize)
{
    currentSampleRate = sampleRate;

    DBG("FrequencyEntrainer: Prepared for processing");
    DBG("  Sample rate: " << sampleRate << " Hz");
    DBG("  Max block size: " << maxBlockSize);
}

void FrequencyEntrainer::process(juce::AudioBuffer<float>& buffer)
{
    if (!sessionActive || sessionPaused)
    {
        buffer.clear();
        return;
    }

    // Generate primary tone
    if (binauralEnabled)
    {
        // Binaural beat
        generateBinauralBeat(buffer, currentProgram.carrierFrequency, currentProgram.beatFrequency);
    }
    else
    {
        // Mono tone (same in both channels)
        generateTone(buffer, currentProgram.carrierFrequency, currentProgram.amplitude);
    }

    // Add harmonics
    for (float harmonicFreq : currentProgram.harmonics)
    {
        juce::AudioBuffer<float> harmonicBuffer(buffer.getNumChannels(), buffer.getNumSamples());
        generateTone(harmonicBuffer, harmonicFreq, currentProgram.amplitude * 0.3f);

        // Mix in
        for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
        {
            buffer.addFrom(ch, 0, harmonicBuffer, ch, 0, buffer.getNumSamples());
        }
    }

    // Apply amplitude modulation (breathing rhythm)
    if (currentProgram.amplitudeModulation > 0.0f)
    {
        applyAmplitudeModulation(buffer, currentProgram.amplitudeModulation);
    }

    // Update elapsed time
    double bufferDuration = buffer.getNumSamples() / currentSampleRate;
    elapsedTime += bufferDuration;

    // Stop if session duration reached
    if (elapsedTime >= sessionDuration)
    {
        stopSession();
    }

    // Update visualization data
    currentWaveform.clear();
    for (int i = 0; i < juce::jmin(512, buffer.getNumSamples()); ++i)
    {
        currentWaveform.push_back(buffer.getSample(0, i));
    }
}

//==============================================================================
// Audio Generation
//==============================================================================

void FrequencyEntrainer::generateTone(juce::AudioBuffer<float>& buffer, float frequency, float amplitude)
{
    int numSamples = buffer.getNumSamples();
    int numChannels = buffer.getNumChannels();

    double phaseIncrement = TWO_PI * frequency / currentSampleRate;

    for (int sample = 0; sample < numSamples; ++sample)
    {
        float value = static_cast<float>(std::sin(oscillatorPhases[0]) * amplitude);

        for (int channel = 0; channel < numChannels; ++channel)
        {
            buffer.setSample(channel, sample, value);
        }

        oscillatorPhases[0] += phaseIncrement;
        if (oscillatorPhases[0] >= TWO_PI)
            oscillatorPhases[0] -= TWO_PI;
    }
}

void FrequencyEntrainer::generateBinauralBeat(juce::AudioBuffer<float>& buffer, float carrierFreq, float beatFreq)
{
    if (buffer.getNumChannels() < 2)
    {
        // Need stereo for binaural
        generateTone(buffer, carrierFreq, currentProgram.amplitude);
        return;
    }

    int numSamples = buffer.getNumSamples();

    // Left ear: carrier frequency
    float leftFreq = carrierFreq;
    // Right ear: carrier + beat frequency
    float rightFreq = carrierFreq + beatFreq;

    double leftPhaseIncrement = TWO_PI * leftFreq / currentSampleRate;
    double rightPhaseIncrement = TWO_PI * rightFreq / currentSampleRate;

    for (int sample = 0; sample < numSamples; ++sample)
    {
        // Left channel
        float leftValue = static_cast<float>(std::sin(oscillatorPhases[0]) * currentProgram.amplitude);
        buffer.setSample(0, sample, leftValue);

        // Right channel
        float rightValue = static_cast<float>(std::sin(oscillatorPhases[1]) * currentProgram.amplitude);
        buffer.setSample(1, sample, rightValue);

        oscillatorPhases[0] += leftPhaseIncrement;
        oscillatorPhases[1] += rightPhaseIncrement;

        if (oscillatorPhases[0] >= TWO_PI)
            oscillatorPhases[0] -= TWO_PI;
        if (oscillatorPhases[1] >= TWO_PI)
            oscillatorPhases[1] -= TWO_PI;
    }
}

void FrequencyEntrainer::applyAmplitudeModulation(juce::AudioBuffer<float>& buffer, float modFreq)
{
    int numSamples = buffer.getNumSamples();
    int numChannels = buffer.getNumChannels();

    double modPhaseIncrement = TWO_PI * modFreq / currentSampleRate;
    static double modPhase = 0.0;

    for (int sample = 0; sample < numSamples; ++sample)
    {
        // Modulation envelope (0.5 to 1.0 for gentle breathing effect)
        float modulation = 0.5f + 0.5f * static_cast<float>(std::sin(modPhase));

        for (int channel = 0; channel < numChannels; ++channel)
        {
            float currentValue = buffer.getSample(channel, sample);
            buffer.setSample(channel, sample, currentValue * modulation);
        }

        modPhase += modPhaseIncrement;
        if (modPhase >= TWO_PI)
            modPhase -= TWO_PI;
    }
}

//==============================================================================
// Session History & Tracking
//==============================================================================

std::vector<FrequencyEntrainer::SessionRecord> FrequencyEntrainer::getSessionHistory() const
{
    return sessionHistory;
}

void FrequencyEntrainer::saveSession(const SessionRecord& record)
{
    sessionHistory.push_back(record);

    DBG("FrequencyEntrainer: Session saved");
    DBG("  Date: " << record.date);
    DBG("  Program: " << record.programName);
    DBG("  Duration: " << record.duration << "s");
    DBG("  Avg Coherence: " << record.avgCoherence);
    DBG("  HRV: " << record.startHRV << " -> " << record.endHRV);

    // In a real implementation, this would save to database or file
}

//==============================================================================
// Visualization
//==============================================================================

std::vector<float> FrequencyEntrainer::getCurrentSpectrum() const
{
    // In a real implementation, this would perform FFT on current audio
    // For now, return placeholder spectrum showing the active frequencies

    std::vector<float> spectrum(512, 0.0f);

    if (sessionActive)
    {
        // Show peak at carrier frequency
        int binIndex = static_cast<int>((currentProgram.carrierFrequency / (currentSampleRate / 2.0)) * 512);
        if (binIndex < 512)
            spectrum[binIndex] = 1.0f;

        // Show harmonics
        for (float harmonic : currentProgram.harmonics)
        {
            int hBinIndex = static_cast<int>((harmonic / (currentSampleRate / 2.0)) * 512);
            if (hBinIndex < 512)
                spectrum[hBinIndex] = 0.5f;
        }
    }

    return spectrum;
}

std::vector<float> FrequencyEntrainer::getCurrentWaveform() const
{
    return currentWaveform;
}
