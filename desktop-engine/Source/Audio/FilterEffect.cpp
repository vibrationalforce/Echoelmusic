// FilterEffect.cpp

#include "FilterEffect.h"

FilterEffect::FilterEffect()
{
}

FilterEffect::~FilterEffect()
{
}

void FilterEffect::prepare(double sampleRate, int samplesPerBlock)
{
    currentSampleRate = sampleRate;

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = (juce::uint32)samplesPerBlock;
    spec.numChannels = 1;

    filterLeft.prepare(spec);
    filterRight.prepare(spec);

    // Setup smoothing (50ms ramp time)
    smoothedCutoff.reset(sampleRate, 0.05);
    smoothedCutoff.setCurrentAndTargetValue(cutoffFrequency);

    // Set initial filter type
    setType(currentType);
    setCutoff(cutoffFrequency);
    setResonance(resonanceQ);
}

void FilterEffect::process(juce::AudioBuffer<float>& buffer)
{
    // Update smoothed cutoff
    if (smoothedCutoff.isSmoothing())
    {
        cutoffFrequency = smoothedCutoff.getNextValue();
        filterLeft.setCutoffFrequency(cutoffFrequency);
        filterRight.setCutoffFrequency(cutoffFrequency);
    }

    auto numSamples = buffer.getNumSamples();
    auto* leftChannel = buffer.getWritePointer(0);
    auto* rightChannel = buffer.getWritePointer(1);

    for (int i = 0; i < numSamples; ++i)
    {
        leftChannel[i] = filterLeft.processSample(0, leftChannel[i]);
        rightChannel[i] = filterRight.processSample(0, rightChannel[i]);
    }
}

void FilterEffect::reset()
{
    filterLeft.reset();
    filterRight.reset();
}

void FilterEffect::setCutoff(float frequency)
{
    frequency = juce::jlimit(20.0f, 20000.0f, frequency);
    smoothedCutoff.setTargetValue(frequency);
}

void FilterEffect::setResonance(float q)
{
    resonanceQ = juce::jlimit(0.1f, 10.0f, q);
    filterLeft.setResonance(resonanceQ);
    filterRight.setResonance(resonanceQ);
}

void FilterEffect::setType(FilterType type)
{
    currentType = type;

    typename Filter::Type filterType;

    switch (type)
    {
        case LowPass:
            filterType = Filter::Type::lowpass;
            break;
        case HighPass:
            filterType = Filter::Type::highpass;
            break;
        case BandPass:
            filterType = Filter::Type::bandpass;
            break;
        default:
            filterType = Filter::Type::lowpass;
    }

    filterLeft.setType(filterType);
    filterRight.setType(filterType);
}

// Biofeedback Mapping

void FilterEffect::setFromBreathRate(float breathRate)
{
    // Breath rate (5-30/min) → Filter cutoff (200-8000 Hz)
    // Slower breathing (meditation) = Lower cutoff (mellow)
    // Faster breathing (active) = Higher cutoff (bright)

    float normalizedBreath = juce::jlimit(5.0f, 30.0f, breathRate);
    normalizedBreath = (normalizedBreath - 5.0f) / (30.0f - 5.0f);  // 0-1

    // Exponential scaling for musical range
    float minCutoff = 200.0f;   // Mellow
    float maxCutoff = 8000.0f;  // Bright

    float cutoff = minCutoff * std::pow(maxCutoff / minCutoff, normalizedBreath);

    setCutoff(cutoff);

    DBG("🫁 Breath: " + juce::String(breathRate, 1) + " /min → Filter: " +
        juce::String(cutoff, 0) + " Hz");
}
