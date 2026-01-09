#include "BrainwaveEntrainment.h"
#include <cmath>

//==============================================================================
// Constants
//==============================================================================

static constexpr double PI = 3.14159265358979323846;
static constexpr double TWO_PI = 2.0 * PI;

//==============================================================================
// Constructor
//==============================================================================

BrainwaveEntrainment::BrainwaveEntrainment()
{
    sessionActive = false;
    sessionPaused = false;
    adaptiveEnabled = false;

    currentHRV = 0.5f;
    currentCoherence = 0.5f;
    currentHeartRate = 70.0f;

    currentSampleRate = 48000.0;
    oscillatorPhases[0] = 0.0;
    oscillatorPhases[1] = 0.0;
    isochronicPhase = 0.0;

    initializeFrequencyDatabase();

    // Default: Alpha state (relaxed wakefulness)
    currentSession = getPresetSession(BrainwaveState::Alpha);

    DBG("BrainwaveEntrainment: Scientifically-grounded entrainment system initialized");
    DBG("  " << getDisclaimer());
}

//==============================================================================
// Frequency Database (Peer-Reviewed Research Only)
//==============================================================================

void BrainwaveEntrainment::initializeFrequencyDatabase()
{
    // Brainwave frequency ranges (EEG research consensus)
    // Source: Niedermeyer & da Silva (2004), Electroencephalography
    brainwaveRanges[BrainwaveState::Delta] = {0.5f, 4.0f};
    brainwaveRanges[BrainwaveState::Theta] = {4.0f, 8.0f};
    brainwaveRanges[BrainwaveState::Alpha] = {8.0f, 14.0f};
    brainwaveRanges[BrainwaveState::Beta] = {14.0f, 30.0f};
    brainwaveRanges[BrainwaveState::Gamma] = {30.0f, 50.0f};

    DBG("BrainwaveEntrainment: Frequency database initialized (EEG research basis)");
}

//==============================================================================
// Session Management
//==============================================================================

BrainwaveEntrainment::EntrainmentSession BrainwaveEntrainment::getPresetSession(BrainwaveState state)
{
    EntrainmentSession session;
    session.targetState = state;
    session.carrierFrequency = 200.0f;  // Standard carrier
    session.duration = 600.0f;  // 10 minutes
    session.amplitude = 0.3f;   // Gentle

    auto it = brainwaveRanges.find(state);
    if (it != brainwaveRanges.end())
    {
        // Use middle of validated range
        float lowFreq = it->second.first;
        float highFreq = it->second.second;
        session.entrainmentFrequency = (lowFreq + highFreq) / 2.0f;
    }

    switch (state)
    {
        case BrainwaveState::Delta:
            session.name = "Delta (Deep Rest) - 2 Hz";
            session.entrainmentFrequency = 2.0f;
            session.amplitudeModulation = 0.1f;  // Very slow breathing
            break;

        case BrainwaveState::Theta:
            session.name = "Theta (Meditation) - 6 Hz";
            session.entrainmentFrequency = 6.0f;
            session.amplitudeModulation = 0.15f;  // Slow breathing
            break;

        case BrainwaveState::Alpha:
            session.name = "Alpha (Relaxation) - 10 Hz";
            session.entrainmentFrequency = 10.0f;
            session.amplitudeModulation = 0.2f;  // Normal relaxed breathing
            break;

        case BrainwaveState::Beta:
            session.name = "Beta (Focus) - 20 Hz";
            session.entrainmentFrequency = 20.0f;
            session.amplitudeModulation = 0.0f;  // No modulation for focus
            break;

        case BrainwaveState::Gamma:
            // MIT GENUS research uses 40Hz
            session.name = "Gamma (Cognition) - 40 Hz (MIT GENUS)";
            session.entrainmentFrequency = 40.0f;
            session.amplitudeModulation = 0.0f;
            break;
    }

    DBG("BrainwaveEntrainment: Created preset session: " << session.name);

    return session;
}

void BrainwaveEntrainment::setSession(const EntrainmentSession& session)
{
    currentSession = session;
    DBG("BrainwaveEntrainment: Session set: " << session.name);
}

void BrainwaveEntrainment::setEntrainmentFrequency(float frequencyHz)
{
    // Limit to scientifically valid range (0.5 - 50 Hz)
    currentSession.entrainmentFrequency = juce::jlimit(0.5f, 50.0f, frequencyHz);
    DBG("BrainwaveEntrainment: Entrainment frequency set to " << frequencyHz << " Hz");
}

void BrainwaveEntrainment::setCarrierFrequency(float frequencyHz)
{
    // Carrier must be audible (20-500 Hz typical)
    currentSession.carrierFrequency = juce::jlimit(20.0f, 500.0f, frequencyHz);
    DBG("BrainwaveEntrainment: Carrier frequency set to " << frequencyHz << " Hz");
}

//==============================================================================
// Mode Selection
//==============================================================================

void BrainwaveEntrainment::setMode(EntrainmentMode mode)
{
    entrainmentMode = mode;

    juce::String modeName;
    switch (mode)
    {
        case EntrainmentMode::BinauralBeat:
            modeName = "Binaural Beat (headphones required)";
            break;
        case EntrainmentMode::IsochronicTone:
            modeName = "Isochronic Tone (speakers OK)";
            break;
        case EntrainmentMode::Combined:
            modeName = "Combined (binaural + isochronic)";
            break;
    }

    DBG("BrainwaveEntrainment: Mode set to " << modeName);
}

//==============================================================================
// Bio-Feedback Integration
//==============================================================================

void BrainwaveEntrainment::setBioData(float hrv, float coherence, float heartRate)
{
    currentHRV = juce::jlimit(0.0f, 1.0f, hrv);
    currentCoherence = juce::jlimit(0.0f, 1.0f, coherence);
    currentHeartRate = juce::jlimit(40.0f, 200.0f, heartRate);

    if (adaptiveEnabled && sessionActive)
    {
        // Slightly adjust amplitude based on coherence
        currentSession.amplitude = 0.2f + (currentCoherence * 0.2f);

        DBG("BrainwaveEntrainment: Adaptive adjustment");
        DBG("  Amplitude: " << currentSession.amplitude);
    }
}

void BrainwaveEntrainment::setAdaptiveEnabled(bool enabled)
{
    adaptiveEnabled = enabled;
    DBG("BrainwaveEntrainment: Adaptive mode " << (enabled ? "enabled" : "disabled"));
}

//==============================================================================
// Session Control
//==============================================================================

void BrainwaveEntrainment::startSession()
{
    sessionActive = true;
    sessionPaused = false;
    sessionStartTime = juce::Time::getMillisecondCounterHiRes() / 1000.0;
    elapsedTime = 0.0;
    sessionDuration = currentSession.duration;

    DBG("BrainwaveEntrainment: Session started");
    DBG("  Session: " << currentSession.name);
    DBG("  Entrainment: " << currentSession.entrainmentFrequency << " Hz");
    DBG("  Carrier: " << currentSession.carrierFrequency << " Hz");
    DBG("  Duration: " << sessionDuration << " seconds");
}

void BrainwaveEntrainment::stopSession()
{
    if (sessionActive)
    {
        DBG("BrainwaveEntrainment: Session stopped after " << elapsedTime << " seconds");
    }

    sessionActive = false;
    sessionPaused = false;
}

void BrainwaveEntrainment::pauseSession()
{
    sessionPaused = true;
    DBG("BrainwaveEntrainment: Session paused");
}

void BrainwaveEntrainment::resumeSession()
{
    sessionPaused = false;
    DBG("BrainwaveEntrainment: Session resumed");
}

float BrainwaveEntrainment::getSessionProgress() const
{
    if (sessionDuration <= 0.0)
        return 0.0f;

    return static_cast<float>(elapsedTime / sessionDuration);
}

double BrainwaveEntrainment::getRemainingTime() const
{
    return juce::jmax(0.0, sessionDuration - elapsedTime);
}

//==============================================================================
// Processing
//==============================================================================

void BrainwaveEntrainment::prepare(double sampleRate, int maxBlockSize)
{
    currentSampleRate = sampleRate;

    DBG("BrainwaveEntrainment: Prepared");
    DBG("  Sample rate: " << sampleRate << " Hz");
    DBG("  Max block: " << maxBlockSize);
}

void BrainwaveEntrainment::process(juce::AudioBuffer<float>& buffer)
{
    if (!sessionActive || sessionPaused)
    {
        buffer.clear();
        return;
    }

    // Generate entrainment based on mode
    switch (entrainmentMode)
    {
        case EntrainmentMode::BinauralBeat:
            generateBinauralBeat(buffer);
            break;

        case EntrainmentMode::IsochronicTone:
            generateIsochronicTone(buffer);
            break;

        case EntrainmentMode::Combined:
            generateBinauralBeat(buffer);
            // Add isochronic overlay
            {
                juce::AudioBuffer<float> isoBuffer(buffer.getNumChannels(), buffer.getNumSamples());
                generateIsochronicTone(isoBuffer);
                for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
                {
                    buffer.addFrom(ch, 0, isoBuffer, ch, 0, buffer.getNumSamples(), 0.5f);
                }
            }
            break;
    }

    // Apply amplitude modulation (breathing rhythm) if set
    if (currentSession.amplitudeModulation > 0.0f)
    {
        applyAmplitudeModulation(buffer, currentSession.amplitudeModulation);
    }

    // Update elapsed time
    double bufferDuration = buffer.getNumSamples() / currentSampleRate;
    elapsedTime += bufferDuration;

    // Stop if session complete
    if (elapsedTime >= sessionDuration)
    {
        stopSession();
    }

    // Update visualization
    currentWaveform.clear();
    for (int i = 0; i < juce::jmin(512, buffer.getNumSamples()); ++i)
    {
        currentWaveform.push_back(buffer.getSample(0, i));
    }
}

//==============================================================================
// Audio Generation
//==============================================================================

void BrainwaveEntrainment::generateBinauralBeat(juce::AudioBuffer<float>& buffer)
{
    if (buffer.getNumChannels() < 2)
    {
        // Binaural requires stereo - fall back to isochronic
        generateIsochronicTone(buffer);
        return;
    }

    int numSamples = buffer.getNumSamples();
    float carrier = currentSession.carrierFrequency;
    float beat = currentSession.entrainmentFrequency;
    float amp = currentSession.amplitude;

    // Left ear: carrier frequency
    // Right ear: carrier + beat frequency
    double leftPhaseInc = TWO_PI * carrier / currentSampleRate;
    double rightPhaseInc = TWO_PI * (carrier + beat) / currentSampleRate;

    for (int sample = 0; sample < numSamples; ++sample)
    {
        float leftValue = static_cast<float>(std::sin(oscillatorPhases[0]) * amp);
        float rightValue = static_cast<float>(std::sin(oscillatorPhases[1]) * amp);

        buffer.setSample(0, sample, leftValue);
        buffer.setSample(1, sample, rightValue);

        oscillatorPhases[0] += leftPhaseInc;
        oscillatorPhases[1] += rightPhaseInc;

        if (oscillatorPhases[0] >= TWO_PI)
            oscillatorPhases[0] -= TWO_PI;
        if (oscillatorPhases[1] >= TWO_PI)
            oscillatorPhases[1] -= TWO_PI;
    }
}

void BrainwaveEntrainment::generateIsochronicTone(juce::AudioBuffer<float>& buffer)
{
    int numSamples = buffer.getNumSamples();
    int numChannels = buffer.getNumChannels();
    float carrier = currentSession.carrierFrequency;
    float beat = currentSession.entrainmentFrequency;
    float amp = currentSession.amplitude;

    double carrierPhaseInc = TWO_PI * carrier / currentSampleRate;
    double isoPhaseInc = TWO_PI * beat / currentSampleRate;

    for (int sample = 0; sample < numSamples; ++sample)
    {
        // Carrier tone
        float carrierValue = static_cast<float>(std::sin(oscillatorPhases[0]));

        // Isochronic envelope (on/off pulsing)
        float envelope = std::sin(isochronicPhase) > 0.0 ? 1.0f : 0.0f;

        float value = carrierValue * envelope * amp;

        for (int channel = 0; channel < numChannels; ++channel)
        {
            buffer.setSample(channel, sample, value);
        }

        oscillatorPhases[0] += carrierPhaseInc;
        isochronicPhase += isoPhaseInc;

        if (oscillatorPhases[0] >= TWO_PI)
            oscillatorPhases[0] -= TWO_PI;
        if (isochronicPhase >= TWO_PI)
            isochronicPhase -= TWO_PI;
    }
}

void BrainwaveEntrainment::applyAmplitudeModulation(juce::AudioBuffer<float>& buffer, float modFreq)
{
    int numSamples = buffer.getNumSamples();
    int numChannels = buffer.getNumChannels();

    double modPhaseInc = TWO_PI * modFreq / currentSampleRate;
    static double modPhase = 0.0;

    for (int sample = 0; sample < numSamples; ++sample)
    {
        // Gentle breathing envelope (0.5 to 1.0)
        float modulation = 0.5f + 0.5f * static_cast<float>(std::sin(modPhase));

        for (int channel = 0; channel < numChannels; ++channel)
        {
            float currentValue = buffer.getSample(channel, sample);
            buffer.setSample(channel, sample, currentValue * modulation);
        }

        modPhase += modPhaseInc;
        if (modPhase >= TWO_PI)
            modPhase -= TWO_PI;
    }
}

//==============================================================================
// Visualization
//==============================================================================

std::vector<float> BrainwaveEntrainment::getCurrentWaveform() const
{
    return currentWaveform;
}
