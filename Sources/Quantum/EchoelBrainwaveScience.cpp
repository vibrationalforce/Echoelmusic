#include "EchoelBrainwaveScience.h"
#include <cmath>

EchoelBrainwaveScience::EchoelBrainwaveScience()
{
}

EchoelBrainwaveScience::~EchoelBrainwaveScience()
{
}

//==============================================================================
// Research Protocols
//==============================================================================

EchoelBrainwaveScience::EntrainmentProtocol
EchoelBrainwaveScience::getResearchProtocol(TherapeuticTarget target)
{
    EntrainmentProtocol protocol;

    switch (target)
    {
        case TherapeuticTarget::DeepSleep:
            protocol.protocolName = "Deep Sleep Enhancement";
            protocol.startFrequency = 2.0f;
            protocol.endFrequency = 2.0f;
            protocol.duration = 1800.0f;  // 30 minutes
            protocol.researchCitation = "Oster, G. (1973). Scientific American.";
            break;

        case TherapeuticTarget::Meditation:
            protocol.protocolName = "Theta Meditation";
            protocol.startFrequency = 6.0f;
            protocol.endFrequency = 6.0f;
            protocol.duration = 1200.0f;  // 20 minutes
            break;

        case TherapeuticTarget::CreativeFlow:
            protocol.protocolName = "Flow State Induction";
            protocol.startFrequency = 7.5f;
            protocol.endFrequency = 7.5f;
            protocol.duration = 900.0f;  // 15 minutes
            break;

        case TherapeuticTarget::LightSleep:
        case TherapeuticTarget::Relaxation:
        case TherapeuticTarget::AlertFocus:
        case TherapeuticTarget::HighPerformance:
        case TherapeuticTarget::ProblemSolving:
        case TherapeuticTarget::StressReduction:
        case TherapeuticTarget::AnxietyRelief:
        case TherapeuticTarget::PainManagement:
        case TherapeuticTarget::DepressionRelief:
        case TherapeuticTarget::LucidDreaming:
        case TherapeuticTarget::RemoteViewing:
        case TherapeuticTarget::OutOfBody:
        case TherapeuticTarget::Psychedelic:
        case TherapeuticTarget::DNARepair:
        case TherapeuticTarget::SpirituaLawakening:
        case TherapeuticTarget::Manifestation:
            // TODO: Implement research protocols for these targets
            protocol.startFrequency = 10.0f;  // Alpha default
            break;
    }

    return protocol;
}

//==============================================================================
// HRV Analysis
//==============================================================================

EchoelBrainwaveScience::HRVMetrics
EchoelBrainwaveScience::calculateHRV(const std::vector<float>& rrIntervalsData)
{
    HRVMetrics metrics;

    if (rrIntervalsData.size() < 2)
        return metrics;

    // Calculate SDNN (standard deviation)
    float mean = 0.0f;
    for (float rr : rrIntervalsData)
        mean += rr;
    mean /= static_cast<float>(rrIntervalsData.size());

    float variance = 0.0f;
    for (float rr : rrIntervalsData)
        variance += (rr - mean) * (rr - mean);
    variance /= static_cast<float>(rrIntervalsData.size());

    metrics.SDNN = std::sqrt(variance);

    // Calculate RMSSD
    float sumSquaredDiffs = 0.0f;
    for (size_t i = 1; i < rrIntervalsData.size(); ++i)
    {
        float diff = rrIntervalsData[i] - rrIntervalsData[i - 1];
        sumSquaredDiffs += diff * diff;
    }
    metrics.RMSSD = std::sqrt(sumSquaredDiffs / static_cast<float>(rrIntervalsData.size() - 1));

    // Calculate pNN50
    int count50 = 0;
    for (size_t i = 1; i < rrIntervalsData.size(); ++i)
    {
        if (std::abs(rrIntervalsData[i] - rrIntervalsData[i - 1]) > 50.0f)
            count50++;
    }
    metrics.pNN50 = (static_cast<float>(count50) / static_cast<float>(rrIntervalsData.size() - 1)) * 100.0f;

    // Estimate coherence (simplified)
    metrics.coherence = juce::jlimit(0.0f, 1.0f, metrics.SDNN / 100.0f);
    metrics.stress = 1.0f - metrics.coherence;

    // Determine coherence level
    if (metrics.coherence < 0.5f)
        metrics.coherenceLevel = HRVMetrics::CoherenceLevel::Low;
    else if (metrics.coherence < 0.8f)
        metrics.coherenceLevel = HRVMetrics::CoherenceLevel::Medium;
    else
        metrics.coherenceLevel = HRVMetrics::CoherenceLevel::High;

    return metrics;
}

void EchoelBrainwaveScience::addHeartbeat(double timestamp)
{
    heartbeatTimestamps.push_back(timestamp);

    // Calculate RR interval
    if (heartbeatTimestamps.size() >= 2)
    {
        double rr = (heartbeatTimestamps.back() - heartbeatTimestamps[heartbeatTimestamps.size() - 2]) * 1000.0;
        rrIntervals.push_back(static_cast<float>(rr));

        // Keep only recent data
        if (rrIntervals.size() > MAX_RR_INTERVALS)
        {
            rrIntervals.erase(rrIntervals.begin());
            heartbeatTimestamps.erase(heartbeatTimestamps.begin());
        }

        // Recalculate HRV
        std::vector<float> rrIntervalsFloat(rrIntervals.begin(), rrIntervals.end());
        currentHRV = calculateHRV(rrIntervalsFloat);
    }
}

//==============================================================================
// EEG Analysis
//==============================================================================

EchoelBrainwaveScience::EEGPowers
EchoelBrainwaveScience::calculateEEGPowers(const std::vector<float>& rawEEG, float sampleRate)
{
    (void)rawEEG;
    (void)sampleRate;

    EEGPowers powers;

    // TODO: Implement FFT-based spectral analysis
    // This would use JUCE's FFT to calculate power in each frequency band

    return powers;
}

EchoelBrainwaveScience::MentalState
EchoelBrainwaveScience::detectMentalState(const EEGPowers& powers)
{
    // Simplified state detection based on dominant frequency
    float maxPower = 0.0f;
    MentalState state = MentalState::Unknown;

    if (powers.delta > maxPower) { maxPower = powers.delta; state = MentalState::DeepSleep; }
    if (powers.theta > maxPower) { maxPower = powers.theta; state = MentalState::Meditative; }
    if (powers.alpha > maxPower) { maxPower = powers.alpha; state = MentalState::Relaxed; }
    if (powers.beta > maxPower) { maxPower = powers.beta; state = MentalState::Focused; }
    if (powers.gamma > maxPower) { maxPower = powers.gamma; state = MentalState::FlowState; }

    return state;
}

//==============================================================================
// Safety
//==============================================================================

void EchoelBrainwaveScience::setSafetyFlags(bool epilepsy, bool pacemaker, bool pregnant)
{
    safetyMonitor.hasEpilepsy = epilepsy;
    safetyMonitor.hasPacemaker = pacemaker;
    safetyMonitor.isPregnant = pregnant;
}

bool EchoelBrainwaveScience::isSafeToStart() const
{
    // Do not start if user has contraindications
    if (safetyMonitor.hasEpilepsy || safetyMonitor.hasPacemaker || safetyMonitor.isPregnant)
        return false;

    // Do not start if session time exceeded
    if (safetyMonitor.totalSessionTime > 3600.0)  // Max 1 hour
        return false;

    return true;
}

//==============================================================================
// Session Control
//==============================================================================

void EchoelBrainwaveScience::startSession(const EntrainmentProtocol& protocol)
{
    if (!isSafeToStart())
        return;

    currentProtocol = protocol;
    sessionActive = true;
    sessionStartTimestamp = juce::Time::getMillisecondCounterHiRes() / 1000.0;
    currentPhase = 0.0f;
    currentFrequency = protocol.startFrequency;
}

void EchoelBrainwaveScience::stopSession()
{
    sessionActive = false;
    double sessionDuration = (juce::Time::getMillisecondCounterHiRes() / 1000.0) - sessionStartTimestamp;
    safetyMonitor.totalSessionTime += sessionDuration;
    safetyMonitor.totalLifetimeExposure += sessionDuration / 3600.0;
}

//==============================================================================
// Processing
//==============================================================================

void EchoelBrainwaveScience::process(juce::AudioBuffer<float>& buffer, double sampleRate)
{
    if (!sessionActive)
        return;

    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    // Generate entrainment signal
    for (int i = 0; i < numSamples; ++i)
    {
        float signal = generateEntrainmentSignal(currentFrequency, currentPhase, currentProtocol.waveShape);

        // Mix with existing audio (very quiet)
        float mixLevel = currentProtocol.maxIntensity * 0.1f;

        for (int ch = 0; ch < numChannels; ++ch)
        {
            buffer.addSample(ch, i, signal * mixLevel);
        }

        // Update phase
        currentPhase += currentFrequency * juce::MathConstants<float>::twoPi / static_cast<float>(sampleRate);
        if (currentPhase > juce::MathConstants<float>::twoPi)
            currentPhase -= juce::MathConstants<float>::twoPi;
    }

    // Update safety monitor
    updateSafetyMonitor(numSamples / sampleRate);
}

float EchoelBrainwaveScience::generateEntrainmentSignal(float frequency, float phase, EntrainmentProtocol::WaveShape shape)
{
    (void)frequency;

    switch (shape)
    {
        case EntrainmentProtocol::WaveShape::Sine:
            return std::sin(phase);

        case EntrainmentProtocol::WaveShape::Triangle:
            return (2.0f / juce::MathConstants<float>::pi) * std::asin(std::sin(phase));

        case EntrainmentProtocol::WaveShape::Square:
            return std::sin(phase) > 0.0f ? 1.0f : -1.0f;

        case EntrainmentProtocol::WaveShape::Pink:
            // TODO: Implement pink noise generation
            return std::sin(phase);

        case EntrainmentProtocol::WaveShape::White:
            // TODO: Implement white noise generation
            return std::sin(phase);

        default:
            return std::sin(phase);
    }
}

void EchoelBrainwaveScience::updateSafetyMonitor(double deltaTime)
{
    safetyMonitor.totalSessionTime += deltaTime;

    // Check limits
    if (safetyMonitor.totalSessionTime > currentProtocol.sessionTimeLimit)
        safetyMonitor.maxSessionTimeExceeded = true;

    if (currentProtocol.maxIntensity > 0.5f)
        safetyMonitor.maxIntensityExceeded = true;

    if (currentFrequency < 0.5f || currentFrequency > 100.0f)
        safetyMonitor.frequencyOutOfRange = true;
}

//==============================================================================
// Research Data
//==============================================================================

void EchoelBrainwaveScience::enableResearchDataCollection(bool enable, bool anonymized)
{
    (void)anonymized;

    collectResearchData = enable;
}

void EchoelBrainwaveScience::saveResearchData(const ResearchData& data)
{
    if (!collectResearchData)
        return;

    researchDataLog.push_back(data);

    // TODO: Export to CSV/JSON for research analysis
}

void EchoelBrainwaveScience::performSpectralAnalysis(const std::vector<float>& signal, float sampleRate,
                                                      std::vector<float>& spectrum)
{
    (void)signal;
    (void)sampleRate;
    (void)spectrum;

    // TODO: Implement FFT-based spectral analysis using juce::dsp::FFT
}
