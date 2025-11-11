#include "ParametricEQ.h"

//==============================================================================
// Constructor
//==============================================================================

ParametricEQ::ParametricEQ(int numBands)
{
    initializeDefaultBands(numBands);
    filterStates.resize(numBands);
    coefficients.resize(numBands);
}

//==============================================================================
// Processing
//==============================================================================

void ParametricEQ::prepare(double sampleRate, int maxBlockSize)
{
    juce::ignoreUnused(maxBlockSize);

    currentSampleRate = sampleRate;

    // Reset all filter states
    reset();

    // Update coefficients for new sample rate
    updateCoefficients();
}

void ParametricEQ::reset()
{
    for (auto& bandStates : filterStates)
    {
        for (auto& state : bandStates)
        {
            state.x1 = state.x2 = 0.0f;
            state.y1 = state.y2 = 0.0f;
        }
    }
}

void ParametricEQ::process(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    // Process each channel
    for (int channel = 0; channel < numChannels && channel < 2; ++channel)
    {
        processChannel(buffer.getWritePointer(channel), numSamples, channel);
    }
}

void ParametricEQ::processChannel(float* channelData, int numSamples, int channelIndex)
{
    // Process each band sequentially
    for (size_t bandIndex = 0; bandIndex < bands.size(); ++bandIndex)
    {
        const auto& band = bands[bandIndex];

        if (!band.enabled)
            continue;

        auto& coeff = coefficients[bandIndex];
        auto& state = filterStates[bandIndex][channelIndex];

        // Process each sample
        for (int i = 0; i < numSamples; ++i)
        {
            channelData[i] = processBiquad(channelData[i], coeff, state);
        }
    }
}

//==============================================================================
// Band Management
//==============================================================================

void ParametricEQ::setBand(int index, float frequency, float gain, float q, FilterType type)
{
    if (index < 0 || index >= static_cast<int>(bands.size()))
        return;

    bands[index].frequency = juce::jlimit(20.0f, 20000.0f, frequency);
    bands[index].gain = juce::jlimit(-24.0f, 24.0f, gain);
    bands[index].q = juce::jlimit(0.1f, 20.0f, q);
    bands[index].type = type;

    // Recalculate coefficients for this band
    coefficients[index] = calculateCoefficients(bands[index]);
}

void ParametricEQ::setBandFrequency(int index, float frequency)
{
    if (index < 0 || index >= static_cast<int>(bands.size()))
        return;

    bands[index].frequency = juce::jlimit(20.0f, 20000.0f, frequency);
    coefficients[index] = calculateCoefficients(bands[index]);
}

void ParametricEQ::setBandGain(int index, float gain)
{
    if (index < 0 || index >= static_cast<int>(bands.size()))
        return;

    bands[index].gain = juce::jlimit(-24.0f, 24.0f, gain);
    coefficients[index] = calculateCoefficients(bands[index]);
}

void ParametricEQ::setBandQ(int index, float q)
{
    if (index < 0 || index >= static_cast<int>(bands.size()))
        return;

    bands[index].q = juce::jlimit(0.1f, 20.0f, q);
    coefficients[index] = calculateCoefficients(bands[index]);
}

void ParametricEQ::setBandType(int index, FilterType type)
{
    if (index < 0 || index >= static_cast<int>(bands.size()))
        return;

    bands[index].type = type;
    coefficients[index] = calculateCoefficients(bands[index]);
}

void ParametricEQ::setBandEnabled(int index, bool enabled)
{
    if (index < 0 || index >= static_cast<int>(bands.size()))
        return;

    bands[index].enabled = enabled;
}

ParametricEQ::Band ParametricEQ::getBand(int index) const
{
    if (index >= 0 && index < static_cast<int>(bands.size()))
        return bands[index];

    return Band();
}

//==============================================================================
// Coefficient Calculation
//==============================================================================

ParametricEQ::BiquadCoefficients ParametricEQ::calculateCoefficients(const Band& band) const
{
    BiquadCoefficients c;

    const float omega = juce::MathConstants<float>::twoPi * band.frequency / static_cast<float>(currentSampleRate);
    const float sinOmega = std::sin(omega);
    const float cosOmega = std::cos(omega);
    const float alpha = sinOmega / (2.0f * band.q);
    const float A = std::pow(10.0f, band.gain / 40.0f);  // Amplitude from dB

    float b0, b1, b2, a0, a1, a2;

    switch (band.type)
    {
        case FilterType::Peak:
        {
            b0 = 1.0f + alpha * A;
            b1 = -2.0f * cosOmega;
            b2 = 1.0f - alpha * A;
            a0 = 1.0f + alpha / A;
            a1 = -2.0f * cosOmega;
            a2 = 1.0f - alpha / A;
            break;
        }

        case FilterType::LowShelf:
        {
            const float sqrtA = std::sqrt(A);
            b0 = A * ((A + 1.0f) - (A - 1.0f) * cosOmega + 2.0f * sqrtA * alpha);
            b1 = 2.0f * A * ((A - 1.0f) - (A + 1.0f) * cosOmega);
            b2 = A * ((A + 1.0f) - (A - 1.0f) * cosOmega - 2.0f * sqrtA * alpha);
            a0 = (A + 1.0f) + (A - 1.0f) * cosOmega + 2.0f * sqrtA * alpha;
            a1 = -2.0f * ((A - 1.0f) + (A + 1.0f) * cosOmega);
            a2 = (A + 1.0f) + (A - 1.0f) * cosOmega - 2.0f * sqrtA * alpha;
            break;
        }

        case FilterType::HighShelf:
        {
            const float sqrtA = std::sqrt(A);
            b0 = A * ((A + 1.0f) + (A - 1.0f) * cosOmega + 2.0f * sqrtA * alpha);
            b1 = -2.0f * A * ((A - 1.0f) + (A + 1.0f) * cosOmega);
            b2 = A * ((A + 1.0f) + (A - 1.0f) * cosOmega - 2.0f * sqrtA * alpha);
            a0 = (A + 1.0f) - (A - 1.0f) * cosOmega + 2.0f * sqrtA * alpha;
            a1 = 2.0f * ((A - 1.0f) - (A + 1.0f) * cosOmega);
            a2 = (A + 1.0f) - (A - 1.0f) * cosOmega - 2.0f * sqrtA * alpha;
            break;
        }

        case FilterType::LowPass:
        {
            b0 = (1.0f - cosOmega) / 2.0f;
            b1 = 1.0f - cosOmega;
            b2 = (1.0f - cosOmega) / 2.0f;
            a0 = 1.0f + alpha;
            a1 = -2.0f * cosOmega;
            a2 = 1.0f - alpha;
            break;
        }

        case FilterType::HighPass:
        {
            b0 = (1.0f + cosOmega) / 2.0f;
            b1 = -(1.0f + cosOmega);
            b2 = (1.0f + cosOmega) / 2.0f;
            a0 = 1.0f + alpha;
            a1 = -2.0f * cosOmega;
            a2 = 1.0f - alpha;
            break;
        }

        case FilterType::BandPass:
        {
            b0 = alpha;
            b1 = 0.0f;
            b2 = -alpha;
            a0 = 1.0f + alpha;
            a1 = -2.0f * cosOmega;
            a2 = 1.0f - alpha;
            break;
        }

        case FilterType::Notch:
        {
            b0 = 1.0f;
            b1 = -2.0f * cosOmega;
            b2 = 1.0f;
            a0 = 1.0f + alpha;
            a1 = -2.0f * cosOmega;
            a2 = 1.0f - alpha;
            break;
        }

        case FilterType::AllPass:
        {
            b0 = 1.0f - alpha;
            b1 = -2.0f * cosOmega;
            b2 = 1.0f + alpha;
            a0 = 1.0f + alpha;
            a1 = -2.0f * cosOmega;
            a2 = 1.0f - alpha;
            break;
        }

        default:
        {
            // Unity gain (bypass)
            b0 = 1.0f;
            b1 = 0.0f;
            b2 = 0.0f;
            a0 = 1.0f;
            a1 = 0.0f;
            a2 = 0.0f;
            break;
        }
    }

    // Normalize coefficients
    c.b0 = b0 / a0;
    c.b1 = b1 / a0;
    c.b2 = b2 / a0;
    c.a1 = a1 / a0;
    c.a2 = a2 / a0;

    return c;
}

void ParametricEQ::updateCoefficients()
{
    for (size_t i = 0; i < bands.size(); ++i)
    {
        coefficients[i] = calculateCoefficients(bands[i]);
    }
}

//==============================================================================
// Initialization
//==============================================================================

void ParametricEQ::initializeDefaultBands(int numBands)
{
    bands.clear();
    bands.reserve(numBands);

    // Default frequencies across spectrum (logarithmically spaced)
    const std::array<float, 32> frequencies = {
        30.0f, 40.0f, 60.0f, 80.0f, 100.0f, 150.0f, 250.0f, 400.0f,
        630.0f, 1000.0f, 1600.0f, 2500.0f, 4000.0f, 6000.0f, 8000.0f, 10000.0f,
        12000.0f, 14000.0f, 16000.0f, 18000.0f, 20000.0f,
        50.0f, 125.0f, 315.0f, 800.0f, 2000.0f, 5000.0f, 12500.0f,
        70.0f, 180.0f, 500.0f, 1250.0f
    };

    for (int i = 0; i < numBands; ++i)
    {
        float freq = frequencies[i % frequencies.size()];

        Band band;
        band.frequency = freq;
        band.gain = 0.0f;
        band.q = 1.0f;
        band.type = FilterType::Peak;
        band.enabled = true;

        bands.push_back(band);
    }
}

//==============================================================================
// Presets
//==============================================================================

void ParametricEQ::loadPreset(const juce::String& presetName)
{
    if (presetName == "Neutral" || presetName == "Flat")
    {
        for (auto& band : bands)
            band.gain = 0.0f;
    }
    else if (presetName == "Warmth")
    {
        if (bands.size() >= 3)
        {
            setBandGain(0, 2.0f);   // Low boost
            setBandGain(1, 1.0f);   // Low-mid boost
            setBandGain(bands.size() - 1, -1.0f);  // High roll-off
        }
    }
    else if (presetName == "Brightness")
    {
        if (bands.size() >= 2)
        {
            setBandGain(bands.size() - 2, 3.0f);
            setBandGain(bands.size() - 1, 4.0f);
        }
    }
    else if (presetName == "Vocal")
    {
        if (bands.size() >= 5)
        {
            setBandGain(0, -2.0f);   // Cut rumble
            setBandGain(1, 1.0f);    // Body
            setBandGain(2, 2.0f);    // Presence
            setBandGain(3, 3.0f);    // Air
            setBandGain(4, 1.0f);    // Sparkle
        }
    }
    else if (presetName == "Bass Boost")
    {
        if (bands.size() >= 2)
        {
            setBandGain(0, 6.0f);
            setBandGain(1, 3.0f);
        }
    }

    updateCoefficients();
}

//==============================================================================
// Utility
//==============================================================================

float ParametricEQ::getFrequencyResponse(float frequency) const
{
    float totalGain = 0.0f;

    for (const auto& band : bands)
    {
        if (!band.enabled)
            continue;

        // Simplified frequency response calculation
        // In production, calculate actual biquad magnitude response

        float octaves = std::abs(std::log2(frequency / band.frequency));
        float attenuation = std::exp(-octaves * band.q);

        totalGain += band.gain * attenuation;
    }

    return totalGain;
}

juce::String ParametricEQ::getFilterTypeName(FilterType type)
{
    switch (type)
    {
        case FilterType::LowShelf:    return "Low Shelf";
        case FilterType::HighShelf:   return "High Shelf";
        case FilterType::Peak:        return "Peak";
        case FilterType::LowPass:     return "Low Pass";
        case FilterType::HighPass:    return "High Pass";
        case FilterType::BandPass:    return "Band Pass";
        case FilterType::Notch:       return "Notch";
        case FilterType::AllPass:     return "All Pass";
        default:                      return "Unknown";
    }
}
