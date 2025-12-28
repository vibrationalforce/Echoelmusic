#include "BrickWallLimiter.h"
#include "../Core/DSPOptimizations.h"

//==============================================================================
// Constructor
//==============================================================================

BrickWallLimiter::BrickWallLimiter()
{
    // Initialize true peak history
    for (auto& channelHistory : truePeakHistory)
    {
        channelHistory.fill(0.0f);
    }
}

//==============================================================================
// Parameters
//==============================================================================

void BrickWallLimiter::setThreshold(float thresholdDb)
{
    threshold = juce::jlimit(-60.0f, 0.0f, thresholdDb);
}

void BrickWallLimiter::setCeiling(float ceilingDb)
{
    ceiling = juce::jlimit(-1.0f, 0.0f, ceilingDb);
}

void BrickWallLimiter::setRelease(float releaseMs)
{
    release = juce::jlimit(10.0f, 1000.0f, releaseMs);
    updateReleaseCoeff();
}

void BrickWallLimiter::setLookahead(float lookaheadMsNew)
{
    lookaheadMs = juce::jlimit(0.0f, 10.0f, lookaheadMsNew);

    // Recalculate lookahead samples
    lookaheadSamples = static_cast<int>(lookaheadMs * currentSampleRate / 1000.0);

    // Resize buffers if needed
    for (auto& buffer : lookaheadBuffers)
    {
        buffer.resize(lookaheadSamples, 0.0f);
    }
}

void BrickWallLimiter::setTruePeakEnabled(bool enabled)
{
    truePeakEnabled = enabled;
}

void BrickWallLimiter::setSoftKnee(float kneeDb)
{
    softKnee = juce::jlimit(0.0f, 6.0f, kneeDb);
}

//==============================================================================
// Processing
//==============================================================================

void BrickWallLimiter::prepare(double sampleRate, int maxBlockSize)
{
    juce::ignoreUnused(maxBlockSize);

    currentSampleRate = sampleRate;

    // Calculate lookahead samples
    lookaheadSamples = static_cast<int>(lookaheadMs * currentSampleRate / 1000.0);

    // Allocate lookahead buffers
    for (auto& buffer : lookaheadBuffers)
    {
        buffer.resize(lookaheadSamples);
        std::fill(buffer.begin(), buffer.end(), 0.0f);
    }

    updateReleaseCoeff();
    reset();
}

void BrickWallLimiter::reset()
{
    // Reset gain envelopes
    gainEnvelope.fill(1.0f);

    // Clear lookahead buffers
    for (auto& buffer : lookaheadBuffers)
    {
        std::fill(buffer.begin(), buffer.end(), 0.0f);
    }

    lookaheadWritePos.fill(0);

    // Reset metering
    gainReduction.fill(0.0f);
    inputLevel.fill(-100.0f);
    outputLevel.fill(-100.0f);
    currentlyLimiting = false;

    // Reset true peak history
    for (auto& channelHistory : truePeakHistory)
    {
        channelHistory.fill(0.0f);
    }
}

void BrickWallLimiter::process(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    currentlyLimiting = false;
    const float ceilingLinear = juce::Decibels::decibelsToGain(ceiling);

    for (int channel = 0; channel < numChannels && channel < 2; ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);
        float& envelope = gainEnvelope[channel];

        float maxInput = 0.0f;
        float maxOutput = 0.0f;
        float maxGR = 0.0f;

        for (int i = 0; i < numSamples; ++i)
        {
            float inputSample = channelData[i];

            // Track input level
            maxInput = std::max(maxInput, std::abs(inputSample));

            // Detect peak (with optional true peak detection)
            float peakLevel = std::abs(inputSample);

            if (truePeakEnabled)
            {
                peakLevel = detectTruePeak(inputSample, channel);
            }

            // Update maximum peak
            maxPeak = std::max(maxPeak, peakLevel);

            // Calculate required gain reduction
            const float peakDb = juce::Decibels::gainToDecibels(peakLevel + 0.00001f);
            float targetGainReduction = calculateGainReduction(peakDb);

            // Apply attack (instant) or release (gradual)
            if (targetGainReduction < envelope)
            {
                // Attack (instant) - limit immediately
                envelope = targetGainReduction;
                currentlyLimiting = true;
            }
            else
            {
                // Release (gradual) - return to unity gain
                envelope = releaseCoeff * envelope + (1.0f - releaseCoeff) * 1.0f;
            }

            // Ensure envelope is within bounds
            envelope = juce::jlimit(targetGainReduction, 1.0f, envelope);

            // Apply gain with lookahead delay
            float outputSample;

            if (lookaheadSamples > 0)
            {
                // Store current sample in lookahead buffer
                lookaheadBuffers[channel][lookaheadWritePos[channel]] = inputSample;

                // Read delayed sample
                int readPos = lookaheadWritePos[channel];
                outputSample = lookaheadBuffers[channel][readPos];

                // Advance write position
                lookaheadWritePos[channel] = (lookaheadWritePos[channel] + 1) % lookaheadSamples;
            }
            else
            {
                outputSample = inputSample;
            }

            // Apply limiting gain
            outputSample *= envelope;

            // Hard clip as safety (should never trigger with proper limiting)
            outputSample = juce::jlimit(-ceilingLinear, ceilingLinear, outputSample);

            channelData[i] = outputSample;

            // Track output level
            maxOutput = std::max(maxOutput, std::abs(outputSample));

            // Track gain reduction
            float currentGR = juce::Decibels::gainToDecibels(envelope);
            maxGR = std::min(maxGR, currentGR);  // Most negative value
        }

        // Update metering (smoothed)
        const float meterSmoothing = 0.2f;

        inputLevel[channel] = inputLevel[channel] * (1.0f - meterSmoothing) +
                              juce::Decibels::gainToDecibels(maxInput + 0.00001f) * meterSmoothing;

        outputLevel[channel] = outputLevel[channel] * (1.0f - meterSmoothing) +
                               juce::Decibels::gainToDecibels(maxOutput + 0.00001f) * meterSmoothing;

        gainReduction[channel] = gainReduction[channel] * (1.0f - meterSmoothing) +
                                 maxGR * meterSmoothing;
    }
}

//==============================================================================
// Metering
//==============================================================================

float BrickWallLimiter::getGainReduction(int channel) const
{
    if (channel >= 0 && channel < 2)
        return gainReduction[channel];
    return 0.0f;
}

float BrickWallLimiter::getInputLevel(int channel) const
{
    if (channel >= 0 && channel < 2)
        return inputLevel[channel];
    return -100.0f;
}

float BrickWallLimiter::getOutputLevel(int channel) const
{
    if (channel >= 0 && channel < 2)
        return outputLevel[channel];
    return -100.0f;
}

bool BrickWallLimiter::isLimiting() const
{
    return currentlyLimiting;
}

float BrickWallLimiter::getPeakSinceReset() const
{
    return juce::Decibels::gainToDecibels(maxPeak + 0.00001f);
}

void BrickWallLimiter::resetPeakMeter()
{
    maxPeak = 0.0f;
}

//==============================================================================
// Internal Methods
//==============================================================================

float BrickWallLimiter::calculateGainReduction(float levelDb) const
{
    if (levelDb <= threshold)
        return 1.0f;  // No limiting

    const float excess = levelDb - ceiling;

    if (excess <= 0.0f)
    {
        // Within threshold and ceiling - soft knee limiting
        if (softKnee > 0.0f)
        {
            const float rangeDb = ceiling - threshold;
            const float position = (levelDb - threshold) / rangeDb;  // 0 to 1

            if (position < 1.0f)
            {
                // Soft knee curve
                const float kneeFactor = 1.0f - (position * position);
                const float targetDb = levelDb - (1.0f - kneeFactor) * excess;
                return juce::Decibels::decibelsToGain(targetDb - levelDb);
            }
        }

        return 1.0f;  // No reduction needed
    }

    // Above ceiling - hard limiting
    const float targetDb = ceiling;
    return juce::Decibels::decibelsToGain(targetDb - levelDb);
}

float BrickWallLimiter::detectTruePeak(float sample, int channel)
{
    // Simplified true peak detection using linear interpolation
    // Full ITU-R BS.1770 would use 4x oversampling with proper reconstruction filter

    auto& history = truePeakHistory[channel];

    // Estimate inter-sample peaks using linear interpolation
    float truePeak = std::abs(sample);

    // Check between current and previous samples
    if (history[0] != 0.0f)
    {
        float interpPeak1 = std::abs((sample + history[0]) * 0.5f);
        float interpPeak2 = std::abs((sample * 0.75f + history[0] * 0.25f));
        float interpPeak3 = std::abs((sample * 0.25f + history[0] * 0.75f));

        truePeak = std::max(truePeak, interpPeak1);
        truePeak = std::max(truePeak, interpPeak2);
        truePeak = std::max(truePeak, interpPeak3);
    }

    // Update history
    history[2] = history[1];
    history[1] = history[0];
    history[0] = sample;

    // Scale to account for oversampling (conservative estimate)
    return truePeak * 1.2f;  // +1.6dB headroom for ISP
}

void BrickWallLimiter::updateReleaseCoeff()
{
    // Calculate coefficient for exponential release - using fast exp
    // Time to reach 63% of target
    releaseCoeff = Echoel::DSP::FastMath::fastExp(-1000.0f / (release * static_cast<float>(currentSampleRate)));
}
