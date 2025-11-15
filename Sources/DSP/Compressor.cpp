#include "Compressor.h"

Compressor::Compressor() {}
Compressor::~Compressor() {}

void Compressor::prepare(double sampleRate, int maximumBlockSize)
{
    juce::ignoreUnused(maximumBlockSize);
    currentSampleRate = sampleRate;
    updateCoefficients();
}

void Compressor::reset()
{
    envelopeL = 0.0f;
    envelopeR = 0.0f;
    gainReduction = 0.0f;
}

void Compressor::process(juce::AudioBuffer<float>& buffer)
{
    int numSamples = buffer.getNumSamples();
    int numChannels = buffer.getNumChannels();

    for (int i = 0; i < numSamples; ++i)
    {
        // Stereo-link detection
        float detectionL = numChannels > 0 ? std::abs(buffer.getSample(0, i)) : 0.0f;
        float detectionR = numChannels > 1 ? std::abs(buffer.getSample(1, i)) : detectionL;
        float detection = juce::jmax(detectionL, detectionR);

        // Envelope follower
        float envelope = envelopeL;
        if (detection > envelope)
            envelope += attackCoeff * (detection - envelope);
        else
            envelope += releaseCoeff * (detection - envelope);

        envelopeL = envelope;

        // Compute gain reduction
        float gain = computeGain(envelope);
        gainReduction = 1.0f - gain;

        // Apply makeup gain
        float makeup = juce::Decibels::decibelsToGain(makeupGain);
        float totalGain = gain * makeup;

        // Apply to all channels
        for (int channel = 0; channel < numChannels; ++channel)
        {
            float sample = buffer.getSample(channel, i);
            buffer.setSample(channel, i, sample * totalGain);
        }
    }
}

void Compressor::setThreshold(float dB)
{
    threshold = juce::jlimit(-60.0f, 0.0f, dB);
}

void Compressor::setRatio(float newRatio)
{
    ratio = juce::jlimit(1.0f, 20.0f, newRatio);
}

void Compressor::setAttack(float ms)
{
    attack = juce::jlimit(0.1f, 100.0f, ms);
    updateCoefficients();
}

void Compressor::setRelease(float ms)
{
    release = juce::jlimit(10.0f, 1000.0f, ms);
    updateCoefficients();
}

void Compressor::setKnee(float dB)
{
    knee = juce::jlimit(0.0f, 12.0f, dB);
}

void Compressor::setMakeupGain(float dB)
{
    makeupGain = juce::jlimit(0.0f, 24.0f, dB);
}

void Compressor::setMode(Mode mode)
{
    currentMode = mode;
}

float Compressor::getGainReduction() const
{
    return gainReduction;
}

void Compressor::updateCoefficients()
{
    // Convert attack/release times to coefficients
    attackCoeff = 1.0f - std::exp(-1.0f / (attack * 0.001f * (float)currentSampleRate));
    releaseCoeff = 1.0f - std::exp(-1.0f / (release * 0.001f * (float)currentSampleRate));
}

float Compressor::computeGain(float input)
{
    float inputDB = juce::Decibels::gainToDecibels(input + 0.00001f);

    // Soft knee implementation
    float overThreshold = inputDB - threshold;
    float gain = 1.0f;

    if (knee > 0.0f && overThreshold > -knee * 0.5f && overThreshold < knee * 0.5f)
    {
        // Soft knee region
        float kneeInput = overThreshold + knee * 0.5f;
        float kneeOutput = kneeInput * kneeInput / (2.0f * knee);
        float compressionDB = kneeOutput / ratio - kneeOutput;
        gain = juce::Decibels::decibelsToGain(compressionDB);
    }
    else if (overThreshold > 0.0f)
    {
        // Above threshold
        float compressionDB = overThreshold / ratio - overThreshold;
        gain = juce::Decibels::decibelsToGain(compressionDB);
    }

    return gain;
}
