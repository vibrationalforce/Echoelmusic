#include "DeEsser.h"
#include "../Core/DSPOptimizations.h"

//==============================================================================
// Constructor
//==============================================================================

DeEsser::DeEsser()
{
    updateCoefficients();
}

//==============================================================================
// Parameters
//==============================================================================

void DeEsser::setThreshold(float thresholdDb)
{
    threshold = juce::jlimit(-60.0f, 0.0f, thresholdDb);
}

void DeEsser::setFrequency(float freq)
{
    frequency = juce::jlimit(2000.0f, 12000.0f, freq);
    updateBandpassCoefficients();
}

void DeEsser::setBandwidth(float bw)
{
    bandwidth = juce::jlimit(1000.0f, 8000.0f, bw);
    updateBandpassCoefficients();
}

void DeEsser::setRatio(float newRatio)
{
    ratio = juce::jlimit(1.0f, 10.0f, newRatio);
}

void DeEsser::setEnabled(bool en)
{
    enabled = en;
}

//==============================================================================
// Processing
//==============================================================================

void DeEsser::prepare(double sampleRate, int maxBlockSize)
{
    juce::ignoreUnused(maxBlockSize);

    currentSampleRate = sampleRate;
    updateCoefficients();
    reset();
}

void DeEsser::reset()
{
    for (auto& state : channelStates)
    {
        state.envelope = 0.0f;
        state.gainReduction = 0.0f;
        state.sibilanceLevel = -100.0f;
        state.bpX1 = state.bpX2 = 0.0f;
        state.bpY1 = state.bpY2 = 0.0f;
    }
}

void DeEsser::process(juce::AudioBuffer<float>& buffer)
{
    if (!enabled)
        return;

    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    for (int channel = 0; channel < numChannels && channel < 2; ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);
        auto& state = channelStates[channel];

        float maxSibilance = -100.0f;
        float maxGR = 0.0f;

        for (int i = 0; i < numSamples; ++i)
        {
            float input = channelData[i];

            // Detect sibilance with bandpass filter
            float sibilanceSignal = applyBandpass(input, state);
            float sibilanceLevel = std::abs(sibilanceSignal);

            // Envelope follower
            if (sibilanceLevel > state.envelope)
            {
                state.envelope = attackCoeff * state.envelope + (1.0f - attackCoeff) * sibilanceLevel;
            }
            else
            {
                state.envelope = releaseCoeff * state.envelope + (1.0f - releaseCoeff) * sibilanceLevel;
            }

            // Calculate gain reduction
            float sibilanceDb = Echoel::DSP::FastMath::gainToDb(state.envelope + 0.00001f);
            float gr = calculateGainReduction(sibilanceDb);

            // Apply gain reduction
            channelData[i] = input * gr;

            // Metering
            maxSibilance = std::max(maxSibilance, sibilanceDb);
            maxGR = std::min(maxGR, Echoel::DSP::FastMath::gainToDb(gr));
        }

        // Update metering
        const float smoothing = 0.3f;
        state.sibilanceLevel = state.sibilanceLevel * (1.0f - smoothing) + maxSibilance * smoothing;
        state.gainReduction = state.gainReduction * (1.0f - smoothing) + maxGR * smoothing;
    }
}

//==============================================================================
// Metering
//==============================================================================

float DeEsser::getGainReduction(int channel) const
{
    if (channel >= 0 && channel < 2)
        return channelStates[channel].gainReduction;
    return 0.0f;
}

float DeEsser::getSibilanceLevel(int channel) const
{
    if (channel >= 0 && channel < 2)
        return channelStates[channel].sibilanceLevel;
    return -100.0f;
}

//==============================================================================
// Internal Methods
//==============================================================================

void DeEsser::updateCoefficients()
{
    // Fast attack, medium release - using fast exp
    attackCoeff = Echoel::DSP::FastMath::fastExp(-1000.0f / (3.0f * static_cast<float>(currentSampleRate)));
    releaseCoeff = Echoel::DSP::FastMath::fastExp(-1000.0f / (100.0f * static_cast<float>(currentSampleRate)));

    updateBandpassCoefficients();
}

void DeEsser::updateBandpassCoefficients()
{
    // Bandpass filter centered at frequency with given bandwidth - using fast trig
    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
    const float omega = juce::MathConstants<float>::twoPi * frequency / static_cast<float>(currentSampleRate);
    const float sinOmega = trigTables.fastSinRad(omega);
    const float cosOmega = trigTables.fastCosRad(omega);
    const float q = frequency / bandwidth;
    const float alpha = sinOmega / (2.0f * q);

    float b0 = alpha;
    float b1 = 0.0f;
    float b2 = -alpha;
    float a0 = 1.0f + alpha;
    float a1 = -2.0f * cosOmega;
    float a2 = 1.0f - alpha;

    // Normalize
    bpCoeffs.b0 = b0 / a0;
    bpCoeffs.b1 = b1 / a0;
    bpCoeffs.b2 = b2 / a0;
    bpCoeffs.a1 = a1 / a0;
    bpCoeffs.a2 = a2 / a0;
}

float DeEsser::applyBandpass(float input, ChannelState& state)
{
    float output = bpCoeffs.b0 * input + bpCoeffs.b1 * state.bpX1 + bpCoeffs.b2 * state.bpX2
                   - bpCoeffs.a1 * state.bpY1 - bpCoeffs.a2 * state.bpY2;

    state.bpX2 = state.bpX1;
    state.bpX1 = input;
    state.bpY2 = state.bpY1;
    state.bpY1 = output;

    return output;
}

float DeEsser::calculateGainReduction(float sibilanceDb)
{
    if (sibilanceDb <= threshold)
        return 1.0f;  // No reduction

    float excess = sibilanceDb - threshold;
    float reductionDb = excess * (1.0f - 1.0f / ratio);

    return Echoel::DSP::FastMath::dbToGain(-reductionDb);
}
