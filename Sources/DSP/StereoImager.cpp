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
    currentSampleRate = sampleRate;

    // ✅ SIMD OPTIMIZATION: Pre-allocate buffers for vectorized M/S processing
    midBuffer.setSize(1, maxBlockSize);
    sideBuffer.setSize(1, maxBlockSize);
    midBuffer.clear();
    sideBuffer.clear();

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
    float* midData = midBuffer.getWritePointer(0);
    float* sideData = sideBuffer.getWritePointer(0);

    // ✅ SIMD OPTIMIZATION: Vectorized M/S encoding
    // Mid = (L + R) * 0.5
    juce::FloatVectorOperations::copy(midData, leftChannel, numSamples);
    juce::FloatVectorOperations::add(midData, rightChannel, numSamples);
    juce::FloatVectorOperations::multiply(midData, 0.5f, numSamples);

    // Side = (L - R) * 0.5
    juce::FloatVectorOperations::copy(sideData, leftChannel, numSamples);
    juce::FloatVectorOperations::subtract(sideData, rightChannel, numSamples);
    juce::FloatVectorOperations::multiply(sideData, 0.5f, numSamples);

    // ✅ SIMD: Apply width to side channel
    juce::FloatVectorOperations::multiply(sideData, width, numSamples);

    // ✅ SIMD: Apply mid/side gains
    juce::FloatVectorOperations::multiply(midData, midGain, numSamples);
    juce::FloatVectorOperations::multiply(sideData, sideGain, numSamples);

    // ✅ SIMD: Get levels for metering (vectorized magnitude)
    float maxMid = juce::FloatVectorOperations::findMaximum(midData, numSamples);
    float maxSide = juce::FloatVectorOperations::findMaximum(sideData, numSamples);
    float minMid = juce::FloatVectorOperations::findMinimum(midData, numSamples);
    float minSide = juce::FloatVectorOperations::findMinimum(sideData, numSamples);
    maxMid = std::max(maxMid, -minMid);  // Absolute max
    maxSide = std::max(maxSide, -minSide);

    // ✅ SIMD OPTIMIZATION: Vectorized M/S decoding to L/R
    // Left = Mid + Side
    juce::FloatVectorOperations::copy(leftChannel, midData, numSamples);
    juce::FloatVectorOperations::add(leftChannel, sideData, numSamples);

    // Right = Mid - Side
    juce::FloatVectorOperations::copy(rightChannel, midData, numSamples);
    juce::FloatVectorOperations::subtract(rightChannel, sideData, numSamples);

    // Handle balance (requires per-sample only when balance != 0)
    if (balance < -0.001f)
    {
        // ✅ SIMD: Pan left - attenuate right channel
        juce::FloatVectorOperations::multiply(rightChannel, (1.0f + balance), numSamples);
    }
    else if (balance > 0.001f)
    {
        // ✅ SIMD: Pan right - attenuate left channel
        juce::FloatVectorOperations::multiply(leftChannel, (1.0f - balance), numSamples);
    }

    // Handle mono output mode
    if (monoOutput)
    {
        // ✅ SIMD: Convert to mono
        juce::FloatVectorOperations::add(leftChannel, rightChannel, numSamples);
        juce::FloatVectorOperations::multiply(leftChannel, 0.5f, numSamples);
        juce::FloatVectorOperations::copy(rightChannel, leftChannel, numSamples);
    }

    // Update correlation metering (sample every few samples for efficiency)
    for (int i = 0; i < numSamples; i += 4)  // Sample every 4th for efficiency
    {
        updateMetering(leftChannel[i], rightChannel[i]);
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
