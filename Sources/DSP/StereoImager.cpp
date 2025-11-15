#include "StereoImager.h"

//==============================================================================
// Constructor
//==============================================================================

StereoImager::StereoImager()
{
}

//==============================================================================
// Parameters
//==============================================================================

void StereoImager::setWidth(float widthAmount)
{
    width = juce::jlimit(0.0f, 2.0f, widthAmount);
}

void StereoImager::setMidGain(float gainDb)
{
    midGain = juce::Decibels::decibelsToGain(juce::jlimit(-12.0f, 12.0f, gainDb));
}

void StereoImager::setSideGain(float gainDb)
{
    sideGain = juce::Decibels::decibelsToGain(juce::jlimit(-12.0f, 12.0f, gainDb));
}

void StereoImager::setBalance(float bal)
{
    balance = juce::jlimit(-1.0f, 1.0f, bal);
}

void StereoImager::setMonoOutput(bool mono)
{
    monoOutput = mono;
}

//==============================================================================
// Processing
//==============================================================================

void StereoImager::prepare(double sampleRate, int maxBlockSize)
{
    juce::ignoreUnused(maxBlockSize);

    currentSampleRate = sampleRate;
    reset();
}

void StereoImager::reset()
{
    correlation = 0.0f;
    midLevel = -100.0f;
    sideLevel = -100.0f;
    correlationSum = 0.0f;
    correlationSampleCount = 0;
}

void StereoImager::process(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();

    if (numChannels < 2)
        return;  // Stereo imager requires stereo input

    const int numSamples = buffer.getNumSamples();

    float* leftChannel = buffer.getWritePointer(0);
    float* rightChannel = buffer.getWritePointer(1);

    float maxMid = 0.0f;
    float maxSide = 0.0f;

    for (int i = 0; i < numSamples; ++i)
    {
        float left = leftChannel[i];
        float right = rightChannel[i];

        // Convert to Mid/Side
        float mid = (left + right) * 0.5f;
        float side = (left - right) * 0.5f;

        // Apply width control
        side *= width;

        // Apply mid/side gains
        mid *= midGain;
        side *= sideGain;

        // Track levels for metering
        maxMid = std::max(maxMid, std::abs(mid));
        maxSide = std::max(maxSide, std::abs(side));

        // Convert back to Left/Right
        left = mid + side;
        right = mid - side;

        // Apply balance
        if (balance < 0.0f)
        {
            // Pan left
            right *= (1.0f + balance);
        }
        else if (balance > 0.0f)
        {
            // Pan right
            left *= (1.0f - balance);
        }

        // Mono output (for compatibility check)
        if (monoOutput)
        {
            float mono = (left + right) * 0.5f;
            left = mono;
            right = mono;
        }

        // Update metering
        updateMetering(left, right);

        // Write output
        leftChannel[i] = left;
        rightChannel[i] = right;
    }

    // Update level meters (smoothed)
    const float meterSmoothing = 0.3f;
    midLevel = midLevel * (1.0f - meterSmoothing) +
               juce::Decibels::gainToDecibels(maxMid + 0.00001f) * meterSmoothing;

    sideLevel = sideLevel * (1.0f - meterSmoothing) +
                juce::Decibels::gainToDecibels(maxSide + 0.00001f) * meterSmoothing;

    // Update correlation meter (every 100 samples)
    if (correlationSampleCount >= 100)
    {
        correlation = correlationSum / correlationSampleCount;
        correlationSum = 0.0f;
        correlationSampleCount = 0;
    }
}

//==============================================================================
// Internal Methods
//==============================================================================

void StereoImager::updateMetering(float left, float right)
{
    // Calculate correlation (phase relationship between L and R)
    // Correlation = 1.0: perfect correlation (mono)
    // Correlation = 0.0: uncorrelated
    // Correlation = -1.0: perfect anti-correlation (wide stereo)

    float leftSq = left * left;
    float rightSq = right * right;
    float product = left * right;

    if (leftSq > 0.00001f && rightSq > 0.00001f)
    {
        float corr = product / std::sqrt(leftSq * rightSq);
        correlationSum += corr;
        correlationSampleCount++;
    }
}
