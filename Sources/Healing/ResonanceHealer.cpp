#include "ResonanceHealer.h"
#include <cmath>

//==============================================================================
// Constants
//==============================================================================

static constexpr double PI = 3.14159265358979323846;
static constexpr double TWO_PI = 2.0 * PI;

//==============================================================================
// Constructor / Destructor
//==============================================================================

ResonanceHealer::ResonanceHealer()
{
    sessionActive = false;
    sessionPaused = false;
    binauralEnabled = false;
    adaptiveHealingEnabled = true;

    currentHRV = 0.5f;
    currentCoherence = 0.5f;
    currentHeartRate = 70.0f;

    currentSampleRate = 48000.0;
    oscillatorPhases[0] = 0.0;
    oscillatorPhases[1] = 0.0;

    // Initialize frequency databases
    initializeFrequencyDatabase();

    // Default program: Schumann resonance (whole body)
    currentProgram = getOrganProgram(Organ::WholeBody);

    DBG("ResonanceHealer: Professional healing frequency system initialized");
}

//==============================================================================
// Frequency Database Initialization
//==============================================================================

void ResonanceHealer::initializeFrequencyDatabase()
{
    // Organ resonance frequencies (research-based)
    organFrequencies[Organ::Brain] = 72.0f;
    organFrequencies[Organ::Heart] = 67.0f;
    organFrequencies[Organ::Lungs] = 58.0f;
    organFrequencies[Organ::Liver] = 55.0f;
    organFrequencies[Organ::Kidneys] = 50.0f;
    organFrequencies[Organ::Stomach] = 58.0f;
    organFrequencies[Organ::Intestines] = 48.0f;
    organFrequencies[Organ::Pancreas] = 60.0f;
    organFrequencies[Organ::Spleen] = 55.0f;
    organFrequencies[Organ::Thyroid] = 16.0f;
    organFrequencies[Organ::AdrenalGlands] = 24.0f;
    organFrequencies[Organ::Bones] = 38.0f;
    organFrequencies[Organ::Muscles] = 25.0f;
    organFrequencies[Organ::Nerves] = 72.0f;
    organFrequencies[Organ::Blood] = 60.0f;
    organFrequencies[Organ::WholeBody] = 7.83f;  // Schumann resonance

    // Solfeggio frequencies (ancient healing tones)
    solfeggioFrequencies[SolfeggioTone::UT_396] = 396.0f;
    solfeggioFrequencies[SolfeggioTone::RE_417] = 417.0f;
    solfeggioFrequencies[SolfeggioTone::MI_528] = 528.0f;  // DNA repair
    solfeggioFrequencies[SolfeggioTone::FA_639] = 639.0f;
    solfeggioFrequencies[SolfeggioTone::SOL_741] = 741.0f;
    solfeggioFrequencies[SolfeggioTone::LA_852] = 852.0f;
    solfeggioFrequencies[SolfeggioTone::SI_963] = 963.0f;

    // Chakra frequencies (planetary tuning)
    chakraFrequencies[Chakra::Root] = 194.18f;
    chakraFrequencies[Chakra::Sacral] = 210.42f;
    chakraFrequencies[Chakra::SolarPlexus] = 126.22f;
    chakraFrequencies[Chakra::Heart] = 136.10f;
    chakraFrequencies[Chakra::Throat] = 141.27f;
    chakraFrequencies[Chakra::ThirdEye] = 221.23f;
    chakraFrequencies[Chakra::Crown] = 172.06f;

    // Brainwave frequency ranges
    brainwaveRanges[BrainwaveState::Delta] = {0.5f, 4.0f};
    brainwaveRanges[BrainwaveState::Theta] = {4.0f, 8.0f};
    brainwaveRanges[BrainwaveState::Alpha] = {8.0f, 14.0f};
    brainwaveRanges[BrainwaveState::Beta] = {14.0f, 30.0f};
    brainwaveRanges[BrainwaveState::Gamma] = {30.0f, 100.0f};

    DBG("ResonanceHealer: Frequency database initialized");
}

//==============================================================================
// Program Management
//==============================================================================

ResonanceHealer::HealingProgram ResonanceHealer::getOrganProgram(Organ organ)
{
    HealingProgram program;

    auto it = organFrequencies.find(organ);
    if (it != organFrequencies.end())
    {
        program.frequency = it->second;
    }

    program.targetOrgan = organ;

    // Set program name
    switch (organ)
    {
        case Organ::Brain:
            program.name = "Brain Resonance (72 Hz)";
            program.harmonics = {144.0f, 216.0f};  // Octaves
            break;
        case Organ::Heart:
            program.name = "Heart Coherence (67 Hz)";
            program.harmonics = {134.0f, 201.0f};
            program.binauralBeatFreq = 10.0f;  // Alpha (relaxation)
            break;
        case Organ::Lungs:
            program.name = "Respiratory Balance (58 Hz)";
            program.harmonics = {116.0f, 174.0f};
            program.amplitudeModulation = 0.25f;  // 4 seconds breathing cycle
            break;
        case Organ::Liver:
            program.name = "Liver Detox (55 Hz)";
            program.harmonics = {110.0f, 165.0f};
            break;
        case Organ::Kidneys:
            program.name = "Kidney Health (50 Hz)";
            program.harmonics = {100.0f, 150.0f};
            break;
        case Organ::Stomach:
            program.name = "Digestive Balance (58 Hz)";
            program.harmonics = {116.0f, 174.0f};
            break;
        case Organ::Intestines:
            program.name = "Intestinal Health (48 Hz)";
            program.harmonics = {96.0f, 144.0f};
            break;
        case Organ::Pancreas:
            program.name = "Pancreas Support (60 Hz)";
            program.harmonics = {120.0f, 180.0f};
            break;
        case Organ::Spleen:
            program.name = "Immune System (55 Hz)";
            program.harmonics = {110.0f, 165.0f};
            break;
        case Organ::Thyroid:
            program.name = "Thyroid Balance (16 Hz)";
            program.harmonics = {32.0f, 48.0f};
            break;
        case Organ::AdrenalGlands:
            program.name = "Adrenal Support (24 Hz)";
            program.harmonics = {48.0f, 72.0f};
            break;
        case Organ::Bones:
            program.name = "Bone Strengthening (38 Hz)";
            program.harmonics = {76.0f, 114.0f};
            break;
        case Organ::Muscles:
            program.name = "Muscle Recovery (25 Hz)";
            program.harmonics = {50.0f, 75.0f};
            break;
        case Organ::Nerves:
            program.name = "Nervous System (72 Hz)";
            program.harmonics = {144.0f, 216.0f};
            break;
        case Organ::Blood:
            program.name = "Blood Circulation (60 Hz)";
            program.harmonics = {120.0f, 180.0f};
            break;
        case Organ::WholeBody:
            program.name = "Schumann Resonance (7.83 Hz)";
            program.harmonics = {15.66f, 23.49f};
            program.binauralBeatFreq = 7.83f;  // Earth frequency
            break;
    }

    // Default settings
    program.duration = 600.0f;  // 10 minutes
    program.amplitude = 0.3f;   // Gentle

    DBG("ResonanceHealer: Created program: " << program.name);

    return program;
}

ResonanceHealer::HealingProgram ResonanceHealer::getSolfeggioProgram(SolfeggioTone tone)
{
    HealingProgram program;

    auto it = solfeggioFrequencies.find(tone);
    if (it != solfeggioFrequencies.end())
    {
        program.frequency = it->second;
    }

    // Set program name and purpose
    switch (tone)
    {
        case SolfeggioTone::UT_396:
            program.name = "UT 396 Hz - Liberation";
            program.targetOrgan = Organ::WholeBody;
            break;
        case SolfeggioTone::RE_417:
            program.name = "RE 417 Hz - Change";
            program.targetOrgan = Organ::WholeBody;
            break;
        case SolfeggioTone::MI_528:
            program.name = "MI 528 Hz - DNA Repair (Love Frequency)";
            program.targetOrgan = Organ::WholeBody;
            program.harmonics = {1056.0f, 1584.0f};
            break;
        case SolfeggioTone::FA_639:
            program.name = "FA 639 Hz - Connection";
            program.targetOrgan = Organ::Heart;
            break;
        case SolfeggioTone::SOL_741:
            program.name = "SOL 741 Hz - Intuition";
            program.targetOrgan = Organ::Brain;
            break;
        case SolfeggioTone::LA_852:
            program.name = "LA 852 Hz - Spiritual Order";
            program.targetOrgan = Organ::Brain;
            break;
        case SolfeggioTone::SI_963:
            program.name = "SI 963 Hz - Divine Consciousness";
            program.targetOrgan = Organ::Brain;
            break;
    }

    program.duration = 900.0f;  // 15 minutes for Solfeggio
    program.amplitude = 0.25f;

    DBG("ResonanceHealer: Created Solfeggio program: " << program.name);

    return program;
}

ResonanceHealer::HealingProgram ResonanceHealer::getChakraProgram(Chakra chakra)
{
    HealingProgram program;

    auto it = chakraFrequencies.find(chakra);
    if (it != chakraFrequencies.end())
    {
        program.frequency = it->second;
    }

    // Set program name
    switch (chakra)
    {
        case Chakra::Root:
            program.name = "Root Chakra (194.18 Hz)";
            program.targetOrgan = Organ::AdrenalGlands;
            break;
        case Chakra::Sacral:
            program.name = "Sacral Chakra (210.42 Hz)";
            program.targetOrgan = Organ::Kidneys;
            break;
        case Chakra::SolarPlexus:
            program.name = "Solar Plexus Chakra (126.22 Hz)";
            program.targetOrgan = Organ::Stomach;
            break;
        case Chakra::Heart:
            program.name = "Heart Chakra (136.10 Hz)";
            program.targetOrgan = Organ::Heart;
            break;
        case Chakra::Throat:
            program.name = "Throat Chakra (141.27 Hz)";
            program.targetOrgan = Organ::Thyroid;
            break;
        case Chakra::ThirdEye:
            program.name = "Third Eye Chakra (221.23 Hz)";
            program.targetOrgan = Organ::Brain;
            break;
        case Chakra::Crown:
            program.name = "Crown Chakra (172.06 Hz)";
            program.targetOrgan = Organ::Brain;
            break;
    }

    program.duration = 420.0f;  // 7 minutes per chakra
    program.amplitude = 0.3f;

    DBG("ResonanceHealer: Created Chakra program: " << program.name);

    return program;
}

void ResonanceHealer::setCustomProgram(const HealingProgram& program)
{
    currentProgram = program;
    DBG("ResonanceHealer: Custom program set: " << program.name);
}

//==============================================================================
// Binaural Beats
//==============================================================================

void ResonanceHealer::setBinauralBeat(BrainwaveState state)
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

    DBG("ResonanceHealer: Binaural beat set to " << (int)state);
    DBG("  Frequency: " << binauralBeatFreq << " Hz");
}

void ResonanceHealer::setBinauralBeatFrequency(float frequencyHz)
{
    binauralBeatFreq = juce::jlimit(0.5f, 100.0f, frequencyHz);
    binauralEnabled = true;

    DBG("ResonanceHealer: Binaural beat frequency set to " << frequencyHz << " Hz");
}

void ResonanceHealer::setBinauralEnabled(bool enabled)
{
    binauralEnabled = enabled;
    DBG("ResonanceHealer: Binaural beats "
        << (enabled ? "enabled" : "disabled"));
}

//==============================================================================
// Bio-Feedback Integration
//==============================================================================

void ResonanceHealer::setBioData(float hrv, float coherence, float heartRate)
{
    currentHRV = juce::jlimit(0.0f, 1.0f, hrv);
    currentCoherence = juce::jlimit(0.0f, 1.0f, coherence);
    currentHeartRate = juce::jlimit(40.0f, 200.0f, heartRate);

    if (adaptiveHealingEnabled && sessionActive)
    {
        // Adapt amplitude based on coherence
        // Higher coherence = increase intensity slightly
        currentProgram.amplitude = 0.2f + (currentCoherence * 0.2f);

        // Adapt modulation based on heart rate
        // Match breathing rate to heart rate for coherence
        float breathingRate = currentHeartRate / 60.0f * 0.2f;  // ~5 breaths/min optimal
        currentProgram.amplitudeModulation = breathingRate;

        DBG("ResonanceHealer: Adaptive healing adjusted");
        DBG("  Amplitude: " << currentProgram.amplitude);
        DBG("  Modulation: " << currentProgram.amplitudeModulation << " Hz");
    }
}

void ResonanceHealer::setAdaptiveHealingEnabled(bool enabled)
{
    adaptiveHealingEnabled = enabled;
    DBG("ResonanceHealer: Adaptive healing "
        << (enabled ? "enabled" : "disabled"));
}

ResonanceHealer::HealingProgram ResonanceHealer::suggestProgramFromBioData()
{
    DBG("ResonanceHealer: Suggesting program based on bio-data");
    DBG("  HRV: " << currentHRV);
    DBG("  Coherence: " << currentCoherence);
    DBG("  Heart Rate: " << currentHeartRate);

    // Low coherence -> Heart coherence program
    if (currentCoherence < 0.4f)
    {
        DBG("  Suggested: Heart Coherence");
        return getOrganProgram(Organ::Heart);
    }

    // Low HRV -> Stress relief (Alpha waves)
    if (currentHRV < 0.4f)
    {
        DBG("  Suggested: Stress Relief (Alpha)");
        HealingProgram program = getOrganProgram(Organ::WholeBody);
        program.name = "Stress Relief (Alpha Waves)";
        program.binauralBeatFreq = 10.0f;  // Alpha
        return program;
    }

    // High heart rate -> Calming (Delta/Theta)
    if (currentHeartRate > 80.0f)
    {
        DBG("  Suggested: Deep Relaxation (Theta)");
        HealingProgram program = getOrganProgram(Organ::WholeBody);
        program.name = "Deep Relaxation (Theta Waves)";
        program.binauralBeatFreq = 6.0f;  // Theta
        return program;
    }

    // Good vitals -> Enhancement (528 Hz DNA repair)
    DBG("  Suggested: DNA Repair (528 Hz)");
    return getSolfeggioProgram(SolfeggioTone::MI_528);
}

//==============================================================================
// Session Control
//==============================================================================

void ResonanceHealer::startSession()
{
    sessionActive = true;
    sessionPaused = false;
    sessionStartTime = juce::Time::getMillisecondCounterHiRes() / 1000.0;
    elapsedTime = 0.0;
    sessionDuration = currentProgram.duration;

    DBG("ResonanceHealer: Session started");
    DBG("  Program: " << currentProgram.name);
    DBG("  Duration: " << sessionDuration << " seconds");
    DBG("  Frequency: " << currentProgram.frequency << " Hz");

    if (binauralEnabled)
        DBG("  Binaural: " << binauralBeatFreq << " Hz");
}

void ResonanceHealer::stopSession()
{
    if (sessionActive)
    {
        // Save session record
        SessionRecord record;
        record.date = juce::Time::getCurrentTime().toString(true, true);
        record.programName = currentProgram.name;
        record.targetOrgan = currentProgram.targetOrgan;
        record.duration = static_cast<float>(elapsedTime);
        record.avgCoherence = currentCoherence;
        record.startHRV = currentHRV;
        record.endHRV = currentHRV;
        record.completed = (elapsedTime >= sessionDuration * 0.9);  // 90% = completed

        saveSession(record);

        DBG("ResonanceHealer: Session stopped");
        DBG("  Duration: " << elapsedTime << " seconds");
        DBG("  Completed: " << (record.completed ? "Yes" : "No"));
    }

    sessionActive = false;
    sessionPaused = false;
}

void ResonanceHealer::pauseSession()
{
    sessionPaused = true;
    DBG("ResonanceHealer: Session paused");
}

void ResonanceHealer::resumeSession()
{
    sessionPaused = false;
    DBG("ResonanceHealer: Session resumed");
}

float ResonanceHealer::getSessionProgress() const
{
    if (sessionDuration <= 0.0)
        return 0.0f;

    return static_cast<float>(elapsedTime / sessionDuration);
}

double ResonanceHealer::getRemainingTime() const
{
    return juce::jmax(0.0, sessionDuration - elapsedTime);
}

//==============================================================================
// Processing
//==============================================================================

void ResonanceHealer::prepare(double sampleRate, int maxBlockSize)
{
    currentSampleRate = sampleRate;

    DBG("ResonanceHealer: Prepared for processing");
    DBG("  Sample rate: " << sampleRate << " Hz");
    DBG("  Max block size: " << maxBlockSize);
}

void ResonanceHealer::process(juce::AudioBuffer<float>& buffer)
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
        generateBinauralBeat(buffer, currentProgram.frequency, binauralBeatFreq);
    }
    else
    {
        // Mono tone (same in both channels)
        generateTone(buffer, currentProgram.frequency, currentProgram.amplitude);
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
    // OPTIMIZATION: Pre-allocate to avoid dynamic allocations in audio callback
    constexpr int kWaveformSize = 512;
    if (currentWaveform.size() != kWaveformSize) {
        currentWaveform.resize(kWaveformSize, 0.0f);
    }
    const int samplesToCopy = juce::jmin(kWaveformSize, buffer.getNumSamples());
    const float* readPtr = buffer.getReadPointer(0);
    for (int i = 0; i < samplesToCopy; ++i) {
        currentWaveform[static_cast<size_t>(i)] = readPtr[i];
    }
    // Zero remaining if buffer was smaller
    for (int i = samplesToCopy; i < kWaveformSize; ++i) {
        currentWaveform[static_cast<size_t>(i)] = 0.0f;
    }
}

//==============================================================================
// Audio Generation
//==============================================================================

void ResonanceHealer::generateTone(juce::AudioBuffer<float>& buffer, float frequency, float amplitude)
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

void ResonanceHealer::generateBinauralBeat(juce::AudioBuffer<float>& buffer, float carrierFreq, float beatFreq)
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

void ResonanceHealer::applyAmplitudeModulation(juce::AudioBuffer<float>& buffer, float modFreq)
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

std::vector<ResonanceHealer::SessionRecord> ResonanceHealer::getSessionHistory() const
{
    return sessionHistory;
}

void ResonanceHealer::saveSession(const SessionRecord& record)
{
    sessionHistory.push_back(record);

    DBG("ResonanceHealer: Session saved");
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

std::vector<float> ResonanceHealer::getCurrentSpectrum() const
{
    // In a real implementation, this would perform FFT on current audio
    // For now, return placeholder spectrum showing the active frequencies

    std::vector<float> spectrum(512, 0.0f);

    if (sessionActive)
    {
        // Show peak at primary frequency
        int binIndex = static_cast<int>((currentProgram.frequency / (currentSampleRate / 2.0)) * 512);
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

std::vector<float> ResonanceHealer::getCurrentWaveform() const
{
    return currentWaveform;
}
