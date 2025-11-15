// BasicSynthesizer.cpp
// Implementation of bio-reactive synthesizer

#include "BasicSynthesizer.h"

BasicSynthesizer::BasicSynthesizer()
{
}

BasicSynthesizer::~BasicSynthesizer()
{
}

void BasicSynthesizer::prepareToPlay(int samplesPerBlockExpected, double sampleRate_)
{
    sampleRate = sampleRate_;

    // Initialize oscillator
    frequency = 220.0;  // A3
    angleDelta = frequency * 2.0 * juce::MathConstants<double>::pi / sampleRate;

    juce::ignoreUnused(samplesPerBlockExpected);
}

void BasicSynthesizer::releaseResources()
{
    // Nothing to release for now
}

void BasicSynthesizer::getNextAudioBlock(const juce::AudioSourceChannelInfo& bufferToFill)
{
    auto* leftBuffer = bufferToFill.buffer->getWritePointer(0, bufferToFill.startSample);
    auto* rightBuffer = bufferToFill.buffer->getWritePointer(1, bufferToFill.startSample);

    // Update frequency from biofeedback
    if (mappingEnabled)
    {
        float targetFreq = mapHeartRateToFrequency(currentHeartRate.load());

        // Smooth frequency changes
        smoothedFrequency += smoothingAlpha * (targetFreq - smoothedFrequency);
        frequency = smoothedFrequency;

        // Update amplitude from HRV
        amplitude = mapHRVToAmplitude(currentHRV.load());

        // Update angle delta
        angleDelta = frequency * 2.0 * juce::MathConstants<double>::pi / sampleRate;
    }

    // Generate sine wave
    for (auto sample = 0; sample < bufferToFill.numSamples; ++sample)
    {
        auto currentSample = (float)(std::sin(currentAngle) * amplitude);

        leftBuffer[sample] = currentSample;
        rightBuffer[sample] = currentSample;

        currentAngle += angleDelta;

        // Keep angle in reasonable range
        if (currentAngle > 2.0 * juce::MathConstants<double>::pi)
            currentAngle -= 2.0 * juce::MathConstants<double>::pi;
    }
}

// Biofeedback Setters

void BasicSynthesizer::setHeartRate(float bpm)
{
    currentHeartRate.store(bpm);
    DBG("♥️ Heart Rate: " + juce::String(bpm, 1) + " bpm → Freq: " +
        juce::String(mapHeartRateToFrequency(bpm), 1) + " Hz");
}

void BasicSynthesizer::setHRV(float ms)
{
    currentHRV.store(ms);
    DBG("🫀 HRV: " + juce::String(ms, 1) + " ms → Amp: " +
        juce::String(mapHRVToAmplitude(ms), 2));
}

void BasicSynthesizer::setHRVCoherence(float coherence)
{
    currentCoherence.store(coherence);
    DBG("🧘 Coherence: " + juce::String(coherence * 100.0f, 1) + "%");
}

void BasicSynthesizer::setPitch(float frequency, float confidence)
{
    currentPitchFreq.store(frequency);

    // Only log occasionally to avoid spam
    static int logCounter = 0;
    if (++logCounter % 60 == 0)  // Log every 60 calls (~1 second at 60 Hz)
    {
        DBG("🎤 Pitch: " + juce::String(frequency, 1) + " Hz (conf: " +
            juce::String(confidence, 2) + ")");
    }
}

// Parameter Mapping

float BasicSynthesizer::mapHeartRateToFrequency(float bpm)
{
    // Map heart rate (40-200 BPM) to frequency (100-800 Hz)
    // Lower HR = lower pitch, higher HR = higher pitch

    float normalizedHR = juce::jlimit(40.0f, 200.0f, bpm);
    float normalized = (normalizedHR - 40.0f) / (200.0f - 40.0f);  // 0-1

    // Exponential scaling for musical range
    float minFreq = 100.0f;  // ~G2
    float maxFreq = 800.0f;  // ~G5

    return minFreq + (maxFreq - minFreq) * normalized;
}

float BasicSynthesizer::mapHRVToAmplitude(float hrv)
{
    // Map HRV (0-100 ms) to amplitude (0.1-0.5)
    // Higher HRV = louder (more relaxed = more expressive)

    float normalizedHRV = juce::jlimit(0.0f, 100.0f, hrv);
    float normalized = normalizedHRV / 100.0f;

    float minAmp = 0.1f;
    float maxAmp = 0.5f;

    return minAmp + (maxAmp - minAmp) * normalized;
}

float BasicSynthesizer::mapCoherenceToWaveform(float coherence)
{
    // Future: Use coherence to blend between waveforms
    // For now, just return coherence value
    return coherence;
}

void BasicSynthesizer::setParameterMappingEnabled(bool enabled)
{
    mappingEnabled = enabled;
    DBG("Parameter Mapping: " + juce::String(enabled ? "Enabled" : "Disabled"));
}
