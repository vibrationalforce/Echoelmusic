#include "MultibandCompressor.h"

//==============================================================================
// Constructor
//==============================================================================

MultibandCompressor::MultibandCompressor()
{
    // Initialize 4-band default configuration
    bands[0] = Band(0.0f, 100.0f, -20.0f, 3.0f);        // Sub/Bass
    bands[1] = Band(100.0f, 1000.0f, -18.0f, 2.5f);     // Low-mid
    bands[2] = Band(1000.0f, 8000.0f, -15.0f, 2.0f);    // Mid-high
    bands[3] = Band(8000.0f, 20000.0f, -12.0f, 2.0f);   // High

    // Default attack/release
    for (auto& band : bands)
    {
        band.attack = 10.0f;
        band.release = 100.0f;
        band.knee = 6.0f;
        band.makeupGain = 0.0f;
        band.enabled = true;
    }
}

//==============================================================================
// Processing
//==============================================================================

void MultibandCompressor::prepare(double sampleRate, int maxBlockSize)
{
    currentSampleRate = sampleRate;

    // Allocate band buffers
    for (auto& buffer : bandBuffers)
    {
        buffer.resize(maxBlockSize);
    }

    // Update coefficients
    updateCoefficients();

    // Reset states
    reset();
}

void MultibandCompressor::reset()
{
    // Reset band states
    for (auto& state : bandStates)
    {
        state.envelope.fill(0.0f);
        state.gainReduction.fill(0.0f);
        state.inputLevel.fill(0.0f);
        state.outputLevel.fill(0.0f);
    }

    // Reset crossover filter states
    for (auto& crossover : crossovers)
    {
        for (auto& channelState : crossover)
        {
            for (auto& lpf : channelState.lowpass)
            {
                lpf.x1 = lpf.x2 = lpf.y1 = lpf.y2 = 0.0f;
            }
            for (auto& hpf : channelState.highpass)
            {
                hpf.x1 = hpf.x2 = hpf.y1 = hpf.y2 = 0.0f;
            }
        }
    }
}

void MultibandCompressor::process(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    // Ensure pre-allocated buffers are large enough (only resize if needed)
    if (bandBuffers[0].size() < static_cast<size_t>(numSamples))
    {
        for (auto& buf : bandBuffers)
            buf.resize(numSamples);
    }

    // Process each channel independently
    for (int channel = 0; channel < numChannels && channel < 2; ++channel)
    {
        // 1. Split into frequency bands (using pre-allocated bandBuffers)
        splitIntoBands(buffer, bandBuffers, channel);

        // 2. Compress each band
        for (int bandIndex = 0; bandIndex < 4; ++bandIndex)
        {
            if (bands[bandIndex].enabled && !bands[bandIndex].bypass)
            {
                compressBand(bandBuffers[bandIndex], bandIndex, channel);
            }
        }

        // 3. Sum bands back together
        float* channelData = buffer.getWritePointer(channel);
        sumBands(bandBuffers, channelData, numSamples);
    }
}

//==============================================================================
// Band Management
//==============================================================================

MultibandCompressor::Band& MultibandCompressor::getBand(int index)
{
    jassert(index >= 0 && index < 4);
    return bands[index];
}

const MultibandCompressor::Band& MultibandCompressor::getBand(int index) const
{
    jassert(index >= 0 && index < 4);
    return bands[index];
}

void MultibandCompressor::setBand(int index, const Band& band)
{
    if (index >= 0 && index < 4)
    {
        bands[index] = band;
        updateCoefficients();
    }
}

void MultibandCompressor::setBandThreshold(int index, float threshold)
{
    if (index >= 0 && index < 4)
    {
        bands[index].threshold = juce::jlimit(-60.0f, 0.0f, threshold);
    }
}

void MultibandCompressor::setBandRatio(int index, float ratio)
{
    if (index >= 0 && index < 4)
    {
        bands[index].ratio = juce::jlimit(1.0f, 20.0f, ratio);
    }
}

void MultibandCompressor::setBandAttack(int index, float attack)
{
    if (index >= 0 && index < 4)
    {
        bands[index].attack = juce::jlimit(0.1f, 500.0f, attack);
        updateCoefficients();
    }
}

void MultibandCompressor::setBandRelease(int index, float release)
{
    if (index >= 0 && index < 4)
    {
        bands[index].release = juce::jlimit(10.0f, 5000.0f, release);
        updateCoefficients();
    }
}

void MultibandCompressor::setBandKnee(int index, float knee)
{
    if (index >= 0 && index < 4)
    {
        bands[index].knee = juce::jlimit(0.0f, 12.0f, knee);
    }
}

void MultibandCompressor::setBandMakeupGain(int index, float gain)
{
    if (index >= 0 && index < 4)
    {
        bands[index].makeupGain = juce::jlimit(0.0f, 24.0f, gain);
    }
}

void MultibandCompressor::setBandEnabled(int index, bool enabled)
{
    if (index >= 0 && index < 4)
    {
        bands[index].enabled = enabled;
    }
}

//==============================================================================
// Metering
//==============================================================================

float MultibandCompressor::getGainReduction(int bandIndex, int channel) const
{
    if (bandIndex >= 0 && bandIndex < 4 && channel >= 0 && channel < 2)
        return bandStates[bandIndex].gainReduction[channel];
    return 0.0f;
}

float MultibandCompressor::getInputLevel(int bandIndex, int channel) const
{
    if (bandIndex >= 0 && bandIndex < 4 && channel >= 0 && channel < 2)
        return bandStates[bandIndex].inputLevel[channel];
    return -100.0f;
}

float MultibandCompressor::getOutputLevel(int bandIndex, int channel) const
{
    if (bandIndex >= 0 && bandIndex < 4 && channel >= 0 && channel < 2)
        return bandStates[bandIndex].outputLevel[channel];
    return -100.0f;
}

//==============================================================================
// Internal Methods
//==============================================================================

void MultibandCompressor::splitIntoBands(const juce::AudioBuffer<float>& input,
                                         std::array<std::vector<float>, 4>& bandSignals,
                                         int channel)
{
    const int numSamples = input.getNumSamples();
    const float* inputData = input.getReadPointer(channel);

    // Copy input to temporary buffer
    std::vector<float> signal(inputData, inputData + numSamples);

    // Crossover frequencies (100Hz, 1kHz, 8kHz)
    const std::array<float, 3> crossoverFreqs = {100.0f, 1000.0f, 8000.0f};

    // Band 0: LP @ 100Hz
    bandSignals[0] = signal;
    applyButterworth(bandSignals[0].data(), numSamples, crossoverFreqs[0], false,
                     crossovers[0][channel].lowpass[0]);
    applyButterworth(bandSignals[0].data(), numSamples, crossoverFreqs[0], false,
                     crossovers[0][channel].lowpass[1]);

    // Band 1: BP 100Hz - 1kHz (HP @ 100Hz, LP @ 1kHz)
    bandSignals[1] = signal;
    applyButterworth(bandSignals[1].data(), numSamples, crossoverFreqs[0], true,
                     crossovers[0][channel].highpass[0]);
    applyButterworth(bandSignals[1].data(), numSamples, crossoverFreqs[0], true,
                     crossovers[0][channel].highpass[1]);
    applyButterworth(bandSignals[1].data(), numSamples, crossoverFreqs[1], false,
                     crossovers[1][channel].lowpass[0]);
    applyButterworth(bandSignals[1].data(), numSamples, crossoverFreqs[1], false,
                     crossovers[1][channel].lowpass[1]);

    // Band 2: BP 1kHz - 8kHz
    bandSignals[2] = signal;
    applyButterworth(bandSignals[2].data(), numSamples, crossoverFreqs[1], true,
                     crossovers[1][channel].highpass[0]);
    applyButterworth(bandSignals[2].data(), numSamples, crossoverFreqs[1], true,
                     crossovers[1][channel].highpass[1]);
    applyButterworth(bandSignals[2].data(), numSamples, crossoverFreqs[2], false,
                     crossovers[2][channel].lowpass[0]);
    applyButterworth(bandSignals[2].data(), numSamples, crossoverFreqs[2], false,
                     crossovers[2][channel].lowpass[1]);

    // Band 3: HP @ 8kHz
    bandSignals[3] = signal;
    applyButterworth(bandSignals[3].data(), numSamples, crossoverFreqs[2], true,
                     crossovers[2][channel].highpass[0]);
    applyButterworth(bandSignals[3].data(), numSamples, crossoverFreqs[2], true,
                     crossovers[2][channel].highpass[1]);
}

void MultibandCompressor::sumBands(const std::array<std::vector<float>, 4>& bandSignals,
                                   float* output,
                                   int numSamples)
{
    // Clear output
    juce::FloatVectorOperations::clear(output, numSamples);

    // Sum all bands
    for (int bandIndex = 0; bandIndex < 4; ++bandIndex)
    {
        if (bands[bandIndex].enabled)
        {
            juce::FloatVectorOperations::add(output, bandSignals[bandIndex].data(), numSamples);
        }
    }
}

void MultibandCompressor::compressBand(std::vector<float>& bandSignal,
                                       int bandIndex,
                                       int channel)
{
    const auto& band = bands[bandIndex];
    auto& state = bandStates[bandIndex];

    const int numSamples = static_cast<int>(bandSignal.size());
    float envelope = state.envelope[channel];

    // Pre-calculate makeup gain (linear)
    const float makeupGainLinear = juce::Decibels::decibelsToGain(band.makeupGain);

    float maxInputDb = -100.0f;
    float maxOutputDb = -100.0f;
    float maxGainReduction = 0.0f;

    for (int i = 0; i < numSamples; ++i)
    {
        const float inputSample = bandSignal[i];
        const float inputLevel = std::abs(inputSample);

        // Envelope follower (peak detection with attack/release)
        if (inputLevel > envelope)
        {
            envelope = state.attackCoeff * envelope + (1.0f - state.attackCoeff) * inputLevel;
        }
        else
        {
            envelope = state.releaseCoeff * envelope + (1.0f - state.releaseCoeff) * inputLevel;
        }

        // OPTIMIZATION: Use fast dB approximations (~5x faster than std::log/pow)
        const float envelopeDb = fastGainToDb(envelope);

        // Calculate compression
        const float gainReductionDb = calculateCompression(envelopeDb,
                                                           band.threshold,
                                                           band.ratio,
                                                           band.knee);

        // Apply compression + makeup gain
        const float totalGainDb = -gainReductionDb + band.makeupGain;
        const float totalGainLinear = fastDbToGain(totalGainDb);

        bandSignal[i] = inputSample * totalGainLinear;

        // Update metering
        maxInputDb = std::max(maxInputDb, envelopeDb);
        maxOutputDb = std::max(maxOutputDb, envelopeDb + totalGainDb);
        maxGainReduction = std::max(maxGainReduction, gainReductionDb);
    }

    // Store state for next buffer
    state.envelope[channel] = envelope;

    // Update metering (smoothed)
    const float meterSmoothing = 0.3f;
    state.inputLevel[channel] = state.inputLevel[channel] * (1.0f - meterSmoothing) + maxInputDb * meterSmoothing;
    state.outputLevel[channel] = state.outputLevel[channel] * (1.0f - meterSmoothing) + maxOutputDb * meterSmoothing;
    state.gainReduction[channel] = state.gainReduction[channel] * (1.0f - meterSmoothing) + maxGainReduction * meterSmoothing;
}

float MultibandCompressor::calculateCompression(float envelopeDb,
                                                float threshold,
                                                float ratio,
                                                float knee) const
{
    if (envelopeDb <= threshold)
        return 0.0f;  // No compression below threshold

    const float excess = envelopeDb - threshold;

    // Soft knee
    if (excess < knee)
    {
        const float kneeRatio = excess / knee;
        return kneeRatio * kneeRatio * excess * (1.0f - 1.0f / ratio) / 2.0f;
    }

    // Above knee (linear compression)
    return (excess - knee / 2.0f) * (1.0f - 1.0f / ratio);
}

void MultibandCompressor::updateCoefficients()
{
    for (int i = 0; i < 4; ++i)
    {
        const auto& band = bands[i];
        auto& state = bandStates[i];

        // Attack coefficient (time to reach 63% of target)
        state.attackCoeff = std::exp(-1000.0f / (band.attack * static_cast<float>(currentSampleRate)));

        // Release coefficient
        state.releaseCoeff = std::exp(-1000.0f / (band.release * static_cast<float>(currentSampleRate)));
    }
}

void MultibandCompressor::applyButterworth(float* signal,
                                           int numSamples,
                                           float frequency,
                                           bool isHighpass,
                                           ButterworthState& state)
{
    // Butterworth 2nd order coefficients
    const float omega = juce::MathConstants<float>::twoPi * frequency / static_cast<float>(currentSampleRate);
    const float cosOmega = std::cos(omega);
    const float sinOmega = std::sin(omega);
    const float alpha = sinOmega / (2.0f * 0.707f);  // Q = 0.707 for Butterworth

    float b0, b1, b2, a0, a1, a2;

    if (isHighpass)
    {
        b0 = (1.0f + cosOmega) / 2.0f;
        b1 = -(1.0f + cosOmega);
        b2 = (1.0f + cosOmega) / 2.0f;
        a0 = 1.0f + alpha;
        a1 = -2.0f * cosOmega;
        a2 = 1.0f - alpha;
    }
    else  // Lowpass
    {
        b0 = (1.0f - cosOmega) / 2.0f;
        b1 = 1.0f - cosOmega;
        b2 = (1.0f - cosOmega) / 2.0f;
        a0 = 1.0f + alpha;
        a1 = -2.0f * cosOmega;
        a2 = 1.0f - alpha;
    }

    // Normalize
    b0 /= a0;
    b1 /= a0;
    b2 /= a0;
    a1 /= a0;
    a2 /= a0;

    // Apply filter
    for (int i = 0; i < numSamples; ++i)
    {
        const float x0 = signal[i];
        const float y0 = b0 * x0 + b1 * state.x1 + b2 * state.x2
                         - a1 * state.y1 - a2 * state.y2;

        signal[i] = y0;

        // Update state
        state.x2 = state.x1;
        state.x1 = x0;
        state.y2 = state.y1;
        state.y1 = y0;
    }
}
