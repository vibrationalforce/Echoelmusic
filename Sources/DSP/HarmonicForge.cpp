#include "HarmonicForge.h"

//==============================================================================
// Constructor
//==============================================================================

HarmonicForge::HarmonicForge()
{
    // Initialize default band crossovers
    bands[0].lowCutFreq = 20.0f;
    bands[0].highCutFreq = crossover1;

    bands[1].lowCutFreq = crossover1;
    bands[1].highCutFreq = crossover2;

    bands[2].lowCutFreq = crossover2;
    bands[2].highCutFreq = crossover3;

    bands[3].lowCutFreq = crossover3;
    bands[3].highCutFreq = 20000.0f;

    // Initialize spectrum data
    for (auto& state : bandStates)
    {
        state.spectrumData.resize(128, -100.0f);
    }

    // Initialize lock-free double buffers for each band
    for (auto& bandBuffers : spectrumBuffers)
    {
        for (auto& buffer : bandBuffers)
        {
            buffer.resize(128, -100.0f);
        }
    }
}

//==============================================================================
// Processing Mode
//==============================================================================

void HarmonicForge::setMultibandMode(bool enabled)
{
    if (multibandEnabled != enabled)
    {
        multibandEnabled = enabled;
        reset();
    }
}

//==============================================================================
// Band Management
//==============================================================================

HarmonicForge::Band& HarmonicForge::getBand(int index)
{
    jassert(index >= 0 && index < 4);
    return bands[index];
}

const HarmonicForge::Band& HarmonicForge::getBand(int index) const
{
    jassert(index >= 0 && index < 4);
    return bands[index];
}

void HarmonicForge::setBand(int index, const Band& band)
{
    jassert(index >= 0 && index < 4);
    bands[index] = band;
}

void HarmonicForge::setBandEnabled(int index, bool enabled)
{
    jassert(index >= 0 && index < 4);
    bands[index].enabled = enabled;
}

void HarmonicForge::setBandSaturationType(int index, SaturationType type)
{
    jassert(index >= 0 && index < 4);
    bands[index].saturationType = type;
}

void HarmonicForge::setBandDrive(int index, float drive)
{
    jassert(index >= 0 && index < 4);
    bands[index].drive = juce::jlimit(0.0f, 1.0f, drive);
}

void HarmonicForge::setBandMix(int index, float mix)
{
    jassert(index >= 0 && index < 4);
    bands[index].mix = juce::jlimit(0.0f, 1.0f, mix);
}

void HarmonicForge::setBandOutput(int index, float output)
{
    jassert(index >= 0 && index < 4);
    bands[index].output = juce::jlimit(0.0f, 2.0f, output);
}

//==============================================================================
// Global Parameters
//==============================================================================

void HarmonicForge::setInputGain(float gainDb)
{
    inputGainDb = juce::jlimit(-20.0f, 20.0f, gainDb);
}

void HarmonicForge::setOutputGain(float gainDb)
{
    outputGainDb = juce::jlimit(-20.0f, 20.0f, gainDb);
}

void HarmonicForge::setAutoMakeupGain(bool enabled)
{
    autoMakeupGain = enabled;
}

void HarmonicForge::setOversamplingFactor(int factor)
{
    if (factor == 1 || factor == 2 || factor == 4 || factor == 8)
    {
        oversamplingFactor = factor;
    }
}

//==============================================================================
// Crossover
//==============================================================================

void HarmonicForge::setCrossoverFrequencies(float low, float mid1, float mid2)
{
    crossover1 = juce::jlimit(20.0f, 20000.0f, low);
    crossover2 = juce::jlimit(crossover1, 20000.0f, mid1);
    crossover3 = juce::jlimit(crossover2, 20000.0f, mid2);

    // Update band frequencies
    bands[0].lowCutFreq = 20.0f;
    bands[0].highCutFreq = crossover1;

    bands[1].lowCutFreq = crossover1;
    bands[1].highCutFreq = crossover2;

    bands[2].lowCutFreq = crossover2;
    bands[2].highCutFreq = crossover3;

    bands[3].lowCutFreq = crossover3;
    bands[3].highCutFreq = 20000.0f;

    updateCrossoverCoefficients();
}

//==============================================================================
// Processing
//==============================================================================

void HarmonicForge::prepare(double sampleRate, int maxBlockSize)
{
    currentSampleRate = sampleRate;

    // Prepare oversampling
    if (oversamplingFactor > 1)
    {
        oversampling = std::make_unique<juce::dsp::Oversampling<float>>(
            2,  // stereo
            static_cast<size_t>(std::log2(oversamplingFactor)),
            juce::dsp::Oversampling<float>::filterHalfBandPolyphaseIIR
        );

        juce::dsp::ProcessSpec spec;
        spec.sampleRate = sampleRate;
        spec.maximumBlockSize = static_cast<juce::uint32>(maxBlockSize);
        spec.numChannels = 2;

        oversampling->initProcessing(static_cast<size_t>(maxBlockSize));
    }

    updateCrossoverCoefficients();
    reset();
}

void HarmonicForge::reset()
{
    for (auto& state : bandStates)
    {
        std::fill(state.filterState.begin(), state.filterState.end(), 0.0f);
        state.inputPeak = 0.0f;
        state.outputPeak = 0.0f;
    }

    if (oversampling)
    {
        oversampling->reset();
    }
}

void HarmonicForge::process(juce::AudioBuffer<float>& buffer)
{
    // Apply input gain
    if (std::abs(inputGainDb) > 0.1f)
    {
        buffer.applyGain(juce::Decibels::decibelsToGain(inputGainDb));
    }

    // Process based on mode
    if (multibandEnabled)
    {
        processMultiband(buffer);
    }
    else
    {
        processSingleBand(buffer);
    }

    // Apply output gain
    if (std::abs(outputGainDb) > 0.1f)
    {
        buffer.applyGain(juce::Decibels::decibelsToGain(outputGainDb));
    }
}

//==============================================================================
// Visualization
//==============================================================================

std::vector<float> HarmonicForge::getHarmonicSpectrum(int bandIndex) const
{
    if (bandIndex >= 0 && bandIndex < 4)
    {
        // Lock-free read from UI thread
        auto& fifo = const_cast<juce::AbstractFifo&>(spectrumFifos[bandIndex]);
        int start1, size1, start2, size2;
        fifo.prepareToRead(1, start1, size1, start2, size2);

        if (size1 > 0)
        {
            const auto& sourceBuffer = spectrumBuffers[bandIndex][start1];
            const_cast<HarmonicForge*>(this)->bandStates[bandIndex].spectrumData = sourceBuffer;
            fifo.finishedRead(size1);
        }

        return bandStates[bandIndex].spectrumData;
    }

    return std::vector<float>(128, -100.0f);
}

float HarmonicForge::getInputLevel(int bandIndex) const
{
    if (bandIndex >= 0 && bandIndex < 4)
    {
        return juce::Decibels::gainToDecibels(bandStates[bandIndex].inputPeak);
    }
    return -100.0f;
}

float HarmonicForge::getOutputLevel(int bandIndex) const
{
    if (bandIndex >= 0 && bandIndex < 4)
    {
        return juce::Decibels::gainToDecibels(bandStates[bandIndex].outputPeak);
    }
    return -100.0f;
}

//==============================================================================
// Internal Methods - Single Band
//==============================================================================

void HarmonicForge::processSingleBand(juce::AudioBuffer<float>& buffer)
{
    processBand(buffer, 0);
}

//==============================================================================
// Internal Methods - Multiband
//==============================================================================

void HarmonicForge::processMultiband(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    // Split into 4 bands using crossover
    std::array<juce::AudioBuffer<float>, 4> bandBuffers;
    for (auto& bandBuffer : bandBuffers)
    {
        bandBuffer.setSize(numChannels, numSamples);
    }

    applyCrossover(buffer, bandBuffers);

    // Process each band
    for (int i = 0; i < 4; ++i)
    {
        if (bands[i].enabled)
        {
            processBand(bandBuffers[i], i);
        }
        else
        {
            bandBuffers[i].clear();
        }
    }

    // Sum bands back together
    buffer.clear();
    for (int i = 0; i < 4; ++i)
    {
        for (int ch = 0; ch < numChannels; ++ch)
        {
            buffer.addFrom(ch, 0, bandBuffers[i], ch, 0, numSamples);
        }
    }
}

//==============================================================================
// Crossover Filter (Simplified Linkwitz-Riley)
//==============================================================================

void HarmonicForge::applyCrossover(const juce::AudioBuffer<float>& input,
                                    std::array<juce::AudioBuffer<float>, 4>& bands)
{
    // Simplified crossover: use simple butterworth filters
    // For professional use, implement proper Linkwitz-Riley 4th order

    const int numSamples = input.getNumSamples();
    const int numChannels = input.getNumChannels();

    // For now, simple frequency-based splitting
    // Band 0: < crossover1
    // Band 1: crossover1 - crossover2
    // Band 2: crossover2 - crossover3
    // Band 3: > crossover3

    // Copy input to all bands (will filter later)
    for (auto& band : bands)
    {
        for (int ch = 0; ch < numChannels; ++ch)
        {
            band.copyFrom(ch, 0, input, ch, 0, numSamples);
        }
    }

    // Simple implementation: apply gain based on frequency content
    // (In production, implement proper crossover filters)
}

//==============================================================================
// Band Processing
//==============================================================================

void HarmonicForge::processBand(juce::AudioBuffer<float>& buffer, int bandIndex)
{
    auto& band = bands[bandIndex];
    auto& state = bandStates[bandIndex];

    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    // Update input meter
    updateMeters(bandIndex, buffer);

    // Store dry signal for parallel processing
    juce::AudioBuffer<float> dryBuffer(numChannels, numSamples);
    for (int ch = 0; ch < numChannels; ++ch)
    {
        dryBuffer.copyFrom(ch, 0, buffer, ch, 0, numSamples);
    }

    // Apply saturation
    for (int ch = 0; ch < numChannels; ++ch)
    {
        float* channelData = buffer.getWritePointer(ch);

        for (int i = 0; i < numSamples; ++i)
        {
            float input = channelData[i];
            float output = applySaturation(input, band.saturationType, band.drive);
            channelData[i] = output;
        }
    }

    // Auto-makeup gain
    if (autoMakeupGain && band.drive > 0.01f)
    {
        float makeupGain = calculateMakeupGain(band.drive);
        buffer.applyGain(makeupGain);
    }

    // Parallel mix
    if (band.mix < 0.999f)
    {
        for (int ch = 0; ch < numChannels; ++ch)
        {
            float* wetData = buffer.getWritePointer(ch);
            const float* dryData = dryBuffer.getReadPointer(ch);

            for (int i = 0; i < numSamples; ++i)
            {
                wetData[i] = dryData[i] * (1.0f - band.mix) + wetData[i] * band.mix;
            }
        }
    }

    // Output gain
    if (std::abs(band.output - 1.0f) > 0.01f)
    {
        buffer.applyGain(band.output);
    }

    // Update output meter
    state.outputPeak = buffer.getMagnitude(0, numSamples);
}

//==============================================================================
// Saturation Algorithms
//==============================================================================

float HarmonicForge::applySaturation(float input, SaturationType type, float drive)
{
    switch (type)
    {
        case SaturationType::Tube:
            return tubeSaturation(input, drive);

        case SaturationType::Tape:
            return tapeSaturation(input, drive);

        case SaturationType::Transistor:
            return transistorSaturation(input, drive);

        case SaturationType::Digital:
            return digitalSaturation(input, drive);

        case SaturationType::Transformer:
            return transformerSaturation(input, drive);

        default:
            return input;
    }
}

float HarmonicForge::tubeSaturation(float input, float drive)
{
    // Tube saturation: smooth, warm, emphasizes even harmonics
    // Uses asymmetric soft-clipping

    float driven = input * (1.0f + drive * 10.0f);

    // Add DC bias for asymmetry (even harmonics)
    float bias = 0.1f * drive;
    driven += bias;

    // Soft-clip with tanh
    float output = std::tanh(driven);

    // Remove DC offset
    output -= std::tanh(bias);

    return output;
}

float HarmonicForge::tapeSaturation(float input, float drive)
{
    // Tape saturation: soft knee, warm, vintage character
    // Softer than tube, more gradual onset

    float driven = input * (1.0f + drive * 5.0f);

    // Soft saturation curve (similar to analog tape)
    if (std::abs(driven) < 0.3f)
    {
        return driven;  // Linear region
    }
    else if (std::abs(driven) < 1.0f)
    {
        // Soft knee region
        float sign = (driven > 0.0f) ? 1.0f : -1.0f;
        float abs_x = std::abs(driven);
        return sign * (0.3f + (abs_x - 0.3f) * 0.7f);
    }
    else
    {
        // Hard saturation
        return std::tanh(driven);
    }
}

float HarmonicForge::transistorSaturation(float input, float drive)
{
    // Transistor saturation: solid-state, harder clipping
    // More aggressive than tube, odd harmonics

    float driven = input * (1.0f + drive * 15.0f);

    // Hard clipping with softer edges
    if (std::abs(driven) < 1.0f)
    {
        return driven;
    }
    else
    {
        float sign = (driven > 0.0f) ? 1.0f : -1.0f;
        return sign * (1.0f + std::tanh((std::abs(driven) - 1.0f) * 2.0f) * 0.3f);
    }
}

float HarmonicForge::digitalSaturation(float input, float drive)
{
    // Digital saturation: hard clipping, bit reduction
    // Aggressive, modern sound

    float driven = input * (1.0f + drive * 20.0f);

    // Hard clip
    float clipped = juce::jlimit(-1.0f, 1.0f, driven);

    // Bit reduction (quantization)
    int bits = static_cast<int>(16 - drive * 12);  // 16-bit to 4-bit
    if (bits < 16)
    {
        float maxValue = std::pow(2.0f, bits) - 1.0f;
        clipped = std::round(clipped * maxValue) / maxValue;
    }

    return clipped;
}

float HarmonicForge::transformerSaturation(float input, float drive)
{
    // Transformer saturation: subtle, musical harmonics
    // Very gentle, adds weight without obvious distortion

    float driven = input * (1.0f + drive * 3.0f);

    // Very soft saturation
    float output = driven / (1.0f + std::abs(driven) * 0.3f);

    // Add subtle even harmonics
    output += std::sin(driven * juce::MathConstants<float>::pi) * drive * 0.1f;

    return output;
}

//==============================================================================
// Utilities
//==============================================================================

void HarmonicForge::updateCrossoverCoefficients()
{
    // Update Linkwitz-Riley crossover filter coefficients
    // (Simplified for now - would need proper biquad coefficient calculation)
}

void HarmonicForge::updateMeters(int bandIndex, const juce::AudioBuffer<float>& buffer)
{
    auto& state = bandStates[bandIndex];
    state.inputPeak = buffer.getMagnitude(0, buffer.getNumSamples());
}

float HarmonicForge::calculateMakeupGain(float drive) const
{
    // Calculate makeup gain to compensate for saturation
    // Approximate: higher drive = more gain reduction
    float gainReduction = 1.0f + drive * 2.0f;
    return std::sqrt(gainReduction);  // Compensate roughly
}
