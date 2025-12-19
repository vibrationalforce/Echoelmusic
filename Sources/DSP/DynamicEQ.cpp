#include "DynamicEQ.h"

//==============================================================================
// Constructor
//==============================================================================

DynamicEQ::DynamicEQ()
{
    // Initialize default bands across frequency spectrum
    const std::array<float, 8> frequencies = {
        60.0f, 150.0f, 400.0f, 1000.0f, 2500.0f, 6000.0f, 12000.0f, 16000.0f
    };

    for (int i = 0; i < 8; ++i)
    {
        bands[i].frequency = frequencies[i];
        bands[i].gain = 0.0f;
        bands[i].q = 1.0f;
        bands[i].filterType = ParametricEQ::Band::Type::Bell;
        bands[i].dynamicMode = DynamicMode::Static;
        bands[i].threshold = -20.0f;
        bands[i].ratio = 3.0f;
        bands[i].attack = 10.0f;
        bands[i].release = 100.0f;
        bands[i].enabled = (i < 4);  // Enable first 4 bands by default
    }

    // Initialize FFT data
    fftData.fill(0.0f);
    spectrumData.fill(0.0f);
}

//==============================================================================
// Processing
//==============================================================================

void DynamicEQ::prepare(double sampleRate, int maxBlockSize)
{
    juce::ignoreUnused(maxBlockSize);

    currentSampleRate = sampleRate;

    // Update all band coefficients
    for (int i = 0; i < 8; ++i)
    {
        updateBandCoefficients(i);
    }

    reset();
}

void DynamicEQ::reset()
{
    for (auto& state : bandStates)
    {
        state.envelope.fill(0.0f);
        state.gainReduction.fill(0.0f);

        // Reset JUCE filters
        for (auto& filter : state.filters)
        {
            filter.reset();
        }
    }

    fftData.fill(0.0f);
    fftDataIndex = 0;
}

void DynamicEQ::process(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    if (numChannels < 2)
        return;

    float* leftChannel = buffer.getWritePointer(0);
    float* rightChannel = buffer.getWritePointer(1);

    // Update spectrum analyzer
    if (spectrumEnabled)
    {
        updateSpectrumData(buffer);
    }

    // Check if any band is soloed
    bool anySolo = false;
    for (const auto& band : bands)
    {
        if (band.enabled && band.solo)
        {
            anySolo = true;
            break;
        }
    }

    // Process each band
    for (int bandIndex = 0; bandIndex < 8; ++bandIndex)
    {
        const auto& band = bands[bandIndex];

        // Skip disabled bands
        if (!band.enabled)
            continue;

        // Skip non-soloed bands if any band is soloed
        if (anySolo && !band.solo)
            continue;

        processBand(bandIndex, leftChannel, rightChannel, numSamples);
    }
}

//==============================================================================
// Band Management
//==============================================================================

DynamicEQ::Band& DynamicEQ::getBand(int index)
{
    jassert(index >= 0 && index < 8);
    return bands[index];
}

const DynamicEQ::Band& DynamicEQ::getBand(int index) const
{
    jassert(index >= 0 && index < 8);
    return bands[index];
}

void DynamicEQ::setBand(int index, const Band& band)
{
    if (index >= 0 && index < 8)
    {
        bands[index] = band;
        updateBandCoefficients(index);
    }
}

void DynamicEQ::setBandFrequency(int index, float freq)
{
    if (index >= 0 && index < 8)
    {
        bands[index].frequency = juce::jlimit(20.0f, 20000.0f, freq);
        updateBandCoefficients(index);
    }
}

void DynamicEQ::setBandGain(int index, float gain)
{
    if (index >= 0 && index < 8)
    {
        bands[index].gain = juce::jlimit(-24.0f, 24.0f, gain);
        updateBandCoefficients(index);
    }
}

void DynamicEQ::setBandQ(int index, float q)
{
    if (index >= 0 && index < 8)
    {
        bands[index].q = juce::jlimit(0.1f, 20.0f, q);
        updateBandCoefficients(index);
    }
}

void DynamicEQ::setBandDynamicMode(int index, DynamicMode mode)
{
    if (index >= 0 && index < 8)
    {
        bands[index].dynamicMode = mode;
    }
}

void DynamicEQ::setBandThreshold(int index, float threshold)
{
    if (index >= 0 && index < 8)
    {
        bands[index].threshold = juce::jlimit(-60.0f, 0.0f, threshold);
    }
}

void DynamicEQ::setBandRatio(int index, float ratio)
{
    if (index >= 0 && index < 8)
    {
        bands[index].ratio = juce::jlimit(1.0f, 20.0f, ratio);
    }
}

//==============================================================================
// Spectrum Analysis
//==============================================================================

std::vector<float> DynamicEQ::getSpectrumData() const
{
    std::lock_guard<std::mutex> lock(spectrumMutex);
    return std::vector<float>(spectrumData.begin(), spectrumData.end());
}

void DynamicEQ::setSpectrumAnalyzerEnabled(bool enabled)
{
    spectrumEnabled = enabled;
}

//==============================================================================
// Internal Methods
//==============================================================================

void DynamicEQ::processBand(int bandIndex,
                            float* leftChannel,
                            float* rightChannel,
                            int numSamples)
{
    auto& band = bands[bandIndex];
    auto& state = bandStates[bandIndex];

    // Mid/Side processing
    if (band.midSideMode)
    {
        for (int i = 0; i < numSamples; ++i)
        {
            // Convert to Mid/Side
            float mid = (leftChannel[i] + rightChannel[i]) * 0.5f;
            float side = (leftChannel[i] - rightChannel[i]) * 0.5f;

            // Process mid channel
            if (band.processMid)
            {
                // Detect level (for dynamics)
                float midLevel = std::abs(mid);

                if (band.dynamicMode != DynamicMode::Static)
                {
                    // Update envelope
                    if (midLevel > state.envelope[0])
                        state.envelope[0] = state.attackCoeff * state.envelope[0] + (1.0f - state.attackCoeff) * midLevel;
                    else
                        state.envelope[0] = state.releaseCoeff * state.envelope[0] + (1.0f - state.releaseCoeff) * midLevel;

                    // Calculate dynamic gain
                    float dynamicGain = calculateDynamicGain(midLevel, band, state.envelope[0]);

                    // Apply EQ with dynamic gain modulation
                    float eqGain = band.gain * dynamicGain;
                    // ... (Apply biquad filter with modulated gain)
                }
            }

            // Process side channel
            if (band.processSide)
            {
                // Similar processing for side channel
            }

            // Convert back to L/R
            leftChannel[i] = mid + side;
            rightChannel[i] = mid - side;
        }
    }
    else
    {
        // Stereo processing (L/R)
        for (int i = 0; i < numSamples; ++i)
        {
            // Process left channel
            float inputL = leftChannel[i];
            float levelL = std::abs(inputL);

            if (band.dynamicMode != DynamicMode::Static)
            {
                // Update envelope
                if (levelL > state.envelope[0])
                    state.envelope[0] = state.attackCoeff * state.envelope[0] + (1.0f - state.attackCoeff) * levelL;
                else
                    state.envelope[0] = state.releaseCoeff * state.envelope[0] + (1.0f - state.releaseCoeff) * levelL;

                // Calculate dynamic gain
                float envelopeDb = juce::Decibels::gainToDecibels(state.envelope[0] + 0.00001f);
                float dynamicGainMod = calculateDynamicGain(envelopeDb, band, state.envelope[0]);

                // Modulate EQ gain based on dynamics
                float modulatedGain = band.gain * dynamicGainMod;

                // Apply EQ with dynamic gain (simplified - use biquad with modulated gain)
                // For full implementation, recalculate biquad coefficients with dynamic gain
            }

            // Process right channel (similar)
            float inputR = rightChannel[i];
            float levelR = std::abs(inputR);

            if (band.dynamicMode != DynamicMode::Static)
            {
                if (levelR > state.envelope[1])
                    state.envelope[1] = state.attackCoeff * state.envelope[1] + (1.0f - state.attackCoeff) * levelR;
                else
                    state.envelope[1] = state.releaseCoeff * state.envelope[1] + (1.0f - state.releaseCoeff) * levelR;
            }
        }
    }
}

float DynamicEQ::calculateDynamicGain(float inputLevelDb,
                                      const Band& band,
                                      float envelope)
{
    juce::ignoreUnused(envelope);

    if (band.dynamicMode == DynamicMode::Static)
        return 1.0f;

    float gainMod = 1.0f;

    switch (band.dynamicMode)
    {
        case DynamicMode::DynamicCut:
        {
            // Reduce gain when signal exceeds threshold
            if (inputLevelDb > band.threshold)
            {
                float excess = inputLevelDb - band.threshold;

                // Soft knee
                if (excess < band.knee)
                {
                    float kneeRatio = excess / band.knee;
                    float reduction = kneeRatio * kneeRatio * excess * (1.0f - 1.0f / band.ratio) / 2.0f;
                    gainMod = 1.0f - (reduction / std::abs(band.gain));
                }
                else
                {
                    float reduction = (excess - band.knee / 2.0f) * (1.0f - 1.0f / band.ratio);
                    gainMod = 1.0f - (reduction / std::abs(band.gain));
                }
            }
            break;
        }

        case DynamicMode::DynamicBoost:
        {
            // Increase gain when signal exceeds threshold
            if (inputLevelDb > band.threshold)
            {
                float excess = inputLevelDb - band.threshold;
                float boost = excess * (band.ratio - 1.0f);
                gainMod = 1.0f + (boost / std::abs(band.gain));
            }
            break;
        }

        case DynamicMode::Expander:
        {
            // Reduce gain when signal is below threshold
            if (inputLevelDb < band.threshold)
            {
                float deficit = band.threshold - inputLevelDb;
                float reduction = deficit * (band.ratio - 1.0f);
                gainMod = 1.0f - (reduction / std::abs(band.gain));
            }
            break;
        }

        default:
            break;
    }

    return juce::jlimit(0.0f, 2.0f, gainMod);
}

void DynamicEQ::updateBandCoefficients(int bandIndex)
{
    auto& band = bands[bandIndex];
    auto& state = bandStates[bandIndex];

    // Calculate attack/release coefficients
    state.attackCoeff = std::exp(-1000.0f / (band.attack * static_cast<float>(currentSampleRate)));
    state.releaseCoeff = std::exp(-1000.0f / (band.release * static_cast<float>(currentSampleRate)));

    // Create JUCE IIR coefficients for peak/bell filter
    auto coefficients = juce::dsp::IIR::Coefficients<float>::makePeakFilter(
        currentSampleRate,
        band.frequency,
        band.q,
        juce::Decibels::decibelsToGain(band.gain)
    );

    // Apply coefficients to both stereo filters
    for (auto& filter : state.filters)
    {
        *filter.coefficients = *coefficients;
    }
}

void DynamicEQ::updateSpectrumData(const juce::AudioBuffer<float>& buffer)
{
    if (buffer.getNumChannels() == 0)
        return;

    const auto* channelData = buffer.getReadPointer(0);
    const int numSamples = buffer.getNumSamples();

    // Fill FFT buffer
    for (int i = 0; i < numSamples; ++i)
    {
        if (fftDataIndex < fftSize)
        {
            fftData[fftDataIndex] = channelData[i];
            fftDataIndex++;
        }

        if (fftDataIndex >= fftSize)
        {
            // Perform FFT
            window.multiplyWithWindowingTable(fftData.data(), fftSize);
            fft.performFrequencyOnlyForwardTransform(fftData.data());

            // Convert to spectrum bins
            std::lock_guard<std::mutex> lock(spectrumMutex);

            for (int bin = 0; bin < spectrumBins; ++bin)
            {
                float minFreq = 20.0f * std::pow(1000.0f, static_cast<float>(bin) / spectrumBins);
                float maxFreq = 20.0f * std::pow(1000.0f, static_cast<float>(bin + 1) / spectrumBins);

                int minFFTBin = static_cast<int>(minFreq / (currentSampleRate / fftSize));
                int maxFFTBin = static_cast<int>(maxFreq / (currentSampleRate / fftSize));

                float sum = 0.0f;
                int count = 0;

                for (int fftBin = minFFTBin; fftBin < maxFFTBin && fftBin < fftSize / 2; ++fftBin)
                {
                    sum += fftData[fftBin];
                    count++;
                }

                if (count > 0)
                {
                    float avgMagnitude = sum / count;
                    float db = juce::Decibels::gainToDecibels(avgMagnitude + 0.001f);
                    float normalized = juce::jmap(db, -60.0f, 0.0f, 0.0f, 1.0f);
                    spectrumData[bin] = juce::jlimit(0.0f, 1.0f, normalized);
                }
            }

            fftDataIndex = 0;
            fftData.fill(0.0f);
        }
    }
}
