#include "BiometricFilter.h"
#include <cmath>

//==============================================================================
BiometricFilter::BiometricFilter()
{
}

void BiometricFilter::prepare(double sampleRate, int samplesPerBlock)
{
    this->sampleRate = sampleRate;
}

void BiometricFilter::processBlock(juce::AudioBuffer<float>& buffer)
{
    for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
    {
        auto* channelData = buffer.getWritePointer(channel);

        for (int sample = 0; sample < buffer.getNumSamples(); ++sample)
        {
            float input = channelData[sample];
            float output = processFilter(input);
            channelData[sample] = output;
        }
    }
}

float BiometricFilter::processFilter(float input)
{
    // Simple state variable filter
    float cutoff = params.cutoffFreq / sampleRate;
    cutoff = juce::jlimit(0.001f, 0.499f, cutoff);

    float resonance = params.resonance * 4.0f;

    // State variable filter equations
    filterStateLow += cutoff * filterStateBand;
    filterStateHigh = input - filterStateLow - resonance * filterStateBand;
    filterStateBand += cutoff * filterStateHigh;

    // Select filter type
    float output = input;

    switch (params.type)
    {
        case FilterParams::Lowpass:
            output = filterStateLow;
            break;
        case FilterParams::Highpass:
            output = filterStateHigh;
            break;
        case FilterParams::Bandpass:
            output = filterStateBand;
            break;
        case FilterParams::Notch:
            output = input - filterStateBand;
            break;
        default:
            output = filterStateLow;
            break;
    }

    return output;
}

void BiometricFilter::setParams(const FilterParams& p)
{
    params = p;
}

void BiometricFilter::setHeartRate(float bpm)
{
    heartRate = juce::jlimit(40.0f, 200.0f, bpm);

    // Modulate cutoff with heart rate
    if (biometricParams.heartRateModulatesCutoff)
    {
        float normalizedHR = (heartRate - 70.0f) / 130.0f;  // 40-200 → -0.23 to +1.0
        float modulatedCutoff = params.cutoffFreq * (1.0f + normalizedHR * biometricParams.modulationDepth);
        params.cutoffFreq = juce::jlimit(20.0f, 20000.0f, modulatedCutoff);
    }
}

void BiometricFilter::setHeartRateVariability(float hrv)
{
    heartRateVariability = juce::jlimit(0.0f, 1.0f, hrv);

    // HRV adds subtle randomness to resonance
    params.resonance *= (1.0f + heartRateVariability * 0.2f);
}
