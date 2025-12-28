#include "TapeDelay.h"
#include "../Core/DSPOptimizations.h"

//==============================================================================
// Constructor
//==============================================================================

TapeDelay::TapeDelay()
{
}

//==============================================================================
// Parameters
//==============================================================================

void TapeDelay::setDelayTime(float timeMs)
{
    delayTime = juce::jlimit(10.0f, 2000.0f, timeMs);
}

void TapeDelay::setFeedback(float fb)
{
    feedback = juce::jlimit(0.0f, 0.95f, fb);
}

void TapeDelay::setMix(float mixAmount)
{
    mix = juce::jlimit(0.0f, 1.0f, mixAmount);
}

void TapeDelay::setWowFlutter(float amount)
{
    wowFlutter = juce::jlimit(0.0f, 1.0f, amount);
}

void TapeDelay::setSaturation(float sat)
{
    saturation = juce::jlimit(0.0f, 1.0f, sat);
}

void TapeDelay::setStereoWidth(float width)
{
    stereoWidth = juce::jlimit(0.0f, 1.0f, width);
}

//==============================================================================
// Processing
//==============================================================================

void TapeDelay::prepare(double sampleRate, int maxBlockSize)
{
    juce::ignoreUnused(maxBlockSize);

    currentSampleRate = sampleRate;

    // Allocate delay buffers (2 seconds max)
    const int maxDelaySamples = static_cast<int>(2.0 * sampleRate);

    for (auto& buffer : delayBuffers)
    {
        buffer.resize(maxDelaySamples);
        std::fill(buffer.begin(), buffer.end(), 0.0f);
    }

    // LFO for wow/flutter (random slow modulation, ~0.2-3 Hz)
    lfoIncrement = 1.5f / static_cast<float>(sampleRate);

    reset();
}

void TapeDelay::reset()
{
    for (auto& buffer : delayBuffers)
    {
        std::fill(buffer.begin(), buffer.end(), 0.0f);
    }

    writePositions.fill(0);
    lfoPhase = 0.0f;

    for (auto& fs : filterStates)
    {
        fs.lpY1 = 0.0f;
        fs.hpX1 = fs.hpY1 = 0.0f;
    }
}

void TapeDelay::process(juce::AudioBuffer<float>& buffer)
{
    // Enable denormal prevention for this scope (prevents CPU spikes in feedback loops)
    Echoel::DSP::DenormalPrevention::ScopedNoDenormals noDenormals;

    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    // Get trig lookup tables for fast sin
    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();

    for (int channel = 0; channel < numChannels && channel < 2; ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);

        // Stereo offset (different delay times per channel)
        float channelDelayOffset = (channel == 1) ? (stereoWidth * 20.0f) : 0.0f;

        for (int i = 0; i < numSamples; ++i)
        {
            float input = channelData[i];

            // Calculate modulated delay time (wow/flutter) - using fast sin lookup
            updateLFO();
            float lfoModulation = trigTables.fastSin(lfoPhase) * wowFlutter * 5.0f;  // +/- 5ms
            float modulatedDelayMs = delayTime + channelDelayOffset + lfoModulation;
            float delaySamples = modulatedDelayMs * static_cast<float>(currentSampleRate) / 1000.0f;

            // Read delayed signal with interpolation
            float delayedSignal = readDelayInterpolated(channel, delaySamples);

            // Apply tape character (filtering + saturation)
            delayedSignal = applyFiltering(delayedSignal, channel);
            delayedSignal = applySaturation(delayedSignal);

            // Write to delay buffer (input + feedback) - denormals already handled by ScopedNoDenormals
            delayBuffers[channel][writePositions[channel]] = input + delayedSignal * feedback;

            // Advance write position
            writePositions[channel] = (writePositions[channel] + 1) % delayBuffers[channel].size();

            // Mix dry/wet
            channelData[i] = input * (1.0f - mix) + delayedSignal * mix;
        }
    }
}

//==============================================================================
// Internal Methods
//==============================================================================

float TapeDelay::readDelayInterpolated(int channel, float delaySamples)
{
    const auto& buffer = delayBuffers[channel];
    const int bufferSize = static_cast<int>(buffer.size());

    // Calculate read position
    float readPos = writePositions[channel] - delaySamples;

    while (readPos < 0.0f)
        readPos += bufferSize;

    // Linear interpolation
    int index1 = static_cast<int>(readPos) % bufferSize;
    int index2 = (index1 + 1) % bufferSize;
    float frac = readPos - std::floor(readPos);

    return buffer[index1] * (1.0f - frac) + buffer[index2] * frac;
}

float TapeDelay::applySaturation(float input)
{
    if (saturation <= 0.01f)
        return input;

    // Soft-clip saturation (tape-like)
    float drive = 1.0f + saturation * 5.0f;
    float x = input * drive;

    // Soft-clip using tanh approximation
    float absX = std::abs(x);
    float sign = (x >= 0.0f) ? 1.0f : -1.0f;

    if (absX < 1.0f)
        return x;
    else if (absX < 2.0f)
        return sign * (1.0f + (absX - 1.0f) * 0.25f);
    else
        return sign * 1.25f;
}

float TapeDelay::applyFiltering(float input, int channel)
{
    auto& fs = filterStates[channel];

    // Lowpass (tape aging, rolls off highs)
    const float lpCoeff = 0.3f;
    float lpOut = lpCoeff * input + (1.0f - lpCoeff) * fs.lpY1;
    fs.lpY1 = lpOut;

    // Highpass (remove DC and rumble)
    const float hpCoeff = 0.998f;
    float hpOut = hpCoeff * (fs.hpY1 + lpOut - fs.hpX1);
    fs.hpX1 = lpOut;
    fs.hpY1 = hpOut;

    return hpOut;
}

void TapeDelay::updateLFO()
{
    lfoPhase += lfoIncrement;

    if (lfoPhase >= 1.0f)
        lfoPhase -= 1.0f;
}
