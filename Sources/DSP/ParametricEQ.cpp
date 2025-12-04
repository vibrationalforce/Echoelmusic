#include "ParametricEQ.h"

ParametricEQ::ParametricEQ()
{
    // Initialize with sensible defaults
    bands[0] = { Band::Type::LowShelf, 80.0f, 0.0f, 0.7f, false };
    bands[1] = { Band::Type::Bell, 200.0f, 0.0f, 1.0f, false };
    bands[2] = { Band::Type::Bell, 500.0f, 0.0f, 1.0f, false };
    bands[3] = { Band::Type::Bell, 1000.0f, 0.0f, 1.0f, false };
    bands[4] = { Band::Type::Bell, 2000.0f, 0.0f, 1.0f, false };
    bands[5] = { Band::Type::Bell, 5000.0f, 0.0f, 1.0f, false };
    bands[6] = { Band::Type::Bell, 10000.0f, 0.0f, 1.0f, false };
    bands[7] = { Band::Type::HighShelf, 12000.0f, 0.0f, 0.7f, false };
}

ParametricEQ::~ParametricEQ() {}

void ParametricEQ::prepare(double sampleRate, int maximumBlockSize)
{
    juce::ignoreUnused(maximumBlockSize);
    currentSampleRate = sampleRate;

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = (juce::uint32)maximumBlockSize;
    spec.numChannels = 2;

    for (auto& filter : filters)
        filter.prepare(spec);

    updateFilters();
}

void ParametricEQ::reset()
{
    for (auto& filter : filters)
        filter.reset();
}

void ParametricEQ::process(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    // Process each enabled band using block processing (MUCH faster than sample-by-sample!)
    for (int bandIndex = 0; bandIndex < numBands; ++bandIndex)
    {
        if (!bands[bandIndex].enabled)
            continue;

        // Process stereo channels with block processing
        for (int channel = 0; channel < juce::jmin(2, numChannels); ++channel)
        {
            const int filterIndex = bandIndex * 2 + channel;
            auto* channelData = buffer.getWritePointer(channel);

            // Block-based processing using JUCE DSP (uses SIMD internally)
            juce::dsp::AudioBlock<float> block(&channelData, 1, numSamples);
            juce::dsp::ProcessContextReplacing<float> context(block);
            filters[filterIndex].process(context);
        }
    }
}

void ParametricEQ::setBand(int bandIndex, const Band& settings)
{
    if (!juce::isPositiveAndBelow(bandIndex, numBands))
        return;
    bands[bandIndex] = settings;
    updateFilterCoefficients(bandIndex);
}

ParametricEQ::Band ParametricEQ::getBand(int bandIndex) const
{
    if (juce::isPositiveAndBelow(bandIndex, numBands))
        return bands[bandIndex];
    return {};
}

void ParametricEQ::setBandFrequency(int bandIndex, float frequency)
{
    if (juce::isPositiveAndBelow(bandIndex, numBands))
    {
        bands[bandIndex].frequency = juce::jlimit(20.0f, 20000.0f, frequency);
        updateFilterCoefficients(bandIndex);
    }
}

void ParametricEQ::updateFilters()
{
    for (int i = 0; i < numBands; ++i)
        updateFilterCoefficients(i);
}

void ParametricEQ::updateFilterCoefficients(int bandIndex)
{
    if (!juce::isPositiveAndBelow(bandIndex, numBands))
        return;

    auto coeffs = createCoefficients(bands[bandIndex]);
    filters[bandIndex * 2].coefficients = coeffs;
    filters[bandIndex * 2 + 1].coefficients = coeffs;
}

juce::dsp::IIR::Coefficients<float>::Ptr ParametricEQ::createCoefficients(const Band& band)
{
    const float freq = juce::jlimit(20.0f, (float)currentSampleRate * 0.49f, band.frequency);
    const float gain = juce::Decibels::decibelsToGain(band.gain);
    const float Q = juce::jmax(0.1f, band.Q);

    switch (band.type)
    {
        case Band::Type::LowPass:
            return juce::dsp::IIR::Coefficients<float>::makeLowPass(currentSampleRate, freq, Q);
        case Band::Type::HighPass:
            return juce::dsp::IIR::Coefficients<float>::makeHighPass(currentSampleRate, freq, Q);
        case Band::Type::LowShelf:
            return juce::dsp::IIR::Coefficients<float>::makeLowShelf(currentSampleRate, freq, Q, gain);
        case Band::Type::HighShelf:
            return juce::dsp::IIR::Coefficients<float>::makeHighShelf(currentSampleRate, freq, Q, gain);
        case Band::Type::Bell:
            return juce::dsp::IIR::Coefficients<float>::makePeakFilter(currentSampleRate, freq, Q, gain);
        default:
            return juce::dsp::IIR::Coefficients<float>::makeAllPass(currentSampleRate, freq, Q);
    }
}

void ParametricEQ::presetFlat()
{
    for (int i = 0; i < numBands; ++i)
    {
        bands[i].enabled = false;
        bands[i].gain = 0.0f;
    }
    updateFilters();
}

void ParametricEQ::presetVocalWarmth()
{
    presetFlat();
    setBand(1, { Band::Type::Bell, 250.0f, -3.0f, 1.5f, true });
    setBand(4, { Band::Type::Bell, 3000.0f, 2.5f, 1.0f, true });
    setBand(6, { Band::Type::HighShelf, 10000.0f, 2.0f, 0.7f, true });
}
