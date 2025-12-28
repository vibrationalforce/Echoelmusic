#include "Compressor.h"
#include "../Core/DSPOptimizations.h"

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
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();
    if (numSamples == 0 || numChannels == 0) return;

    // OPTIMIZATION: Cache channel pointers for all channels (up to 8 for surround)
    float* channelData[8] = { nullptr };
    const int maxChannels = juce::jmin(numChannels, 8);
    for (int ch = 0; ch < maxChannels; ++ch) {
        channelData[ch] = buffer.getWritePointer(ch);
    }

    // OPTIMIZATION: Pre-compute makeup gain (constant per block)
    const float makeup = Echoel::DSP::FastMath::dbToGain(makeupGain);

    for (int i = 0; i < numSamples; ++i)
    {
        // Stereo-link detection using cached pointers
        const float detectionL = channelData[0] ? std::abs(channelData[0][i]) : 0.0f;
        const float detectionR = channelData[1] ? std::abs(channelData[1][i]) : detectionL;
        const float detection = juce::jmax(detectionL, detectionR);

        // Envelope follower
        float envelope = envelopeL;
        if (detection > envelope)
            envelope += attackCoeff * (detection - envelope);
        else
            envelope += releaseCoeff * (detection - envelope);

        envelopeL = envelope;

        // Compute gain reduction
        const float gain = computeGain(envelope);
        gainReduction = 1.0f - gain;

        // Apply total gain (compression + makeup)
        const float totalGain = gain * makeup;

        // Apply to all channels using cached pointers
        for (int ch = 0; ch < maxChannels; ++ch)
        {
            channelData[ch][i] *= totalGain;
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
    // Convert attack/release times to coefficients using fast exp
    attackCoeff = 1.0f - Echoel::DSP::FastMath::fastExp(-1.0f / (attack * 0.001f * (float)currentSampleRate));
    releaseCoeff = 1.0f - Echoel::DSP::FastMath::fastExp(-1.0f / (release * 0.001f * (float)currentSampleRate));
}

float Compressor::computeGain(float input)
{
    float inputDB = Echoel::DSP::FastMath::gainToDb(input + 0.00001f);

    // Soft knee implementation
    float overThreshold = inputDB - threshold;
    float gain = 1.0f;

    if (knee > 0.0f && overThreshold > -knee * 0.5f && overThreshold < knee * 0.5f)
    {
        // Soft knee region
        float kneeInput = overThreshold + knee * 0.5f;
        float kneeOutput = kneeInput * kneeInput / (2.0f * knee);
        float compressionDB = kneeOutput / ratio - kneeOutput;
        gain = Echoel::DSP::FastMath::dbToGain(compressionDB);
    }
    else if (overThreshold > 0.0f)
    {
        // Above threshold
        float compressionDB = overThreshold / ratio - overThreshold;
        gain = Echoel::DSP::FastMath::dbToGain(compressionDB);
    }

    return gain;
}
